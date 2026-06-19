import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// ReaperScans source via the JSON REST API at api.reaperscans.com.
class ReaperScansSource implements MangaSource {
  ReaperScansSource()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.reaperscans.com',
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/116.0.0.0 Mobile Safari/537.36',
              'Origin': 'https://reaperscans.com',
              'Referer': 'https://reaperscans.com/',
              'Accept': 'application/json',
            },
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  @override String get id       => 'reaperscans_en';
  @override String get name     => 'ReaperScans';
  @override String get baseUrl  => 'https://reaperscans.com';
  @override String get language => 'en';
  @override String get version  => '1.0.0';
  @override Uint8List get iconBytes => Uint8List(0);
  @override Map<String, String> get imageHeaders => const {
        'Referer': 'https://reaperscans.com/',
        'Origin': 'https://reaperscans.com',
      };
  @override List<SourceFilter> getFilters() => const [];

  // ── Listings ─────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) =>
      _seriesList(page: page, orderBy: 'total_views');

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) =>
      _seriesList(page: page, orderBy: 'updated_at');

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) async {
    final resp = await _dio.get<dynamic>(
      '/query',
      queryParameters: {
        'query_string': query,
        'series_type': 'Comic',
        'page': page,
        'order': 'desc',
        'orderBy': 'total_views',
        'series_status': 'All',
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
    } catch (_) {}

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = d[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return null;
    }

    // author / artist may be a List of maps or a plain string
    String? pickPerson(String key) {
      final v = d[key];
      if (v is List && v.isNotEmpty) {
        final first = v.first;
        if (first is Map) return first['name']?.toString();
        return first.toString();
      }
      if (v is String && v.isNotEmpty) return v;
      return null;
    }

    // tags / genres may be List<Map> with 'name' or List<String>
    List<String> pickTags() {
      final raw = d['tags'] ?? d['genres'] ?? d['categories'];
      if (raw is List) {
        return raw.map<String>((e) {
          if (e is Map) return e['name']?.toString() ?? '';
          return e.toString();
        }).where((s) => s.isNotEmpty).toList();
      }
      return [];
    }

    return MangaDetail(
      id: mangaId,
      title: pick(const ['title', 'name', 'series_title']) ?? mangaId,
      coverUrl: pick(const ['thumbnail', 'cover', 'image', 'cover_url', 'poster']),
      author: pickPerson('author') ?? pickPerson('authors'),
      artist: pickPerson('artist') ?? pickPerson('artists'),
      description: pick(const ['description', 'synopsis', 'summary']),
      genres: pickTags(),
      status: _statusStr(d['status'] ?? d['publishing_status']),
      url: '$baseUrl/series/$mangaId',
    );
  }

  // ── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final all = <ChapterInfo>[];
    var page = 1;

    while (true) {
      final resp = await _dio.get<dynamic>(
        '/series/$mangaId/chapters',
        queryParameters: {'page': page},
      );
      final body = resp.data;
      final list = _dataList(body);
      if (list.isEmpty) break;

      for (final ch in list) {
        final m = ch as Map<String, dynamic>;
        final id = m['id']?.toString() ?? '';
        final rawNum = m['chapter_name']?.toString() ?? m['chapter_slug']?.toString() ?? '';
        // Extract trailing number from "Chapter 179" or "chapter-179"
        final numMatch = RegExp(r'[\d]+(?:\.[\d]+)?$').firstMatch(rawNum);
        final chNum = numMatch != null ? double.tryParse(numMatch.group(0)!) : null;
        final title = m['chapter_name']?.toString() ??
            'Chapter ${chNum?.toStringAsFixed(0) ?? '?'}';

        all.add(ChapterInfo(
          id: '$mangaId::$id',
          title: title,
          number: chNum,
          uploadDate: m['created_at'] != null
              ? DateTime.tryParse(m['created_at'].toString())
              : null,
          url: '$baseUrl/series/$mangaId/${m['chapter_slug'] ?? id}',
        ));
      }

      // Stop when we've passed the last page
      final meta = body is Map ? body['meta'] as Map? : null;
      final lastPage = meta?['last_page'] as int? ?? 1;
      if (page >= lastPage) break;
      page++;
    }

    all.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return all;
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    // chapterId format: "{seriesSlug}::{numericId}"
    final parts = chapterId.split('::');
    final numericId = parts.length >= 2 ? parts[1] : parts[0];

    if (numericId.isEmpty) {
      throw Exception('Invalid ReaperScans chapter ID: $chapterId');
    }

    final resp = await _dio.get<dynamic>('/chapter/$numericId');
    return _extractPageUrls(resp.data);
  }

  List<String> _extractPageUrls(dynamic body) {
    // Shape 1: { "chapter_image": [{ "url_image": "..." }] }
    if (body is Map && body['chapter_image'] is List) {
      return (body['chapter_image'] as List).map<String>((e) {
        if (e is Map) return e['url_image']?.toString() ?? '';
        return e.toString();
      }).where((u) => u.isNotEmpty).toList();
    }

    // Shape 2: { "chapter": { "pages": ["..."] } } or similar nested
    final pages = _dataList(body);
    return pages.map<String>((p) {
      if (p is String) return p;
      if (p is Map<String, dynamic>) {
        return (p['url_image'] ?? p['url'] ?? p['image'] ?? p['src'] ?? '')
            as String;
      }
      return '';
    }).where((u) => u.isNotEmpty).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<MangaSummary>> _seriesList({
    required int page,
    required String orderBy,
  }) async {
    final resp = await _dio.get<dynamic>(
      '/series',
      queryParameters: {'page': page, 'order': 'desc', 'orderBy': orderBy},
    );
    return _parseSummaries(_dataList(resp.data));
  }

  List<MangaSummary> _parseSummaries(List<dynamic> list) {
    return list.map<MangaSummary>((item) {
      final m    = item as Map<String, dynamic>;
      final slug = m['series_slug']?.toString() ??
          m['slug']?.toString() ??
          m['id']?.toString() ?? '';
      return MangaSummary(
        id: slug,
        title: m['title']?.toString() ?? m['name']?.toString() ?? 'Unknown',
        coverUrl: m['thumbnail']?.toString() ?? m['cover']?.toString(),
        url: '$baseUrl/series/$slug',
      );
    }).toList();
  }

  List<dynamic> _dataList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      for (final key in const ['data', 'results', 'series', 'chapters', 'pages']) {
        if (body[key] is List) return body[key] as List;
      }
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

  String _statusStr(dynamic s) => switch (s?.toString().toLowerCase()) {
        'ongoing' || 'releasing' || 'publishing' => 'ongoing',
        'completed' || 'finished' => 'completed',
        'hiatus' => 'hiatus',
        'cancelled' || 'dropped' => 'cancelled',
        _ => 'unknown',
      };
}
