import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// MangaTaro source backed by its public catalogue and reader endpoints.
class MangaTaroSource implements MangaSource {
  MangaTaroSource([Dio? dio, DateTime Function()? clock])
      : _dio = dio ?? _createClient(),
        _clock = clock ?? DateTime.now;

  static Dio _createClient() => Dio(
        BaseOptions(
          baseUrl: 'https://mangataro.org',
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/131.0.0.0 Mobile Safari/537.36',
            'Accept': 'application/json,text/html,application/xhtml+xml',
            'Referer': 'https://mangataro.org/',
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final Dio _dio;
  final DateTime Function() _clock;

  @override
  String get id => 'mangataro_en';
  @override
  String get name => 'MangaTaro';
  @override
  String get baseUrl => 'https://mangataro.org';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => const {
        'Referer': 'https://mangataro.org/',
      };
  @override
  List<SourceFilter> getFilters() => const [];

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async {
    if (page > 1) return _loadCatalogue(page: page, sort: 'popular');
    final response = await _dio.get<dynamic>('/wp-json/manga/v1/popular');
    return _parseSummaries(_asList(response.data));
  }

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async {
    final response = await _dio.post<dynamic>(
      '/wp-json/manga/v1/latest-chapters',
      data: {'page': page},
    );
    return _parseSummaries(_asList(_asMap(response.data)['data']));
  }

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) =>
      _loadCatalogue(page: page, search: query, sort: 'latest');

  Future<List<MangaSummary>> _loadCatalogue({
    required int page,
    required String sort,
    String search = '',
  }) async {
    final response = await _dio.post<dynamic>(
      '/wp-json/manga/v1/load',
      data: {
        'page': page,
        'search': search,
        'years': '[]',
        'genres': '[]',
        'types': '[]',
        'statuses': '[]',
        'sort': sort,
        'genreMatchMode': 'any',
      },
    );
    return _parseSummaries(_asList(response.data));
  }

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final doc = await _document('/manga/$mangaId');
    final schema = _comicSeriesSchema(doc);
    final title = doc.querySelector('h1')?.text.trim() ??
        _string(schema['name']) ??
        _humanize(mangaId);
    final cover = doc
            .querySelector('.manga-page-wrapper img')
            ?.attributes['src']
            ?.trim() ??
        _string(schema['image']);
    final description =
        doc.querySelector('#description-content-tab')?.text.trim() ??
            _string(schema['description']);

    String? author;
    final authorValue = schema['author'];
    if (authorValue is Map) author = _string(authorValue['name']);
    if (authorValue is List) {
      author = authorValue
          .map(
              (value) => value is Map ? _string(value['name']) : _string(value))
          .whereType<String>()
          .join(', ');
    }

    final genres = doc
        .querySelectorAll('a[href*="/tag/"]')
        .map((element) => element.text.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    return MangaDetail(
      id: mangaId,
      title: _decodeText(title),
      coverUrl: cover,
      author: author,
      description: description == null ? null : _decodeText(description),
      genres: genres,
      status: _normalizeStatus(_string(schema['status'])),
      url: '$baseUrl/manga/$mangaId',
    );
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final doc = await _document('/manga/$mangaId');
    final numericMangaId = doc
        .querySelector('.chapter-list[data-manga-id]')
        ?.attributes['data-manga-id'];
    if (numericMangaId == null || numericMangaId.isEmpty) {
      throw Exception('MangaTaro could not identify this title.');
    }

    final now = _clock().toUtc();
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;
    final hour = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}';
    final digest =
        md5.convert(utf8.encode('${timestamp}mng_ch_$hour')).toString();
    final token = digest.substring(0, 16);
    final response = await _dio.get<dynamic>(
      '/auth/manga-chapters',
      queryParameters: {
        'manga_id': numericMangaId,
        'offset': 0,
        'limit': 500,
        'order': 'DESC',
        '_t': token,
        '_ts': timestamp,
      },
      options: Options(headers: {'Referer': '$baseUrl/manga/$mangaId'}),
    );

    final body = _asMap(response.data);
    if (body['success'] != true) {
      throw Exception('MangaTaro could not load chapters for this title.');
    }
    final chapters = _asList(body['chapters'])
        .map((value) {
          final chapter = _asMap(value);
          final id = _string(chapter['id']) ?? '';
          final number = double.tryParse(_string(chapter['chapter']) ?? '');
          final subtitle = _decodeText(_string(chapter['title']) ?? '').trim();
          final baseTitle =
              number == null ? 'Chapter' : 'Chapter ${_formatNumber(number)}';
          return ChapterInfo(
            id: id,
            title: subtitle.isEmpty ? baseTitle : '$baseTitle - $subtitle',
            number: number,
            scanlator: _string(chapter['group_name']),
            language: _string(chapter['language']) ?? 'en',
            url: _string(chapter['url']),
          );
        })
        .where((chapter) => chapter.id.isNotEmpty)
        .toList();
    chapters.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return chapters;
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    if (int.tryParse(chapterId) == null) {
      throw Exception('Invalid MangaTaro chapter ID: $chapterId');
    }
    final response = await _dio.get<dynamic>(
      '/auth/chapter-content',
      queryParameters: {'chapter_id': chapterId},
    );
    final body = _asMap(response.data);
    if (body['success'] != true) {
      throw Exception(
        _string(body['message']) ?? 'MangaTaro could not load this chapter.',
      );
    }
    final pages = _asList(body['images'])
        .map(_string)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList();
    if (pages.isEmpty) {
      throw Exception('MangaTaro returned no pages for this chapter.');
    }
    return pages;
  }

  Future<dom.Document> _document(String path) async {
    final response = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    return html_parser.parse(response.data ?? '');
  }

  List<MangaSummary> _parseSummaries(List<dynamic> values) {
    final results = <String, MangaSummary>{};
    for (final value in values) {
      final item = _asMap(value);
      final url = _string(item['manga_permalink']) ??
          _string(item['permalink']) ??
          _string(item['url']);
      final slug = _string(item['slug']) ?? _slugFromUrl(url);
      if (slug == null || slug.isEmpty) continue;
      results[slug] = MangaSummary(
        id: slug,
        title: _decodeText(_string(item['title']) ?? _humanize(slug)),
        coverUrl: _string(item['cover']) ?? _string(item['thumbnail']),
        url: '$baseUrl/manga/$slug',
      );
    }
    return results.values.toList();
  }

  Map<String, dynamic> _comicSeriesSchema(dom.Document doc) {
    for (final script
        in doc.querySelectorAll('script[type="application/ld+json"]')) {
      try {
        final value = jsonDecode(script.text);
        if (value is Map && value['@type'] == 'ComicSeries') {
          return Map<String, dynamic>.from(value);
        }
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  List<dynamic> _asList(Object? value) {
    if (value is List) return value;
    if (value is Map) return [value];
    return const [];
  }

  Map<String, dynamic> _asMap(Object? value) => value is Map<String, dynamic>
      ? value
      : value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};

  String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _slugFromUrl(String? value) {
    if (value == null) return null;
    final segments = Uri.tryParse(value)?.pathSegments ?? const [];
    final index = segments.indexOf('manga');
    return index >= 0 && index + 1 < segments.length
        ? segments[index + 1]
        : null;
  }

  String _decodeText(String value) =>
      html_parser.parseFragment(value).text ?? value;

  String _humanize(String slug) => slug
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  String _normalizeStatus(String? value) => switch (value?.toLowerCase()) {
        'ongoing' || 'publishing' => 'ongoing',
        'completed' || 'finished' => 'completed',
        'hiatus' => 'hiatus',
        'dropped' || 'cancelled' => 'cancelled',
        _ => 'unknown',
      };

  String _formatNumber(double number) => number == number.roundToDouble()
      ? number.toInt().toString()
      : number.toString();
}
