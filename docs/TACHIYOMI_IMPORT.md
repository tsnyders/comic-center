# Tachiyomi migration

In **Settings → Restore backup**, choose **Google Drive**, **System storage**,
or **Import from Tachiyomi**. Backups saved privately by Yomi remain listed below.

For Tachiyomi migration, create a backup in Tachiyomi with library entries,
chapters, categories, and history enabled. Select its `.tachibk` or `.proto.gz`
file in Yomi, review the title/chapter counts and source warnings, and tap Import.
The picker requests the shared `Tachiyomi` folder as its starting location.
Android's document provider may open elsewhere if that folder is absent, moved,
on an SD card, or inaccessible; the user can browse to the actual backup.

Import is offline and merges titles by source identity, chapters by source
chapter identity, and categories by name. It retains completed chapters and the
furthest saved page of each chapter. The resume chapter follows the most recent
available history timestamp. Without history, it falls back to the highest
chapter with progress. Duplicate imports do not duplicate database entries.

The import includes titles, authors, descriptions, genre labels, cover URLs,
category membership, chapter metadata, read/unread state, last-read pages, and
available reading timestamps. It never imports image files, download flags,
download paths, extension APKs, tracking accounts, or Tachiyomi settings.
Existing Yomi downloads remain intact. Cover URLs may be loaded normally when
the library is later displayed; importing does not fetch chapter pages.

Known URL formats are converted to Yomi reader identifiers for MangaPill,
MangaDex, ReadComicOnline, ComicExtra, and DemonicScans/MangaDemon. These source
adapters must be enabled in Browse, and their sites must still serve the title.
Unsupported sources, language variants, and incompatible URL formats retain
their exact original source ID and URLs under a `tachiyomi:` identity. Their
titles, chapter list, and progress remain visible, but they cannot be read online
until a compatible mapping/adapter is implemented. The preview reports this
before import. There is no title-only or chapter-number-only source guessing.
AsuraScans, MangaTaro, and ReaperScans currently follow this preservation path
because their Yomi adapters require identifiers not reliably available in old
Tachiyomi URLs.

Only protobuf backups are supported. Legacy Tachiyomi JSON backups, downloaded
chapter ZIP/CBZ files, and raw app databases are rejected with an explanation.
The reader handles old broken source/history field numbering, packed and
unpacked category IDs, newer explicit category IDs, and unknown protobuf fields.
Input is limited to 32 MiB and decompressed data to 128 MiB. Validation happens
before the database transaction, and the transaction rolls back on failure.

Yomi exports now retain unread and partially read chapter metadata as well as
completed chapters, so an imported library survives a later Yomi backup. Old
Yomi `readChapters` backups remain readable. Both local and Drive restores merge
the returned category names into the category store. Android's Export backup
action also offers a system Save as picker, retaining the private copy on cancel.

The new document picker bridge is Android-specific. Existing app-local and
Drive paths remain available on other platforms. **Yomi's existing encryption
still uses an installation-local key:** its encrypted exports cannot be restored
after losing that key or on another device. This change does not redesign that
encryption format. Tachiyomi imports do not depend on the Yomi encryption key.

## Format and platform references

- [Tachiyomi-compatible manga schema (Mihon v0.16.0)](https://github.com/mihonapp/mihon/blob/v0.16.0/app/src/main/java/eu/kanade/tachiyomi/data/backup/models/BackupManga.kt)
- [Chapter schema](https://github.com/mihonapp/mihon/blob/main/app/src/main/java/eu/kanade/tachiyomi/data/backup/models/BackupChapter.kt)
- [Legacy category orders](https://github.com/mihonapp/mihon/blob/v0.16.0/app/src/main/java/eu/kanade/tachiyomi/data/backup/models/BackupCategory.kt)
- [Current category IDs](https://github.com/mihonapp/mihon/blob/main/app/src/main/java/eu/kanade/tachiyomi/data/backup/models/BackupCategory.kt)
- [Android Storage Access Framework and initial location hint](https://developer.android.com/training/data-storage/shared/documents-files)

## Verification

`test/fixtures/tachiyomi/library.tachibk` is synthetic and contains no user data.
It is encoded by Google's Python protobuf implementation, independently of the
Dart decoder. Its adjacent generator documents the field definitions and can
regenerate the fixture. Additional Dart wire fixtures exercise older formats,
malformed records, Unicode, floating chapter numbers, large int64 IDs, unknown
fields, and URL conversion.

Database tests use a temporary Isar database to exercise actual persistence,
repeat merging, rollback, old Yomi backups, and export/restore with partial
progress and existing downloads. Widget tests cover source choices, picker
arguments, cancellation/temporary-file cleanup, preview warnings, invalid files,
and visible partial progress when a backup has no total page count.

Commands:

```powershell
flutter test --no-pub --reporter expanded
flutter build apk --debug --no-pub
```

These checks use synthetic backups. A user's real backup, physical system file
picker, source playback after import, and Google Drive round trip require device
acceptance; an APK build or unit test does not establish those results.
