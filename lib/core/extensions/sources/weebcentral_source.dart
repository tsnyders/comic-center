import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// Series and chapter IDs are the immutable ULIDs, independent of title slugs.
class WeebCentralSource extends MangaSource {
  WeebCentralSource([Dio? dio]) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {..._dio.options.headers, ...imageHeaders});
  }
  final Dio _dio;
  @override
  String get id => 'weebcentral_en';
  @override
  String get name => 'WeebCentral';
  @override
  String get baseUrl => 'https://weebcentral.com';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => {
        'Referer': '$baseUrl/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      };
  Future<Document> _get(String path, [Map<String, Object?>? params]) async =>
      html.parse((await _dio.get<String>(path,
              queryParameters: params,
              options: Options(responseType: ResponseType.plain)))
          .data);
  String _text(Element? el) =>
      el?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  String _url(String path) => Uri.parse('$baseUrl/').resolve(path).toString();
  String? _id(String path, String prefix) =>
      RegExp('/$prefix/([A-Z0-9]{26})(?:/|\$)').firstMatch(path)?.group(1);

  Future<List<MangaSummary>> _search(
      String query, int page, String sort) async {
    final doc = await _get('/search/data', {
      'text': query,
      'sort': sort,
      'order': 'Descending',
      'limit': 32,
      'offset': (page - 1) * 32,
      'display_mode': 'Full Display'
    });
    final results = <String, MangaSummary>{};
    for (final link in doc.querySelectorAll('article > section > a[href]')) {
      final href = link.attributes['href']!;
      final mangaId = _id(href, 'series');
      final img = link.querySelector('img[src*="/cover/"]');
      if (mangaId == null || img == null) continue;
      final title = (img.attributes['alt'] ?? '')
          .replaceFirst(RegExp(r' cover$'), '')
          .trim();
      results[mangaId] = MangaSummary(
          id: mangaId,
          title: title,
          coverUrl: _url(img.attributes['src']!),
          url: '$baseUrl/series/$mangaId');
    }
    return results.values.toList();
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) =>
      _search('', page, 'Popularity');
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) =>
      _search('', page, 'Latest Updates');
  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) =>
      _search(query, page, 'Best Match');
  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final doc = await _get('/series/$mangaId');
    Element? field(String label) => doc
        .querySelectorAll('li')
        .where((li) => _text(li.querySelector('strong')).startsWith(label))
        .firstOrNull;
    final title = _text(doc.querySelector('h1'));
    final status = _text(field('Status')?.querySelector('a')).toLowerCase();
    return MangaDetail(
        id: mangaId,
        title: title.isEmpty ? mangaId : title,
        coverUrl: doc
            .querySelector('meta[property="og:image"]')
            ?.attributes['content'],
        author: field('Author')?.querySelectorAll('a').map(_text).join(', '),
        description: _text(field('Description')?.querySelector('p')),
        genres: field('Tags')?.querySelectorAll('a').map(_text).toList() ?? [],
        status: switch (status) {
          'ongoing' => 'ongoing',
          'complete' => 'completed',
          'hiatus' => 'hiatus',
          'canceled' => 'cancelled',
          _ => 'unknown'
        },
        url: '$baseUrl/series/$mangaId');
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final doc = await _get('/series/$mangaId/full-chapter-list');
    final chapters = <ChapterInfo>[];
    for (final a in doc.querySelectorAll('div[x-data] > a[href]')) {
      final chapterId = _id(a.attributes['href']!, 'chapters');
      if (chapterId == null) continue;
      final title = _text(a.querySelector('span.flex > span'));
      final match =
          RegExp(r'(?:Chapter|Volume)\s+(\d+(?:\.\d+)?)', caseSensitive: false)
              .firstMatch(title);
      chapters.add(ChapterInfo(
          id: chapterId,
          title: title,
          number: double.tryParse(match?.group(1) ?? ''),
          volume: title.startsWith('Volume')
              ? double.tryParse(match?.group(1) ?? '')
              : null,
          language: language,
          uploadDate: DateTime.tryParse(
              a.querySelector('time')?.attributes['datetime'] ?? ''),
          url: '$baseUrl/chapters/$chapterId'));
    }
    return chapters..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final doc = await _get('/chapters/$chapterId/images',
        {'is_prev': 'False', 'reading_style': 'long_strip'});
    final pages = doc
        .querySelectorAll('section[x-data*="scroll"] > img[src]')
        .map((e) => _url(e.attributes['src']!))
        .toList();
    if (pages.isEmpty) {
      throw Exception('WeebCentral has no readable pages for this chapter.');
    }
    return pages;
  }
}
