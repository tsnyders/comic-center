import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// AsuraScans source via the official JSON API at api.asurascans.com.
/// Series slugs are used as manga IDs throughout.
/// Note: recent chapters may use scrambled/tiled images; older chapters
/// display as normal image sequences.
class AsuraScansSource implements MangaSource {
  AsuraScansSource()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.asurascans.com/api',
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/116.0.0.0 Mobile Safari/537.36',
              'Origin': 'https://asuracomic.net',
              'Referer': 'https://asuracomic.net/',
            },
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  @override
  String get id => 'asurascans_en';
  @override
  String get name => 'AsuraScans';
  @override
  String get baseUrl => 'https://asuracomic.net';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => const {
        'Referer': 'https://asuracomic.net/',
      };
  @override
  List<SourceFilter> getFilters() => const [];

  // ── Listings ─────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) =>
      _seriesList(page: page, order: 'rating');

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) =>
      _seriesList(page: page, order: 'updated');

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) async {
    final resp = await _dio.get<dynamic>(
      '/series',
      queryParameters: {
        'search': query,
        'page': page,
        'limit': 20,
      },
    );
    return _parseSummaries(_dataList(resp.data));
  }

  // ── Detail ────────────────────────────────────────────────────────────────

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    Map<String, dynamic> d = const {};
    try {
      final resp = await _dio.get<dynamic>('/series/$mangaId');
      d = _dataMap(resp.data);
    } catch (_) {
      // API endpoint may have moved or changed shape — fall back to slug.
    }

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = d[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return null;
    }

    final apiTitle = pick(const [
      'title', 'name', 'series_title', 'titleEnglish',
      'english_title', 'manga_title', 'romaji',
    ]);

    return MangaDetail(
      id: mangaId,
      title: apiTitle ?? _humanizeSlug(mangaId),
      coverUrl: pick(const [
        'cover', 'thumbnail', 'image', 'cover_url',
        'coverImage', 'poster', 'image_url',
      ]),
      author: pick(const ['author', 'authors']),
      artist: pick(const ['artist', 'artists']),
      description: pick(const ['description', 'synopsis', 'summary']),
      genres: _stringList(d['genres'] ?? d['tags'] ?? d['categories']),
      status: _statusStr(d['status'] ?? d['publishing_status']),
      url: '$baseUrl/series/$mangaId',
    );
  }

  /// Turns "the-beginning-after-the-end-abc123" into
  /// "The Beginning After The End".
  String _humanizeSlug(String slug) {
    var s = slug.replaceAll('_', '-');
    // Strip trailing AsuraComic hash suffix ("-a1b2c3d4").
    final hashSfx = RegExp(r'-[a-f0-9]{6,}$', caseSensitive: false);
    s = s.replaceFirst(hashSfx, '');
    final words = s.split('-').where((w) => w.isNotEmpty).map((w) {
      final lower = w.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    });
    final out = words.join(' ').trim();
    return out.isEmpty ? 'Untitled' : out;
  }

  // ── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final resp = await _dio.get<dynamic>('/series/$mangaId/chapters');
    final list = _dataList(resp.data);

    return list.map<ChapterInfo>((ch) {
      final m = ch as Map<String, dynamic>;
      final uuid = m['id']?.toString() ?? m['uuid']?.toString() ?? '';
      final chNum = (m['number'] ?? m['chapter_number'] as num?)
          ?.toDouble();
      final title = m['title']?.toString() ??
          m['name']?.toString() ??
          'Chapter ${chNum?.toStringAsFixed(0) ?? '?'}';

      return ChapterInfo(
        id: '$mangaId::$uuid',
        title: title,
        number: chNum,
        uploadDate: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString())
            : null,
        url: '$baseUrl/series/$mangaId/chapter/${chNum?.toStringAsFixed(0) ?? uuid}',
      );
    }).toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    // chapterId is "seriesSlug::chapterUUID"
    final sep = chapterId.lastIndexOf('::');
    if (sep < 0) throw Exception('Invalid AsuraScans chapter ID: $chapterId');
    final slug = chapterId.substring(0, sep);
    final uuid = chapterId.substring(sep + 2);

    final resp = await _dio.get<dynamic>('/series/$slug/chapters/$uuid');
    final body = resp.data;

    // Pages may be top-level list or nested under 'pages' key.
    final pages = _dataList(
      (body is Map && body.containsKey('pages')) ? body['pages'] : body,
    );

    return pages.map<String>((p) {
      if (p is String) return p;
      final m = p as Map<String, dynamic>;
      return (m['url'] ?? m['image'] ?? m['src'] ?? '') as String;
    }).where((url) => url.isNotEmpty).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<MangaSummary>> _seriesList({
    required int page,
    required String order,
  }) async {
    final resp = await _dio.get<dynamic>(
      '/series',
      queryParameters: {'page': page, 'order': order, 'limit': 20},
    );
    return _parseSummaries(_dataList(resp.data));
  }

  List<MangaSummary> _parseSummaries(List<dynamic> list) {
    return list.map<MangaSummary>((item) {
      final m = item as Map<String, dynamic>;
      final slug =
          m['slug']?.toString() ?? m['id']?.toString() ?? '';
      return MangaSummary(
        id: slug,
        title: m['title']?.toString() ?? m['name']?.toString() ?? 'Unknown',
        coverUrl: m['cover']?.toString() ?? m['thumbnail']?.toString(),
        url: '$baseUrl/series/$slug',
      );
    }).toList();
  }

  /// Handles both `{data: [...]}` and bare `[...]` responses.
  List<dynamic> _dataList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      if (body['data'] is List) return body['data'] as List;
      if (body['results'] is List) return body['results'] as List;
      if (body['series'] is List) return body['series'] as List;
    }
    return [];
  }

  Map<String, dynamic> _dataMap(dynamic body) {
    Map<String, dynamic>? asMap(dynamic v) =>
        v is Map<String, dynamic> ? v : (v is Map ? Map<String, dynamic>.from(v) : null);

    final root = asMap(body);
    if (root == null) return {};
    for (final key in const ['data', 'series', 'manga', 'item', 'result']) {
      final nested = asMap(root[key]);
      if (nested != null) return nested;
    }
    return root;
  }

  List<String> _stringList(dynamic v) {
    if (v is List) return v.whereType<String>().toList();
    return [];
  }

  String _statusStr(dynamic s) => switch (s?.toString().toLowerCase()) {
        'ongoing' || 'releasing' || 'publishing' => 'ongoing',
        'completed' || 'finished' => 'completed',
        'hiatus' => 'hiatus',
        'cancelled' || 'dropped' => 'cancelled',
        _ => 'unknown',
      };
}
