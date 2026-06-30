import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/chapter_entry.dart';
import 'models/download_entry.dart';
import 'models/manga_entry.dart';
import 'models/source_entry.dart';

/// ============================================================================
/// Schema migration strategy
///
/// Isar (v3) has no manual schema-version system like SQL migrations — it
/// diffs the generated schema (`*.g.dart`, rebuilt via `build_runner`) against
/// what's on disk every time `Isar.open` runs, and updates the database file
/// in place. What that means in practice:
///
/// SAFE — handled automatically, no migration code needed:
///   • Adding a new field (must be nullable or have a default — see every
///     field on MangaEntry/ChapterEntry/etc.). Existing rows get the default.
///   • Adding a new `@Index()` to an existing field. Rebuilt on next open.
///   • Adding a whole new `@Collection()`.
///
/// DESTRUCTIVE — silently loses data, requires a manual migration:
///   • Renaming a field. Isar sees this as "drop field X, add field Y" — the
///     old column's data is gone, not moved.
///   • Changing a field's type (e.g. `int` → `String`). Same as a rename.
///   • Removing a field. The stored data becomes unreachable (Isar doesn't
///     reclaim or warn about it — it's just orphaned in the file).
///
/// Checklist for a destructive change:
///   1. Add the new field/collection alongside the old one in the same
///      release — never repurpose an existing field name for new semantics.
///   2. Write a one-time migration function that runs after `Isar.open()` and
///      before the first frame (see `ExtensionManager.migratePercentEncodedSlugs`
///      in main.dart for the established pattern in this codebase) — read the
///      old field, write the new one, for every affected row.
///   3. Ship the migration in the SAME release as the schema change, so no
///      version of the app ever has the new field without also having run
///      the migration that populates it.
///   4. Only delete the old field's declaration in a LATER release, once
///      you're confident the migration has reached effectively all users.
/// ============================================================================
abstract final class IsarService {
  static Future<Isar> init() async {
    final dir = await _resolveDir();
    return Isar.open(
      [
        MangaEntrySchema,
        ChapterEntrySchema,
        SourceEntrySchema,
        DownloadEntrySchema,
      ],
      directory: dir,
    );
  }

  static Future<String> _resolveDir() async {
    // On Linux running as root the XDG documents dir may be unavailable.
    // Fall back to a temp directory so the app always starts.
    try {
      final d = await getApplicationDocumentsDirectory();
      return d.path;
    } catch (_) {
      final tmp = Directory('/tmp/comic_center_data');
      await tmp.create(recursive: true);
      return tmp.path;
    }
  }
}
