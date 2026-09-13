import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// MangaPill HTML source.
class MangaPillSource implements MangaSource {
  MangaPillSource([Dio? dio]) : _dio = dio ?? _createClient();

  static Dio _createClient() => Dio(
        BaseOptions(
          baseUrl: 'https://mangapill.com',
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/131.0.0.0 Mobile Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final Dio _dio;

  @override
  String get id => 'mangapill_en';
  @override
  String get name => 'MangaPill';
  @override
  String get baseUrl => 'https://mangapill.com';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => const {
        'Referer': 'https://mangapill.com/',
      };
  @override
  List<SourceFilter> getFilters() => const [];

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async {
    final path = page <= 1 ? '/' : '/search?page=$page';
    return _parseCards(await _document(path));
  }

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async {
    return _parseCards(await _document('/chapters?page=$page'));
  }

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) async {
    return _parseCards(
      await _document(
        '/search',
        queryParameters: {'q': query, 'page': page},
      ),
    );
  }

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final doc = await _document('/manga/$mangaId');
    final title = doc.querySelector('h1')?.text.trim() ?? _titleFromId(mangaId);
    final cover = _imageUrl(doc.querySelector('img[alt="$title"]')) ??
        _metaContent(doc, 'og:image');
    final description = doc
        .querySelector('h1')
        ?.parent
        ?.parent
        ?.querySelector('p.text--secondary')
        ?.text
        .trim();
    final genres = doc
        .querySelectorAll('a[href^="/search?genre="]')
        .map((element) => element.text.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    String status = 'unknown';
    for (final label in doc.querySelectorAll('label')) {
      if (label.text.trim().toLowerCase() != 'status') continue;
      status = _normalizeStatus(label.nextElementSibling?.text);
      break;
    }

    return MangaDetail(
      id: mangaId,
      title: title,
      coverUrl: cover,
      description: description,
      genres: genres,
      status: status,
      url: '$baseUrl/manga/$mangaId',
    );
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final doc = await _document('/manga/$mangaId');
    final chapters = <ChapterInfo>[];
    final seen = <String>{};

    for (final link in doc.querySelectorAll('a[href^="/chapters/"]')) {
      final href = link.attributes['href']?.trim() ?? '';
      final chapterId = href.startsWith('/') ? href.substring(1) : href;
      if (chapterId.isEmpty || !seen.add(chapterId)) continue;
      final text = link.text.trim().isNotEmpty
          ? link.text.trim()
          : (link.attributes['title']?.trim() ?? 'Chapter');
      final match = RegExp(r'chapter\s+([\d.]+)', caseSensitive: false)
          .firstMatch('$text ${link.attributes['title'] ?? ''}');
      final number = double.tryParse(match?.group(1) ?? '');
      chapters.add(
        ChapterInfo(
          id: chapterId,
          title: number == null ? text : 'Chapter ${_formatNumber(number)}',
          number: number,
          language: 'en',
          url: '$baseUrl/$chapterId',
        ),
      );
    }

    chapters.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return chapters;
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final cleanId =
        chapterId.startsWith('/') ? chapterId.substring(1) : chapterId;
    if (!cleanId.startsWith('chapters/')) {
      throw Exception('Invalid MangaPill chapter ID: $chapterId');
    }
    final doc = await _document('/$cleanId');
    final pages = doc
        .querySelectorAll('img.js-page')
        .map(_imageUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList();
    if (pages.isEmpty) {
      throw Exception('MangaPill returned no pages for this chapter.');
    }
    return pages;
  }

  Future<dom.Document> _document(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    final response = await _dio.get<String>(
      path,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.plain),
    );
    return html_parser.parse(response.data ?? '');
  }

  List<MangaSummary> _parseCards(dom.Document doc) {
    final results = <String, MangaSummary>{};
    for (final link in doc.querySelectorAll('a[href^="/manga/"]')) {
      final href = link.attributes['href']?.split('?').first.trim() ?? '';
      final match = RegExp(r'^/manga/(\d+/[^/]+)').firstMatch(href);
      final mangaId = match?.group(1);
      if (mangaId == null) continue;

      dom.Element? container = link;
      for (var depth = 0; depth < 3 && container != null; depth++) {
        if (container.querySelector('img') != null) break;
        container = container.parent;
      }
      final image =
          container?.querySelector('img') ?? link.querySelector('img');
      var title = link.text.trim();
      if (title.isEmpty) {
        final sameLink = container
            ?.querySelectorAll('a[href="$href"]')
            .map((element) => element.text.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        title = sameLink ?? '';
      }
      final existing = results[mangaId];
      if (title.isEmpty) title = existing?.title ?? _titleFromId(mangaId);
      final cover = _imageUrl(image) ?? existing?.coverUrl;
      results[mangaId] = MangaSummary(
        id: mangaId,
        title: title,
        coverUrl: cover,
        url: '$baseUrl$href',
      );
    }
    return results.values.toList();
  }

  String? _imageUrl(dom.Element? image) {
    if (image == null) return null;
    final value = image.attributes['data-src'] ?? image.attributes['src'];
    if (value == null || value.trim().isEmpty) return null;
    return _absolute(value.trim());
  }

  String? _metaContent(dom.Document doc, String property) => doc
      .querySelector('meta[property="$property"]')
      ?.attributes['content']
      ?.trim();

  String _absolute(String value) {
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return '$baseUrl$value';
    return value;
  }

  String _titleFromId(String mangaId) {
    final slug = mangaId.split('/').last;
    return slug
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _normalizeStatus(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'publishing' || 'ongoing' => 'ongoing',
        'finished' || 'completed' => 'completed',
        'on hiatus' || 'hiatus' => 'hiatus',
        'discontinued' || 'cancelled' => 'cancelled',
        _ => 'unknown',
      };

  String _formatNumber(double number) => number == number.roundToDouble()
      ? number.toInt().toString()
      : number.toString();
}
