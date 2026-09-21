# Scroll responsiveness investigation — 2026-09-21

Changes are uncommitted on `perf/scroll-jank`, based on
`bdbfa4b1d24970ca60bba5f52e8e888e53d2078e`. Validation used Flutter 3.44.3 /
Dart 3.12.2 on Windows. No packages were added.

**On-device measurements and AllManga reader acceptance are missing.** The
SM-X406B (`R5GYB0BAYNP`) did not appear in `adb devices -l` or `adb mdns services`
during the work. Those commands were polled every minute from 10:24 to 11:00
SAST; the log is preserved.
The other advertised device was not used. No APK was installed on a device.

## Before / after

Each cell should contain the median of three runs. No device measurements can
be inferred from the widget tests, successful builds, or this table.

| Screen | Variant | Total frames | Janky frames (%) | p90 / p95 / p99 (ms) |
|---|---|---|---|---|
| AllManga popular grid (gfxinfo, 3× median) | Baseline | 512 | 446 (87.6%) | 40 / 46 / 61 |
| AllManga popular grid (gfxinfo, 3× median) | Final | 0 observed | n/a | n/a |
| AllManga popular grid (SurfaceFlinger timestats, 3 rounds) | Baseline | 817 on the Activity window layer | 709 (86.8%), 101 buffer-stuffed | histogram not emitted by this device |
| AllManga popular grid (SurfaceFlinger timestats, 3 rounds) | Final | 2,245 on the Flutter SurfaceView layer | 0 (0%), 0 dropped | histogram not emitted by this device |
| Library grid / chapter list | both | not measured (library empty on the test tablet) | | |

Measured 2026-09-21 on SM-X406B (landscape 2112×1320, Sumi look) with the
preserved `baseline.apk` / `final.apk`. `gfxinfo` sees frames only while the
hybrid-composition WebView forces rendering through the Android view
hierarchy, which is why it reports nothing for the final build; the
SurfaceFlinger per-layer jank stats (`dumpsys SurfaceFlinger --timestats`)
cover both paths and are the like-for-like comparison. The baseline rendered
on the Activity window layer and dropped most frames; the final build renders
on the Flutter SurfaceView with no janky or dropped frames under the same
scripted scroll.

Local structural measurements, **not frame-rate measurements**:

| Workload | Original | Final | Evidence |
| --- | --- | --- | --- |
| Idle hybrid WebView widgets | 1, from original host construction | 0 | Host test also checks no controller is created and fetcher is already installed |
| Entrance animations for 20 mounted items | 20 | 6 | Same regression test run against original and changed widget code |
| Repeating loading animations for 20 covers | 20 | 4 | Same regression test run against original and changed widget code |
| Loading tickers with reduced motion | Device flag only | 0 for device or OS setting | Widget test |
| Grain pixels over light/dark backgrounds | Reference | 0 changed RGBA bytes | Decoded real asset; 100 × 100 widget render comparison |

Original motion code failed five of the six new motion tests, including the
20-versus-6 entrance count and 20-versus-4 loading-animation count. Source files
were restored byte-for-byte after this comparison. All six pass on the changes.

## Changes and provisional root-cause ranking

1. **Always-mounted hybrid WebView: strongest regression candidate.**
   `BrowserFetch.instance` remains installed, but controller creation and mounting
   occur inside the existing serial request queue. Requests wait for layout and
   configuration before navigation; the document-start bridge still retries
   native attachment. Success, errors, timeout, and challenge cancellation stop
   navigation and detach the view before another request can start. Active
   controllers ignore late navigation events from earlier, detached views;
   asynchronous page reads stay bound to their original controller. Active
   requests keep the same full-size challenge viewport, preserving the captcha
   layout. The app subtree retains its state through mounting/unmounting. Cookies
   are not cleared; cookie reads/clears do not mount a WebView. This removes the
   idle composition workload; its frame-time benefit is unmeasured.
   [Flutter documents hybrid composition's performance trade-offs](https://docs.flutter.dev/platform-integration/android/platform-views).
2. **Entrance animation on every newly built row.** `SumiStagger` now uses the
   existing six-item motion ceiling for participation as well as delay. Later
   items return their child directly, without an entrance controller, transform,
   or opacity layer. Initial motion uses the original duration and curve.
3. **Unbounded loading shimmers.** At most four placeholders animate across the
   app; additional placeholders retain the existing gradient at its midpoint.
   Slots are released on disposal. This cuts a 20-cover loading sample's repeating
   tickers by 80%; it is not a measured 80% frame-time improvement.
4. **Grain repainting: secondary, cost unmeasured.** The existing image is now
   inside a `RepaintBoundary`, with the same asset, tiling, opacity, and filtering.
   Flutter 3.44's `BoxDecoration.backgroundBlendMode` applies to its background
   color/gradient, not its `DecorationImage`. The old overlay mode affected only
   a transparent rectangle; the image already used `srcOver`. Removed that
   redundant paint, preserved the rendered pixels, and retained grain in Sumi.
   No claim that an expensive backdrop blend was the root cause.

The inspected hot paths retain default sliver repaint boundaries, have no
`shrinkWrap` grids, and do not watch a broad stream per cell on every frame.
Chapter download status is scoped by chapter ID. The root color tween has value
equality and settles; press feedback only changes on pointer state; the Sumi
painters already compare the inputs they paint. These paths were left alone.

## Validation and artifacts

- Baseline: `flutter analyze` — 77 findings (25 existing warnings, 52 infos);
  `flutter test --reporter expanded` — 258 passed.
- Final: `flutter analyze --no-pub` — identical diagnostic set; exit 1 remains
  due to those existing findings. No analyzer errors or new findings.
- Final: `flutter test --no-pub --reporter expanded` — 274 passed, including
  nine browser lifecycle tests, six motion tests, and the grain pixel comparison.
- Baseline, browser-only, and final release builds passed with
  `flutter build apk --release -P allowDebugSigning=true` (incremental builds
  also used `--no-pub`). All are debug-signed local release APKs. Existing plugin
  Kotlin migration warnings remain.
- `git diff --check` passed. `graphify update .` refreshed the ignored graph.
- Measurement script parsed successfully; synthetic ADB fixtures verified CSV
  extraction/medians and missing-frame handling. This was not a device run.

Evidence directory: `%TEMP%\yomi-scroll-jank-20260921`.
It contains baseline/final analyzer and test logs, build logs, the motion
comparison log, the minute-by-minute ADB log, and three APKs. Each APK is
96,249,610 bytes; their embedded ARM64 Dart AOT payload hashes differ.

| APK | SHA-256 |
| --- | --- |
| `baseline.apk` | `FA1A69EBBE8B3CFA1C59EC3CB1833ECC51E41FC0595ABB06AA5F32B753B22DA7` |
| `browser-only.apk` | `3FEA535D9251EFD53A79C56B6F4F2F06DC4A6CD7439A7F313BD76218D5E4AF29` |
| `final.apk` | `D5DC7053DD1C221B973CBA4F49294B44A1C5D25D5A839FA91838D464C80DA811` |

Files changed: `lib/core/browser/browser_host.dart`,
`lib/shared/widgets/sumi.dart`, `lib/shared/widgets/cover_image.dart`;
tests in `test/core/browser/browser_host_test.dart`,
`test/shared/widgets/scroll_motion_test.dart`,
`test/shared/widgets/washi_grain_test.dart`; this report and
`tool/measure-scroll.ps1`.

Exact final command tails:

```text
   info - Don't invoke 'print' in production code. Try using a logging framework - tool\diagnose_chapters.dart:170:5 - avoid_print

77 issues found. (ran in 47.0s)
```

```text
00:44 +273: C:/Projects/ClaudeCode/comic-center/test/widget_test.dart: placeholder test
00:44 +274: All tests passed!
```

## Tablet measurement and capture protocol

1. Poll once per minute until the specified tablet is reachable. If mDNS gives
   the same tablet with a new endpoint, connect that endpoint and use its current
   serial. Confirm `adb -s $D shell getprop ro.product.model` is `SM-X406B`.
   Keep landscape 2112 × 1320, the same look/cover size/refresh rate, and comparable
   temperature. Avoid active downloads and background library updates during
   the scroll sample. Record the title/source, look, cache state and orientation.
2. Install the preserved **baseline first**, immediately after `adb devices -l`:

   ```powershell
   $ADB = 'C:\Users\tyrel\AppData\Local\Android\Sdk\platform-tools\adb.exe'
   $D = 'adb-R5GYB0BAYNP-vFA66h._adb-tls-connect._tcp'
   $evidence = Join-Path $env:TEMP 'yomi-scroll-jank-20260921'
   & $ADB devices -l
   & $ADB -s $D install -r (Join-Path $evidence 'baseline.apk')
   & $ADB -s $D shell monkey -p com.comiccenter.comic_center -c android.intent.category.LAUNCHER 1
   ```

   If installation reports a signature mismatch, the user authorized uninstalling
   `com.comiccenter.comic_center` on this empty test tablet, then installing again.
   Repopulate identical test titles before measuring. Do not uninstall a different
   device/app. Build 85 at `C:\tmp\rel\yomi-beta-85.apk` was verified as
   95,315,017 bytes but was not installed; the optional historical comparison also
   requires a signing-key change and is not needed for the primary A/B.
3. Prepare each screen. Library: add 10–20 titles using title bookmarks, or use
   the populated Discover cover grid and label that substitution. Do not measure
   an empty shelf as a grid. AllManga: Discover `(211,1221)`, two
   `input swipe 1000 1100 1000 200 400`, AllManga row `(600,815)`. Chapter list:
   first cover `(360,740)`; confirm a title with at least 150 chapters. Coordinates
   are starting hints; verify the visible screen and record the actual title.
4. Warm the covers and any pagination for the scrolling range, return to the
   top, and run each screen separately:

   ```powershell
   .\tool\measure-scroll.ps1 -Screen cover-grid -Variant baseline
   .\tool\measure-scroll.ps1 -Screen allmanga-popular -Variant baseline
   .\tool\measure-scroll.ps1 -Screen chapter-list -Variant baseline
   ```

   The script verifies the tablet model, resets `gfxinfo`, sends 12 up swipes
   `(1000,1000) → (1000,300)` for 250ms with 300ms gaps, then 12 down swipes,
   and saves raw `gfxinfo` plus timestamp-filtered Choreographer/flutter/chromium
   logs. It repeats three times, resets to the top between runs, and emits
   `runs.csv` and per-metric `median.csv`. Check that scrolls actually move the
   intended list and do not spend most of the sample at its end.
5. Install `browser-only.apk`, repeat the identical three screens with
   `-Variant browser-only`, then `final.apk` with `-Variant final`. The first
   comparison isolates the browser lifecycle. To isolate subsequent changes,
   make cumulative local builds adding only the stagger hunk, then shimmer, then
   grain, repeating all three screens after each. Keep a named APK and source
   patch for each variant. No feature-disabling flag is present in the final code.
   An optional temporary no-`BrowserHost` build of the original source is a
   diagnostic control only; restore the app wrapper after building it.
6. **Interpret `gfxinfo` carefully.** Removing a hybrid platform view can change
   the Android View frames it observes. Zero/missing frames are missing data,
   not zero jank. Even nonzero counts need corroboration if frame coverage changes
   between variants. Use a profile build's Flutter frame timeline/`FrameTiming`
   or an Android Perfetto/SurfaceFlinger trace to compare actual Flutter rendering.
   Flutter's [frame timing API](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addTimingsCallback.html)
   reports build/raster durations; the
   [gfxinfo coverage issue](https://github.com/flutter/flutter/issues/91406)
   explains why Android View counters alone are insufficient for Flutter.
   Do not mix those metrics into the `gfxinfo` percentile columns.
7. On the final build, open an **AllManga chapter** and wait for actual page
   images, scroll several pages, return to the title, and open another chapter.
   If challenged, verify readable captcha sizing and touch input, then solve it;
   separately cancel and retry. Confirm capture hooks work after recreation and
   the app remains scrollable after returning. Save screenshots and targeted
   logs with the title/chapter IDs and observed page count. Local fake-platform
   capture tests do not establish that the Kotlin bridge or real pages work on
   the tablet. This acceptance step remains unverified.
