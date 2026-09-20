import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:comic_center/core/extensions/sources/comicextra_source.dart';
import 'package:comic_center/core/extensions/sources/asura_scans_source.dart';
import 'package:comic_center/core/extensions/sources/comick_source.dart';
import 'package:comic_center/core/extensions/sources/demonicscans_source.dart';
import 'package:comic_center/core/extensions/sources/mangadex_source.dart';
import 'package:comic_center/core/extensions/sources/mangapill_source.dart';
import 'package:comic_center/core/extensions/sources/mangataro_source.dart';
import 'package:comic_center/core/extensions/sources/readcomiconline_source.dart';
import 'package:comic_center/core/extensions/sources/reaperscans_source.dart';
import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/extensions/sources/madara_source.dart';
import 'package:comic_center/core/extensions/sources/mangathemesia_source.dart';
import 'package:comic_center/core/extensions/sources/flamecomics_source.dart';
import 'package:comic_center/core/extensions/sources/webtoons_source.dart';
import 'package:comic_center/core/extensions/sources/weebcentral_source.dart';
import 'package:comic_center/core/extensions/sources/mangakakalot_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  final Map<String, Object> responses = {};
  final List<RequestOptions> requests = [];

  void stub(String path, Object body) => responses[path] = body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = responses[options.path];
    if (body == null) {
      throw DioException(requestOptions: options, message: 'No stub: ${options.path}');
    }
    final isHtml = body is String;
    return ResponseBody.fromString(
      isHtml ? body : jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [
          isHtml ? Headers.textPlainContentType : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(String baseUrl, _StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  for (final site in ['thunderscans', 'rizzfables']) {
    test('$site theme genres retain native IDs on paged requests', () async {
      final path = site == 'thunderscans' ? '/comics/' : '/series';
      final adapter = _StubAdapter()..stub(path,
          File('test/fixtures/$site/genres.html').readAsStringSync());
      final source = MangaThemesiaSource(id: '${site}_en', name: site,
          baseUrl: site == 'thunderscans' ? 'https://en-thunderscans.com' : 'https://rizzfables.com',
          cataloguePath: path, filterPath: site == 'rizzfables' ? '/Index/filter_series' : null,
          dio: _dio('https://fixture.test', adapter));
      final genres = await source.fetchGenres();
      final action = genres.firstWhere((g) => g.name.toLowerCase() == 'action');
      expect(action.id, isNotEmpty);
      if (site == 'rizzfables') {
        adapter.stub('/Index/filter_series', File('test/fixtures/rizzfables/popular.json').readAsStringSync());
      } else {
        adapter.stub(path, File('test/fixtures/thunderscans/popular.html').readAsStringSync());
      }
      await source.fetchByGenre(action.id, page: 2);
      if (site == 'rizzfables') {
        expect(adapter.requests.last.method, 'POST');
        expect(adapter.requests.last.data['genres_checked[]'], action.id);
        expect(adapter.requests.last.data['OrderValue'], 'popular');
      } else {
        expect(adapter.requests.last.queryParameters['genre[]'], action.id);
        expect(adapter.requests.last.queryParameters['page'], 2);
      }
    });
  }
  for (final site in ['manhwatop', 'manhuaplus', 'toonily']) {
    test('$site Madara genres use same-site links and page paths', () async {
      final path = site == 'toonily' ? '/serie/' : '/manga/';
      final adapter = _StubAdapter()..stub(path,
          '${File('test/fixtures/$site/genres.html').readAsStringSync()}<a href="https://other.test/manga-genre/fake/">Fake</a>');
      final source = MadaraSource(id: '${site}_en', name: site, baseUrl: 'https://$site.com',
          cataloguePath: path, genrePath: site == 'toonily' ? '/genre/' : '/manga-genre/', dio: _dio('https://fixture.test', adapter));
      final genres = await source.fetchGenres();
      expect(genres, isNotEmpty);
      expect(genres.map((g) => g.name), isNot(contains('Fake')));
      final genre = genres.first;
      final pagePath = '${genre.id}page/2/';
      adapter.stub(pagePath, File('test/fixtures/$site/popular.html').readAsStringSync());
      expect(await source.fetchByGenre(genre.id, page: 2), isNotEmpty);
      expect(adapter.requests.last.path, pagePath);
      expect(adapter.requests.last.queryParameters['m_orderby'], 'views');
    });
  }

  test('sources without a proven genre route expose no genre choices', () async {
    final sources = <MangaSource>[
      AsuraScansSource(),
      ComicKSource(),
      DemonicScansSource(),
      ReadComicOnlineSource(),
      ReaperScansSource(),
      FlameComicsSource(),
      WebtoonsSource(),
      WeebCentralSource(),
      MangakakalotSource(id: 'mangakakalot_en', name: 'Mangakakalot', baseUrl: 'https://www.mangakakalot.gg'),
      MangakakalotSource(id: 'natomanga_en', name: 'NatoManga', baseUrl: 'https://www.natomanga.com'),
    ];
    for (final source in sources) {
      expect(await source.fetchGenres(), isEmpty, reason: source.name);
      expect(
        () => source.fetchByGenre('action'),
        throwsUnsupportedError,
        reason: source.name,
      );
    }
  });

  test('MangaDex exposes only genre tags and sends native tag ID', () async {
    final adapter = _StubAdapter()
      ..stub('/manga/tag', {
        'data': [
          {'id': 'action-id', 'attributes': {'group': 'genre', 'name': {'en': 'Action'}}},
          {'id': 'theme-id', 'attributes': {'group': 'theme', 'name': {'en': 'Isekai'}}},
          {'id': 'fantasy-id', 'attributes': {'group': 'genre', 'name': {'en': 'Fantasy'}}},
        ],
      })
      ..stub('/manga', {'data': <Object>[]});
    final source = MangaDexSource(_dio('https://api.mangadex.org', adapter));

    final genres = await source.fetchGenres();
    expect(genres.map((genre) => genre.name), ['Action', 'Fantasy']);
    expect(genres.first.id, 'action-id');

    await source.fetchByGenre(genres.first.id, page: 3);
    final request = adapter.requests.last;
    expect(request.queryParameters['includedTags[]'], 'action-id');
    expect(request.queryParameters['offset'], 40);
  });

  test('MangaPill reads genre choices and filters search route', () async {
    final adapter = _StubAdapter()
      ..stub('/search', '''
        <a href="/search?genre=Action">Action</a>
        <select name="genre"><option value="">All</option><option value="Sci-Fi">Sci-Fi</option></select>
        <a href="/manga/2/one-piece"><img src="/cover.jpg">One Piece</a>
      ''');
    final source = MangaPillSource(_dio('https://mangapill.com', adapter));

    final genres = await source.fetchGenres();
    expect(genres.map((genre) => genre.name), ['Action', 'Sci-Fi']);
    final result = await source.fetchByGenre('Sci-Fi', page: 2);
    expect(result.single.id, '2/one-piece');
    expect(adapter.requests.last.queryParameters, {'genre': 'Sci-Fi', 'page': 2});
  });

  test('MangaTaro sends selected catalogue genre on every page', () async {
    final adapter = _StubAdapter()
      ..stub('/manga', '''
        <input type="checkbox" id="genre-12" name="genres[]" value="12">
        <label for="genre-12">Action</label>
      ''')
      ..stub('/wp-json/manga/v1/load', <Object>[]);
    final source = MangaTaroSource(_dio('https://mangataro.org', adapter));

    final genres = await source.fetchGenres();
    expect(genres.single.id, '12');
    expect(genres.single.name, 'Action');
    await source.fetchByGenre('12', page: 2);
    final request = adapter.requests.last;
    expect(request.data['genres'], '["12"]');
    expect(request.data['page'], 2);
  });

  test('ComicExtra uses genre links and paged genre route', () async {
    final adapter = _StubAdapter()
      ..stub('/advanced-search', '''
        <a href="/genre/action">Action</a>
        <a href="https://other.example/genre/fake">Fake</a>
      ''')
      ..stub('/genre/action', '''
        <div class="cartoon-box"><h3><a href="/comic/the-boys">The Boys</a></h3></div>
      ''');
    final source = ComicExtraSource(_dio('https://comicextra.org', adapter));

    final genres = await source.fetchGenres();
    expect(genres.single.id, '/genre/action');
    final result = await source.fetchByGenre(genres.single.id, page: 2);
    expect(result.single.id, 'the-boys');
    expect(adapter.requests.last.queryParameters['page'], 2);
  });
}
