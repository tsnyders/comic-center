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
    final resp = await _dio.get<dynamic>('/series/$mangaId');
    final d = _dataMap(resp.data);

    return MangaDetail(
      id: mangaId,
      title: d['title'] as String? ?? 'Unknown',
      coverUrl: d['cover'] as String?,
      author: d['author'] as String?,
      artist: d['artist'] as String?,
      description: d['description'] as String?,
      genres: _stringList(d['genres']),
      status: _statusStr(d['status']),
      url: '$baseUrl/series/$mangaId',
    );
  }

  // ── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final resp = await _dio.get<dynamic>('/series/$mangaId/chapters');
    final list = _dataList(resp.data);

    return list.map<ChapterInfo>((ch) {
      final m = ch as Map<String, dynamic>;
      final uuid = (m['id'] ?? m['uuid'] ?? '') as String;
      final num = (m['number'] ?? m['chapter_number'] as num?)
          ?.toDouble();
      final title =
          m['title'] as String? ?? 'Chapter ${num?.toStringAsFixed(0) ?? '?'}';

      return ChapterInfo(
        id: '$mangaId::$uuid',
        title: title,
        number: num,
        uploadDate: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String)
            : null,
        url: '$baseUrl/series/$mangaId/chapter/${num?.toStringAsFixed(0) ?? uuid}',
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
      final slug = (m['slug'] ?? m['id'] ?? '') as String;
      return MangaSummary(
        id: slug,
        title: m['title'] as String? ?? 'Unknown',
        coverUrl: m['cover'] as String?,
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
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) return body['data'] as Map<String, dynamic>;
      return body;
    }
    return {};
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
