import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// DemonicScans source — HTML scraping, no public JSON API.
/// Manga IDs are the URL slug (e.g. "Murim-Login").
/// Chapter IDs are composite "{manga-slug}/{chapter-slug}" (e.g. "Murim-Login/chapter-180").
class DemonicScansSource implements MangaSource {
  DemonicScansSource([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://demonicscans.org',
                headers: {
                  'Referer': 'https://demonicscans.org/',
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
  String get id => 'demonicscans_en';
  @override
  String get name => 'DemonicScans';
  @override
  String get baseUrl => 'https://demonicscans.org';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => const {
        'Referer': 'https://demonicscans.org/',
      };
  @override
  List<SourceFilter> getFilters() => const [];

  // ── Listings ─────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async {
    final html = await _fetchHtml('/advanced.php', queryParameters: {
      'list': page,
      'status': 'all',
      'orderby': 'VIEWS DESC',
    });
    return _parseAdvancedItems(html_parser.parse(html));
  }

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async {
    final html = await _fetchHtml('/lastupdates.php', queryParameters: {'list': page});
    final doc = html_parser.parse(html);

    // Ads are injected as .updates-element items — filter them out via .toffee-badge
    return doc
        .querySelectorAll('div#updates-container > div.updates-element')
        .where((el) => el.querySelector('.toffee-badge') == null)
        .map<MangaSummary>((el) {
          final link = el.querySelector('div.updates-element-info > a');
          final href = link?.attributes['href'] ?? '';
          final slug = _slug(href);
          final title = link?.text.trim() ?? 'Unknown';
          final img = el.querySelector('div.thumb > img');
          final coverUrl = _absolute(img?.attributes['src'] ?? '');
          return MangaSummary(
            id: slug,
            title: title,
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            url: '$baseUrl/manga/$slug',
          );
        })
        .toList();
  }

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) async {
    final html = await _fetchHtml('/search.php',
        queryParameters: {'manga': query});
    final doc = html_parser.parse(html);

    return doc.querySelectorAll('body > a[href]').map<MangaSummary>((el) {
      final href = el.attributes['href'] ?? '';
      final slug = _slug(href);
      // The site has a CSS typo: "seach-right" not "search-right"
      final title = el.querySelector('div.seach-right > div')?.text.trim() ??
          'Unknown';
      final img = el.querySelector('img');
      final coverUrl = _absolute(img?.attributes['src'] ?? '');
      return MangaSummary(
        id: slug,
        title: title,
        coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
        url: '$baseUrl/manga/$slug',
      );
    }).toList();
  }

  // ── Detail ────────────────────────────────────────────────────────────────

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final html = await _fetchHtml('/manga/$mangaId');
    final doc = html_parser.parse(html);

    final title =
        doc.querySelector('h1.big-fat-titles')?.text.trim() ?? mangaId;

    final rawCover =
        doc.querySelector('div#manga-page > img')?.attributes['src'] ?? '';
    final coverUrl = _absolute(rawCover);

    final genres = doc
        .querySelectorAll('div.genres-list > li')
        .map((el) => el.text.trim())
        .where((g) => g.isNotEmpty)
        .toList();

    final description = doc
        .querySelector(
            'div#manga-info-rightColumn > div > div.white-font')
        ?.text
        .trim();

    final stats = doc.querySelector('div#manga-info-stats');
    final author = _statValue(stats, 'Author');
    final statusText = _statValue(stats, 'Status');
    final status = switch (statusText?.toLowerCase()) {
      'ongoing' => 'ongoing',
      'completed' => 'completed',
      _ => 'unknown',
    };

    return MangaDetail(
      id: mangaId,
      title: title,
      coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
      author: author,
      artist: null,
      description: description,
      genres: genres,
      status: status,
      url: '$baseUrl/manga/$mangaId',
    );
  }

  // ── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final html = await _fetchHtml('/manga/$mangaId');
    final doc = html_parser.parse(html);

    // Chapters appear newest-first in HTML; reverse for ascending order
    final els = doc
        .querySelectorAll('div#chapters-list > a.chplinks')
        .toList()
        .reversed
        .toList();

    return els.map<ChapterInfo>((el) {
      final href = el.attributes['href'] ?? '';
      final chapterId = _chapterId(href);

      // ownText: direct text only (excludes the child <span> date)
      final name = _ownText(el);
      final dateStr = el.querySelector('span')?.text.trim();
      final uploadDate =
          dateStr != null ? DateTime.tryParse(dateStr) : null;

      final numMatch =
          RegExp(r'(?:Chapter\s+)?([\d.]+)', caseSensitive: false)
              .firstMatch(name);
      final number =
          numMatch != null ? double.tryParse(numMatch.group(1)!) : null;

      return ChapterInfo(
        id: chapterId,
        title: name.isNotEmpty ? name : 'Chapter',
        number: number,
        uploadDate: uploadDate,
        url: '$baseUrl/manga/$chapterId',
      );
    }).toList();
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    // chapterId format: "{manga-slug}/{chapter-slug}"
    final html = await _fetchHtml('/manga/$chapterId');
    final doc = html_parser.parse(html);

    return doc
        .querySelectorAll('img.imgholder')
        .map((img) => _absolute(img.attributes['src'] ?? ''))
        .where((url) => url.isNotEmpty)
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _fetchHtml(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final resp = await _dio.get<String>(
      path,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.plain),
    );
    return resp.data ?? '';
  }

  List<MangaSummary> _parseAdvancedItems(dom.Document doc) {
    return doc
        .querySelectorAll('div#advanced-content > div.advanced-element')
        .map<MangaSummary>((el) {
          final link = el.querySelector('a[href]');
          final href = link?.attributes['href'] ?? '';
          final slug = _slug(href);
          final h1 = el.querySelector('h1');
          final title =
              h1 != null ? _ownText(h1) : (link?.text.trim() ?? 'Unknown');
          final img = el.querySelector('img');
          final coverUrl = _absolute(img?.attributes['src'] ?? '');
          return MangaSummary(
            id: slug,
            title: title.isNotEmpty ? title : 'Unknown',
            coverUrl: coverUrl.isNotEmpty ? coverUrl : null,
            url: '$baseUrl/manga/$slug',
          );
        })
        .toList();
  }

  /// Resolves a URL that may be relative to an absolute URL.
  String _absolute(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return 'https://demonicscans.org$url';
    return url;
  }

  /// Extracts the manga slug from a URL (e.g. "/manga/Murim-Login" → "Murim-Login").
  ///
  /// DemonicScans serves percent-encoded slugs in href attributes (e.g.
  /// `%2D` for hyphens, sometimes double-encoded). We fully decode so the
  /// canonical form is stored — that way Dio won't re-encode `%` chars and
  /// double-encode the URL when we fetch details/chapters.
  String _slug(String href) {
    final cleaned = href.split('?').first.split('#').first;
    final parts = cleaned.split('/');
    final idx = parts.indexOf('manga');
    final raw = (idx >= 0 && idx + 1 < parts.length) ? parts[idx + 1] : href;
    return _fullyDecode(raw);
  }

  /// Extracts "{manga-slug}/{chapter-slug}" from a chapter URL, fully decoded.
  String _chapterId(String href) {
    final cleaned = href.split('?').first.split('#').first;
    final parts = cleaned.split('/');
    final idx = parts.indexOf('manga');
    if (idx >= 0 && idx + 2 < parts.length) {
      return '${_fullyDecode(parts[idx + 1])}/${_fullyDecode(parts[idx + 2])}';
    }
    return _fullyDecode(href);
  }

  /// Decodes percent-encoding repeatedly until stable (handles double-encoding).
  String _fullyDecode(String s) {
    var prev = s;
    for (var i = 0; i < 5; i++) {
      try {
        final next = Uri.decodeComponent(prev);
        if (next == prev) return next;
        prev = next;
      } catch (_) {
        return prev;
      }
    }
    return prev;
  }

  /// Returns direct text content of an element (excluding child elements).
  String _ownText(dom.Element el) {
    return el.nodes.whereType<dom.Text>().map((n) => n.text).join().trim();
  }

  /// Finds a value from the stats section (e.g., Author or Status).
  String? _statValue(dom.Element? stats, String label) {
    if (stats == null) return null;
    for (final div in stats.querySelectorAll('div')) {
      final items = div.querySelectorAll('li');
      if (items.isEmpty) continue;
      if (items.first.text.trim().toLowerCase().contains(label.toLowerCase())) {
        return items.length > 1 ? items[1].text.trim() : null;
      }
    }
    return null;
  }
}
