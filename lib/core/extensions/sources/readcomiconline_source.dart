import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// ReadComicOnline — the broadest western-comics aggregator
/// (DC, Marvel, Image/Invincible, Dynamite/The Boys, etc.).
///
/// HTML scraping. Listing / detail / chapter parsing are straightforward, but
/// chapter page-image URLs are emitted by an on-page JS de-obfuscator
/// (`beau()` over an `lstImages` array). We can't run that JS from a pure-Dart
/// isolate, so [fetchPageUrls] is best-effort: it tries the high-quality reader
/// view, recovers any already-plain CDN URLs, and applies a base64 fallback.
/// If the site is serving fully-obfuscated URLs, page loading may fail and the
/// extractor needs updating against a live chapter's HTML.
///
/// IDs:
///  - Manga ID  = comic slug (e.g. "The-Boys").
///  - Chapter ID = relative reader path incl. query
///    (e.g. "Comic/The-Boys/Issue-1?id=12345").
class ReadComicOnlineSource implements MangaSource {
  ReadComicOnlineSource([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://readcomiconline.li',
                headers: {
                  'Referer': 'https://readcomiconline.li/',
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
  String get id => 'readcomiconline_en';
  @override
  String get name => 'ReadComicOnline';
  @override
  String get baseUrl => 'https://readcomiconline.li';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => const {
        'Referer': 'https://readcomiconline.li/',
      };
  @override
  List<SourceFilter> getFilters() => const [];

  // ── Listings ─────────────────────────────────────────────────────────────

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async {
    final doc =
        await _fetchDoc('/ComicList/MostPopular', queryParameters: {'page': page});
    return _parseList(doc);
  }

  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async {
    final doc =
        await _fetchDoc('/ComicList/LatestUpdate', queryParameters: {'page': page});
    return _parseList(doc);
  }

  @override
  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  }) async {
    // RCO search is a POST form; fall back to the GET variant if needed.
    try {
      final resp = await _dio.post<String>(
        '/Search/Comic',
        data: {'keyword': query},
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      final results = _parseList(html_parser.parse(resp.data ?? ''));
      if (results.isNotEmpty) return results;
    } catch (_) {}

    try {
      final doc =
          await _fetchDoc('/Search/Comic', queryParameters: {'keyword': query});
      return _parseList(doc);
    } catch (_) {}
    return const [];
  }

  /// Listing/search results render as anchors linking to `/Comic/{slug}`.
  List<MangaSummary> _parseList(dom.Document doc) {
    var items = doc.querySelectorAll('div.list-comic div.item');
    if (items.isEmpty) items = doc.querySelectorAll('table.listing tr td');
    if (items.isEmpty) items = doc.querySelectorAll('div.item-list');

    final out = <MangaSummary>[];
    final seen = <String>{};
    for (final el in items) {
      final link = el.querySelector('a[href*="/Comic/"]');
      final href = link?.attributes['href'] ?? '';
      final slug = _comicSlug(href);
      if (slug.isEmpty || !seen.add(slug)) continue;
      final img = el.querySelector('img');
      final title = (link?.attributes['title'] ??
              img?.attributes['alt'] ??
              link?.text ??
              '')
          .trim();
      final cover = _absolute(
        img?.attributes['src'] ?? img?.attributes['data-src'] ?? '',
      );
      out.add(MangaSummary(
        id: slug,
        title: title.isNotEmpty ? title : _humanize(slug),
        coverUrl: cover.isNotEmpty ? cover : null,
        url: '$baseUrl/Comic/$slug',
      ));
    }

    // Fallback: a bare anchor list when no card wrapper matched.
    if (out.isEmpty) {
      for (final link in doc.querySelectorAll('a[href*="/Comic/"]')) {
        final slug = _comicSlug(link.attributes['href'] ?? '');
        if (slug.isEmpty || slug.contains('?') || !seen.add(slug)) continue;
        final title = link.text.trim();
        if (title.isEmpty) continue;
        out.add(MangaSummary(
          id: slug,
          title: title,
          url: '$baseUrl/Comic/$slug',
        ));
      }
    }
    return out;
  }

  // ── Detail ────────────────────────────────────────────────────────────────

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final doc = await _fetchDoc('/Comic/$mangaId');

    final title = (doc.querySelector('a.bigChar') ??
                doc.querySelector('.heading h3') ??
                doc.querySelector('.heading'))
            ?.text
            .trim() ??
        _humanize(mangaId);

    final coverSrc = doc.querySelector('link[rel="image_src"]')?.attributes['href'] ??
        doc.querySelector('div.rightBox img')?.attributes['src'] ??
        doc.querySelector('.barContent img')?.attributes['src'] ??
        doc.querySelector('#rightside img')?.attributes['src'] ??
        '';
    final cover = _absolute(coverSrc);

    final genres = <String>[];
    for (final p in doc.querySelectorAll('div.barContent p, .section p')) {
      if (p.text.toLowerCase().contains('genres')) {
        genres.addAll(p.querySelectorAll('a').map((a) => a.text.trim()));
        break;
      }
    }

    final description = _summaryText(doc);
    final author = _infoValue(doc, const ['writer', 'author', 'artist']);
    final statusText = _infoValue(doc, const ['status']);

    return MangaDetail(
      id: mangaId,
      title: title,
      coverUrl: cover.isNotEmpty ? cover : null,
      author: author,
      description: description,
      genres: genres.where((g) => g.isNotEmpty).toList(),
      status: _statusStr(statusText),
      url: '$baseUrl/Comic/$mangaId',
    );
  }

  // ── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final doc = await _fetchDoc('/Comic/$mangaId');

    var rows = doc.querySelectorAll('table.listing tr');
    if (rows.isEmpty) rows = doc.querySelectorAll('.episodeList table tr');

    final chapters = <ChapterInfo>[];
    for (final tr in rows) {
      final link = tr.querySelector('a[href*="/Comic/"]');
      final href = link?.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final chId = _chapterId(href);
      if (chId.isEmpty) continue;
      final name = link!.text.trim();
      // Date sits in the second cell when present.
      final cells = tr.querySelectorAll('td');
      DateTime? date;
      if (cells.length > 1) {
        date = _parseDate(cells[1].text.trim());
      }
      chapters.add(ChapterInfo(
        id: chId,
        title: name.isNotEmpty ? name : 'Chapter',
        number: _numberFrom(name),
        uploadDate: date,
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
    // Request the high-quality, single-page reader view.
    final path = chapterId.startsWith('/') ? chapterId : '/$chapterId';
    final sep = path.contains('?') ? '&' : '?';
    final resp = await _dio.get<String>(
      '$path${sep}quality=hq&readType=1',
      options: Options(responseType: ResponseType.plain),
    );
    final body = resp.data ?? '';

    // 1) Pull the `lstImages` entries out of the inline script.
    final raw = <String>[];
    for (final m in RegExp(
      '''lstImages\\.push\\(["']([^"']+)["']\\)''',
    ).allMatches(body)) {
      raw.add(m.group(1)!);
    }

    final urls = <String>[];
    for (final entry in raw) {
      final resolved = _deobfuscate(entry);
      if (resolved.isNotEmpty) urls.add(resolved);
    }
    if (urls.isNotEmpty) return urls;

    // 2) Fallback: scrape any direct CDN image URLs present in the HTML.
    final doc = html_parser.parse(body);
    final imgs = doc
        .querySelectorAll('#divImage img, .divImage img, img[src*="://"]')
        .map((img) => _absolute(img.attributes['src'] ?? ''))
        .where((u) => _looksLikeImage(u))
        .toList();
    if (imgs.isNotEmpty) return imgs;

    throw Exception(
      'Could not extract pages for ReadComicOnline chapter "$chapterId". '
      'The site is serving obfuscated image URLs that require its on-page '
      'JavaScript de-obfuscator. Try the ComicExtra source for this title, or '
      'send a sample chapter HTML so the extractor can be updated.',
    );
  }

  /// Best-effort recovery of an `lstImages` entry into a usable URL.
  ///
  /// Several historical RCO schemes are covered:
  ///  - already a plain http(s) URL → used as-is;
  ///  - a protocol-relative or root-relative URL → absolutised;
  ///  - a base64 blob that decodes to a URL (some mirrors) → decoded.
  /// Anything still opaque is dropped (handled by the caller's fallback).
  String _deobfuscate(String entry) {
    final s = entry.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    if (s.startsWith('//')) return 'https:$s';
    if (s.startsWith('/')) return _absolute(s);

    // Try a plain base64 decode; keep it only if it yields an image URL.
    try {
      final decoded = utf8.decode(base64.decode(_padBase64(s)));
      if (_looksLikeImage(decoded)) {
        return decoded.startsWith('http') ? decoded : _absolute(decoded);
      }
    } catch (_) {}
    return '';
  }

  String _padBase64(String s) {
    final mod = s.length % 4;
    return mod == 0 ? s : s + '=' * (4 - mod);
  }

  bool _looksLikeImage(String u) {
    final lower = u.toLowerCase();
    return lower.startsWith('http') &&
        (lower.contains('.jpg') ||
            lower.contains('.jpeg') ||
            lower.contains('.png') ||
            lower.contains('.webp'));
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

  /// "/Comic/The-Boys" or "/Comic/The-Boys/Issue-1?id=1" → "The-Boys".
  String _comicSlug(String href) {
    final cleaned = href.split('?').first.split('#').first;
    final parts = cleaned.split('/').where((p) => p.isNotEmpty).toList();
    final idx = parts.indexOf('Comic');
    if (idx >= 0 && idx + 1 < parts.length) return parts[idx + 1];
    return '';
  }

  /// Keeps the full reader-relative path + query so the chapter can be
  /// fetched directly: "/Comic/The-Boys/Issue-1?id=1" → "Comic/The-Boys/Issue-1?id=1".
  String _chapterId(String href) {
    var cleaned = href;
    if (cleaned.startsWith('http')) {
      final uri = Uri.parse(cleaned);
      cleaned = uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    }
    cleaned = cleaned.split('#').first;
    // Must point at a chapter (3 path segments under /Comic/{slug}/{chapter}).
    final pathOnly = cleaned.split('?').first;
    final segs = pathOnly.split('/').where((p) => p.isNotEmpty).toList();
    final idx = segs.indexOf('Comic');
    if (idx < 0 || idx + 2 >= segs.length) return '';
    return cleaned.startsWith('/') ? cleaned.substring(1) : cleaned;
  }

  String? _summaryText(dom.Document doc) {
    for (final p in doc.querySelectorAll('div.barContent p, .section p, div p')) {
      final prev = p.previousElementSibling?.text.toLowerCase() ?? '';
      if (prev.contains('summary')) return p.text.trim();
    }
    // Fallback: the longest paragraph on the page is usually the synopsis.
    String best = '';
    for (final p in doc.querySelectorAll('p')) {
      final t = p.text.trim();
      if (t.length > best.length) best = t;
    }
    return best.isNotEmpty ? best : null;
  }

  /// Reads a labelled value from the info block ("Status:", "Writer:" …).
  String? _infoValue(dom.Document doc, List<String> labels) {
    for (final p in doc.querySelectorAll('div.barContent p, .section p')) {
      final text = p.text.trim();
      final lower = text.toLowerCase();
      for (final label in labels) {
        final marker = '$label:';
        final at = lower.indexOf(marker);
        if (at >= 0) {
          final v = text.substring(at + marker.length).trim();
          if (v.isNotEmpty) return v.split('\n').first.trim();
        }
      }
    }
    return null;
  }

  DateTime? _parseDate(String s) {
    // RCO dates look like "MM/dd/yyyy".
    final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
    );
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

  String _statusStr(String? s) => switch (s?.toLowerCase().trim()) {
        'ongoing' => 'ongoing',
        'completed' || 'complete' => 'completed',
        _ => 'unknown',
      };
}
