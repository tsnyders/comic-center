import 'package:isar/isar.dart';

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
