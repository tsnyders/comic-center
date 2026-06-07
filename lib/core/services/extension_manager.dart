import 'package:isar/isar.dart';

import '../database/models/manga_entry.dart';
import '../database/models/source_entry.dart';
import '../extensions/extension_factory.dart';
import '../extensions/source_interface.dart';

abstract final class ExtensionManager {
  /// Load all enabled sources from the DB and instantiate them.
  static Future<List<MangaSource>> loadInstalled(Isar isar) async {
    final entries = await isar.sourceEntrys
        .filter()
        .isEnabledEqualTo(true)
        .findAll();
    return entries
        .map((e) => ExtensionFactory.create(e.sourceId))
        .whereType<MangaSource>()
        .toList();
  }

  /// Persist an extension as installed and return the live source instance.
  /// Returns null if the source ID has no native Dart implementation.
  static Future<MangaSource?> install(
    Isar isar, {
    required String sourceId,
    required String name,
    required String version,
    required String language,
    bool hasNsfw = false,
  }) async {
    final source = ExtensionFactory.create(sourceId);
    if (source == null) return null;

    await isar.writeTxn(() async {
      final existing = await isar.sourceEntrys
          .filter()
          .sourceIdEqualTo(sourceId)
          .findFirst();
      if (existing != null) {
        existing
          ..isEnabled = true
          ..version = version;
        await isar.sourceEntrys.put(existing);
      } else {
        await isar.sourceEntrys.put(SourceEntry()
          ..sourceId = sourceId
          ..name = name
          ..version = version
          ..baseUrl = source.baseUrl
          ..language = language
          ..hasNsfw = hasNsfw
          ..isEnabled = true
          ..installedAt = DateTime.now());
      }
    });

    return source;
  }

  /// Remove an extension from the DB.
  static Future<void> uninstall(Isar isar, String sourceId) async {
    await isar.writeTxn(() async {
      await isar.sourceEntrys
          .filter()
          .sourceIdEqualTo(sourceId)
          .deleteAll();
    });
  }

  /// Update the stored version for an installed extension.
  static Future<void> updateVersion(
    Isar isar,
    String sourceId,
    String newVersion,
  ) async {
    await isar.writeTxn(() async {
      final entry = await isar.sourceEntrys
          .filter()
          .sourceIdEqualTo(sourceId)
          .findFirst();
      if (entry != null) {
        entry.version = newVersion;
        await isar.sourceEntrys.put(entry);
      }
    });
  }

  /// Seeds defaults if the DB has no sources yet. Call once at startup.
  static Future<void> initializeIfEmpty(Isar isar) async {
    final count = await isar.sourceEntrys.count();
    if (count == 0) await seedDefaults(isar);
  }

  /// Fix manga entries whose sourceMangaId contains percent-encoded characters
  /// (legacy bug where slugs were double-encoded). Safe to call on every startup.
  static Future<void> migratePercentEncodedSlugs(Isar isar) async {
    final all = await isar.mangaEntrys
        .filter()
        .sourceIdEqualTo('demonicscans_en')
        .findAll();

    final toFix = all.where((e) => e.sourceMangaId.contains('%')).toList();
    if (toFix.isEmpty) return;

    await isar.writeTxn(() async {
      for (final entry in toFix) {
        final cleanSlug = _fullyDecode(entry.sourceMangaId);
        final cleanKey = 'demonicscans_en::$cleanSlug';

        // Check if a clean entry already exists (avoid duplicates).
        final existing = await isar.mangaEntrys
            .filter()
            .sourceKeyEqualTo(cleanKey)
            .findFirst();

        if (existing != null && existing.id != entry.id) {
          // Clean entry already exists — delete the broken duplicate.
          await isar.mangaEntrys.delete(entry.id);
        } else {
          // Update in-place.
          entry
            ..sourceMangaId = cleanSlug
            ..sourceKey = cleanKey;
          await isar.mangaEntrys.put(entry);
        }
      }
    });
  }

  static String _fullyDecode(String s) {
    var prev = s;
    for (var i = 0; i < 5; i++) {
      try {
        final next = Uri.decodeComponent(prev);
        if (next == prev) return next;
        prev = next;
      } catch (_) {
        return prev;
      }
    }
    return prev;
  }

  /// Seed all bundled sources on first run (empty DB).
  static Future<void> seedDefaults(Isar isar) async {
    const defaults = [
      (
        sourceId: 'mangadex_en_v5',
        name: 'MangaDex',
        version: '1.0.0',
        language: 'en',
        hasNsfw: false,
      ),
      (
        sourceId: 'all_manga_en',
        name: 'AllManga',
        version: '1.0.0',
        language: 'en',
        hasNsfw: false,
      ),
      (
        sourceId: 'demonicscans_en',
        name: 'DemonicScans',
        version: '1.0.0',
        language: 'en',
        hasNsfw: false,
      ),
    ];

    for (final d in defaults) {
      await install(
        isar,
        sourceId: d.sourceId,
        name: d.name,
        version: d.version,
        language: d.language,
        hasNsfw: d.hasNsfw,
      );
    }
  }
}
