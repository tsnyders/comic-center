import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// FlameComics (formerly FlameScans) source via the JSON REST API.
/// Primary API: api.flamecomics.xyz — falls back to api.flamescans.org.
class FlameScansSource implements MangaSource {
  FlameScansSource()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.flamecomics.xyz/api',
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/116.0.0.0 Mobile Safari/537.36',
              'Origin': 'https://flamecomics.me',
              'Referer': 'https://flamecomics.me/',
              'Accept': 'application/json',
            },
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  @override String get id       => 'flamescans_en';
  @override String get name     => 'FlameComics';
  @override String get baseUrl  => 'https://flamecomics.me';
  @override String get language => 'en';
  @override String get version  => '1.0.0';
  @override Uint8List get iconBytes => Uint8List(0);
  @override Map<String, String> get imageHeaders => const {
        'Referer': 'https://flamecomics.me/',
        'Origin': 'https://flamecomics.me',
      };
  @override List<SourceFilter> getFilters() => const [];

  // ── Listings ─────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) =>
      _seriesList(page: page, order: 'rating');

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) =>
      _seriesList(page: page, order: 'updated_at');

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) async {
    final resp = await _dio.get<dynamic>(
      '/comics',
      queryParameters: {'search': query, 'page': page},
    );
    return _parseSummaries(_dataList(resp.data));
  }

  // ── Detail ────────────────────────────────────────────────────────────────

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    Map<String, dynamic> d = const {};
    try {
      final resp = await _dio.get<dynamic>('/comics/$mangaId');
      d = _dataMap(resp.data);
    } catch (_) {}

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = d[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return null;
    }

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
      title: pick(const ['title', 'name', 'series_title']) ?? _humanizeSlug(mangaId),
      coverUrl: pick(const ['cover', 'thumbnail', 'image', 'cover_url', 'poster']),
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
    final resp = await _dio.get<dynamic>('/comics/$mangaId/chapters');
    final list = _dataList(resp.data);

    return list.map<ChapterInfo>((ch) {
      final m   = ch as Map<String, dynamic>;
      final id  = m['id']?.toString() ?? m['uuid']?.toString() ?? '';
      final chNum = (m['chapter_number'] ?? m['number'] as num?)?.toDouble() ??
          _extractNumber(m['chapter_name']?.toString() ?? m['title']?.toString() ?? '');
      final title = m['chapter_name']?.toString() ??
          m['title']?.toString() ??
          'Chapter ${chNum?.toStringAsFixed(0) ?? '?'}';

      return ChapterInfo(
        id: '$mangaId::$id',
        title: title,
        number: chNum,
        uploadDate: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString())
            : null,
        url: '$baseUrl/series/$mangaId/$id',
      );
    }).toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final parts = chapterId.split('::');
    final id = parts.length >= 2 ? parts[1] : parts[0];

    if (id.isEmpty) {
      throw Exception('Invalid FlameComics chapter ID: $chapterId');
    }

    final resp = await _dio.get<dynamic>('/chapters/$id');
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

    // Shape 2: generic data/pages list
    final pages = _dataList(body);
    return pages.map<String>((p) {
      if (p is String) return p;
      if (p is Map<String, dynamic>) {
        return (p['url'] ?? p['url_image'] ?? p['image'] ?? p['src'] ?? '')
            as String;
      }
      return '';
    }).where((u) => u.isNotEmpty).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<MangaSummary>> _seriesList({
    required int page,
    required String order,
  }) async {
    final resp = await _dio.get<dynamic>(
      '/comics',
      queryParameters: {'page': page, 'order': order},
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
        coverUrl: m['cover']?.toString() ?? m['thumbnail']?.toString(),
        url: '$baseUrl/series/$slug',
      );
    }).toList();
  }

  List<dynamic> _dataList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      for (final key in const ['data', 'results', 'comics', 'chapters', 'pages']) {
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
    for (final key in const ['data', 'comic', 'series', 'manga', 'result']) {
      final nested = asMap(root[key]);
      if (nested != null) return nested;
    }
    return root;
  }

  double? _extractNumber(String text) {
    final match = RegExp(r'[\d]+(?:\.[\d]+)?').firstMatch(text);
    return match != null ? double.tryParse(match.group(0)!) : null;
  }

  String _humanizeSlug(String slug) {
    return slug.split(RegExp(r'[-_]')).map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  String _statusStr(dynamic s) => switch (s?.toString().toLowerCase()) {
        'ongoing' || 'releasing' || 'publishing' => 'ongoing',
        'completed' || 'finished' => 'completed',
        'hiatus' => 'hiatus',
        'cancelled' || 'dropped' => 'cancelled',
        _ => 'unknown',
      };
}
