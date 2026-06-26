// Diagnostic: fetches a single manga detail page and dumps the structure so
// we can see what selectors to use for cover image + chapter list.
//
//   dart run tool/diagnose_demonicscans.dart Murim-Login
//
// Prints (in this order):
//   1. URL and HTTP status / length
//   2. The first 20 <img> tags with their parent context
//   3. Anything that looks like a chapter container or link
//   4. Element IDs in the document (for spotting structural changes)
//   5. The full HTML to stdout in a delimited block so it can be copied

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const _dim = '\x1B[2m';
const _bold = '\x1B[1m';
const _cyan = '\x1B[36m';
const _reset = '\x1B[0m';

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
      },
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  stdout.writeln('${_bold}GET $url$_reset');
  final resp = await dio.get<String>(
    url,
    options: Options(responseType: ResponseType.plain),
  );
  final html = resp.data ?? '';
  stdout.writeln('Status: ${resp.statusCode}, Length: ${html.length} bytes\n');

  final doc = html_parser.parse(html);

  // 1. First 25 images
  stdout.writeln('$_cyan── IMAGES (first 25) ──$_reset');
  final imgs = doc.querySelectorAll('img');
  for (var i = 0; i < imgs.length && i < 25; i++) {
    final img = imgs[i];
    final src = img.attributes['src'] ?? '';
    final dataSrc = img.attributes['data-src'] ?? '';
    final cls = img.attributes['class'] ?? '';
    final parent = img.parent;
    final parentTag = parent != null
        ? '<${parent.localName}${_attrSummary(parent)}>'
        : '(no parent)';
    stdout.writeln('  [$i] $parentTag <img'
        '${cls.isNotEmpty ? ' class="$cls"' : ''}'
        ' src="$src"'
        '${dataSrc.isNotEmpty ? ' data-src="$dataSrc"' : ''}>');
  }
  stdout.writeln('  $_dim(${imgs.length} total)$_reset\n');

  // 2. Anything chapter-shaped
  stdout.writeln('$_cyan── CHAPTER-SHAPED ELEMENTS ──$_reset');
  final chapterCandidates = <dom.Element>{
    ...doc.querySelectorAll('[id*="chapter" i]'),
    ...doc.querySelectorAll('[class*="chapter" i]'),
    ...doc.querySelectorAll('[id*="chap" i]'),
    ...doc.querySelectorAll('[class*="chp" i]'),
    ...doc.querySelectorAll('a[href*="chapter" i]'),
  };
  final shown = <String>{};
  var count = 0;
  for (final el in chapterCandidates) {
    if (count >= 30) break;
    final key =
        '${el.localName}|${el.id}|${el.attributes['class']}|${el.attributes['href']}';
    if (!shown.add(key)) continue;
    final href = el.attributes['href'] ?? '';
    final text = el.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;
    stdout.writeln('  <${el.localName}${_attrSummary(el)}>'
        '${href.isNotEmpty ? ' href="$href"' : ''}'
        '${preview.isNotEmpty ? ' :: "$preview"' : ''}');
    count++;
  }
  stdout.writeln('  $_dim(${chapterCandidates.length} candidates)$_reset\n');

  // 3. All element IDs (helps spot rename like "chapters-list" → "chapter-list")
  stdout.writeln('$_cyan── ELEMENT IDs ──$_reset');
  final ids = doc
      .querySelectorAll('[id]')
      .map((e) => '${e.localName}#${e.id}')
      .toSet()
      .toList()
    ..sort();
  stdout.writeln('  ${ids.join(', ')}\n');

  // 4. Check selectors (both old strict and new relaxed)
  stdout.writeln('$_cyan── SELECTOR PROBES ──$_reset');
  _probe(doc, 'h1.big-fat-titles');
  _probe(doc, 'div#manga-page > img'); // OLD (strict direct-child)
  _probe(doc, 'div#manga-page img'); // NEW (any descendant)
  _probe(doc, 'div#manga-info-stats');
  _probe(doc, 'div#chapters-list > a.chplinks'); // OLD
  _probe(doc, 'div#chapters-list a.chplinks'); // NEW
  _probe(doc, 'div#chapters-list a');
  _probe(doc, 'a.chplinks');
  stdout.writeln('');

  // 5. Full HTML for offline inspection (between markers)
  stdout.writeln('$_cyan── FULL HTML ──$_reset');
  stdout.writeln('<<<HTML_BEGIN>>>');
  stdout.writeln(html);
  stdout.writeln('<<<HTML_END>>>');
}

String _attrSummary(dom.Element el) {
  final id = el.id;
  final cls = el.attributes['class'];
  final buf = StringBuffer();
  if (id.isNotEmpty) buf.write(' id="$id"');
  if (cls != null && cls.isNotEmpty) buf.write(' class="$cls"');
  return buf.toString();
}

void _probe(dom.Document doc, String selector) {
  final matches = doc.querySelectorAll(selector);
  stdout.writeln('  $selector → ${matches.length} matches');
}
