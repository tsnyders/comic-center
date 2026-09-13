import 'dart:convert';
import 'dart:typed_data';

import 'package:comic_center/core/extensions/extension_factory.dart';
import 'package:comic_center/core/extensions/sources/asura_scans_source.dart';
import 'package:comic_center/core/extensions/sources/mangapill_source.dart';
import 'package:comic_center/core/extensions/sources/mangataro_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubResponse {
  const _StubResponse(this.body, {this.contentType = Headers.jsonContentType});

  final Object body;
  final String contentType;
}

class _MockAdapter implements HttpClientAdapter {
  final Map<String, _StubResponse> _stubs = {};
  final List<RequestOptions> requests = [];

  void stubJson(String path, Object body) {
    _stubs[path] = _StubResponse(body);
  }

  void stubHtml(String path, String body) {
    _stubs[path] =
        _StubResponse(body, contentType: Headers.textPlainContentType);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final stub = _stubs[options.path];
    if (stub == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'No stub for ${options.path}',
      );
    }
    final body =
        stub.body is String ? stub.body as String : jsonEncode(stub.body);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [stub.contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(String baseUrl, _MockAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('required source registration', () {
    test('all required sources can be created', () {
      expect(ExtensionFactory.create('mangapill_en'), isA<MangaPillSource>());
      expect(ExtensionFactory.create('mangataro_en'), isA<MangaTaroSource>());
      expect(ExtensionFactory.create('asurascans_en'), isA<AsuraScansSource>());
    });

    test('all required sources are built-in catalogue entries', () {
      final ids = ExtensionFactory.builtInExtensions
          .map((extension) => extension.sourceId)
          .toSet();
      expect(
        ids,
        containsAll(<String>{
          'mangapill_en',
          'mangataro_en',
          'asurascans_en',
        }),
      );
    });
  });

  group('AsuraScansSource', () {
    test('parses live API shapes for covers, chapters, and pages', () async {
      final adapter = _MockAdapter();
      adapter.stubJson('/series', {
        'data': [
          {
            'slug': 'nano-machine',
            'title': 'Nano Machine',
            'cover': 'https://cdn.asurascans.com/cover.webp',
            'public_url': '/comics/nano-machine-53fc8424',
          },
        ],
      });
      adapter.stubJson('/series/nano-machine/chapters', {
        'data': [
          {
            'id': 123,
            'slug': 'chapter-7',
            'number': 7,
            'published_at': '2026-09-01T00:00:00Z',
          },
        ],
      });
      adapter.stubJson('/series/nano-machine/chapters/chapter-7', {
        'data': {
          'chapter': {
            'pages': [
              {'url': 'https://cdn.asurascans.com/page-1.webp'},
              {'url': 'https://cdn.asurascans.com/page-2.webp'},
            ],
          },
        },
      });
      final source = AsuraScansSource(
        _dio('https://api.asurascans.com', adapter),
      );

      final popular = await source.fetchPopular();
      final chapters = await source.fetchChapterList('nano-machine');
      final pages = await source.fetchPageUrls(chapters.single.id);

      expect(popular.single.coverUrl, endsWith('cover.webp'));
      expect(popular.single.url,
          'https://asurascans.com/comics/nano-machine-53fc8424');
      expect(chapters.single.id, 'nano-machine::chapter-7::7');
      expect(chapters.single.number, 7);
      expect(pages, hasLength(2));
      expect(source.imageHeaders['Referer'], 'https://asurascans.com/');
    });
  });

  group('MangaPillSource', () {
    test('parses cover, chapter list, and reader pages', () async {
      final adapter = _MockAdapter();
      adapter.stubHtml('/search', '''
        <div>
          <a href="/manga/2/one-piece"><img data-src="https://cdn.test/cover.webp"></a>
          <a href="/manga/2/one-piece"><div>One Piece</div></a>
        </div>
      ''');
      adapter.stubHtml('/manga/2/one-piece', '''
        <meta property="og:image" content="https://cdn.test/cover.webp">
        <div><div><h1>One Piece</h1></div><p class="text--secondary">Pirates.</p></div>
        <label>Status</label><div>publishing</div>
        <a href="/search?genre=Action">Action</a>
        <a href="/chapters/2-1000/one-piece-chapter-1" title="Chapter 1">Chapter 1</a>
      ''');
      adapter.stubHtml('/chapters/2-1000/one-piece-chapter-1', '''
        <img class="js-page" data-src="https://cdn.test/1.png">
        <img class="js-page" data-src="https://cdn.test/2.png">
      ''');
      final source = MangaPillSource(_dio('https://mangapill.com', adapter));

      final results = await source.search('one piece');
      final detail = await source.fetchMangaDetail(results.single.id);
      final chapters = await source.fetchChapterList(results.single.id);
      final pages = await source.fetchPageUrls(chapters.single.id);

      expect(results.single.title, 'One Piece');
      expect(results.single.coverUrl, 'https://cdn.test/cover.webp');
      expect(detail.status, 'ongoing');
      expect(detail.genres, ['Action']);
      expect(chapters.single.number, 1);
      expect(pages, ['https://cdn.test/1.png', 'https://cdn.test/2.png']);
    });
  });

  group('MangaTaroSource', () {
    test('parses catalogue, detail, protected chapter list, and pages',
        () async {
      final adapter = _MockAdapter();
      adapter.stubJson('/wp-json/manga/v1/load', [
        {
          'title': 'Dandadan',
          'url': 'https://mangataro.org/manga/dandadan',
          'cover': 'https://mangataro.org/cover.jpg',
        },
      ]);
      adapter.stubHtml('/manga/dandadan', '''
        <script type="application/ld+json">
          {"@type":"ComicSeries","name":"Dandadan","author":{"name":"Yukinobu Tatsu"},"status":"Ongoing"}
        </script>
        <div class="manga-page-wrapper"><img src="https://mangataro.org/cover.jpg"></div>
        <h1>Dandadan</h1>
        <div id="description-content-tab">Ghosts and aliens.</div>
        <a href="/tag/action">Action</a>
        <div class="chapter-list" data-manga-id="13497"></div>
      ''');
      adapter.stubJson('/auth/manga-chapters', {
        'success': true,
        'chapters': [
          {
            'id': '700805',
            'chapter': '245',
            'title': '',
            'language': 'en',
            'url': 'https://mangataro.org/read/dandadan/ch245-700805',
          },
        ],
      });
      adapter.stubJson('/auth/chapter-content', {
        'success': true,
        'images': [
          'https://mangataro.yachts/storage/001.webp',
          'https://mangataro.yachts/storage/002.webp',
        ],
      });
      final source = MangaTaroSource(
        _dio('https://mangataro.org', adapter),
        () => DateTime.utc(2026, 9, 13, 20),
      );

      final results = await source.search('dandadan');
      final detail = await source.fetchMangaDetail(results.single.id);
      final chapters = await source.fetchChapterList(results.single.id);
      final pages = await source.fetchPageUrls(chapters.single.id);

      expect(results.single.id, 'dandadan');
      expect(results.single.coverUrl, endsWith('cover.jpg'));
      expect(detail.author, 'Yukinobu Tatsu');
      expect(detail.genres, ['Action']);
      expect(chapters.single.id, '700805');
      expect(chapters.single.number, 245);
      expect(pages, hasLength(2));

      final chapterRequest = adapter.requests
          .firstWhere((request) => request.path == '/auth/manga-chapters');
      expect(chapterRequest.queryParameters['_t'], hasLength(16));
      expect(chapterRequest.queryParameters['_ts'], 1789329600);
    });
  });
}
