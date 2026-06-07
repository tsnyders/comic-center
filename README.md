# Yomi

> An immersive manga & manhwa reader for Android with an iOS-native Cupertino UI.

---

## Features

### Library
- Grid view of your saved manga with cover art and unread badges
- **Search** your library in real time from the top bar
- **Filter** by read status and genre via the filter sheet
- **Categories** — create, rename, and delete custom shelves; assign any manga to one or more categories
- Shimmer loading placeholder while the library hydrates

### Reader
- **Left-to-right**, **right-to-left**, and **vertical** scroll modes
- **Fit Width**, **Fit Height**, and **Original** page scale modes
- **Black**, **White**, and **Sepia** backgrounds
- Interactive bottom **scrubber** — tap or drag to jump to any page
- Tap-to-reveal chrome (toolbar + scrubber) with smooth opacity animation
- Always-visible 2 pt progress line at the top of every page
- Temporary page-count pill after page turns

### Downloads
- Per-chapter download queue with **pause**, **resume**, and **cancel**
- Progress bar and page counter while downloading
- Completed download history
- Per-chapter status indicators in the chapter list: queued (clock), in-progress (spinner), paused, failed (retryable), downloaded (green tick)

### Browse / Sources
- Pluggable source system — add any `MangaSource` implementation
- Built-in sources: **AsuraScans** and **AllManga**
- Sort by Popular or Latest in each source
- Search within a source

### Backup & Restore
- **Export** your library to a timestamped JSON backup file stored in app documents
- **Restore** from any saved backup — merges with your current library, preserving read/download status
- Backup list screen with one-tap restore

### Settings
- **Theme** — Dark or Light (adaptive Cupertino colors throughout)
- **Reading direction, page scale, background** — persisted across sessions
- **Download location** — Local or Google Drive (account linking UI)
- **Categories** management
- **Check for Updates** — fetches the latest GitHub release; distinguishes "no releases yet" from a network error
- **Export / Restore Backup**

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI framework | Flutter 3.x — Cupertino widgets |
| State management | Riverpod v2 (`StateProvider`, `AsyncNotifier`, `StreamProvider`) |
| Local database | Isar v3 (embedded NoSQL, reactive streams) |
| Networking | Dio 5 |
| Image loading | `extended_image` (gesture zoom, cache) |
| HTML scraping | `html` package (for web-based sources) |
| Backup / archive | `archive` package |
| Google Drive | `googleapis` + `google_sign_in` |
| Platform channel | `yomi/platform` — `openUrl` via Android `Intent.ACTION_VIEW` |

---

## Architecture

```
lib/
├── core/
│   ├── database/          # Isar schemas (MangaEntry, ChapterEntry, DownloadEntry, …)
│   ├── extensions/
│   │   └── sources/       # Source plugins (AsuraScans, AllManga, …)
│   ├── providers/         # Riverpod providers (library, browse, download, reader, …)
│   ├── services/          # BackupService, UpdateService
│   └── theme/             # AppColors, AppTextStyles, AppColorsX extension
└── features/
    ├── library/           # LibraryScreen, filters, category chips
    ├── browse/            # BrowseScreen, SourceMangaScreen, RepositoryScreen
    ├── title_detail/      # TitleDetailScreen, ChapterListTile
    ├── reader/            # ReaderScreen, ReaderChrome, scrubber, progress line
    ├── downloads/         # DownloadsScreen
    └── settings/          # SettingsScreen, BackupRestoreScreen
```

### Source plugin interface

Implement `MangaSource` and register it in `SourceRegistryProvider`:

```dart
abstract class MangaSource {
  String get id;
  String get name;
  String get baseUrl;
  String get language;
  Map<String, String> get imageHeaders;

  Future<List<MangaSummary>> fetchPopular({int page});
  Future<List<MangaSummary>> fetchLatestUpdates({int page});
  Future<List<MangaSummary>> search(String query, {int page, List<SourceFilter> filters});
  Future<MangaDetail> fetchMangaDetail(String mangaId);
  Future<List<ChapterInfo>> fetchChapterList(String mangaId);
  Future<List<String>> fetchPageUrls(String chapterId);
}
```

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.3
- Android SDK (API 21+)
- Dart SDK ≥ 3.3

### Build

```bash
# Get dependencies
flutter pub get

# Generate Isar schemas and Riverpod annotations
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device or emulator
flutter run

# Build a release APK
flutter build apk --release
```

### Android package ID

`com.comiccenter.comic_center` — keep this unchanged to allow over-the-air APK upgrades without uninstalling.

---

## Contributing

1. Branch from `main`
2. Keep Isar schema files (`*.g.dart`) regenerated via `build_runner`
3. Run `flutter analyze` before opening a PR — all issues should be `info` level only
4. Never change the Android `applicationId`

---

## License

MIT
