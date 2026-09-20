import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../../browser/browser_cookie_store.dart';
import '../../browser/cloudflare_interceptor.dart';
import '../../browser/browser_fetch.dart';
import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// Madara IDs retain the full relative path, without leading/trailing slashes.
class MadaraSource extends MangaSource {
  MadaraSource(
      {required this.id,
      required this.name,
      required this.baseUrl,
      this.language = 'en',
      this.isNsfw = false,
      this.cataloguePath = '/manga/',
      this.genrePath = '/manga-genre/',
      Dio? dio})
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
  final String language;
  final bool isNsfw;
  final String cataloguePath;
  final String genrePath;
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
          BrowserFetch.instance.userAgent,
      if (cookie != null) 'Cookie': cookie,
    };
  }

  Future<Document> _get(String path, [Map<String, Object?>? params]) async =>
      html.parse((await _dio.get<String>(path,
              queryParameters: params,
              options: Options(responseType: ResponseType.plain)))
          .data);
  String _url(String path) => Uri.parse('$baseUrl/').resolve(path).toString();
  String _id(String url) =>
      Uri.parse(url).path.replaceAll(RegExp(r'^/|/$'), '');
  String _text(Element? el) =>
      el?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  String? _image(Element? el) {
    for (final key in ['data-src', 'data-lazy-src', 'src']) {
      final value = el?.attributes[key]?.trim();
      if (value != null && value.isNotEmpty && !value.startsWith('data:')) {
        return _url(value);
      }
    }
    return null;
  }

  List<MangaSummary> _cards(Document doc) {
    final results = <String, MangaSummary>{};
    for (final card
        in doc.querySelectorAll('.page-item-detail, .c-tabs-item__content')) {
      final link = card
          .querySelector('.post-title a, .post-title h3 a, h3 a, h4 a, h5 a');
      final href = link?.attributes['href'];
      if (href == null || _text(link).isEmpty) continue;
      final mangaId = _id(href);
      results[mangaId] = MangaSummary(
          id: mangaId,
          title: _text(link),
          coverUrl: _image(card.querySelector('img')),
          url: _url(href));
    }
    return results.values.toList();
  }

  String _paged(String path, int page) =>
      page == 1 ? path : '${path.replaceAll(RegExp(r'/$'), '')}/page/$page/';
  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async =>
      _cards(await _get(_paged(cataloguePath, page), {'m_orderby': 'views'}));
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async =>
      _cards(await _get(_paged(cataloguePath, page), {'m_orderby': 'latest'}));
  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) async =>
      _cards(
          await _get(_paged('/', page), {'s': query, 'post_type': 'wp-manga'}));
  @override
  Future<List<GenreOption>> fetchGenres() async {
    final doc = await _get(cataloguePath);
    final genres = <String, GenreOption>{};
    for (final a in doc.querySelectorAll('a[href]')) {
      final uri = Uri.tryParse(_url(a.attributes['href']!));
      if (uri == null ||
          uri.host != Uri.parse(baseUrl).host ||
          !uri.path.startsWith(genrePath)) {
        continue;
      }
      final label = _text(a)
          .replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '')
          .replaceFirst(RegExp(r'^Top '), '');
      if (label.isNotEmpty) {
        genres[uri.path] = GenreOption(id: uri.path, name: label);
      }
    }
    return genres.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<List<MangaSummary>> fetchByGenre(String genreId,
          {int page = 1}) async =>
      _cards(await _get(_paged(genreId, page), {'m_orderby': 'views'}));

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final doc = await _get('/$mangaId/');
    final heading = doc.querySelector('.post-title h1, h1');
    heading
        ?.querySelectorAll('.manga-title-badges')
        .forEach((el) => el.remove());
    String status = 'unknown';
    for (final row in doc.querySelectorAll('.post-content_item')) {
      if (_text(row.querySelector('.summary-heading')).toLowerCase() ==
          'status') {
        status = _text(row.querySelector('.summary-content')).toLowerCase();
      }
    }
    return MangaDetail(
        id: mangaId,
        title: _text(heading).isEmpty ? mangaId : _text(heading),
        coverUrl: _image(doc.querySelector('.summary_image img')),
        author: _text(doc.querySelector('.author-content')),
        artist: _text(doc.querySelector('.artist-content')),
        description: _text(doc.querySelector('.summary__content')),
        genres: doc
            .querySelectorAll('.genres-content a')
            .map(_text)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(),
        status: switch (status) {
          'ongoing' => 'ongoing',
          'completed' || 'complete' => 'completed',
          'on hold' || 'hiatus' => 'hiatus',
          'canceled' || 'cancelled' || 'dropped' => 'cancelled',
          _ => 'unknown'
        },
        url: _url('$mangaId/'));
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    var doc = await _get('/$mangaId/');
    if (doc.querySelector('.wp-manga-chapter') == null) {
      // ponytail: Madara can defer chapters to either of two POST endpoints.
      // Do not turn blocked AJAX requests into an apparently empty library.
      final postId =
          doc.querySelector('#manga-chapters-holder')?.attributes['data-id'] ??
              doc.querySelector('.rating-post-id')?.attributes['value'];
      try {
        final response = await _dio.post<String>('/$mangaId/ajax/chapters/',
            options: Options(responseType: ResponseType.plain));
        doc = html.parse(response.data);
      } on DioException {
        if (postId == null) rethrow;
        doc = html.parse('');
      }
      if (doc.querySelector('.wp-manga-chapter') == null && postId != null) {
        doc = await _ajaxChapters(postId);
      }
    }
    final chapters = <String, ChapterInfo>{};
    for (final row in doc.querySelectorAll('.wp-manga-chapter')) {
      final link = row.querySelector('a[href]');
      final href = link?.attributes['href'];
      if (href == null || href.isEmpty || href.startsWith('#')) continue;
      final title = _text(link);
      final chapterId = _id(href);
      final pattern = RegExp(r'(?:chapter|ch\.?)[\s-]*(\d+(?:[.-]\d+)?)',
          caseSensitive: false);
      final match = pattern.firstMatch(title) ?? pattern.firstMatch(chapterId);
      final date = row.querySelector('.chapter-release-date');
      chapters[chapterId] = ChapterInfo(
          id: chapterId,
          title: title,
          language: language,
          number: double.tryParse(match?.group(1)?.replaceAll('-', '.') ?? ''),
          uploadDate: _date(
              date?.querySelector('[title]')?.attributes['title'] ??
                  _text(date)),
          url: _url(href));
    }
    return chapters.values.toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  Future<Document> _ajaxChapters(String postId) async =>
      html.parse((await _dio.post<String>('/wp-admin/admin-ajax.php',
              data: {'action': 'manga_get_chapters', 'manga': postId},
              options: Options(
                  responseType: ResponseType.plain,
                  contentType: Headers.formUrlEncodedContentType)))
          .data);

  DateTime? _date(String value) {
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final relative =
        RegExp(r'(\d+)\s+(minute|hour|day|week)s? ago', caseSensitive: false)
            .firstMatch(value);
    if (relative != null) {
      final minutes = switch (relative.group(2)!.toLowerCase()) {
        'hour' => 60,
        'day' => 1440,
        'week' => 10080,
        _ => 1
      };
      return DateTime.now()
          .subtract(Duration(minutes: int.parse(relative.group(1)!) * minutes));
    }
    final parts = value.replaceAll(',', '').split(RegExp(r'\s+'));
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec'
    ];
    if (parts.length == 3) {
      final monthAt = int.tryParse(parts[0]) == null ? 0 : 1;
      final month =
          months.indexWhere((m) => parts[monthAt].toLowerCase().startsWith(m)) +
              1;
      final day = int.tryParse(parts[1 - monthAt]);
      final year = int.tryParse(parts[2]);
      if (month > 0 && day != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final doc = await _get('/$chapterId/');
    final urls = doc
        .querySelectorAll('.reading-content img')
        .map(_image)
        .whereType<String>()
        .toList();
    if (urls.isEmpty) {
      throw Exception('$name has no readable pages for this chapter.');
    }
    return urls;
  }
}
