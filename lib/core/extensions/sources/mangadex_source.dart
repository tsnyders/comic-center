import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

class MangaDexSource implements MangaSource {
  MangaDexSource()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.mangadex.org',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  static const _cdnBase = 'https://uploads.mangadex.org/covers';

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
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/manga',
      queryParameters: {
        'order[followedCount]': 'desc',
        'availableTranslatedLanguage[]': 'en',
        'includes[]': 'cover_art',
        'limit': 20,
        'offset': (page - 1) * 20,
      },
    );
    return _parseSummaries(resp.data!['data'] as List);
  }

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/manga',
      queryParameters: {
        'order[latestUploadedChapter]': 'desc',
        'availableTranslatedLanguage[]': 'en',
        'includes[]': 'cover_art',
        'limit': 20,
        'offset': (page - 1) * 20,
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
    final resp = await _dio.get<Map<String, dynamic>>(
      '/manga',
      queryParameters: {
        'title': query,
        'availableTranslatedLanguage[]': 'en',
        'includes[]': 'cover_art',
        'limit': 20,
        'offset': (page - 1) * 20,
      },
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
          final fn =
              (r['attributes'] as Map<String, dynamic>?)?['fileName'] as String?;
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
              as Map<String, dynamic>? ?? {};
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
    int offset = 0;
    const limit = 96;

    while (true) {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/manga/$mangaId/feed',
        queryParameters: {
          'translatedLanguage[]': 'en',
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
            scanlator = (r['attributes'] as Map<String, dynamic>?)?['name']
                as String?;
            break;
          }
        }

        final chNumStr = attrs['chapter'] as String?;
        final volStr = attrs['volume'] as String?;
        final rawTitle = attrs['title'] as String? ?? '';

        chapters.add(ChapterInfo(
          id: ch['id'] as String,
          title: rawTitle.isEmpty
              ? 'Chapter ${chNumStr ?? '?'}'
              : rawTitle,
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
    final resp = await _dio.get<Map<String, dynamic>>(
      '/at-home/server/$chapterId',
    );
    final base = resp.data!['baseUrl'] as String;
    final chapter = resp.data!['chapter'] as Map<String, dynamic>;
    final hash = chapter['hash'] as String;
    final data = (chapter['data'] as List).cast<String>();
    return data.map((f) => '$base/data/$hash/$f').toList();
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
