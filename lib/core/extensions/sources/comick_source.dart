import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// ComicK source via api.comick.fun — supports both manga and manhwa.
/// Manga IDs are the `hid` short identifier returned by the search API.
class ComicKSource implements MangaSource {
  ComicKSource([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.comick.fun',
                headers: {
                  'Referer': 'https://comick.io/',
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                      'AppleWebKit/537.36 (KHTML, like Gecko) '
                      'Chrome/116.0.0.0 Mobile Safari/537.36',
                  'Accept': 'application/json',
                },
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  static const _cdnBase = 'https://meo.comick.pictures';

  @override
  String get id => 'comick_en';

  @override
  String get name => 'ComicK';

  @override
  String get baseUrl => 'https://comick.io';

  @override
  String get language => 'en';

  @override
  String get version => '1.0.0';

  @override
  Uint8List get iconBytes => Uint8List(0);

  @override
  Map<String, String> get imageHeaders => const {
        'Referer': 'https://comick.io/',
      };

  @override
  List<SourceFilter> getFilters() => const [];

  // ── Listings ─────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) => _search(
        queryParameters: {
          'sort': 'follow',
          'lang': 'en',
          'page': page,
          'limit': 30,
          't': 'false',
        },
      );

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) => _search(
        queryParameters: {
          'sort': 'uploaded',
          'lang': 'en',
          'page': page,
          'limit': 30,
          't': 'false',
        },
      );

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) =>
      _search(
        queryParameters: {
          'q': query,
          'lang': 'en',
          'page': page,
          'limit': 30,
        },
      );

  // ── Detail ────────────────────────────────────────────────────────────────

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    // mangaId is the comic hid — the API accepts both hid and slug.
    final resp = await _dio.get<Map<String, dynamic>>('/comic/$mangaId');
    final body = resp.data!;
    final comic = body['comic'] as Map<String, dynamic>;

    final title = comic['title'] as String? ?? 'Unknown';
    final slug = comic['slug'] as String? ?? mangaId;
    final coverUrl = _extractCover(comic);

    String? author;
    final authorList = body['authors'] as List?;
    if (authorList != null && authorList.isNotEmpty) {
      author = (authorList.first as Map<String, dynamic>)['name'] as String?;
    }

    String? artist;
    final artistList = body['artists'] as List?;
    if (artistList != null && artistList.isNotEmpty) {
      artist = (artistList.first as Map<String, dynamic>)['name'] as String?;
    }

    final genreList = body['genres'] as List?;
    final genres = genreList
            ?.cast<Map<String, dynamic>>()
            .map((g) => g['name'] as String? ?? '')
            .where((g) => g.isNotEmpty)
            .toList() ??
        [];

    final statusCode = comic['status'] as int? ?? 0;
    final status = switch (statusCode) {
      1 => 'ongoing',
      2 => 'completed',
      3 => 'cancelled',
      4 => 'hiatus',
      _ => 'unknown',
    };

    return MangaDetail(
      id: mangaId,
      title: title,
      coverUrl: coverUrl,
      author: author,
      artist: artist,
      description: comic['desc'] as String?,
      genres: genres,
      status: status,
      url: '$baseUrl/comic/$slug',
    );
  }

  // ── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    // mangaId is the comic hid — chapters endpoint accepts hid directly.
    final resp = await _dio.get<Map<String, dynamic>>(
      '/comic/$mangaId/chapters',
      queryParameters: {
        'lang': 'en',
        'limit': 300,
        'chap-order': 1, // ascending
      },
    );

    final chapters = (resp.data!['chapters'] as List?) ?? [];
    return chapters.map<ChapterInfo>((ch) {
      final c = ch as Map<String, dynamic>;
      final chapHid = c['hid'] as String? ?? '';
      final chapNum = c['chap'] as String?;
      final title = c['title'] as String?;

      // Group names are stored as an array of strings.
      final groups = (c['group_name'] as List?)?.cast<String>();
      final scanlator = groups?.join(', ');

      return ChapterInfo(
        id: chapHid,
        title:
            title != null && title.isNotEmpty ? title : 'Chapter ${chapNum ?? '?'}',
        number: chapNum != null ? double.tryParse(chapNum) : null,
        scanlator: scanlator,
        language: c['lang'] as String?,
        uploadDate: c['updated_at'] != null
            ? DateTime.tryParse(c['updated_at'] as String)
            : null,
        url: '$baseUrl/comic/$mangaId/chapter/$chapNum',
      );
    }).toList();
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final resp =
        await _dio.get<Map<String, dynamic>>('/chapter/$chapterId');
    final chapter = resp.data!['chapter'] as Map<String, dynamic>? ?? {};
    final images = (chapter['md_images'] as List?) ?? [];
    return images
        .cast<Map<String, dynamic>>()
        .map((img) => img['b2key'] as String? ?? '')
        .where((b2key) => b2key.isNotEmpty)
        .map((b2key) => '$_cdnBase/$b2key')
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<MangaSummary>> _search({
    required Map<String, dynamic> queryParameters,
  }) async {
    final resp = await _dio.get<List<dynamic>>(
      '/v1.0/search',
      queryParameters: queryParameters,
    );
    return _parseSummaries(resp.data ?? []);
  }

  List<MangaSummary> _parseSummaries(List<dynamic> items) {
    return items.map<MangaSummary>((item) {
      final m = item as Map<String, dynamic>;
      final hid = m['hid'] as String? ?? '';
      final slug = m['slug'] as String? ?? hid;
      final title = m['title'] as String? ?? 'Unknown';
      final coverUrl = _extractCover(m);

      return MangaSummary(
        id: hid,
        title: title,
        coverUrl: coverUrl,
        url: '$baseUrl/comic/$slug',
      );
    }).toList();
  }

  String? _extractCover(Map<String, dynamic> item) {
    // Try direct cover_url field first (e.g., from /top endpoint)
    final direct = item['cover_url'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;

    // Fall back to md_covers array with b2key CDN path
    final covers = item['md_covers'] as List?;
    if (covers != null && covers.isNotEmpty) {
      for (final cover in covers) {
        final b2key = (cover as Map<String, dynamic>)['b2key'] as String?;
        if (b2key != null && b2key.isNotEmpty) {
          return '$_cdnBase/$b2key';
        }
      }
    }

    return null;
  }
}
