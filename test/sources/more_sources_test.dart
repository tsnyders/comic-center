import 'dart:io';
import 'dart:typed_data';

import 'package:comic_center/core/browser/browser_fetch.dart';
import 'package:comic_center/core/extensions/extension_factory.dart';
import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/extensions/sources/flamecomics_source.dart';
import 'package:comic_center/core/extensions/sources/madara_source.dart';
import 'package:comic_center/core/extensions/sources/mangakakalot_source.dart';
import 'package:comic_center/core/extensions/sources/mangathemesia_source.dart';
import 'package:comic_center/core/extensions/sources/webtoons_source.dart';
import 'package:comic_center/core/extensions/sources/weebcentral_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String site, String file) =>
    File('test/fixtures/$site/$file').readAsStringSync();

class _MockAdapter implements HttpClientAdapter {
  final stubs = <String, (String, int)>{};
  final requests = <RequestOptions>[];
  void stub(String method, String path, String body, {int status = 200}) =>
      stubs['$method $path'] = (body, status);
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final key = '${options.method} ${options.uri.path}';
    final response = stubs[key];
    if (response == null) throw StateError('Unstubbed request: $key');
    return ResponseBody.fromString(response.$1, response.$2, headers: {
      Headers.contentTypeHeader: ['text/plain; charset=utf-8']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('MangaThemesia falls back from malformed JSON to lazy reader images',
      () async {
    final adapter = _MockAdapter()..stub('GET', '/chapter-1/', '''
      <script>ts_reader.run({broken: true});</script>
      <div id="readerarea"><img data-src="//cdn.example/1.jpg" src="data:image/gif;base64,AA"><img src="/2.jpg"></div>
    ''');
    final source = MangaThemesiaSource(
        id: 'test',
        name: 'Test',
        baseUrl: 'https://example.com',
        dio: Dio()..httpClientAdapter = adapter);
    expect(await source.fetchPageUrls('chapter-1'),
        ['https://cdn.example/1.jpg', 'https://example.com/2.jpg']);
  });
  test('theme chapter parsers use decimal slugs and parse relative dates',
      () async {
    for (final theme in ['ts', 'madara']) {
      final adapter = _MockAdapter()
        ..stub(
            'GET',
            '/manga/example/',
            theme == 'ts'
                ? '''
        <div id="chapterlist"><li><a href="/example-chapter-12-5/"><span class="chapternum">Bonus</span><span class="chapterdate">2 days ago</span></a></li></div>
      '''
                : '''
        <li class="wp-manga-chapter"><a href="/manga/example/chapter-12-5/">Bonus</a><span class="chapter-release-date">2 days ago</span></li>
      ''');
      final dio = Dio()..httpClientAdapter = adapter;
      final MangaSource source = theme == 'ts'
          ? MangaThemesiaSource(
              id: 'test',
              name: 'Test',
              baseUrl: 'https://example.com',
              dio: dio)
          : MadaraSource(
              id: 'test',
              name: 'Test',
              baseUrl: 'https://example.com',
              dio: dio);
      final chapter = (await source.fetchChapterList('manga/example')).single;
      expect(chapter.number, 12.5);
      expect(chapter.title, 'Bonus');
      expect(DateTime.now().difference(chapter.uploadDate!).inHours, 48);
    }
  });
  test('Mangakakalot script CDN paths retain numeric page order', () async {
    final adapter = _MockAdapter()..stub('GET', '/manga/example/chapter-1', '''
      <script>const cdns = ["https://cdn.example"]; const chapterImages = ["/images/1.jpg","images/2.jpg"];</script>
    ''');
    final source = MangakakalotSource(
        id: 'test',
        name: 'Test',
        baseUrl: 'https://example.com',
        dio: Dio()..httpClientAdapter = adapter);
    expect(await source.fetchPageUrls('manga/example/chapter-1'), [
      'https://cdn.example/images/1.jpg',
      'https://cdn.example/images/2.jpg'
    ]);
  });
  final cases = <({
    String site,
    MangaSource Function(Dio) create,
    String listPath,
    String mangaId,
    String detailPath,
    String chapterPath,
    String pageId,
    String pagePath,
    String title,
    String status,
    List<double> numbers,
    bool synthetic
  })>[
    (
      site: 'thunderscans',
      create: (d) => MangaThemesiaSource(
          id: 'thunderscans_en',
          name: 'ThunderScans',
          baseUrl: 'https://en-thunderscans.com',
          cataloguePath: '/comics/',
          dio: d),
      listPath: '/comics/',
      mangaId: 'comics/0086250808-i-got-the-weakest-class-dragon-tamer',
      detailPath: '/comics/0086250808-i-got-the-weakest-class-dragon-tamer/',
      chapterPath: '',
      pageId: '1482765166-i-got-the-weakest-class-dragon-tamer-1',
      pagePath: '/1482765166-i-got-the-weakest-class-dragon-tamer-1/',
      title: 'I Got The Weakest Class, Dragon Tamer!?',
      status: 'ongoing',
      numbers: [1, 2],
      synthetic: false
    ),
    (
      site: 'rizzfables',
      create: (d) => MangaThemesiaSource(
          id: 'rizzfables_en',
          name: 'Rizz Fables',
          baseUrl: 'https://rizzfables.com',
          cataloguePath: '/series',
          filterPath: '/Index/filter_series',
          dio: d),
      listPath: '/Index/filter_series',
      mangaId: 'series/r2311170-a-bad-person',
      detailPath: '/series/r2311170-a-bad-person/',
      chapterPath: '',
      pageId: 'chapter/r2311170-a-bad-person-chapter-1',
      pagePath: '/chapter/r2311170-a-bad-person-chapter-1/',
      title: 'A Bad Person',
      status: 'ongoing',
      numbers: [1, 2],
      synthetic: false
    ),
    (
      site: 'manhwatop',
      create: (d) => MadaraSource(
          id: 'manhwatop_en',
          name: 'ManhwaTop',
          baseUrl: 'https://manhwatop.com',
          isNsfw: true,
          dio: d),
      listPath: '/manga/',
      mangaId: 'manga/martial-peak-series',
      detailPath: '/manga/martial-peak-series/',
      chapterPath: '/manga/martial-peak-series/ajax/chapters/',
      pageId: 'manga/martial-peak-series/chapter-1',
      pagePath: '/manga/martial-peak-series/chapter-1/',
      title: 'Martial Peak',
      status: 'ongoing',
      numbers: [1, 2],
      synthetic: true
    ),
    (
      site: 'manhuaplus',
      create: (d) => MadaraSource(
          id: 'manhuaplus_en',
          name: 'ManhuaPlus',
          baseUrl: 'https://manhuaplus.com',
          dio: d),
      listPath: '/manga/',
      mangaId: 'manga/martial-peak',
      detailPath: '/manga/martial-peak/',
      chapterPath: '',
      pageId: 'manga/martial-peak/chapter-3860',
      pagePath: '/manga/martial-peak/chapter-3860/',
      title: 'Martial Peak',
      status: 'ongoing',
      numbers: [500, 3860],
      synthetic: false
    ),
    (
      site: 'toonily',
      create: (d) => MadaraSource(
          id: 'toonily_en',
          name: 'Toonily',
          baseUrl: 'https://toonily.com',
          cataloguePath: '/serie/',
          genrePath: '/genre/',
          isNsfw: true,
          dio: d),
      listPath: '/serie/',
      mangaId: 'serie/the-beginning-after-the-end-54f5cb7c',
      detailPath: '/serie/the-beginning-after-the-end-54f5cb7c/',
      chapterPath: '',
      pageId: 'serie/the-beginning-after-the-end-54f5cb7c/chapter-1',
      pagePath: '/serie/the-beginning-after-the-end-54f5cb7c/chapter-1/',
      title: 'The Beginning After the End',
      status: 'ongoing',
      numbers: [1, 2],
      synthetic: false
    ),
    (
      site: 'weebcentral',
      create: WeebCentralSource.new,
      listPath: '/search/data',
      mangaId: '01J76XY7E4JCPK14V53BVQWD9Y',
      detailPath: '/series/01J76XY7E4JCPK14V53BVQWD9Y',
      chapterPath: '/series/01J76XY7E4JCPK14V53BVQWD9Y/full-chapter-list',
      pageId: '01J76XYY6FR49PR82YQB2FR3MK',
      pagePath: '/chapters/01J76XYY6FR49PR82YQB2FR3MK/images',
      title: 'Bleach',
      status: 'completed',
      numbers: [1, 2],
      synthetic: false
    ),
    (
      site: 'flamecomics',
      create: FlameComicsSource.new,
      listPath: '/browse',
      mangaId: '2',
      detailPath: '/series/2',
      chapterPath: '',
      pageId: '2/0c9db8012fbd1257',
      pagePath: '/series/2/0c9db8012fbd1257',
      title: "Omniscient Reader's Viewpoint",
      status: 'hiatus',
      numbers: [0, 1],
      synthetic: false
    ),
    (
      site: 'webtoons',
      create: WebtoonsSource.new,
      listPath: '/en/ranking/popular',
      mangaId: 'webtoon/6054',
      detailPath: '/episodeList',
      chapterPath: '/api/v1/webtoon/6054/episodes',
      pageId:
          'en/drama/the-price-is-your-everything/ep-1-murder-of-the-crown-princess/viewer?title_no=6054&episode_no=1',
      pagePath:
          '/en/drama/the-price-is-your-everything/ep-1-murder-of-the-crown-princess/viewer',
      title: 'The Price Is Your Everything',
      status: 'ongoing',
      numbers: [1, 2],
      synthetic: false
    ),
    for (final site in ['mangakakalot', 'natomanga'])
      (
        site: site,
        create: (d) => MangakakalotSource(
            id: '${site}_en',
            name: site,
            baseUrl: site == 'mangakakalot'
                ? 'https://www.mangakakalot.gg'
                : 'https://www.natomanga.com',
            dio: d),
        listPath: '/manga-list/hot-manga',
        mangaId: 'rise-of-the-limitless-necromancer',
        detailPath: '/manga/rise-of-the-limitless-necromancer',
        chapterPath: '/api/manga/rise-of-the-limitless-necromancer/chapters',
        pageId: 'manga/rise-of-the-limitless-necromancer/chapter-1',
        pagePath: '/manga/rise-of-the-limitless-necromancer/chapter-1',
        title: 'Fixture series',
        status: 'ongoing',
        numbers: [1, 2],
        synthetic: true
      ),
  ];

  for (final c in cases) {
    group(c.site, () {
      late _MockAdapter adapter;
      late MangaSource source;
      late Dio dio;
      final family = c.site == 'mangakakalot' || c.site == 'natomanga';
      setUp(() {
        adapter = _MockAdapter();
        dio = Dio()..httpClientAdapter = adapter;
        source = c.create(dio);
        if (source is MadaraSource) {
          adapter.stub(
              'GET', '${c.listPath}page/2/', fixture(c.site, 'popular.html'));
          adapter.stub('GET', '/page/3/', fixture(c.site, 'popular.html'));
        }
        adapter.stub(
            c.site == 'rizzfables' ? 'POST' : 'GET',
            c.listPath,
            fixture(
                c.site,
                family
                    ? 'home-cards.html'
                    : c.site == 'rizzfables'
                        ? 'popular.json'
                        : 'popular.html'));
        adapter.stub('GET', c.detailPath,
            fixture(c.site, family ? 'detail.synthetic.html' : 'detail.html'));
        if (c.chapterPath.isNotEmpty) {
          adapter.stub(
              c.site == 'manhwatop' ? 'POST' : 'GET',
              c.chapterPath,
              fixture(
                  c.site,
                  c.site == 'manhwatop'
                      ? 'chapters.synthetic.html'
                      : c.site == 'weebcentral'
                          ? 'chapters.html'
                          : 'chapters.json'));
        }
        adapter.stub(
            'GET',
            c.pagePath,
            fixture(
                c.site, c.synthetic ? 'pages.synthetic.html' : 'pages.html'));
      });

      test('optional registration, headers, and bounded timeouts', () {
        expect(ExtensionFactory.create(source.id), isNotNull);
        final entry = ExtensionFactory.builtInExtensions
            .singleWhere((e) => e.sourceId == source.id);
        expect(ExtensionFactory.pkgToSourceId[entry.pkg], source.id);
        expect(
            entry.isNsfw,
            ['manhwatop', 'toonily', 'weebcentral', 'mangakakalot', 'natomanga']
                .contains(c.site));
        expect(source.imageHeaders['Referer'], startsWith('https://'));
        if (source is MadaraSource || source is MangakakalotSource) {
          expect(
            source.imageHeaders['User-Agent'],
            BrowserFetch.instance.userAgent,
          );
          expect(
            dio.options.headers['User-Agent'],
            BrowserFetch.instance.userAgent,
          );
        }
        expect(dio.options.connectTimeout, const Duration(seconds: 15));
        expect(dio.options.receiveTimeout, const Duration(seconds: 25));
        final manager =
            File('lib/core/services/extension_manager.dart').readAsStringSync();
        expect(manager, isNot(contains("'${source.id}'")),
            reason: 'New sources must remain optional installs.');
      });
      test(
          family
              ? 'catalogue parser accepts captured homepage cards (route blocked live)'
              : 'popular parses captured catalogue with covers', () async {
        final results = await source.fetchPopular();
        expect(results, isNotEmpty);
        expect(
            results.every((m) =>
                m.id.isNotEmpty &&
                m.title.isNotEmpty &&
                (m.coverUrl?.startsWith('https://') ?? false)),
            isTrue);
        expect(results.map((m) => m.id).toSet().length, results.length);
      });
      test(
          family
              ? 'detail parses synthetic contract case'
              : 'detail parses captured title, status and genres', () async {
        final detail = await source.fetchMangaDetail(c.mangaId);
        expect(detail.title, c.title);
        expect(detail.status, c.status);
        expect(detail.genres, isNotEmpty);
        expect(detail.coverUrl, startsWith('https://'));
        expect(detail.description, isNotEmpty);
      });
      test(
          c.site == 'manhwatop'
              ? 'AJAX chapters parse synthetic contract case in order'
              : 'captured chapters have numbers, dates and ascending order',
          () async {
        final chapters = await source.fetchChapterList(c.mangaId);
        expect(chapters.map((ch) => ch.number), c.numbers);
        expect(
            chapters.every((ch) => ch.id.isNotEmpty && ch.uploadDate != null),
            isTrue);
        expect(chapters.map((ch) => ch.id), contains(c.pageId));
      });
      test(
          c.synthetic
              ? 'reader parses synthetic contract case'
              : 'reader parses captured ordered page URLs', () async {
        final pages = await source.fetchPageUrls(c.pageId);
        expect(pages, isNotEmpty);
        expect(
            pages.every((url) => Uri.tryParse(url)?.scheme == 'https'), isTrue);
        expect(pages.toSet().length, pages.length);
        if (c.site == 'flamecomics') {
          expect(pages[2], contains('/003-168.jpg'));
          expect(pages[10], contains('/011-127.jpg'));
        }
        if (c.site == 'webtoons') {
          expect(source.imageHeaders['Referer'], 'https://www.webtoons.com');
        }
      });
      test('network failures propagate and empty readers fail explicitly',
          () async {
        adapter.stub('GET', c.pagePath, 'Blocked', status: 403);
        await expectLater(
            source.fetchPageUrls(c.pageId), throwsA(isA<DioException>()));
        adapter.stub('GET', c.pagePath, '<html></html>');
        await expectLater(
            source.fetchPageUrls(c.pageId), throwsA(isA<Exception>()));
      });
      test('popular paging and latest/search routes preserve arguments',
          () async {
        await source.fetchPopular(page: 2);
        final params = adapter.requests.last.queryParameters;
        if (source is WeebCentralSource) {
          expect(params['offset'], 32);
          expect(params['sort'], 'Popularity');
          await source.fetchLatestUpdates(page: 3);
          expect(
              adapter.requests.last.queryParameters['sort'], 'Latest Updates');
          await source.search('a & b', page: 2);
          expect(adapter.requests.last.queryParameters['text'], 'a & b');
        } else if (source is MangaThemesiaSource) {
          if (c.site == 'rizzfables') {
            expect(await source.fetchPopular(page: 2), isEmpty);
            expect(
                (adapter.requests.last.data as Map)['OrderValue'], 'popular');
            expect((await source.search('bad')).single.id, c.mangaId);
          } else {
            expect(params['page'], 2);
            adapter.stub('GET', '/', fixture(c.site, 'popular.html'));
            await source.search('dragon', page: 3);
            expect(adapter.requests.last.queryParameters['s'], 'dragon');
            expect(adapter.requests.last.queryParameters['paged'], 3);
          }
          await source.fetchLatestUpdates();
        } else if (source is MadaraSource) {
          expect(adapter.requests.last.uri.path, '${c.listPath}page/2/');
          expect(params['m_orderby'], 'views');
          await source.fetchLatestUpdates();
          expect(adapter.requests.last.queryParameters['m_orderby'], 'latest');
          await source.search('martial', page: 3);
          expect(adapter.requests.last.queryParameters,
              {'s': 'martial', 'post_type': 'wp-manga'});
        } else if (source is MangakakalotSource) {
          expect(params['page'], 2);
          adapter.stub('GET', '/manga-list/latest-manga',
              fixture(c.site, 'home-cards.html'));
          adapter.stub('GET', '/search/story/one_piece',
              fixture(c.site, 'home-cards.html'));
          await source.fetchLatestUpdates(page: 3);
          expect(adapter.requests.last.queryParameters['page'], 3);
          await source.search('one piece', page: 2);
          expect(adapter.requests.last.uri.path, '/search/story/one_piece');
        } else if (source is FlameComicsSource) {
          expect(await source.fetchPopular(page: 2), isEmpty);
          adapter.stub('GET', '/', fixture(c.site, 'latest.html'));
          expect(await source.fetchLatestUpdates(), isNotEmpty);
          expect(await source.search('not a real title'), isEmpty);
        } else if (source is WebtoonsSource) {
          adapter.stub(
              'GET', '/en/search/originals', fixture(c.site, 'popular.html'));
          await source.search('tower', page: 3);
          expect(adapter.requests.last.queryParameters,
              {'keyword': 'tower', 'page': 3});
        }
      });
      if (c.site == 'manhwatop') {
        test(
            'older admin-ajax fallback sends form data and propagates double failure',
            () async {
          adapter.stub('POST', c.chapterPath, '', status: 404);
          adapter.stub('POST', '/wp-admin/admin-ajax.php',
              fixture(c.site, 'chapters.synthetic.html'));
          expect(await source.fetchChapterList(c.mangaId), hasLength(2));
          expect(adapter.requests.last.data,
              {'action': 'manga_get_chapters', 'manga': '4158'});
          expect(adapter.requests.last.contentType,
              Headers.formUrlEncodedContentType);
          adapter.stub('POST', '/wp-admin/admin-ajax.php', '', status: 403);
          await expectLater(
              source.fetchChapterList(c.mangaId), throwsA(isA<DioException>()));
          adapter.stub('POST', c.chapterPath, '<ul></ul>');
          adapter.requests.clear();
          await expectLater(
              source.fetchChapterList(c.mangaId), throwsA(isA<DioException>()));
          expect(
              adapter.requests
                  .where((r) => r.uri.path == '/wp-admin/admin-ajax.php'),
              hasLength(1));
        });
      }
    });
  }
}
