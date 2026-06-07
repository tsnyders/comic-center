// Live integration test for the DemonicScans source.
//
// This hits the REAL demonicscans.org site over the network, so it cannot run
// in CI or in network-restricted sandboxes. Run it locally:
//
//   dart run tool/live_demonicscans_test.dart
//
// Optionally pass a manga slug to drill into a specific title:
//
//   dart run tool/live_demonicscans_test.dart Murim-Login
//
// Exit code is 0 when every stage returns data, non-zero otherwise — so it can
// double as a smoke test in a local pre-release check.

import 'dart:io';

import 'package:comic_center/core/extensions/sources/demonicscans_source.dart';

const _green = '\x1B[32m';
const _red = '\x1B[31m';
const _dim = '\x1B[2m';
const _reset = '\x1B[0m';

int _failures = 0;

void _check(String label, bool ok, [String detail = '']) {
  final mark = ok ? '$_green✓$_reset' : '$_red✗$_reset';
  if (!ok) _failures++;
  final suffix = detail.isEmpty ? '' : '  $_dim$detail$_reset';
  stdout.writeln('  $mark $label$suffix');
}

Future<void> main(List<String> args) async {
  final source = DemonicScansSource();
  stdout.writeln('\nLive test against ${source.baseUrl}\n');

  // ── 1. Popular ───────────────────────────────────────────────────────────
  stdout.writeln('① fetchPopular(page: 1)');
  String? firstSlug = args.isNotEmpty ? args.first : null;
  try {
    final popular = await source.fetchPopular(page: 1);
    _check('returned items', popular.isNotEmpty, '${popular.length} titles');
    if (popular.isNotEmpty) {
      final sample = popular.first;
      _check('title is a real name (has spaces, no %)',
          sample.title.contains(' ') && !sample.title.contains('%'),
          '"${sample.title}"');
      _check('id/slug is decoded (no %)', !sample.id.contains('%'),
          'id="${sample.id}"');
      _check('cover URL present', sample.coverUrl != null,
          sample.coverUrl ?? 'null');
      firstSlug ??= sample.id;
      stdout.writeln('    $_dim sample: ${sample.title} → ${sample.id}$_reset');
    }
  } catch (e) {
    _check('request succeeded', false, '$e');
  }

  // ── 2. Latest ────────────────────────────────────────────────────────────
  stdout.writeln('\n② fetchLatestUpdates(page: 1)');
  try {
    final latest = await source.fetchLatestUpdates(page: 1);
    _check('returned items', latest.isNotEmpty, '${latest.length} titles');
    final anyAd = latest.any((m) => m.title.toLowerCase().contains('toffee'));
    _check('ads filtered out', !anyAd);
  } catch (e) {
    _check('request succeeded', false, '$e');
  }

  // ── 3. Search ────────────────────────────────────────────────────────────
  stdout.writeln('\n③ search("murim")');
  try {
    final results = await source.search('murim');
    _check('returned items', results.isNotEmpty, '${results.length} matches');
    if (results.isNotEmpty) {
      firstSlug ??= results.first.id;
      stdout.writeln(
          '    $_dim sample: ${results.first.title} → ${results.first.id}$_reset');
    }
  } catch (e) {
    _check('request succeeded', false, '$e');
  }

  if (firstSlug == null) {
    stdout.writeln('\n${_red}No slug discovered — cannot test detail/chapters/'
        'pages.$_reset');
    exit(1);
  }

  // ── 4. Detail ────────────────────────────────────────────────────────────
  stdout.writeln('\n④ fetchMangaDetail("$firstSlug")');
  try {
    final detail = await source.fetchMangaDetail(firstSlug);
    _check('title resolved (not the raw slug)',
        detail.title.isNotEmpty && detail.title != firstSlug, '"${detail.title}"');
    _check('cover URL present', detail.coverUrl != null);
    _check('genres found', detail.genres.isNotEmpty,
        detail.genres.take(4).join(', '));
    _check('status parsed', detail.status != 'unknown', detail.status);
    _check('author found', detail.author != null, detail.author ?? 'null');
  } catch (e) {
    _check('request succeeded', false, '$e');
  }

  // ── 5. Chapters ──────────────────────────────────────────────────────────
  stdout.writeln('\n⑤ fetchChapterList("$firstSlug")');
  String? firstChapterId;
  try {
    final chapters = await source.fetchChapterList(firstSlug);
    _check('CHAPTERS RETURNED (the bug)', chapters.isNotEmpty,
        '${chapters.length} chapters');
    if (chapters.isNotEmpty) {
      final c0 = chapters.first;
      final cN = chapters.last;
      _check('ascending order (first.number <= last.number)',
          (c0.number ?? 0) <= (cN.number ?? 0),
          'first=${c0.number}, last=${cN.number}');
      _check('chapter id is decoded (no %)', !c0.id.contains('%'), c0.id);
      _check('chapter title excludes date', !c0.title.contains('20'),
          '"${c0.title}"');
      firstChapterId = cN.id; // newest chapter — most likely to have pages
      stdout.writeln(
          '    $_dim newest: "${cN.title}" → ${cN.id}$_reset');
    }
  } catch (e) {
    _check('request succeeded', false, '$e');
  }

  // ── 6. Pages ─────────────────────────────────────────────────────────────
  if (firstChapterId != null) {
    stdout.writeln('\n⑥ fetchPageUrls("$firstChapterId")');
    try {
      final pages = await source.fetchPageUrls(firstChapterId);
      _check('PAGES RETURNED', pages.isNotEmpty, '${pages.length} images');
      if (pages.isNotEmpty) {
        _check('first page is absolute URL', pages.first.startsWith('http'),
            pages.first);
      }
    } catch (e) {
      _check('request succeeded', false, '$e');
    }
  }

  // ── Summary ──────────────────────────────────────────────────────────────
  stdout.writeln('');
  if (_failures == 0) {
    stdout.writeln('${_green}ALL LIVE CHECKS PASSED$_reset\n');
    exit(0);
  } else {
    stdout.writeln('$_red$_failures CHECK(S) FAILED$_reset\n');
    exit(1);
  }
}
