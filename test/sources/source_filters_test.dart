import 'dart:convert';
import 'dart:typed_data';

import 'package:comic_center/core/extensions/extension_factory.dart';
import 'package:comic_center/core/extensions/models/filter.dart';
import 'package:comic_center/core/extensions/sources/comick_source.dart';
import 'package:comic_center/core/extensions/sources/mangadex_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      throw DioException(
          requestOptions: options, message: 'No stub: ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
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

/// Sets the state of the named items in a group, leaving the rest untouched.
GroupFilter _pick(GroupFilter group, Map<String, TriState> states) {
  var out = group;
  for (var i = 0; i < group.items.length; i++) {
    final state = states[group.items[i].name];
    if (state != null) out = out.withItem(i, group.items[i].withState(state));
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ComicK is registered as an optional catalogue source', () {
    expect(ExtensionFactory.create('comick_en'), isA<ComicKSource>());
    expect(
      ExtensionFactory.pkgToSourceId['eu.kanade.tachiyomi.extension.all.comick'],
      'comick_en',
    );
    expect(
      ExtensionFactory.builtInExtensions.map((e) => e.sourceId),
      contains('comick_en'),
    );
  });

  group('MangaDex', () {
    test('maps filters to /manga query params', () async {
      final adapter = _StubAdapter()
        ..stub('/manga/tag', {
          'data': [
            {
              'id': 'action-id',
              'attributes': {'group': 'genre', 'name': {'en': 'Action'}},
            },
            {
              'id': 'isekai-id',
              'attributes': {'group': 'theme', 'name': {'en': 'Isekai'}},
            },
          ],
        })
        ..stub('/manga', {'data': <Object>[]});
      final source = MangaDexSource(_dio('https://api.mangadex.org', adapter));
      await source.fetchGenres(); // warms the tag cache used by getFilters

      final edited = [
        for (final f in source.getFilters())
          switch (f) {
            SortFilter() =>
              f.withIndex(f.options.indexOf('Rating')).withAscending(true),
            GroupFilter(name: 'Content rating') =>
              _pick(f, {'Safe': TriState.include}),
            GroupFilter(name: 'Status') => _pick(
                f, {'Ongoing': TriState.include, 'Hiatus': TriState.include}),
            GroupFilter(name: 'Demographic') =>
              _pick(f, {'Shounen': TriState.include}),
            GroupFilter(name: 'Tags') => _pick(
                f, {'Action': TriState.include, 'Isekai': TriState.exclude}),
            _ => f,
          },
      ];
      await source.search('naruto', page: 2, filters: edited);

      final q = adapter.requests.last.queryParameters;
      expect(q['title'], 'naruto');
      expect(q['order[rating]'], 'asc');
      expect(q['contentRating[]'], ['safe']);
      expect(q['status[]'], ['ongoing', 'hiatus']);
      expect(q['publicationDemographic[]'], ['shounen']);
      expect(q['includedTags[]'], ['action-id']);
      expect(q['excludedTags[]'], ['isekai-id']);
      expect(q['offset'], 20);
    });

    test('empty query falls back from relevance to followed count', () async {
      final adapter = _StubAdapter()..stub('/manga', {'data': <Object>[]});
      final source = MangaDexSource(_dio('https://api.mangadex.org', adapter));

      await source.search('', filters: source.getFilters());

      final q = adapter.requests.last.queryParameters;
      expect(q.containsKey('title'), isFalse);
      expect(q['order[followedCount]'], 'desc');
      expect(q.containsKey('status[]'), isFalse);
    });

    test('reads language, content rating and data saver preferences',
        () async {
      SharedPreferences.setMockInitialValues({
        'source.mangadex_en_v5.languages': ['ja', 'en'],
        'source.mangadex_en_v5.contentRating': ['safe'],
        'source.mangadex_en_v5.dataSaver': true,
      });
      final adapter = _StubAdapter()
        ..stub('/manga', {'data': <Object>[]})
        ..stub('/manga/m1/feed', {'data': <Object>[], 'total': 0})
        ..stub('/at-home/server/c1', {
          'baseUrl': 'https://cdn',
          'chapter': {
            'hash': 'h',
            'data': ['full.png'],
            'dataSaver': ['small.jpg'],
          },
        });
      final source = MangaDexSource(_dio('https://api.mangadex.org', adapter));

      await source.fetchPopular();
      final listing = adapter.requests.last.queryParameters;
      expect(listing['availableTranslatedLanguage[]'], ['ja', 'en']);
      expect(listing['contentRating[]'], ['safe']);

      await source.fetchChapterList('m1');
      expect(
        adapter.requests.last.queryParameters['translatedLanguage[]'],
        ['ja', 'en'],
      );

      expect(
        await source.fetchPageUrls('c1'),
        ['https://cdn/data-saver/h/small.jpg'],
      );
    });
  });

  group('ComicK', () {
    test('maps filters to /v1.0/search query params', () async {
      final adapter = _StubAdapter()..stub('/v1.0/search', <Object>[]);
      final source = ComicKSource(_dio('https://api.comick.fun', adapter));

      final edited = [
        for (final f in source.getFilters())
          switch (f) {
            SortFilter() => f.withIndex(f.options.indexOf('Latest upload')),
            SelectFilter() => f.withIndex(f.options.indexOf('Completed')),
            GroupFilter() => _pick(
                f, {'Action': TriState.include, 'Romance': TriState.exclude}),
            _ => f,
          },
      ];
      await source.search('solo', filters: edited);

      final q = adapter.requests.last.queryParameters;
      expect(q['q'], 'solo');
      expect(q['sort'], 'uploaded');
      expect(q['status'], '2');
      expect(q['genres'], ['action']);
      expect(q['excludes'], ['romance']);
      expect(q['lang'], 'en');
    });

    test('default filters send no status and language pref is honoured',
        () async {
      SharedPreferences.setMockInitialValues({'source.comick_en.lang': 'ja'});
      final adapter = _StubAdapter()
        ..stub('/v1.0/search', <Object>[])
        ..stub('/comic/h1/chapters', {'chapters': <Object>[]});
      final source = ComicKSource(_dio('https://api.comick.fun', adapter));

      await source.search('', filters: source.getFilters());
      final q = adapter.requests.last.queryParameters;
      expect(q.containsKey('status'), isFalse);
      expect(q.containsKey('q'), isFalse);
      expect(q['sort'], 'follow');
      expect(q['lang'], 'ja');

      await source.fetchChapterList('h1');
      expect(adapter.requests.last.queryParameters['lang'], 'ja');
    });
  });
}
