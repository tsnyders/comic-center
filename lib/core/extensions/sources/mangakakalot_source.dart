import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../../browser/browser_cookie_store.dart';
import '../../browser/cloudflare_interceptor.dart';
import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// The MangaBox layout shared by Mangakakalot and NatoManga.
/// Manga IDs are slugs; chapter IDs are manga/<slug>/<chapter-slug>.
class MangakakalotSource extends MangaSource {
  MangakakalotSource(
      {required this.id, required this.name, required this.baseUrl, Dio? dio})
      : _dio = dio ?? Dio() {
    final requestHeaders = Map<String, String>.of(imageHeaders)
      ..remove('Cookie');
    _dio.options = _dio.options.copyWith(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {..._dio.options.headers, ...requestHeaders});
    if (dio == null) {
      _dio.interceptors.add(CloudflareInterceptor(_dio, interactive: true));
    }
  }
  final Dio _dio;
  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders {
    final cookie = BrowserCookieStore.cookieForHost(Uri.parse(baseUrl).host);
    return {
      'Referer': '$baseUrl/',
      'User-Agent': BrowserCookieStore.userAgent ??
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      if (cookie != null) 'Cookie': cookie,
    };
  }

  // ponytail: inner HTML routes can challenge plain HTTP even when the home/API work.
  // Propagate HTTP failures; an empty list would incorrectly imply an empty library.
  Future<Document> _get(String path, [Map<String, Object?>? params]) async =>
      html.parse((await _dio.get<String>(path,
              queryParameters: params,
              options: Options(responseType: ResponseType.plain)))
          .data);
  String _text(Element? e) =>
      e?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  String _url(String path) => Uri.parse('$baseUrl/').resolve(path).toString();
  String? _image(Element? e) {
    final src = e?.attributes['data-src'] ?? e?.attributes['src'];
    return src == null || src.isEmpty || src.startsWith('data:')
        ? null
        : _url(src);
  }

  List<MangaSummary> _cards(Document doc) {
    final result = <String, MangaSummary>{};
    for (final card in doc.querySelectorAll(
        '.list-truyen-item-wrap, .list-comic-item-wrap, .story_item, .itemupdate')) {
      final a = card.querySelector('h3 a[href]');
      final href = a?.attributes['href'];
      if (href == null) continue;
      final parts =
          Uri.parse(href).pathSegments.where((s) => s.isNotEmpty).toList();
      if (parts.length != 2 || parts.first != 'manga') continue;
      result[parts.last] = MangaSummary(
          id: parts.last,
          title: _text(a),
          coverUrl: _image(card.querySelector('img')),
          url: _url(href));
    }
    return result.values.toList();
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async =>
      _cards(await _get('/manga-list/hot-manga', {'page': page}));
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async =>
      _cards(await _get('/manga-list/latest-manga', {'page': page}));
  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) async =>
      _cards(await _get(
          '/search/story/${Uri.encodeComponent(query.trim().replaceAll(RegExp(r'\s+'), '_'))}',
          {'page': page}));
  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final doc = await _get('/manga/$mangaId');
    final info = doc.querySelector('.manga-info-top, .panel-story-info');
    Element? field(String label) {
      for (final row in info?.querySelectorAll('li, tr') ?? <Element>[]) {
        if (_text(row).toLowerCase().startsWith(label)) return row;
      }
      return null;
    }

    final title = _text(info?.querySelector('h1, h2'));
    final status = _text(field('status')).toLowerCase();
    return MangaDetail(
        id: mangaId,
        title: title.isEmpty ? mangaId : title,
        coverUrl:
            _image(doc.querySelector('.manga-info-pic img, .info-image img')),
        author: field('author')?.querySelectorAll('a').map(_text).join(', '),
        description: _text(doc.querySelector(
            '#noidungm, #panel-story-info-description, #contentBox')),
        genres: field('genre')?.querySelectorAll('a').map(_text).toList() ?? [],
        status: status.contains('ongoing')
            ? 'ongoing'
            : status.contains('completed')
                ? 'completed'
                : 'unknown',
        url: '$baseUrl/manga/$mangaId');
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final response = await _dio.get<String>('/api/manga/$mangaId/chapters',
        queryParameters: {'limit': -1},
        options: Options(responseType: ResponseType.plain));
    final root = jsonDecode(response.data ?? '{}');
    final data = root is Map ? root['data'] : null;
    final chapters = data is Map ? data['chapters'] : null;
    if (root is! Map || root['success'] != true || chapters is! List) {
      throw Exception('$name could not load the chapter list.');
    }
    return chapters
        .whereType<Map>()
        .where((c) => c['chapter_slug'] is String)
        .map((c) {
      final chapterId = 'manga/$mangaId/${c['chapter_slug']}';
      return ChapterInfo(
          id: chapterId,
          title: '${c['chapter_name'] ?? 'Chapter'}',
          number: double.tryParse('${c['chapter_num']}'),
          language: language,
          uploadDate: DateTime.tryParse('${c['updated_at']}'),
          url: _url(chapterId));
    }).toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final doc = await _get('/$chapterId');
    for (final script in doc.querySelectorAll('script')) {
      List<String> array(String key) {
        final match = RegExp('$key\\s*=\\s*(\\[.*?\\])', dotAll: true)
            .firstMatch(script.text);
        if (match == null) return [];
        try {
          final value = jsonDecode(match.group(1)!);
          return value is List ? value.whereType<String>().toList() : [];
        } on FormatException {
          return [];
        }
      }

      final cdns = array('cdns');
      final images = array('chapterImages');
      if (cdns.isNotEmpty && images.isNotEmpty) {
        return images
            .map((path) => Uri.parse('${cdns.first}/')
                .resolve(path.replaceFirst(RegExp(r'^/'), ''))
                .toString())
            .toList();
      }
    }
    final pages = doc
        .querySelectorAll('.container-chapter-reader > img')
        .map(_image)
        .whereType<String>()
        .toList();
    if (pages.isEmpty) {
      throw Exception('$name has no readable pages for this chapter.');
    }
    return pages;
  }
}
