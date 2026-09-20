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

/// MangaThemesia markup. IDs are site-relative paths without outer slashes.
class MangaThemesiaSource extends MangaSource {
  MangaThemesiaSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.language = 'en',
    this.isNsfw = false,
    this.cataloguePath = '/manga/',
    this.filterPath,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      headers: {..._dio.options.headers, ...imageHeaders},
    );
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

  /// Rizz retains the theme markup but serves its catalogue through a POST API.
  final String? filterPath;
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => {
        'Referer': '$baseUrl/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/131.0.0.0 Safari/537.36',
      };

  Future<Document> _get(String path, [Map<String, Object?>? params]) async =>
      html.parse((await _dio.get<String>(path,
              queryParameters: params,
              options: Options(responseType: ResponseType.plain)))
          .data);

  String _id(String url) =>
      Uri.parse(url).path.replaceAll(RegExp(r'^/|/$'), '');
  String _url(String path) => Uri.parse('$baseUrl/').resolve(path).toString();
  String _text(Element? e) =>
      e?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  String? _image(Element? e) {
    for (final key in ['data-src', 'data-lazy-src', 'src']) {
      final value = e?.attributes[key]?.trim();
      if (value != null && value.isNotEmpty && !value.startsWith('data:')) {
        return _url(value);
      }
    }
    return null;
  }

  List<MangaSummary> _cards(Document doc) {
    final results = <String, MangaSummary>{};
    for (final card in doc.querySelectorAll('.bsx')) {
      final link = card.querySelector('a[href]');
      final href = link?.attributes['href'];
      if (href == null ||
          !href.contains('${cataloguePath.replaceAll(RegExp(r'/$'), '')}/')) {
        continue;
      }
      final mangaId = _id(href);
      final title =
          link?.attributes['title'] ?? _text(card.querySelector('.tt'));
      if (mangaId.isEmpty || title.isEmpty) continue;
      results[mangaId] = MangaSummary(
          id: mangaId,
          title: title,
          coverUrl: _image(card.querySelector('img')),
          url: _url(href));
    }
    return results.values.toList();
  }

  Future<List<MangaSummary>> _catalogue(int page, String order,
      {String? genre, String query = ''}) async {
    if (filterPath != null) {
      final response = await _dio.post<String>(filterPath!,
          data: {
            'OrderValue': order,
            'StatusValue': 'all',
            'TypeValue': 'all',
            if (genre != null) 'genres_checked[]': genre
          },
          options: Options(
              contentType: Headers.formUrlEncodedContentType,
              responseType: ResponseType.plain));
      final data = jsonDecode(response.data ?? '[]');
      if (data is! List) throw Exception('$name could not load its catalogue.');
      // ponytail: this endpoint returns the entire filtered catalogue; page locally.
      final entries = <MangaSummary>[];
      for (final item in data.whereType<Map>()) {
        final title = item['title']?.toString() ?? '';
        if (title.isEmpty ||
            !title.toLowerCase().contains(query.toLowerCase())) {
          continue;
        }
        // Same canonical slug transformation used by the site's filter controls.
        final slug = title
            .toLowerCase()
            .replaceAll(RegExp('[^a-z0-9]+'), '-')
            .replaceFirst('-s-', 's-')
            .replaceFirst('-ll-', 'll-');
        final mangaId = 'series/r2311170-$slug';
        entries.add(MangaSummary(
            id: mangaId,
            title: title,
            coverUrl: _url('/assets/images/${item['image_url']}'),
            url: _url(mangaId)));
      }
      return entries.skip((page - 1) * 20).take(20).toList();
    }
    return _cards(await _get(query.isEmpty ? cataloguePath : '/', {
      if (query.isEmpty) 'page': page else 'paged': page,
      'order': order,
      if (genre != null) 'genre[]': genre,
      if (query.isNotEmpty) 's': query,
    }));
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) =>
      _catalogue(page, 'popular');
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) =>
      _catalogue(page, 'update');
  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) =>
      _catalogue(page, 'title', query: query);

  @override
  Future<List<GenreOption>> fetchGenres() async {
    final doc = await _get(cataloguePath);
    final genres = <String, GenreOption>{};
    for (final input in doc.querySelectorAll('input[name="genre[]"]')) {
      final value = input.attributes['value'];
      final label = doc
          .querySelectorAll('label')
          .where((e) => e.attributes['for'] == input.id)
          .firstOrNull;
      final title = _text(label);
      if (value != null && value.isNotEmpty && title.isNotEmpty) {
        genres[value] = GenreOption(id: value, name: title);
      }
    }
    return genres.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<List<MangaSummary>> fetchByGenre(String genreId, {int page = 1}) =>
      _catalogue(page, 'popular', genre: genreId);

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final doc = await _get('/$mangaId/');
    String? field(String label) {
      for (final row in doc.querySelectorAll('.tsinfo .imptdt, .infox .fmed')) {
        if (_text(row).toLowerCase().startsWith(label)) {
          return _text(row.querySelector('i, span'));
        }
      }
      return null;
    }

    final title = _text(doc.querySelector('h1.entry-title'));
    final status = field('status')?.toLowerCase();
    final descriptionElement = doc
        .querySelector('[itemprop="description"], .entry-content')
        ?.clone(true);
    descriptionElement
        ?.querySelectorAll('script, style')
        .forEach((el) => el.remove());
    var description = _text(descriptionElement);
    if (description.isEmpty) {
      for (final script in doc.querySelectorAll('script')) {
        final match = RegExp(r'\bvar\s+description\s*=\s*("(?:\\.|[^"\\])*")')
            .firstMatch(script.text);
        if (match == null) continue;
        try {
          description = jsonDecode(match.group(1)!) as String;
          break;
        } on FormatException {/* Leave genuinely missing metadata empty. */}
      }
    }
    return MangaDetail(
        id: mangaId,
        title: title.isEmpty ? mangaId : title,
        coverUrl: _image(doc.querySelector('.thumb img')),
        author: field('author'),
        artist: field('artist'),
        description: description,
        genres: doc
            .querySelectorAll('.mgen a, .seriestugenre a')
            .map(_text)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(),
        status: switch (status) {
          'ongoing' => 'ongoing',
          'completed' || 'complete' => 'completed',
          'hiatus' => 'hiatus',
          'dropped' || 'cancelled' => 'cancelled',
          _ => 'unknown'
        },
        url: _url('$mangaId/'));
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final doc = await _get('/$mangaId/');
    final chapters = <String, ChapterInfo>{};
    for (final row in doc.querySelectorAll('#chapterlist li')) {
      final link = row.querySelector('a[href]');
      final href = link?.attributes['href'];
      if (href == null || href.isEmpty || href.startsWith('#')) continue;
      final chapterId = _id(href);
      final title = _text(row.querySelector('.chapternum'));
      final pattern =
          RegExp(r'chapter[\s-]*(\d+(?:[.-]\d+)?)', caseSensitive: false);
      final match = pattern.firstMatch(title) ?? pattern.firstMatch(chapterId);
      final number =
          double.tryParse(match?.group(1)?.replaceAll('-', '.') ?? '');
      chapters[chapterId] = ChapterInfo(
          id: chapterId,
          title: title.isEmpty ? _text(link) : title,
          number: number,
          language: language,
          uploadDate: _date(_text(row.querySelector('.chapterdate'))),
          url: _url(href));
    }
    return chapters.values.toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

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
    for (final script in doc.querySelectorAll('script')) {
      final match =
          RegExp(r'ts_reader\.run\(\s*(\{.*?\})\s*\)\s*;', dotAll: true)
              .firstMatch(script.text);
      if (match == null) continue;
      try {
        final data = jsonDecode(match.group(1)!);
        final sources = data is Map ? data['sources'] : null;
        if (sources is List) {
          for (final source in sources.whereType<Map>()) {
            final images = source['images'];
            if (images is List) {
              final urls = images
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .map(_url)
                  .toList();
              if (urls.isNotEmpty) return urls;
            }
          }
        }
      } on FormatException {/* Fall back to the rendered reader. */}
    }
    final urls = doc
        .querySelectorAll('#readerarea img')
        .map(_image)
        .whereType<String>()
        .toList();
    if (urls.isEmpty) {
      throw Exception('$name has no readable pages for this chapter.');
    }
    return urls;
  }
}
