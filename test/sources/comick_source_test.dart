import 'dart:convert';
import 'dart:typed_data';

import 'package:comic_center/core/extensions/sources/comick_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Minimal Dio HTTP adapter that returns pre-registered JSON responses ────

class _MockAdapter implements HttpClientAdapter {
  final Map<String, dynamic> _stubs = {};

  void stub(String path, dynamic json) => _stubs[path] = json;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    // Try exact match first, then prefix match (handles query-param paths)
    final body = _stubs[path] ??
        _stubs.entries
            .firstWhere(
              (e) => path.startsWith(e.key) || e.key == path.split('?').first,
              orElse: () => const MapEntry('', null),
            )
            .value;

    if (body == null) {
      throw DioException(
        requestOptions: options,
        message: 'No mock stub for path "$path"',
        type: DioExceptionType.connectionError,
      );
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ComicKSource _buildSource(_MockAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.comick.fun',
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.httpClientAdapter = adapter;
  return ComicKSource(dio);
}

// ── Sample API payloads ───────────────────────────────────────────────────

final _searchItem = {
  'hid': 'testHid1',
  'slug': 'solo-leveling',
  'title': 'Solo Leveling',
  'md_covers': [
    {'b2key': 'cover_solo_leveling.jpg'},
  ],
};

final _searchResponse = [_searchItem];

final _detailResponse = {
  'comic': {
    'hid': 'testHid1',
    'slug': 'solo-leveling',
    'title': 'Solo Leveling',
    'desc': 'A great manhwa.',
    'status': 2,
    'md_covers': [
      {'b2key': 'cover_solo_leveling.jpg'},
    ],
  },
  'authors': [
    {'name': 'Chugong'},
  ],
  'artists': [
    {'name': 'DUBU'},
  ],
  'genres': [
    {'name': 'Action'},
    {'name': 'Fantasy'},
  ],
};

final _chaptersResponse = {
  'chapters': [
    {
      'hid': 'chapHid1',
      'chap': '1',
      'title': 'Arise',
      'lang': 'en',
      'updated_at': '2023-01-01T00:00:00Z',
      'group_name': ['Scanlation Group A'],
    },
    {
      'hid': 'chapHid2',
      'chap': '2',
      'title': null,
      'lang': 'en',
      'updated_at': '2023-01-08T00:00:00Z',
      'group_name': <String>[],
    },
  ],
};

final _chapterImageResponse = {
  'chapter': {
    'hid': 'chapHid1',
    'md_images': [
      {'b2key': 'page1.jpg'},
      {'b2key': 'page2.jpg'},
      {'b2key': 'page3.jpg'},
    ],
  },
};

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('ComicKSource', () {
    test('source metadata is correct', () {
      final source = ComicKSource();
      expect(source.id, 'comick_en');
      expect(source.name, 'ComicK');
      expect(source.baseUrl, 'https://comick.io');
      expect(source.language, 'en');
      expect(source.imageHeaders['Referer'], 'https://comick.io/');
    });

    group('fetchPopular', () {
      test('parses search response into MangaSummary list', () async {
        final adapter = _MockAdapter();
        adapter.stub('/v1.0/search', _searchResponse);
        final source = _buildSource(adapter);

        final results = await source.fetchPopular();

        expect(results, hasLength(1));
        expect(results.first.id, 'testHid1');
        expect(results.first.title, 'Solo Leveling');
        expect(results.first.coverUrl,
            'https://meo.comick.pictures/cover_solo_leveling.jpg');
        expect(results.first.url, 'https://comick.io/comic/solo-leveling');
      });

      test('handles empty response without error', () async {
        final adapter = _MockAdapter();
        adapter.stub('/v1.0/search', <dynamic>[]);
        final source = _buildSource(adapter);

        final results = await source.fetchPopular();
        expect(results, isEmpty);
      });

      test('handles missing md_covers gracefully', () async {
        final adapter = _MockAdapter();
        adapter.stub('/v1.0/search', [
          {'hid': 'h1', 'slug': 'test-manga', 'title': 'Test', 'md_covers': []},
        ]);
        final source = _buildSource(adapter);

        final results = await source.fetchPopular();
        expect(results.first.coverUrl, isNull);
      });
    });

    group('fetchLatestUpdates', () {
      test('returns parsed summaries', () async {
        final adapter = _MockAdapter();
        adapter.stub('/v1.0/search', _searchResponse);
        final source = _buildSource(adapter);

        final results = await source.fetchLatestUpdates();
        expect(results, hasLength(1));
        expect(results.first.title, 'Solo Leveling');
      });
    });

    group('search', () {
      test('returns matching results', () async {
        final adapter = _MockAdapter();
        adapter.stub('/v1.0/search', _searchResponse);
        final source = _buildSource(adapter);

        final results = await source.search('solo');
        expect(results, hasLength(1));
        expect(results.first.title, 'Solo Leveling');
      });
    });

    group('fetchMangaDetail', () {
      test('parses all fields correctly', () async {
        final adapter = _MockAdapter();
        adapter.stub('/comic/testHid1', _detailResponse);
        final source = _buildSource(adapter);

        final detail = await source.fetchMangaDetail('testHid1');

        expect(detail.id, 'testHid1');
        expect(detail.title, 'Solo Leveling');
        expect(detail.description, 'A great manhwa.');
        expect(detail.author, 'Chugong');
        expect(detail.artist, 'DUBU');
        expect(detail.genres, containsAll(['Action', 'Fantasy']));
        expect(detail.status, 'completed'); // status code 2
        expect(detail.coverUrl,
            'https://meo.comick.pictures/cover_solo_leveling.jpg');
        expect(detail.url, 'https://comick.io/comic/solo-leveling');
      });

      test('maps status codes correctly', () async {
        Future<String> statusFor(int code) async {
          final adapter = _MockAdapter();
          final payload = Map<String, dynamic>.from(_detailResponse);
          payload['comic'] = Map<String, dynamic>.from(
              _detailResponse['comic'] as Map<String, dynamic>)
            ..['status'] = code;
          adapter.stub('/comic/x', payload);
          final detail = await _buildSource(adapter).fetchMangaDetail('x');
          return detail.status;
        }

        expect(await statusFor(1), 'ongoing');
        expect(await statusFor(2), 'completed');
        expect(await statusFor(3), 'cancelled');
        expect(await statusFor(4), 'hiatus');
        expect(await statusFor(99), 'unknown');
      });
    });

    group('fetchChapterList', () {
      test('parses chapters with titles and dates', () async {
        final adapter = _MockAdapter();
        adapter.stub('/comic/testHid1/chapters', _chaptersResponse);
        final source = _buildSource(adapter);

        final chapters = await source.fetchChapterList('testHid1');

        expect(chapters, hasLength(2));

        final ch1 = chapters.first;
        expect(ch1.id, 'chapHid1');
        expect(ch1.title, 'Arise');
        expect(ch1.number, 1.0);
        expect(ch1.scanlator, 'Scanlation Group A');
        expect(ch1.language, 'en');
        expect(ch1.uploadDate, DateTime.parse('2023-01-01T00:00:00Z'));
      });

      test('falls back to "Chapter N" when title is null', () async {
        final adapter = _MockAdapter();
        adapter.stub('/comic/testHid1/chapters', _chaptersResponse);
        final source = _buildSource(adapter);

        final chapters = await source.fetchChapterList('testHid1');
        expect(chapters[1].title, 'Chapter 2');
      });

      test('returns empty list when chapters key is missing', () async {
        final adapter = _MockAdapter();
        adapter.stub('/comic/x/chapters', <String, dynamic>{});
        final source = _buildSource(adapter);

        final chapters = await source.fetchChapterList('x');
        expect(chapters, isEmpty);
      });
    });

    group('fetchPageUrls', () {
      test('returns CDN URLs from md_images', () async {
        final adapter = _MockAdapter();
        adapter.stub('/chapter/chapHid1', _chapterImageResponse);
        final source = _buildSource(adapter);

        final urls = await source.fetchPageUrls('chapHid1');

        expect(urls, hasLength(3));
        expect(urls[0], 'https://meo.comick.pictures/page1.jpg');
        expect(urls[1], 'https://meo.comick.pictures/page2.jpg');
        expect(urls[2], 'https://meo.comick.pictures/page3.jpg');
      });

      test('filters out entries with empty b2key', () async {
        final adapter = _MockAdapter();
        adapter.stub('/chapter/c1', {
          'chapter': {
            'md_images': [
              {'b2key': 'valid.jpg'},
              {'b2key': ''},
              {'b2key': 'also_valid.jpg'},
            ],
          },
        });
        final source = _buildSource(adapter);

        final urls = await source.fetchPageUrls('c1');
        expect(urls, hasLength(2));
      });

      test('returns empty list when md_images is absent', () async {
        final adapter = _MockAdapter();
        adapter.stub('/chapter/c1', {'chapter': <String, dynamic>{}});
        final source = _buildSource(adapter);

        final urls = await source.fetchPageUrls('c1');
        expect(urls, isEmpty);
      });
    });
  });
}
