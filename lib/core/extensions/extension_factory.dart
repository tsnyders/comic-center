import 'source_interface.dart';
import 'sources/all_manga_source.dart';
import 'sources/demonicscans_source.dart';
import 'sources/mangadex_source.dart';

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
    // Legacy AsuraScans / ComicK entries redirect to DemonicScans
    'eu.kanade.tachiyomi.extension.en.asurascans': 'demonicscans_en',
    'eu.kanade.tachiyomi.extension.en.asura': 'demonicscans_en',
    'eu.kanade.tachiyomi.extension.en.comick': 'demonicscans_en',
  };

  static MangaSource? create(String sourceId) => switch (sourceId) {
        'mangadex_en_v5' => MangaDexSource(),
        'all_manga_en' => AllMangaSource(),
        'demonicscans_en' => DemonicScansSource(),
        _ => null,
      };
}
