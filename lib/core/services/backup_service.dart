import 'dart:convert';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/manga_entry.dart';

// ── Backup / Restore service ──────────────────────────────────────────────────

class BackupService {
  static const _version = 1;

  // ── Export ──────────────────────────────────────────────────────────────────

  static Future<BackupFile> export({
    required Isar isar,
    required List<String> categories,
  }) async {
    final now = DateTime.now();
    final dir = await _backupDir();
    final name = 'yomi_backup_${_stamp(now)}.json';
    final file = File('${dir.path}/$name');

    final mangas =
        await isar.mangaEntrys.filter().inLibraryEqualTo(true).findAll();

    final mangaData = await Future.wait(mangas.map((m) async {
      final chapters = await isar.chapterEntrys
          .filter()
          .mangaIdEqualTo(m.id)
          .isReadEqualTo(true)
          .findAll();
      return {
        'sourceKey': m.sourceKey,
        'sourceId': m.sourceId,
        'sourceMangaId': m.sourceMangaId,
        'title': m.title,
        'coverUrl': m.coverUrl,
        'author': m.author,
        'artist': m.artist,
        'description': m.description,
        'genres': m.genres,
        'status': m.status,
        'categories': m.categories,
        'lastReadChapterId': m.lastReadChapterId,
        'lastReadChapterNumber': m.lastReadChapterNumber,
        'lastReadPage': m.lastReadPage,
        'lastReadAt': m.lastReadAt?.toIso8601String(),
        'addedToLibrary': m.addedToLibrary?.toIso8601String(),
        'readChapters': chapters
            .map((c) => {
                  'sourceChapterId': c.sourceChapterId,
                  'title': c.title,
                  'number': c.number,
                  'isRead': c.isRead,
                  'lastPageRead': c.lastPageRead,
                  'readAt': c.readAt?.toIso8601String(),
                })
            .toList(),
      };
    }));

    final payload = {
      'version': _version,
      'app': 'Yomi',
      'createdAt': now.toIso8601String(),
      'categories': categories,
      'manga': mangaData,
    };

    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return BackupFile(file: file, createdAt: now, mangaCount: mangas.length);
  }

  // ── List local backups ──────────────────────────────────────────────────────

  static Future<List<BackupFile>> listBackups() async {
    final dir = await _backupDir(create: false);
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files.map((f) => BackupFile(file: f)).toList();
  }

  // ── Restore ─────────────────────────────────────────────────────────────────

  static Future<RestoreResult> restore({
    required Isar isar,
    required File file,
  }) async {
    final raw = await file.readAsString();

    // Validate file is parseable and is the right format
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('Backup file is not valid JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup file has an unexpected structure.');
    }

    final json = decoded;

    // Version Gate
    final version = json['version'];
    if (version == null) {
      throw const FormatException('Backup file is missing the version field.');
    }
    if (version != _version) {
      throw FormatException(
          'Unsupported backup version $version (expected $_version).');
    }

    final mangaList = (json['manga'] as List?) ?? [];
    // Validate required per-item fields before touching the DB
    for (final item in mangaList) {
      final m = item as Map<String, dynamic>;
      final sourceKey = m['sourceKey'];
      if (sourceKey is! String || sourceKey.isEmpty) {
        throw const FormatException(
            'Backup contains a manga entry with a missing or empty sourceKey.');
      }
    }

    int mangaCount = 0, chapterCount = 0;

    await isar.writeTxn(() async {
      for (final item in mangaList) {
        final m = item as Map<String, dynamic>;
        final sourceKey = m['sourceKey'] as String;

        var entry = await isar.mangaEntrys
            .filter()
            .sourceKeyEqualTo(sourceKey)
            .findFirst();

        entry ??= MangaEntry()
          ..sourceKey = sourceKey
          ..sourceId = (m['sourceId'] as String?) ?? ''
          ..sourceMangaId = (m['sourceMangaId'] as String?) ?? ''
          ..sourceUrl = '';

        entry
          ..title = (m['title'] as String?) ?? 'Unknown'
          ..coverUrl = m['coverUrl'] as String?
          ..author = m['author'] as String?
          ..artist = m['artist'] as String?
          ..description = m['description'] as String?
          ..genres = (m['genres'] as List?)?.cast<String>() ?? []
          ..status = (m['status'] as String?) ?? 'unknown'
          ..inLibrary = true
          ..categories = (m['categories'] as List?)?.cast<String>() ?? []
          ..lastReadChapterId = m['lastReadChapterId'] as String?
          ..lastReadChapterNumber =
              (m['lastReadChapterNumber'] as num?)?.toDouble()
          ..lastReadPage = (m['lastReadPage'] as int?) ?? 0
          ..lastReadAt = _parseDate(m['lastReadAt'])
          ..addedToLibrary = _parseDate(m['addedToLibrary']) ?? DateTime.now()
          ..lastUpdated = DateTime.now();

        await isar.mangaEntrys.put(entry);
        mangaCount++;

        for (final ch in (m['readChapters'] as List?) ?? []) {
          final c = ch as Map<String, dynamic>;
          final sid = (c['sourceChapterId'] as String?) ?? '';

          var cEntry = await isar.chapterEntrys
              .filter()
              .mangaIdEqualTo(entry.id)
              .and()
              .sourceChapterIdEqualTo(sid)
              .findFirst();

          cEntry ??= ChapterEntry()
            ..mangaId = entry.id
            ..sourceChapterId = sid
            ..title = (c['title'] as String?) ?? ''
            ..number = (c['number'] as num?)?.toDouble();

          cEntry
            ..isRead = (c['isRead'] as bool?) ?? true
            ..lastPageRead = (c['lastPageRead'] as int?) ?? 0
            ..readAt = _parseDate(c['readAt']);

          await isar.chapterEntrys.put(cEntry);
          chapterCount++;
        }

        // Sync unread count
        final total =
            await isar.chapterEntrys.filter().mangaIdEqualTo(entry.id).count();
        final read = await isar.chapterEntrys
            .filter()
            .mangaIdEqualTo(entry.id)
            .isReadEqualTo(true)
            .count();
        entry
          ..chapterCount = total
          ..unreadCount = (total - read).clamp(0, 9999);
        await isar.mangaEntrys.put(entry);
      }
    });

    return RestoreResult(mangaCount: mangaCount, chapterCount: chapterCount);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Future<Directory> _backupDir({bool create = true}) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/backups');
    if (create && !await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _stamp(DateTime dt) =>
      '${dt.year}${_p(dt.month)}${_p(dt.day)}_${_p(dt.hour)}${_p(dt.minute)}';

  static String _p(int n) => n.toString().padLeft(2, '0');

  static DateTime? _parseDate(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;
}

// ── Data classes ──────────────────────────────────────────────────────────────

class BackupFile {
  BackupFile({required this.file, this.createdAt, this.mangaCount});
  final File file;
  final DateTime? createdAt;
  final int? mangaCount;

  String get displayName {
    final n = file.path
        .split('/')
        .last
        .replaceFirst('yomi_backup_', '')
        .replaceAll('.json', '');
    return n.replaceAll('_', '  ').trim();
  }
}

class RestoreResult {
  const RestoreResult({required this.mangaCount, required this.chapterCount});
  final int mangaCount;
  final int chapterCount;
}
