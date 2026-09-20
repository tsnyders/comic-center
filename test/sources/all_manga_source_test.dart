import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:comic_center/core/extensions/extension_factory.dart';
import 'package:comic_center/core/extensions/models/filter.dart';
import 'package:comic_center/core/extensions/sources/all_manga_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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
    test('has stable metadata, filters, and catalogue registration', () {
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
      expect(source.imageHeaders['User-Agent'], contains('Chrome/'));

      expect(ExtensionFactory.create('all_manga_en'), isA<AllMangaSource>());
      expect(
        ExtensionFactory
            .pkgToSourceId['eu.kanade.tachiyomi.extension.en.allmanga'],
        'all_manga_en',
      );
      final entry = ExtensionFactory.builtInExtensions
          .singleWhere((item) => item.sourceId == 'all_manga_en');
      expect(entry.name, 'AllManga');
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

    test('pages join pictureUrlHead with scalar pictureUrls', () async {
      final (source, adapter) = _source([_fixture('pages')]);

      final pages = await source.fetchPageUrls('ex9vXC6gWYY9bGkSo|1193');

      expect(pages, [
        'https://ytimgf.youtube-anime.com/'
            'manga/ex9vXC6gWYY9bGkSo/1193/001.webp',
        'https://ytimgf.youtube-anime.com/'
            'manga/ex9vXC6gWYY9bGkSo/1193/002.webp',
        'https://images.example.test/page-003.webp',
      ]);
      final body = _body(adapter.requests.single);
      expect(body['query'].toString(), contains('chapterPages'));
      expect(body['query'].toString(), isNot(matches(r'pictureUrls\s*\{')));
      expect(_variables(adapter.requests.single), {
        'mangaId': 'ex9vXC6gWYY9bGkSo',
        'translationType': 'sub',
        'chapterString': '1193',
      });
    });

    test('surfaces the first GraphQL error message', () async {
      final (source, _) = _source([
        {
          'errors': [
            {'message': 'AA_CRYPTO_MISSING'},
          ],
          'data': {'chapterPages': null},
        },
      ]);

      expect(
        source.fetchPageUrls('ex9vXC6gWYY9bGkSo|1193'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('AllManga API: AA_CRYPTO_MISSING'),
          ),
        ),
      );
    });

    test('every API operation is POST with the required browser headers',
        () async {
      final (source, adapter) = _source([
        _fixture('popular'),
        _fixture('latest'),
        _fixture('search'),
        _fixture('detail'),
        _fixture('detail'),
        _fixture('pages'),
      ]);

      await source.fetchPopular();
      await source.fetchLatestUpdates();
      await source.search('One Piece');
      await source.fetchMangaDetail('ex9vXC6gWYY9bGkSo');
      await source.fetchChapterList('ex9vXC6gWYY9bGkSo');
      await source.fetchPageUrls('ex9vXC6gWYY9bGkSo|1193');

      expect(adapter.requests, hasLength(6));
      for (final request in adapter.requests) {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api');
        expect(request.headers['Origin'], 'https://allmanga.to');
        expect(request.headers['Referer'], 'https://allmanga.to/');
        expect(request.headers['User-Agent'], contains('Chrome/'));
        expect(request.headers['Content-Type'], Headers.jsonContentType);
      }
    });
  });
}
