import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:comic_center/core/browser/browser_fetch.dart';
import 'package:comic_center/core/extensions/extension_factory.dart';
import 'package:comic_center/core/extensions/models/filter.dart';
import 'package:comic_center/core/extensions/sources/all_manga_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_browser_fetch.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(List<Object?> responses) : _responses = [...responses];

  final List<Object?> _responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_responses.isEmpty) {
      throw DioException(
        requestOptions: options,
        message: 'No AllManga mock response remains.',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(_responses.removeAt(0)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ScriptedCaptureBrowserFetch extends FakeBrowserFetch {
  _ScriptedCaptureBrowserFetch(Iterable<Object> responses)
      : _responses = [...responses],
        super(userAgent: 'AllMangaTestBrowser/1.0');

  final List<Object> _responses;
  final List<
      ({
        Uri url,
        String jsHook,
        String channel,
        String? afterLoad,
        bool interactive
      })> captureCalls = [];

  @override
  Future<Map<String, dynamic>> capture(
    Uri url, {
    required String jsHook,
    required String channel,
    String? afterLoad,
    Duration timeout = const Duration(seconds: 30),
    bool interactive = true,
  }) async {
    calls.add('capture $url channel=$channel interactive=$interactive');
    captureCalls.add((
      url: url,
      jsHook: jsHook,
      channel: channel,
      afterLoad: afterLoad,
      interactive: interactive,
    ));
    if (_responses.isEmpty) {
      throw StateError('No scripted AllManga capture response remains.');
    }
    final response = _responses.removeAt(0);
    if (response is Exception) throw response;
    if (response is! Map) {
      throw StateError('AllManga capture response must be a map.');
    }
    return <String, dynamic>{
      for (final entry in response.entries) entry.key.toString(): entry.value,
    };
  }
}

Map<String, Object?> _fixture(String name) =>
    (jsonDecode(File('test/fixtures/allmanga/$name.json').readAsStringSync())
            as Map)
        .cast<String, Object?>();

(AllMangaSource, _MockAdapter) _source(List<Object?> responses) {
  final adapter = _MockAdapter(responses);
  final dio = Dio()..httpClientAdapter = adapter;
  return (AllMangaSource(dio), adapter);
}

Map<String, Object?> _body(RequestOptions request) =>
    (request.data as Map).cast<String, Object?>();

Map<String, Object?> _variables(RequestOptions request) =>
    (_body(request)['variables'] as Map).cast<String, Object?>();

void main() {
  group('AllMangaSource', () {
    late BrowserFetch previousBrowserFetch;

    setUp(() => previousBrowserFetch = BrowserFetch.instance);
    tearDown(() => BrowserFetch.instance = previousBrowserFetch);

    test('has stable metadata, filters, and catalogue registration', () {
      BrowserFetch.instance =
          FakeBrowserFetch(userAgent: 'AllMangaTestBrowser/1.0');
      final source = AllMangaSource();

      expect(source.id, 'all_manga_en');
      expect(source.name, 'AllManga');
      expect(source.baseUrl, 'https://allmanga.to');
      expect(source.language, 'en');
      expect(source.getFilters().whereType<SelectFilter>().single.value, 'ALL');
      expect(
        source.getFilters().whereType<GroupFilter>().single.items.single.name,
        'Show adult',
      );
      expect(source.imageHeaders['Referer'], 'https://allmanga.to/');
      expect(source.imageHeaders['User-Agent'], 'AllMangaTestBrowser/1.0');

      expect(ExtensionFactory.create('all_manga_en'), isA<AllMangaSource>());
      expect(
        ExtensionFactory
            .pkgToSourceId['eu.kanade.tachiyomi.extension.en.allmanga'],
        'all_manga_en',
      );
      final entry = ExtensionFactory.builtInExtensions
          .singleWhere((item) => item.sourceId == 'all_manga_en');
      expect(entry.pkg, 'eu.kanade.tachiyomi.extension.en.allmanga');
      expect(entry.isNsfw, isFalse);
    });

    test('popular parses recommendations and uses queryPopular variables',
        () async {
      final (source, adapter) = _source([_fixture('popular')]);

      final results = await source.fetchPopular(page: 2);

      expect(results, hasLength(3));
      expect(results.first.id, 'JJHbe9N2pe94w7t2S');
      expect(results.first.title, 'All-Class Awakening: God Slayer');
      expect(
        results.first.coverUrl,
        'https://s4.anilist.co/file/anilistcdn/media/manga/cover/medium/'
        'b197224-Pvwfb85Sswpl.jpg',
      );
      expect(
        results[1].title,
        'The Exiled Heavy Knight Knows How to Game the System',
      );
      final request = adapter.requests.single;
      expect(_body(request)['query'].toString(), contains('queryPopular'));
      expect(_variables(request), containsPair('type', 'manga'));
      expect(_variables(request), containsPair('size', 26));
      expect(_variables(request), containsPair('page', 2));
      expect(_variables(request), containsPair('dateRange', 7));
    });

    test('latest parses relative thumbnails and requests Recent manga',
        () async {
      final (source, adapter) = _source([_fixture('latest')]);

      final results = await source.fetchLatestUpdates(page: 3);

      expect(results, hasLength(3));
      expect(results.first.title, 'Super Robot Wars Tribute');
      expect(
        results.first.coverUrl,
        'https://wp.youtube-anime.com/aln.youtube-anime.com/'
        'mcovers/m_tbs/6aaf5a5671e36839afe800e3/001.webp?w=250',
      );
      final variables = _variables(adapter.requests.single);
      expect(variables['page'], 3);
      expect(variables['countryOrigin'], 'ALL');
      expect(variables['translationType'], 'sub');
      expect(
        variables['search'],
        containsPair('sortBy', 'Recent'),
      );
      expect(
        _body(adapter.requests.single)['query'].toString(),
        contains('VaildTranslationTypeMangaEnumType'),
      );
    });

    test('search maps country and Show adult filters', () async {
      final (source, adapter) = _source([_fixture('search')]);
      final defaults = source.getFilters();
      final country = defaults.whereType<SelectFilter>().single.withIndex(1);
      final content = defaults.whereType<GroupFilter>().single;
      final adult = content.withItem(
        0,
        content.items.single.withState(TriState.include),
      );

      final results = await source.search(
        'One Piece',
        page: 2,
        filters: [country, adult],
      );

      expect(results.first.id, 'ex9vXC6gWYY9bGkSo');
      expect(results.first.title, 'One Piece');
      expect(results[1].coverUrl, isNull);
      final variables = _variables(adapter.requests.single);
      expect(variables['countryOrigin'], 'JP');
      expect(variables['page'], 2);
      expect(variables['search'], containsPair('query', 'One Piece'));
      expect(variables['search'], containsPair('allowAdult', true));
      expect(variables['search'], containsPair('allowUnknown', false));
    });

    test('detail parses authors, genres, status, and relative thumbnail',
        () async {
      final (source, adapter) = _source([_fixture('detail')]);

      final detail = await source.fetchMangaDetail('ex9vXC6gWYY9bGkSo');

      expect(detail.id, 'ex9vXC6gWYY9bGkSo');
      expect(detail.title, 'One Piece');
      expect(detail.author, 'Oda Eiichiro');
      expect(detail.genres, containsAll(['Action', 'Adventure', 'Shounen']));
      expect(detail.status, 'ongoing');
      expect(
        detail.coverUrl,
        'https://wp.youtube-anime.com/aln.youtube-anime.com/'
        'mcovers/m_tbs/ex9vXC6gWYY9bGkSo/115.webp?w=250',
      );
      expect(
        _body(adapter.requests.single)['query'].toString(),
        contains(r'manga(_id:$id)'),
      );
      expect(_variables(adapter.requests.single)['id'], 'ex9vXC6gWYY9bGkSo');
    });

    test('chapters are newest first with stable composite IDs and numbers',
        () async {
      final detail = _fixture('detail');
      final data = detail['data'] as Map<String, Object?>;
      final manga = data['manga'] as Map<String, Object?>;
      final available =
          manga['availableChaptersDetail'] as Map<String, Object?>;
      available['sub'] = ['1', '1072.2', '1193', '1192'];
      final (source, _) = _source([detail]);

      final chapters = await source.fetchChapterList('ex9vXC6gWYY9bGkSo');

      expect(
          chapters.map((chapter) => chapter.number), [1193, 1192, 1072.2, 1]);
      expect(chapters.first.id, 'ex9vXC6gWYY9bGkSo|1193');
      expect(chapters.first.title, 'Chapter 1193');
      expect(
        chapters.first.url,
        'https://allmanga.to/manga/ex9vXC6gWYY9bGkSo/chapter-1193-sub',
      );
    });

    test('pages navigate the current reader and join every URL shape', () async {
      final browser = _ScriptedCaptureBrowserFetch([
        _fixture('pages'),
        <String, Object?>{
          'chapterPages': {
            'edges': [
              {
                'pictureUrls': [
                  {'url': '/manga/example/001.webp'},
                  {'url': '//images.example.test/002.webp'},
                  {'url': 'https://images.example.test/003.webp'},
                ],
              },
            ],
          },
        },
        <String, Object?>{
          'chapterPages': {
            'edges': [
              {
                'serverUrl': 'images.example.test/',
                'pictureUrlHead': 'https://old.example.test/',
                'pictureUrls': [
                  {'url': '/manga/example/1072.2/001.webp'},
                ],
              },
            ],
          },
        },
      ]);
      BrowserFetch.instance = browser;
      final source = AllMangaSource();

      final pages = await source.fetchPageUrls('ex9vXC6gWYY9bGkSo|1193');

      expect(pages, [
        'https://ytimgf.youtube-anime.com/'
            'manga/ex9vXC6gWYY9bGkSo/1193/001.webp',
        'https://ytimgf.youtube-anime.com/'
            'manga/ex9vXC6gWYY9bGkSo/1193/002.webp',
        'https://images.example.test/page-003.webp',
      ]);
      expect(source.imageHeaders['User-Agent'], 'AllMangaTestBrowser/1.0');
      final call = browser.captureCalls.single;
      expect(
        call.url,
        Uri.parse('https://mkissa.to/manga/ex9vXC6gWYY9bGkSo'),
      );
      expect(call.afterLoad,
          contains("'/manga/ex9vXC6gWYY9bGkSo/chapter-1193-sub'"));
      expect(call.afterLoad, contains('a.click()'));
      expect(call.afterLoad, contains("document.querySelector('[data-href]')"));
      expect(call.afterLoad, contains('a.remove()'));
      expect(call.channel, 'yomiAllManga');
      expect(call.interactive, isTrue);
      expect(call.jsHook, contains('Response.prototype.json'));
      expect(call.jsHook, contains('JSON.parse'));
      expect(call.jsHook, contains('data.chapterPages'));
      expect(call.jsHook, contains('data.data.chapterPages'));
      expect(call.jsHook, contains('JSON.stringify(data)'));
      expect(call.jsHook, contains('window.yomiAllManga.postMessage'));

      expect(await source.fetchPageUrls('manga-id|1'), [
        'https://ytimgf.youtube-anime.com/manga/example/001.webp',
        'https://images.example.test/002.webp',
        'https://images.example.test/003.webp',
      ]);
      expect(browser.captureCalls, hasLength(2));
      expect(await source.fetchPageUrls('manga-id|1072.2'), [
        'https://images.example.test/manga/example/1072.2/001.webp',
      ]);
      expect(browser.captureCalls.last.afterLoad,
          contains('/manga/manga-id/chapter-1072.2-sub'));
    });

    test('page capture translates retries and browser failures', () async {
      final errorPayload = <String, Object?>{
        'errors': [
          {'message': 'NEED_CAPTCHA'},
        ],
        'data': {'chapterPages': null},
      };
      final browser = _ScriptedCaptureBrowserFetch([
        errorPayload,
        errorPayload,
      ]);
      BrowserFetch.instance = browser;
      final source = AllMangaSource();

      await expectLater(
        source.fetchPageUrls('ex9vXC6gWYY9bGkSo|1193'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('AllManga pages: NEED_CAPTCHA'),
          ),
        ),
      );
      expect(browser.captureCalls, hasLength(2));
      expect(browser.captureCalls.last.interactive, isTrue);

      BrowserFetch.instance = _ScriptedCaptureBrowserFetch([
        const BrowserFetchUnavailable(),
      ]);

      await expectLater(
        AllMangaSource().fetchPageUrls('ex9vXC6gWYY9bGkSo|1193'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('AllManga pages need the in-app browser (Android)'),
          ),
        ),
      );

      BrowserFetch.instance = _ScriptedCaptureBrowserFetch([
        const BrowserChallengeCancelled(),
      ]);

      await expectLater(
        AllMangaSource().fetchPageUrls('ex9vXC6gWYY9bGkSo|1193'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Site check cancelled'),
          ),
        ),
      );
    });

    test('every GraphQL operation is POST with the required browser headers',
        () async {
      final (source, adapter) = _source([
        _fixture('popular'),
        _fixture('latest'),
        _fixture('search'),
        _fixture('detail'),
        _fixture('detail'),
      ]);

      await source.fetchPopular();
      await source.fetchLatestUpdates();
      await source.search('One Piece');
      await source.fetchMangaDetail('ex9vXC6gWYY9bGkSo');
      await source.fetchChapterList('ex9vXC6gWYY9bGkSo');

      expect(adapter.requests, hasLength(5));
      for (final request in adapter.requests) {
        expect(request.method, 'POST');
        expect(request.uri.host, 'api.allanime.day');
        expect(request.uri.path, '/api');
        expect(request.headers['Origin'], 'https://allmanga.to');
        expect(request.headers['Referer'], 'https://allmanga.to/');
        expect(request.headers['User-Agent'], contains('Chrome/'));
        expect(request.headers['Content-Type'], Headers.jsonContentType);
      }
    });
  });
}
