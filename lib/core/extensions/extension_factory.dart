import 'source_interface.dart';
import 'sources/asura_scans_source.dart';
import 'sources/comicextra_source.dart';
import 'sources/comick_source.dart';
import 'sources/demonicscans_source.dart';
import 'sources/mangadex_source.dart';
import 'sources/mangapill_source.dart';
import 'sources/mangataro_source.dart';
import 'sources/reaperscans_source.dart';
import 'sources/readcomiconline_source.dart';
import 'sources/mangathemesia_source.dart';
import 'sources/madara_source.dart';
import 'sources/weebcentral_source.dart';
import 'sources/flamecomics_source.dart';
import 'sources/webtoons_source.dart';
import 'sources/mangakakalot_source.dart';

/// Maps keiyoushi package names to Yomi source IDs, and source IDs to
/// constructor functions. Since Flutter compiles Dart AOT, extensions are
/// pre-compiled and gated by install state rather than dynamically loaded.
abstract final class ExtensionFactory {
  /// keiyoushi pkg name → Yomi sourceId.
  static const pkgToSourceId = <String, String>{
    'eu.kanade.tachiyomi.extension.en.thunderscans': 'thunderscans_en',
    'eu.kanade.tachiyomi.extension.en.rizzcomic': 'rizzfables_en',
    'eu.kanade.tachiyomi.extension.en.manhwatop': 'manhwatop_en',
    'eu.kanade.tachiyomi.extension.en.manhuaplus': 'manhuaplus_en',
    'eu.kanade.tachiyomi.extension.en.toonily': 'toonily_en',
    'eu.kanade.tachiyomi.extension.en.weebcentral': 'weebcentral_en',
    'eu.kanade.tachiyomi.extension.en.flamecomics': 'flamecomics_en',
    'eu.kanade.tachiyomi.extension.all.webtoons': 'webtoons_en',
    'eu.kanade.tachiyomi.extension.en.mangakakalot': 'mangakakalot_en',
    'eu.kanade.tachiyomi.extension.en.manganelo': 'natomanga_en',
    'eu.kanade.tachiyomi.extension.all.mangadex': 'mangadex_en_v5',
    'eu.kanade.tachiyomi.extension.en.mangadex': 'mangadex_en_v5',
    // DemonicScans (formerly MangaDemon)
    'eu.kanade.tachiyomi.extension.en.mangademon': 'demonicscans_en',
    'eu.kanade.tachiyomi.extension.en.demonicscans': 'demonicscans_en',
    // AsuraScans
    'eu.kanade.tachiyomi.extension.en.asurascans': 'asurascans_en',
    'eu.kanade.tachiyomi.extension.en.asura': 'asurascans_en',
    // MangaPill
    'eu.kanade.tachiyomi.extension.en.mangapill': 'mangapill_en',
    // MangaTaro
    'eu.kanade.tachiyomi.extension.en.mangataro': 'mangataro_en',
    // ReaperScans
    'eu.kanade.tachiyomi.extension.en.reaperscans': 'reaperscans_en',
    'eu.kanade.tachiyomi.extension.en.reaper': 'reaperscans_en',
    // ReadComicOnline (western comics: DC, Marvel, Image, Dynamite)
    'eu.kanade.tachiyomi.extension.en.readcomiconline': 'readcomiconline_en',
    // ComicExtra (western comics)
    'eu.kanade.tachiyomi.extension.en.comicextra': 'comicextra_en',
    // ComicK (multi-language aggregator)
    'eu.kanade.tachiyomi.extension.all.comick': 'comick_en',
  };

  /// Native sources that should always be installable from the catalogue, even
  /// when the upstream keiyoushi index doesn't list them. Western-comic
  /// aggregators in particular are frequently absent from / removed from the
  /// keiyoushi repo, so we surface them ourselves.
  static const builtInExtensions =
      <({String name, String pkg, String sourceId, String lang, bool isNsfw})>[
    (
      name: 'ThunderScans',
      pkg: 'eu.kanade.tachiyomi.extension.en.thunderscans',
      sourceId: 'thunderscans_en',
      lang: 'en',
      isNsfw: false
    ),
    (
      name: 'Rizz Fables',
      pkg: 'eu.kanade.tachiyomi.extension.en.rizzcomic',
      sourceId: 'rizzfables_en',
      lang: 'en',
      isNsfw: false
    ),
    (
      name: 'ManhwaTop',
      pkg: 'eu.kanade.tachiyomi.extension.en.manhwatop',
      sourceId: 'manhwatop_en',
      lang: 'en',
      isNsfw: true
    ),
    (
      name: 'ManhuaPlus',
      pkg: 'eu.kanade.tachiyomi.extension.en.manhuaplus',
      sourceId: 'manhuaplus_en',
      lang: 'en',
      isNsfw: false
    ),
    (
      name: 'Toonily',
      pkg: 'eu.kanade.tachiyomi.extension.en.toonily',
      sourceId: 'toonily_en',
      lang: 'en',
      isNsfw: true
    ),
    (
      name: 'WeebCentral',
      pkg: 'eu.kanade.tachiyomi.extension.en.weebcentral',
      sourceId: 'weebcentral_en',
      lang: 'en',
      isNsfw: true
    ),
    (
      name: 'Flame Comics',
      pkg: 'eu.kanade.tachiyomi.extension.en.flamecomics',
      sourceId: 'flamecomics_en',
      lang: 'en',
      isNsfw: false
    ),
    (
      name: 'WEBTOON',
      pkg: 'eu.kanade.tachiyomi.extension.all.webtoons',
      sourceId: 'webtoons_en',
      lang: 'en',
      isNsfw: false
    ),
    (
      name: 'Mangakakalot',
      pkg: 'eu.kanade.tachiyomi.extension.en.mangakakalot',
      sourceId: 'mangakakalot_en',
      lang: 'en',
      isNsfw: true
    ),
    (
      name: 'NatoManga',
      pkg: 'eu.kanade.tachiyomi.extension.en.manganelo',
      sourceId: 'natomanga_en',
      lang: 'en',
      isNsfw: true
    ),
    (
      name: 'MangaPill',
      pkg: 'eu.kanade.tachiyomi.extension.en.mangapill',
      sourceId: 'mangapill_en',
      lang: 'en',
      isNsfw: false,
    ),
    (
      name: 'MangaTaro',
      pkg: 'eu.kanade.tachiyomi.extension.en.mangataro',
      sourceId: 'mangataro_en',
      lang: 'en',
      isNsfw: false,
    ),
    (
      name: 'AsuraScans',
      pkg: 'eu.kanade.tachiyomi.extension.en.asurascans',
      sourceId: 'asurascans_en',
      lang: 'en',
      isNsfw: false,
    ),
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
    (
      name: 'ComicK',
      pkg: 'eu.kanade.tachiyomi.extension.all.comick',
      sourceId: 'comick_en',
      lang: 'all',
      isNsfw: true,
    ),
  ];

  static MangaSource? create(String sourceId) => switch (sourceId) {
        'thunderscans_en' => MangaThemesiaSource(
            id: 'thunderscans_en',
            name: 'ThunderScans',
            baseUrl: 'https://en-thunderscans.com',
            cataloguePath: '/comics/'),
        'rizzfables_en' => MangaThemesiaSource(
            id: 'rizzfables_en',
            name: 'Rizz Fables',
            baseUrl: 'https://rizzfables.com',
            cataloguePath: '/series',
            filterPath: '/Index/filter_series'),
        'manhwatop_en' => MadaraSource(
            id: 'manhwatop_en',
            name: 'ManhwaTop',
            baseUrl: 'https://manhwatop.com',
            isNsfw: true),
        'manhuaplus_en' => MadaraSource(
            id: 'manhuaplus_en',
            name: 'ManhuaPlus',
            baseUrl: 'https://manhuaplus.com'),
        'toonily_en' => MadaraSource(
            id: 'toonily_en',
            name: 'Toonily',
            baseUrl: 'https://toonily.com',
            isNsfw: true,
            cataloguePath: '/serie/',
            genrePath: '/genre/'),
        'weebcentral_en' => WeebCentralSource(),
        'flamecomics_en' => FlameComicsSource(),
        'webtoons_en' => WebtoonsSource(),
        'mangakakalot_en' => MangakakalotSource(
            id: 'mangakakalot_en',
            name: 'Mangakakalot',
            baseUrl: 'https://www.mangakakalot.gg'),
        'natomanga_en' => MangakakalotSource(
            id: 'natomanga_en',
            name: 'NatoManga',
            baseUrl: 'https://www.natomanga.com'),
        'mangadex_en_v5' => MangaDexSource(),
        'mangapill_en' => MangaPillSource(),
        'mangataro_en' => MangaTaroSource(),
        'demonicscans_en' => DemonicScansSource(),
        'asurascans_en' => AsuraScansSource(),
        'reaperscans_en' => ReaperScansSource(),
        'readcomiconline_en' => ReadComicOnlineSource(),
        'comicextra_en' => ComicExtraSource(),
        'comick_en' => ComicKSource(),
        _ => null,
      };
}
