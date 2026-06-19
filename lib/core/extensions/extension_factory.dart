import 'source_interface.dart';
import 'sources/all_manga_source.dart';
import 'sources/asura_scans_source.dart';
import 'sources/demonicscans_source.dart';
import 'sources/flamescans_source.dart';
import 'sources/mangadex_source.dart';
import 'sources/reaperscans_source.dart';

/// Maps keiyoushi package names to Yomi source IDs, and source IDs to
/// constructor functions. Since Flutter compiles Dart AOT, extensions are
/// pre-compiled and gated by install state rather than dynamically loaded.
abstract final class ExtensionFactory {
  /// keiyoushi pkg name → Yomi sourceId.
  static const pkgToSourceId = <String, String>{
    'eu.kanade.tachiyomi.extension.all.mangadex': 'mangadex_en_v5',
    'eu.kanade.tachiyomi.extension.en.mangadex': 'mangadex_en_v5',
    'eu.kanade.tachiyomi.extension.en.allmanga': 'all_manga_en',
    // DemonicScans (formerly MangaDemon)
    'eu.kanade.tachiyomi.extension.en.mangademon': 'demonicscans_en',
    'eu.kanade.tachiyomi.extension.en.demonicscans': 'demonicscans_en',
    // AsuraScans
    'eu.kanade.tachiyomi.extension.en.asurascans': 'asurascans_en',
    'eu.kanade.tachiyomi.extension.en.asura': 'asurascans_en',
    // ReaperScans
    'eu.kanade.tachiyomi.extension.en.reaperscans': 'reaperscans_en',
    'eu.kanade.tachiyomi.extension.en.reaper': 'reaperscans_en',
    // FlameComics (formerly FlameScans)
    'eu.kanade.tachiyomi.extension.en.flamescans': 'flamescans_en',
    'eu.kanade.tachiyomi.extension.en.flamecomics': 'flamescans_en',
  };

  static MangaSource? create(String sourceId) => switch (sourceId) {
        'mangadex_en_v5'  => MangaDexSource(),
        'all_manga_en'    => AllMangaSource(),
        'demonicscans_en' => DemonicScansSource(),
        'asurascans_en'   => AsuraScansSource(),
        'reaperscans_en'  => ReaperScansSource(),
        'flamescans_en'   => FlameScansSource(),
        _                 => null,
      };
}
