import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';
import '../source_prefs.dart';

class MangaDexSource extends MangaSource {
  MangaDexSource([Dio? dio])
      : _dio = dio ?? Dio(
          BaseOptions(
            baseUrl: 'https://api.mangadex.org',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  static const _cdnBase = 'https://uploads.mangadex.org/covers';
  static const _pageSize = 20;

  static const _ratingOptions = ['Safe', 'Suggestive', 'Erotica', 'Pornographic'];
  static const _ratingValues = ['safe', 'suggestive', 'erotica', 'pornographic'];
  // API default when contentRating[] is omitted.
  static const _defaultRatings = ['safe', 'suggestive', 'erotica'];
  static const _langOptions = [
    'English', 'Japanese', 'Korean', 'Chinese', 'Spanish', 'Portuguese (BR)',
    'French', 'German', 'Russian', 'Italian', 'Indonesian', 'Vietnamese',
  ];
  static const _langValues = [
    'en', 'ja', 'ko', 'zh', 'es', 'pt-br', 'fr', 'de', 'ru', 'it', 'id', 'vi',
  ];

  static const _sortName = 'Sort';
  static const _ratingName = 'Content rating';
  static const _statusName = 'Status';
  static const _demographicName = 'Demographic';
  static const _tagsName = 'Tags';

  /// Every tag from `/manga/tag`, cached by [fetchGenres] so the synchronous
  /// [getFilters] can offer them. The browse screen loads genres on open, so
  /// the cache is warm by the time the filter sheet is shown.
  List<TriStateFilter> _tags = const [];

  SourcePrefs get _prefs => SourcePrefs(id);

  @override
  String get id => 'mangadex_en_v5';

  @override
  String get name => 'MangaDex';

  @override
  String get baseUrl => 'https://mangadex.org';

  @override
  String get language => 'en';

  @override
  String get version => '1.0.0';

  @override
  Uint8List get iconBytes => Uint8List(0);

  @override
  Map<String, String> get imageHeaders => const {};

  @override
  List<SourcePreference> get preferences => const [
        MultiSelectPreference(
          key: 'contentRating',
          title: 'Content rating',
          options: _ratingOptions,
          values: _ratingValues,
          defaultValue: _defaultRatings,
        ),
        MultiSelectPreference(
          key: 'languages',
          title: 'Chapter languages',
          options: _langOptions,
          values: _langValues,
          defaultValue: ['en'],
        ),
        TogglePreference(key: 'dataSaver', title: 'Data saver (smaller pages)'),
      ];

  @override
  List<SourceFilter> getFilters() => [
        const SortFilter(
          name: _sortName,
          options: [
            'Relevance', 'Followed', 'Latest upload', 'Rating',
            'Created', 'Updated', 'Title', 'Year',
          ],
          values: [
            'relevance', 'followedCount', 'latestUploadedChapter', 'rating',
            'createdAt', 'updatedAt', 'title', 'year',
          ],
        ),
        const GroupFilter(name: _ratingName, excludable: false, items: [
          TriStateFilter(name: 'Safe', value: 'safe'),
          TriStateFilter(name: 'Suggestive', value: 'suggestive'),
          TriStateFilter(name: 'Erotica', value: 'erotica'),
          TriStateFilter(name: 'Pornographic', value: 'pornographic'),
        ]),
        const GroupFilter(name: _statusName, excludable: false, items: [
          TriStateFilter(name: 'Ongoing', value: 'ongoing'),
          TriStateFilter(name: 'Completed', value: 'completed'),
          TriStateFilter(name: 'Hiatus', value: 'hiatus'),
          TriStateFilter(name: 'Cancelled', value: 'cancelled'),
        ]),
        const GroupFilter(name: _demographicName, excludable: false, items: [
          TriStateFilter(name: 'Shounen', value: 'shounen'),
          TriStateFilter(name: 'Shoujo', value: 'shoujo'),
          TriStateFilter(name: 'Josei', value: 'josei'),
          TriStateFilter(name: 'Seinen', value: 'seinen'),
          TriStateFilter(name: 'None', value: 'none'),
        ]),
        if (_tags.isNotEmpty) GroupFilter(name: _tagsName, items: _tags),
      ];

  /// Query params shared by every `/manga` listing, honouring the language
  /// and content-rating preferences.
  Future<Map<String, dynamic>> _listParams(int page) async => {
        'availableTranslatedLanguage[]':
            await _prefs.getStringList('languages', const ['en']),
        'contentRating[]':
            await _prefs.getStringList('contentRating', _defaultRatings),
        'includes[]': 'cover_art',
        'limit': _pageSize,
        'offset': (page - 1) * _pageSize,
      };

  @override
  Future<List<GenreOption>> fetchGenres() async {
    final response = await _dio.get<Map<String, dynamic>>('/manga/tag');
    final tags = response.data?['data'] as List? ?? const [];
    final genres = <GenreOption>[];
    final all = <TriStateFilter>[];
    for (final value in tags) {
      if (value is! Map<String, dynamic>) continue;
      final attributes = value['attributes'];
      if (attributes is! Map<String, dynamic>) continue;
      final id = value['id'];
      final names = attributes['name'];
      final name = names is Map ? names['en'] : null;
      if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
        continue;
      }
      all.add(TriStateFilter(name: name, value: id));
      if (attributes['group'] == 'genre') {
        genres.add(GenreOption(id: id, name: name));
      }
    }
    all.sort((a, b) => a.name.compareTo(b.name));
    _tags = all;
    genres.sort((a, b) => a.name.compareTo(b.name));
    return genres;
  }

  @override
  Future<List<MangaSummary>> fetchByGenre(String genreId, {int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/manga',
      queryParameters: {
        ...await _listParams(page),
        'includedTags[]': genreId,
        'order[followedCount]': 'desc',
      },
    );
    return _parseSummaries(response.data!['data'] as List);
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/manga',
      queryParameters: {
        ...await _listParams(page),
        'order[followedCount]': 'desc',
      },
    );
    return _parseSummaries(resp.data!['data'] as List);
  }

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/manga',
      queryParameters: {
        ...await _listParams(page),
        'order[latestUploadedChapter]': 'desc',
      },
    );
    return _parseSummaries(resp.data!['data'] as List);
  }

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) async {
    final params = await _listParams(page);
    final title = query.trim();
    if (title.isNotEmpty) params['title'] = title;

    var sortKey = 'relevance';
    var ascending = false;
    for (final filter in filters) {
      switch (filter) {
        case SortFilter():
          sortKey = filter.value;
          ascending = filter.ascending;
        case GroupFilter():
          final included = filter.included.toList();
          final excluded = filter.excluded.toList();
          switch (filter.name) {
            case _ratingName:
              if (included.isNotEmpty) params['contentRating[]'] = included;
            case _statusName:
              if (included.isNotEmpty) params['status[]'] = included;
            case _demographicName:
              if (included.isNotEmpty) {
                params['publicationDemographic[]'] = included;
              }
            case _tagsName:
              if (included.isNotEmpty) params['includedTags[]'] = included;
              if (excluded.isNotEmpty) params['excludedTags[]'] = excluded;
          }
        case _:
          break;
      }
    }
    // The API rejects order[relevance] when there is no title to rank by.
    if (sortKey == 'relevance' && title.isEmpty) sortKey = 'followedCount';
    params['order[$sortKey]'] = ascending ? 'asc' : 'desc';

    final resp = await _dio.get<Map<String, dynamic>>(
      '/manga',
      queryParameters: params,
    );
    return _parseSummaries(resp.data!['data'] as List);
  }

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/manga/$mangaId',
      queryParameters: {
        'includes[]': ['cover_art', 'author', 'artist'],
      },
    );

    final data = resp.data!['data'] as Map<String, dynamic>;
    final attrs = data['attributes'] as Map<String, dynamic>;
    final rels = data['relationships'] as List? ?? [];

    String? coverUrl;
    String? author;
    String? artist;

    for (final rel in rels) {
      final r = rel as Map<String, dynamic>;
      switch (r['type'] as String?) {
        case 'cover_art':
          final fn = (r['attributes'] as Map<String, dynamic>?)?['fileName']
              as String?;
          if (fn != null) coverUrl = '$_cdnBase/$mangaId/$fn.512.jpg';
        case 'author':
          author ??=
              (r['attributes'] as Map<String, dynamic>?)?['name'] as String?;
        case 'artist':
          artist ??=
              (r['attributes'] as Map<String, dynamic>?)?['name'] as String?;
      }
    }

    final titleMap = attrs['title'] as Map<String, dynamic>? ?? {};
    final title = titleMap['en'] as String? ??
        titleMap.values.whereType<String>().firstOrNull ??
        'Unknown';

    final descMap = attrs['description'] as Map<String, dynamic>? ?? {};
    final description = descMap['en'] as String? ??
        descMap.values.whereType<String>().firstOrNull;

    final tags = attrs['tags'] as List? ?? [];
    final genres = tags
        .cast<Map<String, dynamic>>()
        .where((t) =>
            t['type'] == 'tag' &&
            ((t['attributes'] as Map<String, dynamic>?)?['group'] as String?) ==
                'genre')
        .map<String>((t) {
          final nameMap = ((t['attributes'] as Map<String, dynamic>?)!['name'])
                  as Map<String, dynamic>? ??
              {};
          return nameMap['en'] as String? ?? '';
        })
        .where((g) => g.isNotEmpty)
        .toList();

    return MangaDetail(
      id: mangaId,
      title: title,
      coverUrl: coverUrl,
      author: author,
      artist: artist,
      description: description,
      genres: genres,
      status: attrs['status'] as String? ?? 'unknown',
      url: '$baseUrl/manga/$mangaId',
    );
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final chapters = <ChapterInfo>[];
    final languages = await _prefs.getStringList('languages', const ['en']);
    int offset = 0;
    const limit = 96;

    while (true) {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/manga/$mangaId/feed',
        queryParameters: {
          'translatedLanguage[]': languages,
          'order[chapter]': 'asc',
          'includes[]': 'scanlation_group',
          'limit': limit,
          'offset': offset,
        },
      );

      final body = resp.data!;
      final items = body['data'] as List;
      final total = body['total'] as int;

      for (final item in items) {
        final ch = item as Map<String, dynamic>;
        final attrs = ch['attributes'] as Map<String, dynamic>;
        final rels = ch['relationships'] as List? ?? [];

        String? scanlator;
        for (final rel in rels) {
          final r = rel as Map<String, dynamic>;
          if (r['type'] == 'scanlation_group') {
            scanlator =
                (r['attributes'] as Map<String, dynamic>?)?['name'] as String?;
            break;
          }
        }

        final chNumStr = attrs['chapter'] as String?;
        final volStr = attrs['volume'] as String?;
        final rawTitle = attrs['title'] as String? ?? '';

        chapters.add(ChapterInfo(
          id: ch['id'] as String,
          title: rawTitle.isEmpty ? 'Chapter ${chNumStr ?? '?'}' : rawTitle,
          number: chNumStr != null ? double.tryParse(chNumStr) : null,
          volume: volStr != null ? double.tryParse(volStr) : null,
          scanlator: scanlator,
          language: attrs['translatedLanguage'] as String?,
          uploadDate: attrs['publishAt'] != null
              ? DateTime.tryParse(attrs['publishAt'] as String)
              : null,
          url: '$baseUrl/chapter/${ch['id']}',
        ));
      }

      offset += items.length;
      if (offset >= total || items.isEmpty) break;
    }

    return chapters;
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final dataSaver = await _prefs.getBool('dataSaver', false);
    final resp = await _dio.get<Map<String, dynamic>>(
      '/at-home/server/$chapterId',
    );
    final base = resp.data!['baseUrl'] as String;
    final chapter = resp.data!['chapter'] as Map<String, dynamic>;
    final hash = chapter['hash'] as String;
    final dir = dataSaver ? 'data-saver' : 'data';
    final files = (chapter[dataSaver ? 'dataSaver' : 'data'] as List)
        .cast<String>();
    return files.map((f) => '$base/$dir/$hash/$f').toList();
  }

  List<MangaSummary> _parseSummaries(List items) {
    return items.map<MangaSummary>((item) {
      final m = item as Map<String, dynamic>;
      final mangaId = m['id'] as String;
      final attrs = m['attributes'] as Map<String, dynamic>;
      final rels = m['relationships'] as List? ?? [];

      final titleMap = attrs['title'] as Map<String, dynamic>? ?? {};
      final title = titleMap['en'] as String? ??
          titleMap.values.whereType<String>().firstOrNull ??
          'Unknown';

      String? coverUrl;
      for (final rel in rels) {
        final r = rel as Map<String, dynamic>;
        if (r['type'] == 'cover_art') {
          final fn = (r['attributes'] as Map<String, dynamic>?)?['fileName']
              as String?;
          if (fn != null) coverUrl = '$_cdnBase/$mangaId/$fn.512.jpg';
          break;
        }
      }

      return MangaSummary(
        id: mangaId,
        title: title,
        coverUrl: coverUrl,
        url: '$baseUrl/manga/$mangaId',
      );
    }).toList();
  }
}
