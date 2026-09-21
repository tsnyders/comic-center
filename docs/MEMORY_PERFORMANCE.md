Memory investigation on SM-X406B, 2026-09-21. Changes are uncommitted on
`perf/memory`; no packages were added. Flutter 3.44.3 / Dart 3.12.2 on Windows.

Six complete reads per APK showed no monotonic navigation leak. The candidate
reduced sampled peak PSS by **20.6%**, median reading PSS by **26.6%**, and final
idle-grid PSS from **484.1 to 351.6 MiB**. The fixed-page artwork comparison is
pixel-identical at 1x. Reader image retention is lower; native allocated heap and
cold-grid PSS were not improved in this run. Detailed measurements and limits
follow.

The baseline is the preserved `yomi-scroll-jank-20260921/final.apk`, SHA-256
`D5DC7053DD1C221B973CBA4F49294B44A1C5D25D5A839FA91838D464C80DA811`.
The candidate is a release APK built with
`flutter build apk --release -P allowDebugSigning=true`.
Its SHA-256 is
`665F13277DF5400D804560001E0F94B8F9F4BC41C09D8F8719C62604AD95B77E`.

The device workload uses landscape 2112 x 1320, Sumi, an empty Library,
AllManga's popular grid, and **All-Class Awakening: God Slayer, Chapter 1,
193 strip images**. Each variant starts with a force-stop/cold process launch,
three grid swipes, one complete chapter read, then five complete open/read/back
repeats. Each return goes through the title screen to the grid. The script
checks title, chapter, page count, page progress, return destination, and stable
app PID. It samples during reading every twelve swipes, settles for ten seconds
at end/back checkpoints, then measures the final grid again after sixty seconds.

Both installs preserve app data and disk caches. Initial baseline scouting
warmed some images; subsequent baseline reads and the candidate use warm disk
caches. Repeated reads are therefore the stronger comparison. Reading updates
normal chapter progress. This is one paired device run, not a population estimate
or a cold-network benchmark. Sampled peaks can miss short spikes between probes.

`tool/measure-memory.ps1` saves `samples.csv`, `checkpoints.csv`, raw app/system
`dumpsys meminfo`, checkpoint screenshots, UI evidence, and filtered logcat.
Run it after installing the relevant APK:

```powershell
flutter build apk --release -P allowDebugSigning=true
adb devices -l
adb -s 192.168.0.132:45797 install -r build/app/outputs/flutter-apk/app-release.apk
.\tool\measure-memory.ps1 -Variant after -Device 192.168.0.132:45797
```

The script requires this tablet/layout and the named title as the first cover.
It deliberately stops if source content, layout, chapter selection, or loading
changes. It does not clear storage or silently substitute another workload.

All reported values use MiB (raw Android KB divided by 1024). Native is the
**PSS column of the detailed Native Heap row**, not allocated heap size.
Graphics comes from App Summary. App PSS excludes the separate WebView renderer.
Swap PSS is retained in CSV: resident Native/PSS falling under memory pressure
does not by itself prove that allocations were freed. The requested
`dumpsys meminfo` instrumentation itself requests ART GC for object counts
([Android implementation](https://android.googlesource.com/platform/frameworks/base/+/android16-qpr2-release/core/java/android/app/ActivityThread.java));
the logs contain explicit GC. These are instrumented results using the same
method for both builds. No additional application GC or trim command was sent.

Changes and evidence:

- Reader strips keep one viewport on either side instead of 2.5 on regular
  devices. Decoded pages are evicted on disposal on all device tiers, retaining
  disk copies. Paged and strip decode widths remain physical screen width times
  2.0 (regular) or 1.25 (low spec); visible-image sharpness is not reduced.
  Real-decode widget tests cover both modes and tiers, offscreen eviction,
  reader teardown, and preservation of unrelated cached cover art.
- The shared decoded-image LRU is 64 MiB on regular devices and retains the
  existing 48 MiB low-spec ceiling. The 1000-entry limit is unchanged. Live
  viewport images, pending decodes, and engine/GPU allocations are additional;
  this is not a total-process memory limit. No named `extended_image` cache or
  raw-byte image cache is enabled in this app. Covers retain their existing
  350 logical pixels times DPR decode width.
- Chapter URL lists retain the existing fifteen-minute expiry, with a new
  shared count ceiling of three recently fetched lists per provider container.
  Active current/next-chapter subscriptions survive eviction/expiry. Tests
  exercise twenty keys, expiry, invalidation, and container cleanup. The cap
  bounds retained lists without shortening the browser refetch interval.
- `SumiRise` now cancels delayed entrance timers on retrigger and disposal.
  Previously `Future.delayed` retained the removed state until its delay
  elapsed and could start an obsolete trigger. This is bounded transient
  retention, not evidence of an indefinitely growing navigation leak. Two
  regression tests cover both paths.

The remaining inspected paths were left unchanged:

- Reader page/scroll/zoom controllers and the manual prefetch subscription are
  disposed; mode switches dispose the old page controller. The static active
  reader guard is cleared and the volume subscription is canceled on teardown.
- The four-slot shimmer counter increments only when creating a controller and
  decrements on its matching disposal. Existing unmount/re-entry and reduced
  motion tests pass. `SumiPress` owns/disposes its controller; the grain repaint
  boundary retains the existing visual asset.
- Browser requests clear their completer/channel, detach the view, and drop the
  active controller in cleanup. Installed `webview_flutter_android` uses weak
  delegate references and native-instance finalization. Cookie entries replace
  per-host values. A cached sandbox renderer process can survive after all
  WebView objects disappear; its PID/UID association is checked separately,
  rather than charging every device sandbox process to Yomi.
- App-lifetime Isar watchers retain current library/downloaded-ID results;
  route-specific chapter, update, and history watchers dispose. Chapter sync
  retains its five-minute cache. History queries limit to 300; updates truncate
  to 300 only after materializing matching chapters. Downloaded-ID derivation
  scans downloaded chapters on changes. These remain large-library allocation
  costs, not demonstrated leaks in this empty-library workload.
- Widget payloads already contain at most twelve recent titles plus one
  continue-reading title. Each library event still sorts/encodes and queues a
  platform write; rapid events could create transient backlog. Startup duplicate
  scanning and the three-worker library updater also allocate proportional to
  library data. Large-library/update stress was not measured here.
- Source Dio clients create connection pools lazily; the installed IO adapter
  uses a three-second idle timeout. Background downloads already stream with
  `Dio.download` into a temporary file. Download implementation was not changed.
- Reader disk cache pruning already runs at startup (three days on low spec,
  seven otherwise). Cover disk caching uses the dependency's default 200-object,
  thirty-day policy, not the outdated seven-day description in `main.dart`.
  Disk cache size is separate from decoded RAM and was not cleared for this run.

Flutter documents that the
[image-cache byte limit](https://api.flutter.dev/flutter/painting/ImageCache/maximumSizeBytes.html)
controls its LRU, while
[clearing that cache](https://api.flutter.dev/flutter/painting/ImageCache/clear.html)
does not clear images with live listeners. The implementation uses selective
reader disposal instead of clearing all application images on navigation.

Validation completed:

- Baseline `flutter analyze`: 77 existing findings (25 warnings, 52 infos).
  Candidate: the same 77 diagnostics after normalizing line numbers; no new
  diagnostics. Exit code 1 is the existing warning/info baseline.
- Baseline `flutter test`: 274 passed. Candidate: 283 passed (nine added tests).
  Focused run of `test/core/providers/provider_cache_test.dart`,
  `test/shared/widgets/scroll_motion_test.dart`, and
  `test/features/reader/reader_screen_test.dart`: 19 passed.
- Release build succeeded; APK installed with `adb install -r` on SM-X406B.
- PowerShell parser and `git diff --check` passed. Required `graphify update .`
  completed; its generated graph stays ignored. No branch switch, stash,
  commit, or push was performed.

Exact command-output tails from the final runs:

```text
flutter analyze
77 issues found. (ran in 122.6s)

flutter test
01:38 +280: C:/Projects/ClaudeCode/comic-center-memory/test/sources/more_sources_test.dart: natomanga reader parses synthetic contract case
01:38 +281: C:/Projects/ClaudeCode/comic-center-memory/test/sources/more_sources_test.dart: natomanga network failures propagate and empty readers fail explicitly
01:39 +282: C:/Projects/ClaudeCode/comic-center-memory/test/sources/more_sources_test.dart: natomanga popular paging and latest/search routes preserve arguments
01:39 +283: All tests passed!
```

Files changed: `lib/core/providers/provider_cache.dart`,
`lib/core/providers/reader_provider.dart`, `lib/core/services/device_profile.dart`,
`lib/features/reader/reader_screen.dart`, `lib/main.dart`,
`lib/shared/widgets/sumi.dart`, `test/core/providers/provider_cache_test.dart`,
`test/features/reader/reader_screen_test.dart`,
`test/shared/widgets/scroll_motion_test.dart`, `tool/measure-memory.ps1`, and
this report and `docs/memory-checkpoints.csv`.

Measured results (MiB), with Native and Graphics taken at the same sample as PSS:

| Checkpoint | Before PSS | Native | Graphics | After PSS | Native | Graphics |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cold-library | 170.0 | 46.9 | 52.1 | 179.8 | 52.8 | 40.1 |
| grid-scrolled | 203.6 | 49.4 | 72.9 | 215.6 | 54.5 | 72.8 |
| reader-start / initial | 440.1 | 83.6 | 229.8 | 432.9 | 51.8 | 211.8 |
| reader-end / initial | 524.7 | 84.8 | 320.3 | 377.8 | 44.7 | 193.2 |
| back-grid / initial | 517.7 | 80.6 | 311.2 | 374.5 | 45.1 | 186.2 |
| reader-start / repeat 1 | 510.8 | 80.9 | 311.2 | 366.6 | 40.7 | 189.4 |
| reader-end / repeat 1 | 497.0 | 38.6 | 318.1 | 346.6 | 20.2 | 189.1 |
| back-grid / repeat 1 | 493.6 | 38.6 | 314.6 | 339.8 | 21.4 | 182.2 |
| reader-start / repeat 2 | 495.1 | 31.0 | 314.7 | 347.4 | 22.1 | 189.4 |
| reader-end / repeat 2 | 474.2 | 25.6 | 322.6 | 340.7 | 21.0 | 189.6 |
| back-grid / repeat 2 | 471.6 | 25.6 | 315.2 | 331.9 | 20.8 | 182.2 |
| reader-start / repeat 3 | 511.3 | 35.7 | 329.9 | 375.4 | 32.4 | 197.0 |
| reader-end / repeat 3 | 521.7 | 37.0 | 322.5 | 368.3 | 34.7 | 189.8 |
| back-grid / repeat 3 | 513.3 | 37.1 | 315.4 | 364.1 | 34.8 | 182.4 |
| reader-start / repeat 4 | 508.1 | 37.1 | 315.3 | 369.3 | 34.9 | 189.6 |
| reader-end / repeat 4 | 507.3 | 36.2 | 322.7 | 367.6 | 36.7 | 189.7 |
| back-grid / repeat 4 | 498.5 | 36.1 | 315.3 | 359.1 | 36.2 | 182.3 |
| reader-start / repeat 5 | 501.0 | 36.2 | 315.3 | 365.5 | 36.8 | 189.5 |
| reader-end / repeat 5 | 503.0 | 36.2 | 322.7 | 363.8 | 28.6 | 189.7 |
| back-grid / repeat 5 | 485.1 | 26.4 | 315.3 | 359.2 | 27.8 | 182.2 |
| grid-idle-60s / repeat 5 | 484.1 | 26.2 | 315.3 | 351.6 | 27.8 | 182.2 |
| Sampled peak PSS | 545.1 | 38.4 | 347.7 | 432.9 | 51.8 | 211.8 |

Across 158 baseline and 160 candidate samples, median reading PSS fell from
508.9 to 373.6 MiB (26.6%); median return-to-grid PSS fell from 496.1 to 359.1 MiB
(27.6%). Sampled peak PSS fell 20.6%. Median reading PSS plus Swap PSS fell from
554.9 to 433.7 MiB (21.8%), so paging does not account for the whole saving.
These are combined-change results; individual changes were not measured in
separate builds. Cold/grid PSS was 9.8/12.0 MiB higher in this single candidate
run, so an isolated cold-browsing memory improvement is not established.

No monotonically growing navigation leak was reproduced in either build.
The first/last grid returns were 517.7/485.1 MiB before and 374.5/359.2 MiB after.
Native allocated heap (different from Native PSS above) settled near 94.2 MiB in
the baseline's last three returns. The candidate ended at 96.6 MiB allocated;
there is no claim of reduced native heap allocation. The large measured saving
is in Graphics. Resident/allocated values, the repeat dip/rise, and stable app
PIDs support a retained-cache/graphics plateau, rather than continuing growth.
This does not prove every route, source, failure path, or large library leak-free;
no Dart retainer graph or GPU allocation trace was captured.

Every measured reader-end and grid-return checkpoint had zero Java WebView
objects. One associated sandbox process was reused per variant: baseline PID
12296 and candidate PID 6905, both verified against Yomi's client UID
`u0a455`. Its return-to-grid PSS ranged from 72.4 to 176.0 MiB before and 71.4 to
170.1 MiB after; it does not grow per loop. At final idle it was 133.9/123.1 MiB.
It remains additional memory outside the main-app table. The CSV includes its
PSS alongside Dalvik, Private Other, Swap PSS, app PID, timestamps, and raw-file
names. Empty renderer fields mean no associated renderer was recorded there.

Filtered logcat for the measured app PIDs contains 143/147 GC messages,
zero OOM/fatal-exception messages, and zero `onTrimMemory` messages. Baseline has
no `Skipped N frames` message; candidate has one reporting 31 frames at 15:30:44.
This is not a frame-time benchmark, and no scrolling-performance improvement is
claimed. GC counts include the instrumentation effect described above.

The 1x quality check captured Chapter 1, page 100 in paged mode before/after.
The artwork region `(0,150)-(2112,1100)` has **zero different pixels out of
2,006,400**, excluding changing system/chrome text. Reader decode-width tests
also cover strip and paged modes on regular and low-spec profiles. Screenshots
and `page-100-pixel-comparison.json` are in the evidence directory below.
An additional post-measurement AllManga open timed out and succeeded on retry;
none of the measured loops timed out. Native WebView release timing from this
extra check was deferred: one object after the timeout, two after retry and
quiet paged reading, then zero after twelve ordinary strip swipes, backing out,
and ten seconds of settling. Immediate native destruction after every request
is therefore not established. The dependency's Dart-finalizer cleanup can lag;
the observed objects were eventually released without an extra GC/trim command.
Browser lifecycle code was left unchanged. These extra probes are outside the
paired measurement table.

The complete raw evidence, candidate APK, screenshots, CSVs, hashes, and command
logs are under `C:/Users/tyrel/AppData/Local/Temp/yomi-memory-20260921`.
The preserved baseline APK remains at
`C:/Users/tyrel/AppData/Local/Temp/yomi-scroll-jank-20260921/final.apk`.
Measurement subdirectories are `before-20260921-144141` and
`after-20260921-152432`. The worktree's
[memory-checkpoints.csv](memory-checkpoints.csv) preserves all 42 main
checkpoints. The branch remains ready for lead review; nothing was committed
or pushed.
