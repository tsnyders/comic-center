import 'source_interface.dart';
import 'sources/asura_scans_source.dart';
import 'sources/comicextra_source.dart';
import 'sources/demonicscans_source.dart';
import 'sources/mangadex_source.dart';
import 'sources/reaperscans_source.dart';
import 'sources/readcomiconline_source.dart';

/// Maps keiyoushi package names to Yomi source IDs, and source IDs to
/// constructor functions. Since Flutter compiles Dart AOT, extensions are
/// pre-compiled and gated by install state rather than dynamically loaded.
abstract final class ExtensionFactory {
  /// keiyoushi pkg name → Yomi sourceId.
  static const pkgToSourceId = <String, String>{
    'eu.kanade.tachiyomi.extension.all.mangadex': 'mangadex_en_v5',
    'eu.kanade.tachiyomi.extension.en.mangadex': 'mangadex_en_v5',
    // DemonicScans (formerly MangaDemon)
    'eu.kanade.tachiyomi.extension.en.mangademon': 'demonicscans_en',
    'eu.kanade.tachiyomi.extension.en.demonicscans': 'demonicscans_en',
    // AsuraScans
    'eu.kanade.tachiyomi.extension.en.asurascans': 'asurascans_en',
    'eu.kanade.tachiyomi.extension.en.asura': 'asurascans_en',
    // ReaperScans
    'eu.kanade.tachiyomi.extension.en.reaperscans': 'reaperscans_en',
    'eu.kanade.tachiyomi.extension.en.reaper': 'reaperscans_en',
    // ReadComicOnline (western comics: DC, Marvel, Image, Dynamite)
    'eu.kanade.tachiyomi.extension.en.readcomiconline': 'readcomiconline_en',
    // ComicExtra (western comics)
    'eu.kanade.tachiyomi.extension.en.comicextra': 'comicextra_en',
  };

  /// Native sources that should always be installable from the catalogue, even
  /// when the upstream keiyoushi index doesn't list them. Western-comic
  /// aggregators in particular are frequently absent from / removed from the
  /// keiyoushi repo, so we surface them ourselves.
  static const builtInExtensions =
      <({String name, String pkg, String sourceId, String lang, bool isNsfw})>[
    (
      name: 'ReadComicOnline',
      pkg: 'eu.kanade.tachiyomi.extension.en.readcomiconline',
      sourceId: 'readcomiconline_en',
      lang: 'en',
      isNsfw: false,
    ),
    (
      name: 'ComicExtra',
      pkg: 'eu.kanade.tachiyomi.extension.en.comicextra',
      sourceId: 'comicextra_en',
      lang: 'en',
      isNsfw: false,
    ),
  ];

  static MangaSource? create(String sourceId) => switch (sourceId) {
        'mangadex_en_v5'     => MangaDexSource(),
        'demonicscans_en'    => DemonicScansSource(),
        'asurascans_en'      => AsuraScansSource(),
        'reaperscans_en'     => ReaperScansSource(),
        'readcomiconline_en' => ReadComicOnlineSource(),
        'comicextra_en'      => ComicExtraSource(),
        _                    => null,
      };
}
