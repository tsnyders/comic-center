param(
    [Parameter(Mandatory = $true)]
    [string]$Variant,
    [string]$Adb = 'C:\Users\tyrel\AppData\Local\Android\Sdk\platform-tools\adb.exe',
    [string]$Device = '192.168.0.132:45797',
    [string]$OutputDirectory = (Join-Path $env:TEMP 'yomi-memory-measurements'),
    [string]$Title = 'All-Class Awakening: God Slayer',
    [int]$Chapter = 1,
    [int]$MinimumPages = 150,
    [ValidateRange(1, 20)][int]$Repeats = 5,
    [ValidateRange(1, 1000)][int]$MaximumSwipes = 600,
    [ValidateRange(0, 60)][int]$SettleSeconds = 10
)

# Install the variant first. Uses the existing Sumi layout at 2112 x 1320,
# AllManga's first popular cover, and a fixed chapter in strip mode. Keeps
# app data/disk caches; updates reading progress as normal reader use does.
# Stop on a changed source/layout or failed load instead of recording a spinner.
$ErrorActionPreference = 'Stop'
$package = 'com.comiccenter.comic_center'
$invariant = [Globalization.CultureInfo]::InvariantCulture
$rows = [Collections.Generic.List[object]]::new()
$sequence = 0

function Invoke-Device([string[]]$Arguments) {
    # Windows PowerShell treats harmless native stderr (monkey/pull) as errors.
    $ErrorActionPreference = 'Continue'
    $result = & $Adb -s $Device @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ADB failed: $($Arguments -join ' ')" }
    return $result
}

function Read-Metric([string]$Text, [string]$Pattern) {
    $match = [regex]::Match($Text, $Pattern)
    if (!$match.Success) { return $null }
    return [long]::Parse($match.Groups[1].Value, $invariant)
}

function Read-Ui {
    Invoke-Device @('shell', 'uiautomator', 'dump', '/sdcard/yomi-memory.xml') | Out-Null
    $raw = (Invoke-Device @('shell', 'cat', '/sdcard/yomi-memory.xml')) -join "`n"
    $raw | Set-Content -Encoding UTF8 (Join-Path $runPath 'latest-ui.xml')
    return [xml]$raw
}

function Find-Node($Ui, [string]$Pattern) {
    return $Ui.SelectNodes('//node') | Where-Object {
        $_.'content-desc' -match $Pattern -or $_.text -match $Pattern
    } | Select-Object -First 1
}

function Tap-Node($Node) {
    if ($null -eq $Node) { throw 'Expected UI control is missing; inspect latest-ui.xml.' }
    $bounds = [regex]::Match($Node.bounds, '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$')
    if (!$bounds.Success) { throw 'Invalid UI bounds.' }
    $x = [int](([int]$bounds.Groups[1].Value + [int]$bounds.Groups[3].Value) / 2)
    $y = [int](([int]$bounds.Groups[2].Value + [int]$bounds.Groups[4].Value) / 2)
    Invoke-Device @('shell', 'input', 'tap', "$x", "$y") | Out-Null
}

function Save-Screen([string]$Name) {
    Invoke-Device @('shell', 'screencap', '-p', '/sdcard/yomi-memory.png') | Out-Null
    Invoke-Device @('pull', '/sdcard/yomi-memory.png', (Join-Path $runPath "$Name.png")) | Out-Null
}

function Save-Memory([string]$Checkpoint, [int]$Loop, [int]$Swipes = 0, [switch]$Full) {
    $script:sequence++
    $name = '{0:D3}-{1}-{2}' -f $script:sequence, $Loop, $Checkpoint
    $raw = (Invoke-Device @('shell', 'dumpsys', 'meminfo', $package)) -join "`n"
    $raw | Set-Content -Encoding UTF8 (Join-Path $runPath "$name.txt")
    $row = [pscustomobject]@{
        Variant = $Variant; Checkpoint = $Checkpoint; Loop = $Loop
        Timestamp = (Get-Date).ToString('o'); Swipes = $Swipes
        Pid = Read-Metric $raw 'MEMINFO in pid (\d+)'
        PssKB = Read-Metric $raw 'TOTAL PSS:\s*(\d+)'
        NativeKB = Read-Metric $raw '(?m)^\s*Native Heap\s+(\d+)'
        DalvikKB = Read-Metric $raw '(?m)^\s*Dalvik Heap\s+(\d+)'
        GraphicsKB = Read-Metric $raw 'Graphics:\s*(\d+)'
        PrivateOtherKB = Read-Metric $raw 'Private Other:\s*(\d+)'
        SwapPssKB = Read-Metric $raw 'TOTAL SWAP PSS:\s*(\d+)'
        WebViews = Read-Metric $raw 'WebViews:\s*(\d+)'
        RawFile = "$name.txt"
    }
    if ($null -eq $row.PssKB) { throw "Missing PSS at $name; measurement is invalid." }
    if ($rows.Count -gt 0 -and $row.Pid -ne $rows[0].Pid) {
        throw 'App process restarted during measurement; do not compare this run.'
    }
    $rows.Add($row)
    $rows | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runPath 'samples.csv')
    if ($Full) {
        $system = Invoke-Device @('shell', 'dumpsys', 'meminfo')
        $system | Set-Content -Encoding UTF8 (Join-Path $runPath "$name-system.txt")
        # Keep sandbox entries separate: a renderer without a client association
        # cannot safely be charged to this app from its name alone.
        $system | Select-String 'comiccenter|sandboxed_process' |
            Set-Content -Encoding UTF8 (Join-Path $runPath "$name-processes.txt")
        Save-Screen $name
    }
    Write-Host ("{0}: PSS {1:N1}, Native {2:N1}, Graphics {3:N1} MiB; WebViews {4}" -f
        $name, ($row.PssKB / 1024), ($row.NativeKB / 1024), ($row.GraphicsKB / 1024), $row.WebViews)
}

function Read-Reader($Ui) {
    $node = Find-Node $Ui 'Ch\. [\d.]+ . Page \d+ / \d+'
    if ($null -eq $node) { return $null }
    $match = [regex]::Match($node.'content-desc', 'Ch\. ([\d.]+) . Page (\d+) / (\d+)')
    return [pscustomobject]@{
        Chapter = $match.Groups[1].Value
        Page = [int]$match.Groups[2].Value
        Total = [int]$match.Groups[3].Value
    }
}

function Open-Reader {
    Invoke-Device @('shell', 'input', 'tap', '360', '740') | Out-Null
    Start-Sleep -Seconds 3
    $ui = Read-Ui
    if (!(Find-Node $ui ([regex]::Escape($Title)))) { throw 'Unexpected title; inspect latest-ui.xml.' }
    Invoke-Device @('shell', 'input', 'tap', '1010', '765') | Out-Null
    Start-Sleep -Seconds 12
    $ui = Read-Ui
    if ($null -eq (Read-Reader $ui)) {
        Invoke-Device @('shell', 'input', 'tap', '1056', '650') | Out-Null
        Start-Sleep -Seconds 1
        $ui = Read-Ui
    }
    $reader = Read-Reader $ui
    if ($null -eq $reader) { throw 'Reader did not load; inspect latest-ui.xml.' }
    if ($reader.Chapter -ne "$Chapter") {
        Tap-Node (Find-Node $ui '^Choose chapter')
        Start-Sleep -Seconds 1
        $ui = Read-Ui
        $chapterNode = Find-Node $ui "(^|\n)Chapter $Chapter`$"
        if ($null -eq $chapterNode) { throw 'Requested chapter is outside picker viewport; adjust preparation.' }
        Tap-Node $chapterNode
        Start-Sleep -Seconds 12
        $ui = Read-Ui
        $reader = Read-Reader $ui
    }
    if ($null -eq $reader -or $reader.Chapter -ne "$Chapter" -or $reader.Total -lt $MinimumPages) {
        throw 'Wrong chapter or insufficient pages; measurement is invalid.'
    }
    $strip = Find-Node $ui '^Strip . '
    if ($null -eq $strip) { throw 'Reader mode control missing.' }
    if ($strip.selected -ne 'true') { Tap-Node $strip; Start-Sleep -Seconds 1 }
    # The exact left edge of the scrubber resets saved progress to page one.
    Invoke-Device @('shell', 'input', 'tap', '66', '1174') | Out-Null
    Start-Sleep -Seconds 2
    $ui = Read-Ui
    $reader = Read-Reader $ui
    if ($reader.Page -gt 2) { throw 'Could not reset chapter to the beginning.' }
    Write-Host "Reading $Title, chapter $Chapter, $($reader.Total) images."
    return $reader.Total
}

if ((Invoke-Device @('get-state')) -ne 'device') { throw 'Tablet is not reachable.' }
$model = (Invoke-Device @('shell', 'getprop', 'ro.product.model')).Trim()
if ($model -ne 'SM-X406B') { throw "Expected SM-X406B; found $model. No gestures sent." }
$safeVariant = $Variant -replace '[^a-zA-Z0-9_-]', '_'
$runPath = Join-Path $OutputDirectory "$safeVariant-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
Write-Host "Raw evidence: $runPath"
$PSBoundParameters | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $runPath 'parameters.json')
Invoke-Device @('shell', 'dumpsys', 'package', $package) | Set-Content (Join-Path $runPath 'package.txt')
Invoke-Device @('shell', 'wm', 'size') | Set-Content (Join-Path $runPath 'display.txt')
Invoke-Device @('shell', 'dumpsys', 'battery') | Set-Content (Join-Path $runPath 'battery.txt')
$since = (Invoke-Device @('shell', "date '+%m-%d %H:%M:%S.000'")).Trim()
if ($since -notmatch '^\d\d-\d\d \d\d:\d\d:\d\d\.000$') { throw 'Unexpected tablet timestamp.' }

try {
    Invoke-Device @('shell', 'am', 'force-stop', $package) | Out-Null
    Invoke-Device @('shell', 'monkey', '-p', $package, '-c', 'android.intent.category.LAUNCHER', '1') | Out-Null
    Start-Sleep -Seconds $SettleSeconds
    $ui = Read-Ui
    if ($ui.hierarchy.rotation -ne '1' -or !(Find-Node $ui 'Your shelf')) {
        throw 'Expected landscape Library after launch.'
    }
    Save-Memory 'cold-library' -1 -Full
    Invoke-Device @('shell', 'input', 'tap', '269', '1204') | Out-Null
    Start-Sleep -Seconds 1
    for ($i = 0; $i -lt 2; $i++) {
        Invoke-Device @('shell', 'input', 'swipe', '1000', '1100', '1000', '200', '400') | Out-Null
        Start-Sleep -Milliseconds 500
    }
    $ui = Read-Ui
    Tap-Node (Find-Node $ui '(^|\n)AllManga(\n|$)')
    Start-Sleep -Seconds 10
    $ui = Read-Ui
    if (!(Find-Node $ui '^AllManga$')) { throw 'AllManga grid is not open.' }
    for ($i = 0; $i -lt 3; $i++) {
        Invoke-Device @('shell', 'input', 'swipe', '1000', '1100', '1000', '200', '400') | Out-Null
        Start-Sleep -Seconds 1
    }
    Start-Sleep -Seconds $SettleSeconds
    Save-Memory 'grid-scrolled' -1 -Full
    Invoke-Device @('shell', 'i=0; while [ "$i" -lt 6 ]; do input swipe 1000 300 1000 1100 400; i=$((i+1)); done') | Out-Null
    Start-Sleep -Seconds 2

    for ($loop = 0; $loop -le $Repeats; $loop++) {
        $total = Open-Reader
        Save-Memory 'reader-start' $loop -Full
        $swipes = 0
        do {
            Invoke-Device @('shell', 'i=0; while [ "$i" -lt 12 ]; do input swipe 1000 1100 1000 200 300; sleep 0.3; i=$((i+1)); done') | Out-Null
            $swipes += 12
            Start-Sleep -Seconds 2
            $ui = Read-Ui
            $reader = Read-Reader $ui
            if ($null -eq $reader -or $reader.Total -ne $total) { throw 'Reader changed during scroll.' }
            if (Find-Node $ui 'Failed to load') { throw 'Image load failure; measurement is invalid.' }
            Save-Memory 'reading' $loop $swipes
            Write-Host "Page $($reader.Page) / $total after $swipes swipes"
            if ($swipes -ge $MaximumSwipes -and $reader.Page -lt $total) { throw 'Chapter end was not reached.' }
        } while ($reader.Page -lt $total)
        Start-Sleep -Seconds $SettleSeconds
        Save-Memory 'reader-end' $loop $swipes -Full
        Invoke-Device @('shell', 'input', 'keyevent', '4') | Out-Null
        Start-Sleep -Seconds 1
        Invoke-Device @('shell', 'input', 'keyevent', '4') | Out-Null
        Start-Sleep -Seconds $SettleSeconds
        $ui = Read-Ui
        if (!(Find-Node $ui '^AllManga$')) { throw 'Did not return to grid.' }
        Save-Memory 'back-grid' $loop $swipes -Full
    }
    Start-Sleep -Seconds 60
    Save-Memory 'grid-idle-60s' $Repeats -Full
    Invoke-Device @('shell', 'dumpsys', 'activity', 'processes') |
        Set-Content (Join-Path $runPath 'activity-processes.txt')
} finally {
    Invoke-Device @('shell', "logcat -d -T '$since' -v threadtime") |
        Select-String 'GC|OutOfMemory|onTrimMemory|Skipped|FATAL EXCEPTION' |
        Set-Content -Encoding UTF8 (Join-Path $runPath 'logcat-memory.txt')
    $rows | Where-Object Checkpoint -ne 'reading' |
        Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runPath 'checkpoints.csv')
    Write-Host "Raw evidence: $runPath"
}
