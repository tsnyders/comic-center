import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// AllManga source using the allanime.day persisted-query GraphQL API.
class AllMangaSource implements MangaSource {
  AllMangaSource()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.allanime.day',
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/116.0.0.0 Mobile Safari/537.36',
              'Referer': 'https://allmanga.to/',
            },
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  // Persisted-query hashes discovered from the allanime.day API.
  static const _hashSearch =
      '2d48e19fb67ddcac42fbb885204b6abb0a84f406f15ef83f36de4a66f49f651a';
  static const _hashDetail =
      'd77781dcf964b97aea0be621dbde430e89e200b58526823ee6010dd11c3ca96a';
  static const _hashPages =
      'a062f1b131dae3d17c1950fad14640d066b988ac10347ed49cfbe70f5e7f661b';

  @override
  String get id => 'all_manga_en';
  @override
  String get name => 'AllManga';
  @override
  String get baseUrl => 'https://allmanga.to';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  // Images are served from the ytimgf CDN and need the youtu-chan Referer.
  Map<String, String> get imageHeaders =>
      const {'Referer': 'https://youtu-chan.com/'};
  @override
  List<SourceFilter> getFilters() => const [];

  // ── Listings ────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) =>
      _search(sortBy: 'Top', page: page);

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) =>
      _search(sortBy: 'Latest_Updated', page: page);

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) =>
      _search(query: query, page: page);

  // ── Detail ───────────────────────────────────────────────────────────────

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final data = await _query(
      hash: _hashDetail,
      variables: {
        '_id': mangaId,
        'search': {'allowAdult': false},
      },
    );

    final show = data['show'] as Map<String, dynamic>? ?? {};
    return MangaDetail(
      id: mangaId,
      title: show['name'] as String? ?? 'Unknown',
      coverUrl: _coverUrl(show['thumbnail'] as String?),
      description: show['description'] as String?,
      author: _firstAuthor(show['authors']),
      genres: (show['genres'] as List? ?? []).cast<String>(),
      status: _statusStr(show['status']),
      url: '$baseUrl/manga/$mangaId',
    );
  }

  // ── Chapters ─────────────────────────────────────────────────────────────

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final data = await _query(
      hash: _hashDetail,
      variables: {
        '_id': mangaId,
        'search': {'allowAdult': false},
      },
    );

    final show = data['show'] as Map<String, dynamic>? ?? {};
    final detail =
        show['availableChaptersDetail'] as Map<String, dynamic>? ?? {};
    // Manga chapters live under 'sub' (subtitled = translated).
    final nums = (detail['sub'] as List? ?? []).cast<String>();

    return nums.map((num) {
      return ChapterInfo(
        id: '$mangaId::$num',
        title: 'Chapter $num',
        number: double.tryParse(num),
        language: 'en',
        url: '$baseUrl/read/$mangaId/chapter/$num',
      );
    }).toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  // ── Pages ────────────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    // chapterId is "mangaId::chapterNum"
    final sep = chapterId.lastIndexOf('::');
    if (sep < 0) throw Exception('Invalid AllManga chapter ID: $chapterId');
    final mangaId = chapterId.substring(0, sep);
    final chapterNum = chapterId.substring(sep + 2);

    final data = await _query(
      hash: _hashPages,
      variables: {
        'mangaId': mangaId,
        'translationType': 'sub',
        'chapterString': chapterNum,
        'limit': 1000,
        'offset': 0,
      },
    );

    final edges = (data['chapterPages']?['edges'] as List? ?? []);
    final urls = <String>[];
    for (final edge in edges) {
      final pics =
          (edge as Map<String, dynamic>)['pictureUrls'] as List? ?? [];
      for (final pic in pics) {
        final String? raw;
        if (pic is String) {
          raw = pic;
        } else if (pic is Map<String, dynamic>) {
          raw = pic['url'] as String?;
        } else {
          raw = null;
        }
        if (raw == null || raw.isEmpty) continue;
        // Relative paths need the image CDN prepended.
        final url = raw.startsWith('http')
            ? raw
            : 'https://ytimgf.fast4speed.rsvp$raw';
        urls.add(url);
      }
    }
    return urls;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<List<MangaSummary>> _search({
    String query = '',
    String? sortBy,
    int page = 1,
  }) async {
    final variables = <String, dynamic>{
      'search': {
        'query': query,
        'isManga': true,
        if (sortBy != null) 'sortBy': sortBy,
        'allowAdult': false,
        'allowUnknown': false,
      },
      'limit': 20,
      'page': page,
      'translationType': 'sub',
      'countryOrigin': 'ALL',
    };

    final data = await _query(hash: _hashSearch, variables: variables);
    final edges = (data['shows']?['edges'] as List? ?? []);

    return edges.map<MangaSummary>((item) {
      final m = item as Map<String, dynamic>;
      return MangaSummary(
        id: m['_id'] as String,
        title: m['name'] as String? ?? 'Unknown',
        coverUrl: _coverUrl(m['thumbnail'] as String?),
        url: '$baseUrl/manga/${m['_id']}',
      );
    }).toList();
  }

  Future<Map<String, dynamic>> _query({
    required String hash,
    required Map<String, dynamic> variables,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/api',
      queryParameters: {
        'variables': jsonEncode(variables),
        'extensions': jsonEncode({
          'persistedQuery': {'version': 1, 'sha256Hash': hash},
        }),
      },
    );
    return (resp.data!['data'] as Map<String, dynamic>?) ?? {};
  }

  String? _coverUrl(String? thumb) {
    if (thumb == null || thumb.isEmpty) return null;
    if (thumb.startsWith('http')) {
      // Normalize the numbered filename to 001.jpg for consistent cover art,
      // then apply the w=250 size param the CDN whitelists.
      final normalized = thumb.replaceAllMapped(
        RegExp(r'\d+\.(jpg|png|webp)'),
        (m) => '001.${m[1]}',
      );
      return '$normalized?w=250';
    }
    // Relative path: prepend the static asset CDN.
    final clean = thumb.startsWith('/') ? thumb : '/$thumb';
    final normalized = clean.replaceAllMapped(
      RegExp(r'\d+\.(jpg|png|webp)'),
      (m) => '001.${m[1]}',
    );
    return 'https://wp.youtube-anime.com/aln.youtube-anime.com$normalized?w=250';
  }

  String? _firstAuthor(dynamic authors) {
    if (authors is Map) {
      final edges = authors['edges'] as List? ?? [];
      if (edges.isEmpty) return null;
      return (edges.first as Map<String, dynamic>)['name'] as String?;
    }
    if (authors is List && authors.isNotEmpty) {
      return authors.first?.toString();
    }
    return null;
  }

  String _statusStr(dynamic status) => switch (
      status?.toString().toLowerCase()) {
    'releasing' => 'ongoing',
    'completed' => 'completed',
    'hiatus' => 'hiatus',
    'cancelled' => 'cancelled',
    _ => 'unknown',
  };
}
