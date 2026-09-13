// Live smoke test for the three required English sources.
//
// This exercises the real sites and therefore stays out of the regular CI
// suite. Run it before a release with:
//
//   dart run tool/live_required_sources_test.dart

// It verifies catalogue covers, title details, chapter lists, reader page
// discovery, and that the first page can be fetched with the source headers.

import 'dart:io';

import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/extensions/sources/asura_scans_source.dart';
import 'package:comic_center/core/extensions/sources/mangapill_source.dart';
import 'package:comic_center/core/extensions/sources/mangataro_source.dart';
import 'package:dio/dio.dart';

Future<void> main() async {
  final sources = <MangaSource>[
    MangaPillSource(),
    MangaTaroSource(),
    AsuraScansSource(),
  ];
  var failures = 0;

  for (final source in sources) {
    stdout.writeln('\n${source.name} (${source.baseUrl})');
    try {
      final titles = await source.fetchPopular();
      _require(titles.isNotEmpty, 'catalogue returned no titles');
      final title = titles.firstWhere(
        (item) => item.coverUrl?.isNotEmpty ?? false,
        orElse: () => titles.first,
      );
      _require(title.title.isNotEmpty, 'catalogue title is empty');
      _require(title.coverUrl?.isNotEmpty ?? false, 'cover URL is missing');
      stdout.writeln('  PASS cover: ${title.title}');

      final coverBytes = await _fetchImagePrefix(
        title.coverUrl!,
        source.imageHeaders,
      );
      _require(coverBytes > 0, 'cover image returned no bytes');

      final detail = await source.fetchMangaDetail(title.id);
      _require(detail.title.isNotEmpty, 'title detail is empty');
      stdout.writeln('  PASS detail: ${detail.title}');

      final chapters = await source.fetchChapterList(title.id);
      _require(chapters.isNotEmpty, 'chapter list is empty');
      stdout.writeln('  PASS chapters: ${chapters.length}');

      final pages = await source.fetchPageUrls(chapters.last.id);
      _require(pages.isNotEmpty, 'reader returned no pages');
      _require(Uri.tryParse(pages.first)?.hasAbsolutePath ?? false,
          'first page URL is not absolute');
      stdout.writeln('  PASS reader: ${pages.length} pages');

      final pageBytes = await _fetchImagePrefix(
        pages.first,
        source.imageHeaders,
      );
      _require(pageBytes > 0, 'page image returned no bytes');
      stdout.writeln('  PASS download: page bytes are accessible');
    } catch (error) {
      failures++;
      stderr.writeln('  FAIL: $error');
    }
  }

  if (failures > 0) {
    stderr.writeln('\n$failures required source(s) failed.');
    exitCode = 1;
    return;
  }
  stdout.writeln('\nAll required source checks passed.');
}

Future<int> _fetchImagePrefix(
  String url,
  Map<String, String> sourceHeaders,
) async {
  final client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 400,
    ),
  );
  final response = await client.get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      headers: {...sourceHeaders, 'Range': 'bytes=0-1023'},
    ),
  );
  return response.data?.length ?? 0;
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}
