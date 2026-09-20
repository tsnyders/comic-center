import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

import '../models/chapter_info.dart';
import '../models/filter.dart';
import '../models/manga_detail.dart';
import '../models/manga_summary.dart';
import '../source_interface.dart';

/// Read page props directly, avoiding a cached Next build ID after deployments.
class FlameComicsSource extends MangaSource {
  FlameComicsSource([Dio? dio]) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {..._dio.options.headers, ...imageHeaders});
  }
  final Dio _dio;
  @override
  String get id => 'flamecomics_en';
  @override
  String get name => 'Flame Comics';
  @override
  String get baseUrl => 'https://flamecomics.xyz';
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
  static const _cdn = 'https://cdn.flamecomics.xyz/uploads/images/series';
  Map<String, Object?> _map(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : {};
  List<Map<String, Object?>> _list(Object? value) =>
      value is List ? value.whereType<Map>().map(_map).toList() : [];
  List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : [];
  Future<Map<String, Object?>> _props(String path) async {
    final response = await _dio.get<String>(path,
        options: Options(responseType: ResponseType.plain));
    final raw = html.parse(response.data).querySelector('#__NEXT_DATA__')?.text;
    if (raw == null) throw Exception('Flame Comics could not load this page.');
    return _map(_map(_map(jsonDecode(raw))['props'])['pageProps']);
  }

  String _cover(Map<String, Object?> item) =>
      '$_cdn/${item['series_id']}/${item['cover']}?${item['last_edit']}';
  MangaSummary _summary(Map<String, Object?> item) => MangaSummary(
      id: '${item['series_id']}',
      title: '${item['title']}',
      coverUrl: _cover(item),
      url: '$baseUrl/series/${item['series_id']}');
  Future<List<MangaSummary>> _browse(int page, String query) async {
    final props = await _props('/browse');
    final series = _list(props['series'])
        .where((s) =>
            s['series_id'] != null &&
            [
              '${s['title']}',
              ..._strings(s['altTitles'])
            ].any((title) => title.toLowerCase().contains(query.toLowerCase())))
        .toList();
    series.sort((a, b) => ((a['popularityRank'] as num?) ?? double.infinity)
        .compareTo((b['popularityRank'] as num?) ?? double.infinity));
    return series.skip((page - 1) * 20).take(20).map(_summary).toList();
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) => _browse(page, '');
  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) =>
      _browse(page, query);
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async {
    final props = await _props('/');
    final entries = <String, MangaSummary>{};
    for (final block in _list(_map(props['latestEntries'])['blocks'])) {
      for (final item in _list(block['series'])) {
        final summary = _summary(item);
        entries[summary.id] = summary;
      }
    }
    // ponytail: the homepage exposes a finite update feed, paged locally.
    return entries.values.skip((page - 1) * 20).take(20).toList();
  }

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    final s = _map((await _props('/series/$mangaId'))['series']);
    final status = '${s['status']}'.toLowerCase();
    return MangaDetail(
        id: mangaId,
        title: s['title']?.toString() ?? mangaId,
        coverUrl: s['cover'] == null ? null : _cover(s),
        author: _strings(s['author']).join(', '),
        artist: _strings(s['artist']).join(', '),
        description: html.parse(s['description']?.toString()).body?.text,
        genres: _strings(s['tags'] ?? s['categories']),
        status: switch (status) {
          'ongoing' => 'ongoing',
          'completed' => 'completed',
          'hiatus' => 'hiatus',
          'dropped' => 'cancelled',
          _ => 'unknown'
        },
        url: '$baseUrl/series/$mangaId');
  }

  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    final props = await _props('/series/$mangaId');
    return _list(props['chapters']).where((c) => c['token'] != null).map((c) {
      final chapterId = '$mangaId/${c['token']}';
      return ChapterInfo(
          id: chapterId,
          title:
              'Chapter ${c['chapter']}${c['title'] == null || c['title'] == '' ? '' : ' - ${c['title']}'}',
          number: double.tryParse('${c['chapter']}'),
          language: language,
          uploadDate: c['release_date'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  (c['release_date'] as num).toInt() * 1000,
                  isUtc: true)
              : null,
          url: '$baseUrl/series/$chapterId');
    }).toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    final chapter = _map((await _props('/series/$chapterId'))['chapter']);
    final raw = chapter['images'];
    final images = raw is Map
        ? (raw.keys.map((k) => k.toString()).toList()
              ..sort((a, b) => int.parse(a).compareTo(int.parse(b))))
            .map((k) => _map(raw[k]))
            .toList()
        : _list(raw);
    final pages = images
        .where((i) => i['name'] is String)
        .map((i) =>
            '$_cdn/$chapterId/${Uri.encodeComponent(i['name'] as String)}?${chapter['release_date']}')
        .toList();
    // ponytail: split spreads remain separate images; the reader contract is URLs only.
    if (pages.isEmpty) {
      throw Exception('Flame Comics has no readable pages for this chapter.');
    }
    return pages;
  }
}
