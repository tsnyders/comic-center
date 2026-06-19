import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// AsuraScans source via the official JSON API at api.asurascans.com.
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
              'Accept': 'application/json',
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
        'Origin': 'https://asuracomic.net',
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
    } catch (_) {}

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

  String _humanizeSlug(String slug) {
    var s = slug.replaceAll('_', '-');
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
      final m   = ch as Map<String, dynamic>;
      final uuid = m['slug']?.toString() ??
          m['uuid']?.toString() ??
          m['id']?.toString() ??
          '';
      final chNum = (m['number'] ?? m['chapter_number'] as num?)?.toDouble();
      final title = m['title']?.toString() ??
          m['name']?.toString() ??
          'Chapter ${chNum?.toStringAsFixed(0) ?? '?'}';

      // Store both slug and uuid so fetchPageUrls can try multiple strategies.
      // Format: "mangaSlug::chapterUUID::chapterNumber"
      final chNum0 = chNum?.toStringAsFixed(0) ?? '';
      return ChapterInfo(
        id: '$mangaId::$uuid::$chNum0',
        title: title,
        number: chNum,
        uploadDate: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString())
            : null,
        url: '$baseUrl/series/$mangaId/chapter/$chNum0',
      );
    }).toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    // chapterId format: "seriesSlug::chapterUUID::chapterNumber"
    // (legacy format without chapterNumber is also supported: "seriesSlug::uuid")
    final parts = chapterId.split('::');
    if (parts.length < 2) {
      throw Exception('Invalid AsuraScans chapter ID: $chapterId');
    }
    final slug    = parts[0];
    final uuid    = parts[1];
    final chNum   = parts.length >= 3 ? parts[2] : '';

    if (slug.isEmpty) throw Exception('Empty manga slug in chapter ID');

    // Strategy 1: fetch by UUID via /series/{slug}/chapters/{uuid}
    if (uuid.isNotEmpty) {
      try {
        final resp = await _dio.get<dynamic>('/series/$slug/chapters/$uuid');
        final urls = _extractPageUrls(resp.data);
        if (urls.isNotEmpty) return urls;
      } catch (_) {}
    }

    // Strategy 2: fetch by chapter number via /series/{slug}/chapters?number={num}
    if (chNum.isNotEmpty) {
      try {
        final resp = await _dio.get<dynamic>(
          '/series/$slug/chapters',
          queryParameters: {'number': chNum},
        );
        final urls = _extractPageUrls(resp.data);
        if (urls.isNotEmpty) return urls;
      } catch (_) {}
    }

    // Strategy 3: direct chapter endpoint without slug
    if (uuid.isNotEmpty) {
      try {
        final resp = await _dio.get<dynamic>('/chapters/$uuid');
        final urls = _extractPageUrls(resp.data);
        if (urls.isNotEmpty) return urls;
      } catch (_) {}
    }

    throw Exception(
      'Could not load pages for this AsuraScans chapter. '
      'The chapter may have moved or the source format changed. '
      '(slug=$slug, uuid=$uuid, ch=$chNum)',
    );
  }

  List<String> _extractPageUrls(dynamic body) {
    // Pages may be under a 'pages' key or at the root level.
    final raw = (body is Map && body.containsKey('pages'))
        ? body['pages']
        : body;
    final pages = _dataList(raw);

    return pages.map<String>((p) {
      if (p is String) return p;
      if (p is Map<String, dynamic>) {
        return (p['url'] ?? p['image'] ?? p['src'] ?? p['link'] ?? '')
            as String;
      }
      return '';
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
      final m    = item as Map<String, dynamic>;
      final slug = m['slug']?.toString() ?? m['id']?.toString() ?? '';
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
      for (final key in const ['data', 'results', 'series', 'pages', 'chapters']) {
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

  List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.map<String>((e) {
        if (e is String) return e;
        if (e is Map) return e['name']?.toString() ?? '';
        return '';
      }).where((s) => s.isNotEmpty).toList();
    }
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
