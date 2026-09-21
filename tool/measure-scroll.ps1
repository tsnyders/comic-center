param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('cover-grid', 'allmanga-popular', 'chapter-list')]
    [string]$Screen,
    [Parameter(Mandatory = $true)]
    [string]$Variant,
    [string]$Adb = 'C:\Users\tyrel\AppData\Local\Android\Sdk\platform-tools\adb.exe',
    [string]$Device = 'adb-R5GYB0BAYNP-vFA66h._adb-tls-connect._tcp',
    [string]$OutputDirectory = (Join-Path $env:TEMP 'yomi-scroll-jank-measurements')
)

# Navigate to the named screen, at its top, before invoking this script.
# Keep title count, look, cover size, orientation and warm cache identical.
$ErrorActionPreference = 'Stop'
$package = 'com.comiccenter.comic_center'
$invariant = [Globalization.CultureInfo]::InvariantCulture

function Invoke-Device([string[]]$Arguments) {
    $result = & $Adb -s $Device @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB failed: $($Arguments -join ' ')" }
    return $result
}

function Read-Metric([string]$Text, [string]$Pattern) {
    $match = [regex]::Match($Text, $Pattern)
    if (!$match.Success) { return $null }
    return [double]::Parse($match.Groups[1].Value, $invariant)
}

function Get-Median($Values) {
    $ordered = @($Values | Sort-Object)
    if ($ordered.Count -ne 3 -or @($ordered | Where-Object { $null -eq $_ }).Count) {
        return $null
    }
    return $ordered[1]
}

if ((Invoke-Device @('get-state')) -ne 'device') { throw 'Tablet is not reachable.' }
$model = (Invoke-Device @('shell', 'getprop', 'ro.product.model')).Trim()
if ($model -ne 'SM-X406B') { throw "Expected SM-X406B; found $model. No scrolls sent." }
$safeVariant = $Variant -replace '[^a-zA-Z0-9_-]', '_'
$runPath = Join-Path $OutputDirectory "$safeVariant-$Screen-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
Invoke-Device @('shell', 'dumpsys', 'package', $package) | Set-Content (Join-Path $runPath 'package.txt')
Invoke-Device @('shell', 'wm', 'size') | Set-Content (Join-Path $runPath 'display.txt')
Invoke-Device @('shell', 'dumpsys', 'battery') | Set-Content (Join-Path $runPath 'battery.txt')

$rows = @()
for ($repeat = 1; $repeat -le 3; $repeat++) {
    # Reset scroll to top outside the measured interval. Warm all tested covers
    # before starting the first run; pagination/network work is a separate test.
    Invoke-Device @('shell', 'i=0; while [ "$i" -lt 12 ]; do input swipe 1000 300 1000 1000 250; i=$((i+1)); done') | Out-Null
    Start-Sleep -Seconds 2
    $since = (Invoke-Device @('shell', "date '+%m-%d %H:%M:%S.000'")).Trim()
    if ($since -notmatch '^\d\d-\d\d \d\d:\d\d:\d\d\.000$') { throw 'Unexpected tablet timestamp.' }
    Invoke-Device @('shell', 'dumpsys', 'gfxinfo', $package, 'reset') | Out-Null
    # One remote shell avoids host/ADB round-trip jitter between gestures.
    $scroll = 'i=0; while [ "$i" -lt 12 ]; do input swipe 1000 1000 1000 300 250; sleep 0.3; i=$((i+1)); done; i=0; while [ "$i" -lt 12 ]; do input swipe 1000 300 1000 1000 250; sleep 0.3; i=$((i+1)); done'
    Invoke-Device @('shell', $scroll) | Out-Null
    $raw = (Invoke-Device @('shell', 'dumpsys', 'gfxinfo', $package)) -join "`n"
    $raw | Set-Content -LiteralPath (Join-Path $runPath "gfxinfo-$repeat.txt")
    Invoke-Device @('shell', "logcat -d -T '$since' -v threadtime Choreographer:I flutter:I chromium:I '*:S'") |
        Set-Content -LiteralPath (Join-Path $runPath "logcat-$repeat.txt")
    $frames = Read-Metric $raw 'Total frames rendered:\s*(\d+)'
    $rows += [pscustomobject]@{
        Variant = $Variant; Screen = $Screen; Repeat = $repeat
        TotalFrames = $frames
        JankyFrames = Read-Metric $raw 'Janky frames:\s*(\d+)'
        JankyPercent = Read-Metric $raw 'Janky frames:\s*\d+\s*\(([\d.]+)%\)'
        P90ms = Read-Metric $raw '90th percentile:\s*([\d.]+)ms'
        P95ms = Read-Metric $raw '95th percentile:\s*([\d.]+)ms'
        P99ms = Read-Metric $raw '99th percentile:\s*([\d.]+)ms'
    }
    if ($null -eq $frames -or $frames -eq 0) {
        foreach ($metric in @('JankyFrames', 'JankyPercent', 'P90ms', 'P95ms', 'P99ms')) {
            $rows[-1].$metric = $null
        }
        Write-Warning 'gfxinfo did not observe frames. This is missing data, not zero Flutter jank; use a profile FrameTiming/Perfetto trace.'
    }
    Write-Output $rows[-1]
}
$rows | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runPath 'runs.csv')
$summary = [ordered]@{ Variant = $Variant; Screen = $Screen; Repeats = 3 }
foreach ($metric in @('TotalFrames', 'JankyFrames', 'JankyPercent', 'P90ms', 'P95ms', 'P99ms')) {
    $summary[$metric] = Get-Median @($rows | ForEach-Object { $_.$metric })
}
[pscustomobject]$summary | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runPath 'median.csv')
Write-Output ([pscustomobject]$summary)
Write-Output "Raw evidence: $runPath"
