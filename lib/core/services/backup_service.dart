import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/manga_entry.dart';

class BackupService {
  static Future<File> export(Isar isar) async {
    final mangas = await isar.mangaEntrys
        .filter()
        .inLibraryEqualTo(true)
        .findAll();

    final mangaIds = mangas.map((m) => m.id).toList();
    List<ChapterEntry> chapters = [];
    for (final id in mangaIds) {
      final chs = await isar.chapterEntrys
          .filter()
          .mangaIdEqualTo(id)
          .findAll();
      chapters.addAll(chs);
    }

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'mangas': mangas.map(_mangaToMap).toList(),
      'chapters': chapters.map(_chapterToMap).toList(),
    };

    final json = jsonEncode(data);
    final compressed = GZipEncoder().encode(utf8.encode(json))!;

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/yomi_backup_$ts.json.gz');
    await file.writeAsBytes(compressed);
    return file;
  }

  static Future<void> restore(Isar isar, File file) async {
    final compressed = await file.readAsBytes();
    final json = utf8.decode(GZipDecoder().decodeBytes(compressed));
    final data = jsonDecode(json) as Map<String, dynamic>;

    final mangas = (data['mangas'] as List)
        .map((m) => _mangaFromMap(m as Map<String, dynamic>))
        .toList();
    final chapters = (data['chapters'] as List)
        .map((c) => _chapterFromMap(c as Map<String, dynamic>))
        .toList();

    await isar.writeTxn(() async {
      await isar.mangaEntrys.putAll(mangas);
      await isar.chapterEntrys.putAll(chapters);
    });
  }

  static Map<String, dynamic> _mangaToMap(MangaEntry m) => {
        'id': m.id,
        'sourceKey': m.sourceKey,
        'sourceId': m.sourceId,
        'sourceMangaId': m.sourceMangaId,
        'sourceUrl': m.sourceUrl,
        'title': m.title,
        'coverUrl': m.coverUrl,
        'author': m.author,
        'artist': m.artist,
        'description': m.description,
        'genres': m.genres,
        'status': m.status,
        'inLibrary': m.inLibrary,
        'chapterCount': m.chapterCount,
        'unreadCount': m.unreadCount,
        'categories': m.categories,
        'addedToLibrary': m.addedToLibrary?.toIso8601String(),
        'lastUpdated': m.lastUpdated?.toIso8601String(),
        'lastReadAt': m.lastReadAt?.toIso8601String(),
        'lastReadChapterId': m.lastReadChapterId,
        'lastReadChapterNumber': m.lastReadChapterNumber,
        'lastReadPage': m.lastReadPage,
      };

  static Map<String, dynamic> _chapterToMap(ChapterEntry c) => {
        'id': c.id,
        'mangaId': c.mangaId,
        'sourceChapterId': c.sourceChapterId,
        'title': c.title,
        'number': c.number,
        'volume': c.volume,
        'scanlator': c.scanlator,
        'language': c.language,
        'isRead': c.isRead,
        'lastPageRead': c.lastPageRead,
        'pageCount': c.pageCount,
        'uploadDate': c.uploadDate?.toIso8601String(),
        'readAt': c.readAt?.toIso8601String(),
      };

  static MangaEntry _mangaFromMap(Map<String, dynamic> m) => MangaEntry()
    ..id = m['id'] as int
    ..sourceKey = m['sourceKey'] as String
    ..sourceId = m['sourceId'] as String
    ..sourceMangaId = m['sourceMangaId'] as String
    ..sourceUrl = m['sourceUrl'] as String? ?? ''
    ..title = m['title'] as String
    ..coverUrl = m['coverUrl'] as String?
    ..author = m['author'] as String?
    ..artist = m['artist'] as String?
    ..description = m['description'] as String?
    ..genres = (m['genres'] as List?)?.cast<String>() ?? []
    ..status = m['status'] as String? ?? 'unknown'
    ..inLibrary = m['inLibrary'] as bool? ?? true
    ..chapterCount = m['chapterCount'] as int? ?? 0
    ..unreadCount = m['unreadCount'] as int? ?? 0
    ..categories = (m['categories'] as List?)?.cast<String>() ?? []
    ..addedToLibrary = m['addedToLibrary'] != null
        ? DateTime.parse(m['addedToLibrary'] as String)
        : null
    ..lastUpdated = m['lastUpdated'] != null
        ? DateTime.parse(m['lastUpdated'] as String)
        : null
    ..lastReadAt = m['lastReadAt'] != null
        ? DateTime.parse(m['lastReadAt'] as String)
        : null
    ..lastReadChapterId = m['lastReadChapterId'] as String?
    ..lastReadChapterNumber =
        (m['lastReadChapterNumber'] as num?)?.toDouble()
    ..lastReadPage = m['lastReadPage'] as int? ?? 0;

  static ChapterEntry _chapterFromMap(Map<String, dynamic> c) =>
      ChapterEntry()
        ..id = c['id'] as int
        ..mangaId = c['mangaId'] as int
        ..sourceChapterId = c['sourceChapterId'] as String
        ..title = c['title'] as String
        ..number = (c['number'] as num?)?.toDouble()
        ..volume = (c['volume'] as num?)?.toDouble()
        ..scanlator = c['scanlator'] as String?
        ..language = c['language'] as String?
        ..isRead = c['isRead'] as bool? ?? false
        ..isDownloaded = false
        ..lastPageRead = c['lastPageRead'] as int? ?? 0
        ..pageCount = c['pageCount'] as int? ?? 0
        ..uploadDate = c['uploadDate'] != null
            ? DateTime.parse(c['uploadDate'] as String)
            : null
        ..readAt = c['readAt'] != null
            ? DateTime.parse(c['readAt'] as String)
            : null;
}
