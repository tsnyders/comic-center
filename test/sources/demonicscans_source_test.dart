import 'dart:typed_data';

import 'package:comic_center/core/extensions/sources/demonicscans_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Minimal Dio adapter that returns pre-registered HTML responses ─────────

class _MockAdapter implements HttpClientAdapter {
  final Map<String, String> _stubs = {};

  void stub(String path, String html) => _stubs[path] = html;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Match by path, ignoring query string
    final path = options.path.split('?').first;
    final body = _stubs[path] ?? _stubs[options.path];

    if (body == null) {
      throw DioException(
        requestOptions: options,
        message: 'No mock stub for "${options.path}"',
        type: DioExceptionType.connectionError,
      );
    }

    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DemonicScansSource _buildSource(_MockAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://demonicscans.org',
      headers: {'Accept': 'text/html'},
    ),
  );
  dio.httpClientAdapter = adapter;
  return DemonicScansSource(dio);
}

// ── HTML fixtures ─────────────────────────────────────────────────────────

const _popularHtml = '''
<html><body>
<div id="advanced-content">
  <div class="advanced-element">
    <a href="/manga/Murim-Login">
      <img src="/images/thumbnails/murim.jpg">
      <h1>Murim Login</h1>
    </a>
  </div>
  <div class="advanced-element">
    <a href="/manga/Solo-Leveling">
      <img src="https://demonicscans.org/images/thumbnails/solo.jpg">
      <h1>Solo Leveling</h1>
    </a>
  </div>
</div>
</body></html>
''';

const _latestHtml = '''
<html><body>
<div id="updates-container">
  <div class="updates-element">
    <div class="thumb"><img src="/images/thumbnails/murim.jpg"></div>
    <div class="updates-element-info"><a href="/manga/Murim-Login">Murim Login</a></div>
  </div>
  <div class="updates-element">
    <div class="toffee-badge">Ad</div>
    <div class="updates-element-info"><a href="/manga/fake-ad">Fake Ad</a></div>
  </div>
  <div class="updates-element">
    <div class="thumb"><img src="/images/thumbnails/solo.jpg"></div>
    <div class="updates-element-info"><a href="/manga/Solo-Leveling">Solo Leveling</a></div>
  </div>
</div>
</body></html>
''';

const _searchHtml = '''
<html><body>
<a href="/manga/Murim-Login">
  <img src="/images/thumbnails/murim.jpg">
  <div class="seach-right"><div>Murim Login</div></div>
</a>
<a href="/manga/Solo-Leveling">
  <img src="/images/thumbnails/solo.jpg">
  <div class="seach-right"><div>Solo Leveling</div></div>
</a>
</body></html>
''';

const _detailHtml = '''
<html><body>
<div id="manga-page"><img src="/images/covers/murim.jpg"></div>
<h1 class="big-fat-titles">Murim Login</h1>
<div class="genres-list"><li>Action</li><li>Fantasy</li></div>
<div id="manga-info-rightColumn">
  <div><div class="white-font">A great manhwa about a gamer who enters a murim world.</div></div>
</div>
<div id="manga-info-stats">
  <div><li>Author</li><li>Kim Tae-Gyun</li></div>
  <div><li>Status</li><li>Ongoing</li></div>
</div>
<div id="chapters-list">
  <a class="chplinks" href="/manga/Murim-Login/chapter-2">Chapter 2<span>2023-01-08</span></a>
  <a class="chplinks" href="/manga/Murim-Login/chapter-1">Chapter 1<span>2023-01-01</span></a>
</div>
</body></html>
''';

const _pagesHtml = '''
<html><body>
<div>
  <img class="imgholder" src="https://demonicscans.org/images/manga/murim/ch1/001.jpg">
  <img class="imgholder" src="https://demonicscans.org/images/manga/murim/ch1/002.jpg">
  <img class="imgholder" src="https://demonicscans.org/images/manga/murim/ch1/003.jpg">
</div>
</body></html>
''';

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('DemonicScansSource', () {
    test('source metadata is correct', () {
      final source = DemonicScansSource();
      expect(source.id, 'demonicscans_en');
      expect(source.name, 'DemonicScans');
      expect(source.baseUrl, 'https://demonicscans.org');
      expect(source.language, 'en');
      expect(source.imageHeaders['Referer'], 'https://demonicscans.org/');
    });

    group('fetchPopular', () {
      test('parses advanced.php grid into MangaSummary list', () async {
        final adapter = _MockAdapter()..stub('/advanced.php', _popularHtml);
        final source = _buildSource(adapter);

        final results = await source.fetchPopular();

        expect(results, hasLength(2));
        expect(results[0].id, 'Murim-Login');
        expect(results[0].title, 'Murim Login');
        expect(results[0].coverUrl,
            'https://demonicscans.org/images/thumbnails/murim.jpg');
        expect(results[0].url,
            'https://demonicscans.org/manga/Murim-Login');
        expect(results[1].id, 'Solo-Leveling');
        // Already absolute URL passes through unchanged
        expect(results[1].coverUrl,
            'https://demonicscans.org/images/thumbnails/solo.jpg');
      });

      test('returns empty list when no items in page', () async {
        final adapter = _MockAdapter()
          ..stub('/advanced.php', '<html><body><div id="advanced-content"></div></body></html>');
        final results = await _buildSource(adapter).fetchPopular();
        expect(results, isEmpty);
      });

      test('fully decodes double-encoded slug in href', () async {
        // DemonicScans serves some slugs with double-encoded hyphens, e.g.
        // "%252D" (which is "%25" + "2D" — i.e. "%2D" encoded again).
        // The slug must be fully decoded so subsequent fetchMangaDetail
        // doesn't re-encode the "%" and produce a URL the server doesn't match.
        const html = '''
<html><body>
<div id="advanced-content">
  <div class="advanced-element">
    <a href="/manga/Revenge-of-the-Iron%252DBlooded-Sword-Hound">
      <img src="/images/x.jpg"><h1>Revenge</h1>
    </a>
  </div>
</div>
</body></html>''';
        final adapter = _MockAdapter()..stub('/advanced.php', html);
        final results = await _buildSource(adapter).fetchPopular();

        expect(results.first.id, 'Revenge-of-the-Iron-Blooded-Sword-Hound');
      });
    });

    group('fetchLatestUpdates', () {
      test('filters out ad elements with .toffee-badge', () async {
        final adapter = _MockAdapter()..stub('/lastupdates.php', _latestHtml);
        final source = _buildSource(adapter);

        final results = await source.fetchLatestUpdates();

        expect(results, hasLength(2),
            reason: 'Should include 2 real entries and skip the ad');
        expect(results.any((r) => r.id == 'fake-ad'), isFalse);
        expect(results[0].id, 'Murim-Login');
        expect(results[1].id, 'Solo-Leveling');
      });

      test('returns empty list when container is empty', () async {
        final adapter = _MockAdapter()
          ..stub('/lastupdates.php',
              '<html><body><div id="updates-container"></div></body></html>');
        final results = await _buildSource(adapter).fetchLatestUpdates();
        expect(results, isEmpty);
      });
    });

    group('search', () {
      test('parses search results', () async {
        final adapter = _MockAdapter()..stub('/search.php', _searchHtml);
        final source = _buildSource(adapter);

        final results = await source.search('murim');

        expect(results, hasLength(2));
        expect(results[0].id, 'Murim-Login');
        expect(results[0].title, 'Murim Login');
        expect(results[1].title, 'Solo Leveling');
      });
    });

    group('fetchMangaDetail', () {
      test('parses title, cover, genres, description, author, status', () async {
        final adapter = _MockAdapter()
          ..stub('/manga/Murim-Login', _detailHtml);
        final source = _buildSource(adapter);

        final detail = await source.fetchMangaDetail('Murim-Login');

        expect(detail.id, 'Murim-Login');
        expect(detail.title, 'Murim Login');
        expect(detail.coverUrl,
            'https://demonicscans.org/images/covers/murim.jpg');
        expect(detail.genres, containsAll(['Action', 'Fantasy']));
        expect(detail.description,
            contains('A great manhwa about a gamer'));
        expect(detail.author, 'Kim Tae-Gyun');
        expect(detail.status, 'ongoing');
        expect(detail.url, 'https://demonicscans.org/manga/Murim-Login');
      });

      test('maps completed status correctly', () async {
        final html = _detailHtml.replaceAll('<li>Ongoing</li>', '<li>Completed</li>');
        final adapter = _MockAdapter()..stub('/manga/x', html);
        final detail = await _buildSource(adapter).fetchMangaDetail('x');
        expect(detail.status, 'completed');
      });

      test('falls back to mangaId as title when h1 missing', () async {
        final adapter = _MockAdapter()
          ..stub('/manga/my-manga', '<html><body></body></html>');
        final detail = await _buildSource(adapter).fetchMangaDetail('my-manga');
        expect(detail.title, 'my-manga');
      });
    });

    group('fetchChapterList', () {
      test('returns chapters in ascending order (oldest first)', () async {
        final adapter = _MockAdapter()
          ..stub('/manga/Murim-Login', _detailHtml);
        final source = _buildSource(adapter);

        final chapters = await source.fetchChapterList('Murim-Login');

        expect(chapters, hasLength(2));
        // Oldest chapter first
        expect(chapters[0].id, 'Murim-Login/chapter-1');
        expect(chapters[0].title, 'Chapter 1');
        expect(chapters[0].number, 1.0);
        expect(chapters[0].uploadDate, DateTime.parse('2023-01-01'));
        expect(chapters[1].id, 'Murim-Login/chapter-2');
        expect(chapters[1].number, 2.0);
      });

      test('chapter title excludes the date span text', () async {
        final adapter = _MockAdapter()
          ..stub('/manga/Murim-Login', _detailHtml);
        final chapters =
            await _buildSource(adapter).fetchChapterList('Murim-Login');
        // Title should be just "Chapter 1", not "Chapter 12023-01-01"
        expect(chapters[0].title, 'Chapter 1');
      });

      test('returns empty list when no chapters found', () async {
        final adapter = _MockAdapter()
          ..stub('/manga/x',
              '<html><body><div id="chapters-list"></div></body></html>');
        final chapters = await _buildSource(adapter).fetchChapterList('x');
        expect(chapters, isEmpty);
      });

      test('decodes percent-encoded chapter href so subsequent page fetches resolve', () async {
        const html = '''
<html><body>
<div id="chapters-list">
  <a class="chplinks" href="/manga/Revenge-of-the-Iron%252DBlooded-Sword-Hound/chapter-1">Chapter 1<span>2024-01-01</span></a>
</div>
</body></html>''';
        final adapter = _MockAdapter()
          ..stub('/manga/Revenge-of-the-Iron-Blooded-Sword-Hound', html);
        final chapters = await _buildSource(adapter)
            .fetchChapterList('Revenge-of-the-Iron-Blooded-Sword-Hound');

        expect(chapters, hasLength(1));
        expect(chapters[0].id,
            'Revenge-of-the-Iron-Blooded-Sword-Hound/chapter-1');
      });
    });

    group('fetchPageUrls', () {
      test('extracts imgholder src URLs', () async {
        final adapter = _MockAdapter()
          ..stub('/manga/Murim-Login/chapter-1', _pagesHtml);
        final source = _buildSource(adapter);

        final urls = await source.fetchPageUrls('Murim-Login/chapter-1');

        expect(urls, hasLength(3));
        expect(urls[0],
            'https://demonicscans.org/images/manga/murim/ch1/001.jpg');
        expect(urls[2],
            'https://demonicscans.org/images/manga/murim/ch1/003.jpg');
      });

      test('resolves relative image URLs to absolute', () async {
        const html = '''
<html><body>
<div><img class="imgholder" src="/images/manga/test/001.jpg"></div>
</body></html>''';
        final adapter = _MockAdapter()..stub('/manga/x/chapter-1', html);
        final urls = await _buildSource(adapter).fetchPageUrls('x/chapter-1');
        expect(urls[0], 'https://demonicscans.org/images/manga/test/001.jpg');
      });

      test('returns empty list when no imgholder images found', () async {
        final adapter = _MockAdapter()
          ..stub('/manga/x/c1', '<html><body></body></html>');
        final urls = await _buildSource(adapter).fetchPageUrls('x/c1');
        expect(urls, isEmpty);
      });

      test('fetchPageUrls uses decoded slug so URL is single-encoded', () async {
        // Verify the end-to-end flow from screenshot bug:
        // href "/manga/Revenge-of-the-Iron%252DBlooded.../chapter-1"
        //   → chapter id "Revenge-of-the-Iron-Blooded.../chapter-1"
        //   → page fetch hits "/manga/Revenge-of-the-Iron-Blooded.../chapter-1"
        //   (NOT a re-encoded "%25252D" URL).
        const pagesHtml = '''
<html><body><div>
  <img class="imgholder" src="/images/p1.jpg">
</div></body></html>''';
        final adapter = _MockAdapter()
          ..stub('/manga/Revenge-of-the-Iron-Blooded-Sword-Hound/chapter-1',
              pagesHtml);
        final source = _buildSource(adapter);

        final urls = await source.fetchPageUrls(
            'Revenge-of-the-Iron-Blooded-Sword-Hound/chapter-1');

        expect(urls, hasLength(1));
        expect(urls[0], 'https://demonicscans.org/images/p1.jpg');
      });
    });
  });
}
