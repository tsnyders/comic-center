import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// Manga IDs are webtoon/<titleNo> or canvas/<titleNo>; chapters retain viewer URLs.
class WebtoonsSource extends MangaSource {
  WebtoonsSource([Dio? dio]) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {..._dio.options.headers, ...imageHeaders});
  }
  final Dio _dio;
  @override
  String get id => 'webtoons_en';
  @override
  String get name => 'WEBTOON';
  @override
  String get baseUrl => 'https://www.webtoons.com';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => {
        'Referer': 'https://www.webtoons.com',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      };
  Future<Document> _get(String path, [Map<String, Object?>? params]) async =>
      html.parse((await _dio.get<String>(path,
              queryParameters: params,
              options: Options(responseType: ResponseType.plain)))
          .data);
  String _url(String path) => Uri.parse('$baseUrl/').resolve(path).toString();
  String _text(Element? el) =>
      el?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  String? _mangaId(String href) {
    final uri = Uri.tryParse(href);
    final number =
        uri?.queryParameters['title_no'] ?? uri?.queryParameters['titleNo'];
    if (number == null || int.tryParse(number) == null) return null;
    return '${uri!.path.contains('/canvas/') || uri.path.startsWith('/challenge/') ? 'canvas' : 'webtoon'}/$number';
  }

  List<MangaSummary> _cards(Document doc) {
    final entries = <String, MangaSummary>{};
    for (final a in doc.querySelectorAll('.webtoon_list li a[href]')) {
      final href = a.attributes['href']!;
      final mangaId = _mangaId(href);
      if (mangaId == null) continue;
      final title = _text(a.querySelector('.title, .subj'));
      if (title.isEmpty) continue;
      final img = a.querySelector('img');
      final cover = img?.attributes['data-src'] ?? img?.attributes['src'];
      entries[mangaId] = MangaSummary(
          id: mangaId,
          title: title,
          coverUrl: cover == null ? null : _url(cover),
          url: _url(href));
    }
    return entries.values.toList();
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async {
    // The ranking page is a finite list, so slicing avoids repeating page one.
    return _cards(await _get('/en/ranking/popular'))
        .skip((page - 1) * 20)
        .take(20)
        .toList();
  }

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    return _cards(await _get(
            '/en/originals/${days[DateTime.now().weekday - 1]}',
            {'sortOrder': 'UPDATE'}))
        .skip((page - 1) * 20)
        .take(20)
        .toList();
  }

  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) async =>
      _cards(
          await _get('/en/search/originals', {'keyword': query, 'page': page}));
  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final parts = mangaId.split('/');
    final path = '${parts.first == 'canvas' ? '/challenge' : ''}/episodeList';
    // The mobile legacy detail route can silently return the homepage to Dio.
    // Desktop resolves titleNo to the canonical series page; episodes use mobile JSON.
    final doc = await _get(path, {'titleNo': parts.last});
    final title = _text(doc.querySelector('h1.subj, h3.subj'));
    final schedule =
        _text(doc.querySelector('#_asideDetail .day_info')).toLowerCase();
    return MangaDetail(
        id: mangaId,
        title: title.isEmpty ? mangaId : title,
        coverUrl: doc
            .querySelector('meta[property="og:image"]')
            ?.attributes['content'],
        author: _text(doc.querySelector(
            '.detail_header .author_area, .detail_header .author')),
        description: _text(doc.querySelector('#_asideDetail .summary')),
        genres: doc
            .querySelectorAll('.detail_header .genre')
            .map(_text)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(),
        status: schedule.contains('completed')
            ? 'completed'
            : schedule.isEmpty
                ? 'unknown'
                : 'ongoing',
        url: '$baseUrl$path?titleNo=${parts.last}');
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final response = await _dio.get<String>(
        'https://m.webtoons.com/api/v1/$mangaId/episodes',
        queryParameters: {
          'pageSize': 99999,
          if (mangaId.startsWith('canvas/')) 'readingLanguageCode': 'en'
        },
        options: Options(responseType: ResponseType.plain));
    final data = jsonDecode(response.data ?? '{}');
    final result = data is Map ? data['result'] : null;
    final episodes = result is Map ? result['episodeList'] : null;
    if (episodes is! List) {
      throw Exception('WEBTOON could not load the episode list.');
    }
    // ponytail: only episodes exposed by the public API; paid/app-only episodes are unavailable.
    return episodes
        .whereType<Map>()
        .where((e) => e['viewerLink'] is String)
        .map((e) {
      final uri = Uri.parse(e['viewerLink'] as String);
      final chapterId =
          '${uri.path.replaceFirst(RegExp(r'^/'), '')}?${uri.query}';
      return ChapterInfo(
          id: chapterId,
          title: html.parse('${e['episodeTitle']}').body?.text ?? '',
          number: (e['episodeNo'] as num?)?.toDouble(),
          language: language,
          uploadDate: e['exposureDateMillis'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  (e['exposureDateMillis'] as num).toInt(),
                  isUtc: true)
              : null,
          url: _url(chapterId));
    }).toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final doc = await _get('/$chapterId');
    final pages = doc
        .querySelectorAll('#_imageList img[data-url]')
        .map((img) => _url(img.attributes['data-url']!))
        .toList();
    if (pages.isEmpty) {
      throw Exception('This WEBTOON episode has no public image pages.');
    }
    return pages;
  }
}
