import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// An offline, metadata-only Tachiyomi backup ready for Yomi's merge restore.
/// Wire tags follow the upstream models linked in docs/TACHIYOMI_IMPORT.md.
class TachiyomiBackup {
  const TachiyomiBackup._(this.manga, this.categories, this.unavailableSources,
      this.connectedSources);

  static const maxFileBytes = 32 * 1024 * 1024;
  static const maxDecodedBytes = 128 * 1024 * 1024;
  final List<Map<String, Object?>> manga;
  final List<String> categories;
  final List<String> unavailableSources;
  final Map<String, String> connectedSources;
  int get mangaCount => manga.length;
  int get chapterCount =>
      manga.fold(0, (total, item) => total + (item['chapters'] as List).length);
  Map<String, Object?> get payload => {
        'version': 1,
        'app': 'Yomi',
        'categories': categories,
        'manga': manga,
      };

  /// Keeps the selected order and the backup's order of referenced categories.
  Map<String, Object?> payloadFor(Iterable<Map<String, Object?>> selected) {
    final entries = selected.toList();
    final referenced = entries
        .expand((entry) => (entry['categories'] as List).cast<String>())
        .toSet();
    return {
      ...payload,
      'manga': entries,
      'categories': categories.where(referenced.contains).toList(),
    };
  }

  /// Accepts .tachibk / .proto.gz gzip files and uncompressed protobuf.
  /// Never reads image archives, download directories, or extension APKs.
  static TachiyomiBackup decode(List<int> input) {
    if (input.isEmpty || input.length > maxFileBytes) {
      throw const FormatException('The backup is empty or exceeds 32 MB.');
    }
    Uint8List bytes;
    if (input.length >= 2 && input[0] == 0x1f && input[1] == 0x8b) {
      final output = _BoundedSink();
      try {
        final sink = gzip.decoder.startChunkedConversion(output);
        sink.add(input);
        sink.close();
        bytes = output.bytes.takeBytes();
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException('This Tachiyomi backup is damaged.');
      }
    } else {
      bytes = Uint8List.fromList(input);
    }
    final root = _Message.read(bytes);
    final records = root.messages(1);
    if (records.isEmpty) {
      throw const FormatException(
          'No library entries found. Choose a Tachiyomi '
          '.tachibk or .proto.gz backup created with library entries included.');
    }
    final categoriesById = <int, String>{};
    final categoryNames = <String>[];
    for (final category in root.messages(2)) {
      final name = category.string(1).trim();
      if (name.isEmpty) continue;
      // Tachiyomi stored category order; recent Mihon uses explicit IDs.
      categoriesById[category.integer(3) ?? category.integer(2) ?? 0] = name;
      if (!categoryNames.contains(name)) categoryNames.add(name);
    }
    final sources = <int, String>{};
    for (final old in root.messages(100)) {
      final id = old.integer(1);
      if (id != null) sources[id] = old.string(0);
    }
    for (final source in root.messages(101)) {
      final id = source.integer(2);
      if (id != null) sources[id] = source.string(1);
    }
    final missing = <String>{};
    final connected = <String, String>{};
    final manga = <Map<String, Object?>>[];
    for (final record in records) {
      final source = record.integer(1);
      final url = record.string(2);
      if (source == null || url.trim().isEmpty) {
        throw const FormatException(
            'A backup title is missing its source or URL.');
      }
      if (record.integer(100) == 0) continue;
      final sourceName = sources[source] ?? 'Tachiyomi source $source';
      final chapters = record.messages(16);
      final mapped = _SourceMapping.forName(sourceName, url, chapters);
      final sourceId = mapped?.sourceId ?? 'tachiyomi:$source';
      final mangaId = mapped?.mangaId ?? url;
      if (mapped == null) missing.add(sourceName);
      if (mapped != null) connected[mapped.sourceId] = sourceName;
      final history = <String, int>{};
      for (final field in [102, 104]) {
        for (final h in record.messages(field)) {
          final key = h.string(field == 102 ? 0 : 1);
          final time = h.integer(field == 102 ? 1 : 2) ?? 0;
          if (time > (history[key] ?? 0)) history[key] = time;
        }
      }
      final chapterData = <Map<String, Object?>>[];
      Map<String, Object?>? resume;
      int resumeTime = -1;
      for (final c in chapters) {
        final chapterUrl = c.string(1);
        if (chapterUrl.trim().isEmpty) {
          throw const FormatException('A backup chapter is missing its URL.');
        }
        final page = c.integer(6) ?? 0;
        final number = c.float(9);
        if (page < 0 || (number != null && !number.isFinite)) {
          throw const FormatException('Invalid reading progress in backup.');
        }
        final time = history[chapterUrl] ?? 0;
        final chapter = <String, Object?>{
          'sourceChapterId': mapped?.chapterId(chapterUrl) ?? chapterUrl,
          'title': c.string(2),
          'number': number,
          'scanlator': c.optionalString(3),
          'isRead': c.integer(4) == 1,
          'lastPageRead': page,
          'readAt': _date(time),
          'uploadDate': _date(c.integer(8)),
        };
        chapterData.add(chapter);
        final touched = time > 0 || page > 0 || chapter['isRead'] == true;
        if (touched &&
            (resume == null ||
                time > resumeTime ||
                (time == resumeTime &&
                    (number ?? -1) > (resume['number'] as double? ?? -1)))) {
          resume = chapter;
          resumeTime = time;
        }
      }
      manga.add({
        'sourceKey': '$sourceId::$mangaId',
        'sourceId': sourceId,
        'sourceName': sourceName,
        'sourceMangaId': mangaId,
        'sourceUrl': url,
        'title': record.string(3).isEmpty ? 'Untitled comic' : record.string(3),
        'artist': record.optionalString(4),
        'author': record.optionalString(5),
        'description': record.optionalString(6),
        'genres': record.strings(7),
        'status': switch (record.integer(8)) {
          1 => 'ongoing',
          2 => 'completed',
          4 => 'completed',
          5 => 'cancelled',
          6 => 'hiatus',
          _ => 'unknown',
        },
        'coverUrl': record.optionalString(9),
        'addedToLibrary': _date(record.integer(13)),
        'categories': record
            .integers(17)
            .map((id) => categoriesById[id])
            .whereType<String>()
            .toSet()
            .toList(),
        'chapters': chapterData,
        'lastReadChapterId': resume?['sourceChapterId'],
        'lastReadChapterNumber': resume?['number'],
        'lastReadPage': resume?['lastPageRead'] ?? 0,
        'lastReadAt': resume?['readAt'],
      });
    }
    return TachiyomiBackup._(
        manga, categoryNames, missing.toList()..sort(), connected);
  }

  static String? _date(int? value) {
    if (value == null || value <= 0) return null;
    if (value > 8640000000000000) {
      throw const FormatException('Invalid date in backup.');
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
        .toIso8601String();
  }
}

/// Only connect sources whose identifiers can be converted losslessly.
/// Retain everything else under its original source ID, without guessing by title.
class _SourceMapping {
  const _SourceMapping(this.sourceId, this.mangaId, this.chapterId);
  final String sourceId;
  final String mangaId;
  final String? Function(String) chapterId;

  static _SourceMapping? forName(
      String name, String url, List<_Message> chapters) {
    final key = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\(en\)$'), '')
        .replaceAll(RegExp(r'[\s_-]'), '');
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final path = uri.path.replaceAll(RegExp(r'^/|/$'), '');
    String? mangaId;
    String? sourceId;
    String? Function(String) convert = _pathAndQuery;
    switch (key) {
      case 'mangapill':
        sourceId = 'mangapill_en';
        mangaId = _after(path, 'manga/');
        convert = (s) {
          final p = _pathAndQuery(s);
          return p != null && p.startsWith('chapters/') ? p : null;
        };
      case 'mangadex':
        sourceId = 'mangadex_en_v5';
        mangaId = _uuid(url);
        convert = _uuid;
      case 'readcomiconline':
        sourceId = 'readcomiconline_en';
        mangaId = _after(path, 'Comic/');
        convert = (s) {
          final p = _pathAndQuery(s);
          return p != null &&
                  p.startsWith('Comic/') &&
                  Uri.parse(p).pathSegments.length >= 3
              ? p
              : null;
        };
      case 'comicextra':
        sourceId = 'comicextra_en';
        mangaId = _after(path, 'comic/');
        convert = (s) {
          final parts = Uri.tryParse(s)
              ?.path
              .replaceFirst(RegExp(r'/full/?$'), '')
              .split('/')
              .where((s) => s.isNotEmpty)
              .toList();
          return parts != null && parts.length >= 2
              ? parts.sublist(parts.length - 2).join('/')
              : null;
        };
      case 'demonicscans':
      case 'mangademon':
        sourceId = 'demonicscans_en';
        mangaId = _after(path, 'manga/');
        convert = (s) {
          final p = _pathAndQuery(s);
          if (p == null) return null;
          if (p.startsWith('chaptered.php?')) return p;
          return _after(p, 'manga/');
        };
      case 'thunderscans':
      case 'rizzfables':
      case 'rizzcomic':
      case 'realmscans':
      case 'manhwatop':
      case 'manhuaplus':
      case 'toonily':
        sourceId = switch (key) {
          'rizzfables' || 'rizzcomic' || 'realmscans' => 'rizzfables_en',
          _ => '${key}_en',
        };
        final prefix = switch (sourceId) {
          'thunderscans_en' => 'comics/',
          'rizzfables_en' => 'series/r2311170-',
          'toonily_en' => 'serie/',
          _ => 'manga/',
        };
        mangaId = path.startsWith(prefix) && !path.substring(prefix.length).contains('/') ? path : null;
        convert = (s) {
          final p = Uri.tryParse(s)?.path.replaceAll(RegExp(r'^/|/$'), '');
          return p == null || p.isEmpty ? null : p;
        };
      case 'weebcentral':
        sourceId = 'weebcentral_en';
        mangaId = RegExp(r'^series/([A-Z0-9]{26})(?:/|$)').firstMatch(path)?.group(1);
        convert = (s) => RegExp(r'(?:^|/)chapters/([A-Z0-9]{26})(?:/|$)')
            .firstMatch(Uri.tryParse(s)?.path ?? '')?.group(1);
      case 'flamecomics':
      case 'flamescans':
        sourceId = 'flamecomics_en';
        mangaId = RegExp(r'^series/(\d+)$').firstMatch(path)?.group(1);
        convert = (s) => RegExp(r'(?:^|/)series/(\d+/[a-zA-Z0-9]+)/*$')
            .firstMatch(Uri.tryParse(s)?.path ?? '')?.group(1);
      case 'webtoon':
      case 'webtoons':
      case 'webtoons.com':
        sourceId = 'webtoons_en';
        final titleNo = uri.queryParameters['title_no'] ?? uri.queryParameters['titleNo'];
        if (titleNo != null && int.tryParse(titleNo) != null) {
          mangaId = '${path.contains('/canvas/') || path.startsWith('challenge/') ? 'canvas' : 'webtoon'}/$titleNo';
        }
      case 'mangakakalot':
      case 'natomanga':
      case 'manganato':
      case 'manganelo':
        sourceId = key == 'mangakakalot' ? 'mangakakalot_en' : 'natomanga_en';
        // Legacy numeric Manganato URLs cannot be converted to current slugs.
        mangaId = RegExp(r'^manga/([^/]+)$').firstMatch(path)?.group(1);
        convert = (s) => RegExp(r'(?:^|/)(manga/[^/]+/[^/]+)/*$')
            .firstMatch(Uri.tryParse(s)?.path ?? '')?.group(1);
    }
    if (sourceId == null ||
        mangaId == null ||
        mangaId.isEmpty ||
        chapters.any((c) => convert(c.string(1)) == null)) {
      return null;
    }
    return _SourceMapping(sourceId, mangaId, convert);
  }

  static String? _pathAndQuery(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.path.isEmpty) return null;
    return uri.path.replaceFirst(RegExp(r'^/'), '') +
        (uri.hasQuery ? '?${uri.query}' : '');
  }

  static String? _after(String path, String prefix) =>
      path.startsWith(prefix) ? path.substring(prefix.length) : null;
  static String? _uuid(String value) => RegExp(
          r'(?:^|/)([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})(?:/|\?|$)')
      .firstMatch(value)
      ?.group(1)
      ?.toLowerCase();
}

class _BoundedSink extends ByteConversionSinkBase {
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > TachiyomiBackup.maxDecodedBytes) {
      throw const FormatException('The expanded backup exceeds 128 MB.');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

// Small schema-specific protobuf reader. Unknown fields are skipped by wire
// type; int64 source IDs stay integers (never pass through floating point).
class _Message {
  _Message(this.fields);
  final Map<int, List<Object>> fields;
  static _Message read(Uint8List bytes) {
    final r = _WireReader(bytes);
    final fields = <int, List<Object>>{};
    while (!r.done) {
      final tag = r.varint();
      final field = tag >>> 3;
      final wire = tag & 7;
      final Object value;
      switch (wire) {
        case 0:
          value = r.varint();
        case 1:
          value = r.take(8); // unknown fixed64 fields
        case 2:
          value = r.take(r.varint());
        case 5:
          value = ByteData.sublistView(r.take(4)).getFloat32(0, Endian.little);
        default:
          throw const FormatException('Invalid Tachiyomi protobuf field.');
      }
      (fields[field] ??= []).add(value);
      if (fields[field]!.length > 500000) {
        throw const FormatException('Too many records in this backup.');
      }
    }
    return _Message(fields);
  }

  List<Object> _values(int n) => fields[n] ?? const [];
  int? integer(int n) {
    final values = _values(n);
    if (values.isEmpty) return null;
    if (values.last is! int) {
      throw const FormatException('Invalid integer field.');
    }
    return values.last as int;
  }

  List<int> integers(int n) => _values(n).expand((v) {
        if (v is int) return [v];
        if (v is! Uint8List) {
          throw const FormatException('Invalid category field.');
        }
        final r = _WireReader(v);
        final values = <int>[];
        while (!r.done) {
          values.add(r.varint());
        }
        return values;
      }).toList();
  double? float(int n) {
    final values = _values(n);
    if (values.isEmpty) return null;
    if (values.last is! double) {
      throw const FormatException('Invalid chapter number.');
    }
    return values.last as double;
  }

  List<String> strings(int n) => _values(n).map((v) {
        if (v is! Uint8List) throw const FormatException('Invalid text field.');
        return utf8.decode(v);
      }).toList();
  String string(int n) => optionalString(n) ?? '';
  String? optionalString(int n) {
    final values = strings(n);
    return values.isEmpty ? null : values.last;
  }

  List<_Message> messages(int n) => _values(n).map((v) {
        if (v is! Uint8List) {
          throw const FormatException('Invalid backup record.');
        }
        return _Message.read(v);
      }).toList();
}

class _WireReader {
  _WireReader(this.bytes);
  final Uint8List bytes;
  int offset = 0;
  bool get done => offset == bytes.length;
  int varint() {
    var value = 0;
    for (var shift = 0; shift < 70; shift += 7) {
      if (done) throw const FormatException('Truncated backup field.');
      final byte = bytes[offset++];
      if (shift == 63 && byte > 1) {
        throw const FormatException('Invalid 64-bit value.');
      }
      value |= (byte & 127) << shift;
      if (byte < 128) return value;
    }
    throw const FormatException('Invalid backup integer.');
  }

  Uint8List take(int length) {
    if (length < 0 || length > bytes.length - offset) {
      throw const FormatException('Truncated backup record.');
    }
    final data = Uint8List.sublistView(bytes, offset, offset + length);
    offset += length;
    return data;
  }
}
