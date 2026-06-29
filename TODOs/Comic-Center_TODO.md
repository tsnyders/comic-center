# Yomi — Codebase Audit: Bugs & Feature Opportunities

> PRs already in flight: #56 (widget upgrade) · #57 (downloads read local files)

---

## 🔴 Critical Bugs

### 1. Unread count never decreases after marking a chapter read
**Files:** `library_provider.dart`, `library_screen.dart`
The `unreadCount` field is stored on `MangaEntry` but never decremented when
`markChapterRead()` is called. The badge persists incorrectly until the app restarts.
`unreadCount` should be a derived value computed from actual chapter read states,
not a stored integer.

### 2. "Continue Reading" progress not saved
**File:** `library_provider.dart`
`markChapterRead()` sets `lastReadChapterId` on the manga but never writes
`lastReadChapterNumber`. The cinematic hero on the library screen reads
`lastReadChapterNumber` to draw the progress bar — it always shows 0.

### 3. Hero animation conflict — same tag on two visible widgets
**Files:** `library_screen.dart`, `widgets/manga_card.dart`
The cinematic hero at the top of the library and the list row cards below it both
use `mangaCoverHeroTag(manga.id)` for the same manga at the same time. Flutter
crashes/corrupts hero animations when two heroes share a tag in the same route.

### 4. Auto-update toggle is wired to nothing
**File:** `settings_screen.dart`
The "Auto-check for updates" switch has `onChanged: (_) {}`. The feature is
visible and interactive but has no effect whatsoever.

### 5. Download race condition — `_processQueue` fires concurrently
**File:** `download_provider.dart`
`_processQueue()` is `async` but called as fire-and-forget (not awaited). The
`_isProcessing` guard only prevents re-entry within a single call; rapid
enqueue events spawn overlapping queue processors, causing out-of-order
downloads and duplicate progress writes.

### 6. Cancelled downloads leave orphaned files on disk
**File:** `download_provider.dart`
`cancel()` deletes the `DownloadEntry` from the database but never removes the
partially-downloaded directory at `downloads/{mangaId}/{chapterId}/`. Storage
bloat accumulates permanently.

### 7. Backup restore has no schema validation
**File:** `backup_service.dart`
The restore path deserializes JSON from an arbitrary file with no version check,
required-field validation, or type coercion. A malformed or version-mismatched
backup silently corrupts the database.

---

## 🟠 High Priority

### 8. Webtoon page tracking assumes uniform image heights
**File:** `reader_screen.dart`
The vertical scroll position is divided by `maxScrollExtent` and multiplied by
`totalPages` to estimate the current page. Webtoon images vary wildly in height,
so this calculation is wrong for most real chapters — the page pill and progress
bar fall out of sync.

### 9. No connectivity check before network operations
No screen or provider checks reachability before fetching manga, chapters, or
page URLs. Users on airplane mode receive cryptic timeout errors rather than a
clear "No internet connection" message.

### 10. Browse results not paginated — only first page shown
**File:** `source_manga_screen.dart`
Source interfaces support page-based fetching but the browse screen never
requests page 2+. Users see only the first ~20 results and have no way to
load more.

### 11. Cover palette extraction runs on the main thread
**File:** `cover_palette_provider.dart`
`palette_generator` is synchronous and runs on the UI isolate. Opening a title
detail screen freezes the UI for ~200–400 ms on mid-range devices while the
dominant color is extracted.

### 12. No disk space or permission check before downloading
**File:** `download_provider.dart`
Downloads begin without checking available storage. On a full device the write
fails silently mid-download, leaving a partial chapter that appears downloaded
in the UI.

### 13. `markAllChaptersRead` is not transactional
**File:** `library_provider.dart`
Chapters are updated in a loop; if one write fails partway through, earlier
chapters are marked read while later ones are not — inconsistent state with no
rollback.

### 14. No retry logic on network errors
All source implementations (MangaDex, AsuraScans, etc.) make single-attempt
requests. A transient timeout means complete failure with no retry. A simple
exponential back-off with 2–3 attempts would resolve most flaky-network issues.

---

## 🟡 Medium Priority

### 15. Google Drive download location throws but UI doesn't redirect
**File:** `download_provider.dart`
Selecting Google Drive as the download location throws an exception with a text
message. The UI shows a generic error rather than navigating the user to
Settings → Downloads to change the location.

### 16. Library filter recalculates on every keystroke without debounce
**File:** `library_provider.dart`
`filteredLibraryProvider` watches `librarySearchProvider` directly. Every
character typed re-runs the full filter + sort across the entire library. Noticeable
jank on libraries with 500+ titles.

### 17. No image cache size limits
**File:** `widgets/cover_image.dart`
`cached_network_image` uses its default unlimited memory cache. Scrolling through
a large source catalog loads hundreds of cover bitmaps into RAM with no eviction
policy, causing OOM crashes on low-memory devices.

### 18. Webtoon mode loads all images into memory at once
**File:** `reader_screen.dart`
`_buildWebtoonView` passes all page URLs to a `ListView.builder`, but
`ExtendedImage` eagerly decodes every image. A 60-page webtoon chapter can
consume 150–300 MB of RAM.

### 19. Chapter metadata never refreshed after initial fetch
Chapter titles, numbers, and scanlator info are written once and never updated.
If a source corrects metadata (common for early-access chapters), the local
entries stay stale indefinitely.

### 20. No request deduplication
Opening the same title detail screen twice in quick succession fires two
identical network requests for chapters. No provider memoizes in-flight requests.

### 21. No batch download — must queue one chapter at a time
**Files:** `downloads_screen.dart`, `download_provider.dart`
There is no "Download all unread chapters" or "Download next N chapters" action.
Users must long-press each chapter individually.

### 22. Silent failure when `fetchPageUrls` returns empty list
If a source returns zero page URLs, the reader shows a blank screen with a
spinner that never resolves — no error message, no retry button.

### 23. Dio timeouts too long (60 s receive)
**File:** `download_provider.dart`
The receive timeout is 60 seconds. On a broken connection this means a full
minute of frozen UI before the user sees any error.

### 24. Cover URL 404s show nothing — no placeholder fallback
**File:** `widgets/cover_image.dart`
When a cover URL returns 404 or the image fails to load, the cell displays an
empty box. There is no book-icon or title-initial fallback to fill the space.

### 25. Category deletion has no confirmation dialog
**File:** `category_management_screen.dart`
Swiping to delete a category containing hundreds of manga requires no
confirmation. The operation is immediate and irreversible in the current session.

### 26. `unreadCount` in the widget service is always from the stored field
**File:** `widget_service.dart`
The recently-updated widget displays `unreadCount` from the same stale field
described in Bug #1. The widget badge is wrong for the same reason.

### 27. No reading statistics or history screen
There is a "Continue Reading" shelf but no history of what was read, when, or
for how long. Most manga readers expose at least a "Recently read" list and total
chapters read.

### 28. No duplicate title detection across sources
A user can add "One Piece" from MangaDex, AsuraScans, and ReaperScans — they
appear as three independent entries in the library with no indication they are
the same title.

### 29. Changelog parser may break on non-standard GitHub release notes
**File:** `changelog_screen.dart`
The changelog screen fetches and renders GitHub release markdown. Any formatting
deviation from the expected pattern silently renders garbled text.

### 30. No input validation in `ChapterEntry` / `MangaEntry` DB writes
Entries can be inserted with `number = null`, `uploadDate = null`,
`sourceChapterId = ""`. Downstream filters and sort comparisons assume these
fields are populated, causing silent wrong-ordering or null dereferences.

---

## 🟢 Low Priority / Nice-to-Have

### 31. Reader brightness/settings errors silently swallowed
**File:** `reader_screen.dart`
`catch (_) {}` blocks hide brightness reset and settings persistence errors.
Users don't know when their settings fail to save.

### 32. No reading mode per source/title
Reading direction (LTR, RTL, vertical) is global. Webtoon manhwa and Japanese
manga have opposite defaults — users must manually switch every time they change
genres.

### 33. iOS users have no hardware key page-turning alternative
**File:** `reader_screen.dart`
Volume-key page turning is correctly skipped on iOS but no gesture or
accessibility alternative is offered. iPad users in particular expect side-button
support.

### 34. No Isar migration strategy documented
**File:** `isar_service.dart`
Schema changes between app versions have no migration path documented or
implemented. A field rename or type change silently wipes the collection.

### 35. Hardcoded colors scattered throughout UI files
Dozens of `Color(0x2E000000)`-style literals throughout screen files bypass the
`AppColors` system. Theme changes don't propagate to them.

### 36. No accessibility labels on settings switches/segmented controls
**File:** `settings_screen.dart`
Screen readers announce "Switch" or "SegmentedControl" without context. Labels
describing what each control does are missing.

### 37. No rate limiting on source API calls
Rapid navigation (back/forward through search pages) fires bursts of requests
that some sources will 429 or IP-ban.

### 38. Backup files not encrypted — reading history is PII
**File:** `backup_service.dart`
JSON backups contain the full reading history in plaintext. On a shared or stolen
device, a user's reading habits are exposed.

### 39. No log file / in-app log viewer for bug reporting
Errors go to stderr only. Users have no way to share a diagnostic log when
reporting bugs, and developers have no visibility into production failures.

### 40. Extension/source system entirely undocumented
`SourceInterface` contract, required fields, and expected error types are not
documented. Adding a new source requires reverse-engineering existing ones.

---

## Feature Opportunities

### Reader
- [ ] Per-title reading direction memory (saves last used mode per manga)
- [ ] Double-tap to zoom in paged mode
- [ ] Long-press page → save image to gallery / share
- [ ] Sleep timer (auto-close reader after N minutes)
- [ ] Reading statistics (pages/day, total time, chapters finished)
- [ ] Offline indicator in reader chrome when reading downloaded chapters
- [ ] Panel-by-panel zoom mode for small-screen users

### Library
- [ ] Sort by date added, last updated, title, unread count
- [ ] Multi-select → bulk mark read / download / remove
- [ ] "New chapters" dedicated feed (chronological, all library)
- [ ] Reading challenge / streak tracker
- [ ] Series grouping (link sequels/prequels)
- [ ] Tags/custom labels beyond categories
- [ ] Smart lists (e.g., "Completed series", "Unread > 5 chapters")

### Downloads
- [ ] "Download all unread" per manga
- [ ] Background download via WorkManager (survives app close)
- [ ] Download quality selector (if source offers multiple resolutions)
- [ ] Storage usage breakdown per manga
- [ ] Auto-delete read chapters after N days

### Discover / Browse
- [ ] Infinite scroll / load-more on source results
- [ ] Trending / popular / recently added tabs per source
- [ ] Cross-source search (search all installed sources simultaneously)
- [ ] Recommended titles based on library genre profile
- [ ] Ratings/reviews pulled from source metadata

### Notifications
- [ ] Push notification when tracked manga gets a new chapter
- [ ] Download complete notification
- [ ] "Resume reading" notification shortcut

### Android Platform
- [ ] Predictive back gesture support (Android 14+)
- [ ] Per-app language selection (Android 13+)
- [ ] Dynamic color / Material You theming on Android 12+
- [ ] Lock-screen widget support
- [ ] Quick Settings tile for "Continue Reading"
- [ ] Picture-in-picture mode for webtoon scrolling
- [ ] Scheduled background updates via WorkManager

### Sync & Backup
- [ ] Automatic cloud backup on a schedule
- [ ] MAL / AniList / MangaUpdates sync (mark read, track progress)
- [ ] Cross-device sync via a lightweight sync server or CRDT

### iOS
- [ ] WidgetKit home screen and lock screen widgets
- [ ] iCloud backup integration
- [ ] Spotlight search indexing for library titles

---

## By Effort

| Effort | Items |
|---|---|
| < 1 hour | #1, #2, #6, #13, #22, #24, #25, #31 |
| 1–4 hours | #3, #5, #7, #9, #12, #15, #16, #20, #23, #27 |
| 4–8 hours | #4, #8, #10, #11, #14, #17, #18, #21, #28 |
| 1–3 days | Reader features, batch downloads, notifications, WorkManager |
| 1+ weeks | Cross-source search, sync, MAL integration, iOS widgets |
