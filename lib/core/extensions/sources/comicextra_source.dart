import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// ComicExtra — western comics aggregator (DC, Marvel, Image, Dynamite).
///
/// HTML scraping, no public JSON API. This is the "reliable" of the two
/// comic sources because chapter pages are served as plain `<img>` tags on a
/// `/full` view, so page extraction does not require JS de-obfuscation.
///
/// IDs:
///  - Manga ID  = comic slug (e.g. "the-boys").
///  - Chapter ID = "{comicSlug}/{chapterSlug}" (e.g. "the-boys/chapter-1").
///
/// The site has historically moved between .com/.net/.org domains; if it moves
/// again only [baseUrl] needs updating.
class ComicExtraSource implements MangaSource {
  ComicExtraSource([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://comicextra.org',
                headers: {
                  'Referer': 'https://comicextra.org/',
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                      'AppleWebKit/537.36 (KHTML, like Gecko) '
                      'Chrome/120.0.0.0 Safari/537.36',
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                },
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  @override
  String get id => 'comicextra_en';
  @override
  String get name => 'ComicExtra';
  @override
  String get baseUrl => 'https://comicextra.org';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => const {
        'Referer': 'https://comicextra.org/',
      };
  @override
  List<SourceFilter> getFilters() => const [];

  // ── Listings ─────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async {
    final doc = await _fetchDoc('/popular-comics', queryParameters: {'page': page});
    return _parseList(doc);
  }

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async {
    final doc = await _fetchDoc('/recent-comics', queryParameters: {'page': page});
    return _parseList(doc);
  }

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) async {
    // Primary search endpoint. Fall back to the advanced-search page if the
    // simple one ever changes shape.
    for (final attempt in <Future<dom.Document> Function()>[
      () => _fetchDoc('/comic-search', queryParameters: {'key': query, 'page': page}),
      () => _fetchDoc('/advanced-search',
          queryParameters: {'key': query, 'page': page}),
    ]) {
      try {
        final doc = await attempt();
        final results = _parseList(doc);
        if (results.isNotEmpty) return results;
      } catch (_) {}
    }
    return const [];
  }

  /// Comics appear in `.cartoon-box` cards across the listing/search pages.
  /// A few defensive fallbacks cover older markup.
  List<MangaSummary> _parseList(dom.Document doc) {
    var cards = doc.querySelectorAll('div.cartoon-box');
    if (cards.isEmpty) cards = doc.querySelectorAll('div.eg-box');
    if (cards.isEmpty) cards = doc.querySelectorAll('div.movie-list-index div.item');

    final out = <MangaSummary>[];
    for (final el in cards) {
      final link = el.querySelector('h3 a') ??
          el.querySelector('a[href*="/comic/"]') ??
          el.querySelector('a[href]');
      final href = link?.attributes['href'] ?? '';
      final slug = _comicSlug(href);
      if (slug.isEmpty) continue;
      final title = (link?.attributes['title'] ?? link?.text ?? '').trim();
      final img = el.querySelector('img');
      final cover = _absolute(
        img?.attributes['src'] ??
            img?.attributes['data-src'] ??
            img?.attributes['data-original'] ??
            '',
      );
      out.add(MangaSummary(
        id: slug,
        title: title.isNotEmpty ? title : _humanize(slug),
        coverUrl: cover.isNotEmpty ? cover : null,
        url: '$baseUrl/comic/$slug',
      ));
    }
    return out;
  }

  // ── Detail ────────────────────────────────────────────────────────────────

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final doc = await _fetchDoc('/comic/$mangaId');

    final title = (doc.querySelector('.movie-title h1') ??
                doc.querySelector('h1.title-1') ??
                doc.querySelector('h1'))
            ?.text
            .trim() ??
        _humanize(mangaId);

    final img = doc.querySelector('.movie-l-img img') ??
        doc.querySelector('.anime-image img') ??
        doc.querySelector('.movie-image img') ??
        doc.querySelector('img[src*="/uploads/"]');
    final cover = _absolute(
      img?.attributes['src'] ?? img?.attributes['data-src'] ?? '',
    );

    final description = (doc.querySelector('#film-content') ??
            doc.querySelector('.detail-desc-content') ??
            doc.querySelector('div.shortcontent'))
        ?.text
        .trim();

    final genres = doc
        .querySelectorAll('.movie-dd a[href*="/genre"], dd a[href*="/genre"]')
        .map((e) => e.text.trim())
        .where((g) => g.isNotEmpty)
        .toList();

    final author = _dlValue(doc, const ['author', 'writer', 'artist']);
    final statusText = _dlValue(doc, const ['status']);

    return MangaDetail(
      id: mangaId,
      title: title,
      coverUrl: cover.isNotEmpty ? cover : null,
      author: author,
      description: description,
      genres: genres,
      status: _statusStr(statusText),
      url: '$baseUrl/comic/$mangaId',
    );
  }

  // ── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final doc = await _fetchDoc('/comic/$mangaId');

    var anchors = doc.querySelectorAll('div.episode-list table tr td a');
    if (anchors.isEmpty) anchors = doc.querySelectorAll('ul.basic-list li a');
    if (anchors.isEmpty) {
      anchors = doc.querySelectorAll('a[href*="/$mangaId/"]');
    }

    final chapters = <ChapterInfo>[];
    for (final el in anchors) {
      final href = el.attributes['href'] ?? '';
      final chId = _chapterId(href);
      if (chId.isEmpty || !chId.contains('/')) continue;
      final name = _ownText(el).isNotEmpty ? _ownText(el) : el.text.trim();
      final number = _numberFrom(name) ?? _numberFrom(chId);
      chapters.add(ChapterInfo(
        id: chId,
        title: name.isNotEmpty ? name : 'Chapter',
        number: number,
        url: '$baseUrl/$chId',
      ));
    }

    // Site lists newest-first; reading order is ascending.
    chapters.sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
    return chapters;
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    // The `/full` view renders every page image on one HTML page as plain
    // <img> tags — no JS de-obfuscation needed.
    final path = chapterId.startsWith('/') ? chapterId : '/$chapterId';
    final doc = await _fetchDoc('$path/full');

    var imgs = doc.querySelectorAll('div.chapter-container img');
    if (imgs.isEmpty) imgs = doc.querySelectorAll('div.chapter_img img');
    if (imgs.isEmpty) imgs = doc.querySelectorAll('img.chapter_img');
    if (imgs.isEmpty) {
      // Last resort: any image hosted under the comics upload path.
      imgs = doc.querySelectorAll('img[src*="/uploads/"], img[data-src]');
    }

    final urls = imgs
        .map((img) => _absolute(
              (img.attributes['src'] ??
                      img.attributes['data-src'] ??
                      img.attributes['data-original'] ??
                      '')
                  .trim(),
            ))
        .where((u) => u.isNotEmpty)
        .toList();

    if (urls.isEmpty) {
      throw Exception(
        'No pages found for ComicExtra chapter "$chapterId". '
        'The site markup may have changed.',
      );
    }
    return urls;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<dom.Document> _fetchDoc(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final resp = await _dio.get<String>(
      path,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.plain),
    );
    return html_parser.parse(resp.data ?? '');
  }

  String _absolute(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$baseUrl$url';
    return url;
  }

  /// "/comic/the-boys" → "the-boys".
  String _comicSlug(String href) {
    final cleaned = href.split('?').first.split('#').first;
    final parts = cleaned.split('/').where((p) => p.isNotEmpty).toList();
    final idx = parts.indexOf('comic');
    if (idx >= 0 && idx + 1 < parts.length) return parts[idx + 1];
    return parts.isNotEmpty ? parts.last : '';
  }

  /// "/the-boys/chapter-1" → "the-boys/chapter-1".
  String _chapterId(String href) {
    var cleaned = href.split('?').first.split('#').first;
    if (cleaned.startsWith('http')) cleaned = Uri.parse(cleaned).path;
    cleaned = cleaned.replaceFirst(RegExp(r'/full/?$'), '');
    final parts = cleaned.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}/${parts.last}';
    }
    return cleaned.replaceFirst(RegExp(r'^/'), '');
  }

  /// Reads a value from the `<dl>`-style info block by matching a label.
  String? _dlValue(dom.Document doc, List<String> labels) {
    for (final dt in doc.querySelectorAll('dt')) {
      final label = dt.text.trim().toLowerCase();
      if (labels.any(label.contains)) {
        final dd = dt.nextElementSibling;
        final v = dd?.text.trim();
        if (v != null && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  double? _numberFrom(String s) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(s);
    return m != null ? double.tryParse(m.group(1)!) : null;
  }

  String _humanize(String slug) {
    final words = slug
        .replaceAll('_', '-')
        .split('-')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1));
    final out = words.join(' ').trim();
    return out.isEmpty ? 'Untitled' : out;
  }

  String _ownText(dom.Element el) =>
      el.nodes.whereType<dom.Text>().map((n) => n.text).join().trim();

  String _statusStr(String? s) => switch (s?.toLowerCase().trim()) {
        'ongoing' => 'ongoing',
        'completed' || 'complete' => 'completed',
        _ => 'unknown',
      };
}
