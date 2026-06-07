// Targeted DemonicScans diagnostic — focused on chapters only, no HTML dump.
//
// The previous diagnostic dumped the full ~383KB HTML which got truncated on
// upload. This one outputs only what we need (small text), and writes the raw
// HTML to a separate file so it can be uploaded as its own artifact.
//
//   dart run tool/diagnose_chapters.dart Murim-Login

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

Future<void> main(List<String> args) async {
  final slug = args.isNotEmpty ? args.join('-') : 'Murim-Login';
  final url = 'https://demonicscans.org/manga/$slug';

  final dio = Dio(
    BaseOptions(
      headers: {
        'Referer': 'https://demonicscans.org/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  print('GET $url');
  final resp = await dio.get<String>(
    url,
    options: Options(responseType: ResponseType.plain),
  );
  final html = resp.data ?? '';
  print('Status: ${resp.statusCode}, Length: ${html.length} bytes\n');

  // Always save the raw HTML for offline inspection.
  File('raw-page.html').writeAsStringSync(html);
  print('Wrote raw HTML to raw-page.html (artifact)\n');

  final doc = html_parser.parse(html);

  // 1. All unique element IDs
  print('── ALL ELEMENT IDs ──');
  final ids = doc.querySelectorAll('[id]')
      .map((e) => '${e.localName}#${e.id}')
      .toSet().toList()
    ..sort();
  for (final id in ids) print('  $id');
  print('  (${ids.length} unique)\n');

  // 2. All <a href> patterns — bucket by path prefix
  print('── LINK PATTERNS (href bucket → count, sample) ──');
  final hrefBuckets = <String, List<String>>{};
  for (final a in doc.querySelectorAll('a[href]')) {
    final href = a.attributes['href'] ?? '';
    final bucket = _bucket(href);
    hrefBuckets.putIfAbsent(bucket, () => []).add(href);
  }
  final sortedBuckets = hrefBuckets.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final e in sortedBuckets.take(20)) {
    print('  ${e.key.padRight(40)} ${e.value.length.toString().padLeft(4)}  '
        '${e.value.first}');
  }
  print('');

  // 3. Anything with "$slug" in href — chapter links would match
  print('── LINKS CONTAINING "$slug" ──');
  final mangaLinks = doc.querySelectorAll('a[href*="$slug"]');
  for (var i = 0; i < mangaLinks.length && i < 15; i++) {
    final a = mangaLinks[i];
    final href = a.attributes['href'] ?? '';
    final cls = a.attributes['class'] ?? '';
    final text = a.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final preview = text.length > 60 ? '${text.substring(0, 60)}…' : text;
    final parent = a.parent;
    final parentDesc = parent != null
        ? '${parent.localName}${_attrSummary(parent)}'
        : '?';
    print('  [$i] parent=$parentDesc');
    print('      <a${cls.isNotEmpty ? ' class="$cls"' : ''} href="$href">'
        '${preview.isNotEmpty ? ' :: "$preview"' : ''}</a>');
  }
  print('  (${mangaLinks.length} total)\n');

  // 4. Look for things that LOOK like chapter containers — anything with
  // many children of the same tag (typical chapter list pattern).
  print('── ELEMENTS WITH MANY SAME-TAG CHILDREN (≥5) ──');
  final containers = <_Container>[];
  for (final el in doc.querySelectorAll('*')) {
    final children = el.children;
    if (children.length < 5) continue;
    final firstTag = children.first.localName;
    final allSame = children.every((c) => c.localName == firstTag);
    if (!allSame) continue;
    containers.add(_Container(
      tag: el.localName ?? '?',
      id: el.id,
      cls: el.attributes['class'] ?? '',
      childTag: firstTag ?? '?',
      childCount: children.length,
      childClass: children.first.attributes['class'] ?? '',
      sampleText: children.first.text.trim().replaceAll(RegExp(r'\s+'), ' '),
    ));
  }
  containers.sort((a, b) => b.childCount.compareTo(a.childCount));
  for (final c in containers.take(20)) {
    final id = c.id.isEmpty ? '' : ' #${c.id}';
    final cls = c.cls.isEmpty ? '' : ' .${c.cls.replaceAll(' ', '.')}';
    final childCls = c.childClass.isEmpty ? '' : '.${c.childClass.replaceAll(' ', '.')}';
    final sample = c.sampleText.length > 50
        ? '${c.sampleText.substring(0, 50)}…'
        : c.sampleText;
    print('  <${c.tag}$id$cls> → ${c.childCount}× <${c.childTag}$childCls>  '
        '"$sample"');
  }
  print('');

  // 5. <script> contents — chapters may be in embedded JSON
  print('── SCRIPT TAGS (text length > 200) ──');
  final scripts = doc.querySelectorAll('script');
  for (var i = 0; i < scripts.length; i++) {
    final s = scripts[i];
    final src = s.attributes['src'] ?? '';
    final text = s.text;
    if (src.isNotEmpty) {
      print('  [$i] external: $src');
      continue;
    }
    if (text.length < 200) continue;
    // Look for chapter-related substrings
    final hasChapter = text.toLowerCase().contains('chapter');
    final hasChplinks = text.contains('chplinks');
    final hasChaptersList = text.contains('chapters-list');
    print('  [$i] inline (${text.length} bytes) '
        'chapter:$hasChapter chplinks:$hasChplinks chapters-list:$hasChaptersList');
    if (hasChapter || hasChplinks || hasChaptersList) {
      // Print a snippet near the first occurrence
      final lower = text.toLowerCase();
      var idx = lower.indexOf('chapters-list');
      if (idx < 0) idx = lower.indexOf('chplinks');
      if (idx < 0) idx = lower.indexOf('chapter');
      final start = (idx - 80).clamp(0, text.length);
      final end = (idx + 200).clamp(0, text.length);
      print('      ...${text.substring(start, end)}...');
    }
  }
  print('');

  // 6. Cover image candidates — anything with /thumbnails/ in src
  print('── COVER CANDIDATES (img src containing /thumbnails/) ──');
  for (final img in doc.querySelectorAll('img')) {
    final src = img.attributes['src'] ?? '';
    if (!src.contains('/thumbnails/') && !src.contains('/cover')) continue;
    final cls = img.attributes['class'] ?? '';
    final parent = img.parent;
    final parentDesc = parent != null
        ? '${parent.localName}${_attrSummary(parent)}'
        : '?';
    print('  parent=$parentDesc <img class="$cls" src="$src">');
  }
}

class _Container {
  _Container({
    required this.tag,
    required this.id,
    required this.cls,
    required this.childTag,
    required this.childCount,
    required this.childClass,
    required this.sampleText,
  });
  final String tag;
  final String id;
  final String cls;
  final String childTag;
  final int childCount;
  final String childClass;
  final String sampleText;
}

String _attrSummary(dom.Element el) {
  final id = el.id;
  final cls = el.attributes['class'];
  final buf = StringBuffer();
  if (id.isNotEmpty) buf.write('#$id');
  if (cls != null && cls.isNotEmpty) {
    buf.write('.${cls.split(RegExp(r"\s+")).join(".")}');
  }
  return buf.toString();
}

String _bucket(String href) {
  if (href.startsWith('#')) return '(anchor)';
  if (href.startsWith('mailto:')) return 'mailto:';
  if (href.startsWith('javascript:')) return 'javascript:';
  if (href.startsWith('http')) {
    final u = Uri.tryParse(href);
    if (u != null) {
      return '${u.host}${u.pathSegments.take(2).map((s) => '/$s').join()}';
    }
  }
  final cleaned = href.split('?').first;
  final parts = cleaned.split('/').where((p) => p.isNotEmpty).take(2).toList();
  return '/${parts.join('/')}';
}
