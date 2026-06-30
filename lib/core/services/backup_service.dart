import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/manga_entry.dart';

// ── Backup / Restore service ──────────────────────────────────────────────────
//
// Backup contents are PII (full reading history) — see TODO #38. Files on
// disk are AES-256-CBC encrypted with a per-device key generated on first
// use and stored in SharedPreferences. The key never leaves the device, so
// a backup encrypted on one device CANNOT be decrypted on another — this is
// a deliberate trade-off: it stops a casual look at an exported file (the
// threat the TODO describes — a shared/stolen device) at the cost of
// cross-device portability via Drive restore. Legacy plaintext backups
// (written before this change) are still readable on restore.

class BackupService {
  static const _version = 1;
  static const _keyPrefKey = 'backup.encryptionKeyB64';

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

    final plainJson = const JsonEncoder.withIndent('  ').convert(payload);
    final envelope = await _encrypt(plainJson);
    await file.writeAsString(jsonEncode(envelope));
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

    Map<String, dynamic> json;
    if (decoded['enc'] == true) {
      final plain = await _decrypt(decoded);
      final innerDecoded = jsonDecode(plain);
      if (innerDecoded is! Map<String, dynamic>) {
        throw const FormatException(
            'Decrypted backup has an unexpected structure.');
      }
      json = innerDecoded;
    } else {
      // Legacy backup written before encryption was added — restore as-is.
      json = decoded;
    }

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

  // ── Encryption ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _encrypt(String plainText) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return {
      'enc': true,
      'iv': iv.base64,
      'data': encrypted.base64,
    };
  }

  static Future<String> _decrypt(Map<String, dynamic> envelope) async {
    final ivB64 = envelope['iv'] as String?;
    final dataB64 = envelope['data'] as String?;
    if (ivB64 == null || dataB64 == null) {
      throw const FormatException('Encrypted backup is missing iv/data.');
    }
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromBase64(ivB64);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    try {
      return encrypter.decrypt64(dataB64, iv: iv);
    } catch (e) {
      throw FormatException(
          'Could not decrypt this backup — it may have been created on a '
          'different device. ($e)');
    }
  }

  static Future<enc.Key> _getOrCreateKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyPrefKey);
    if (existing != null) return enc.Key.fromBase64(existing);
    final key = enc.Key.fromSecureRandom(32); // AES-256
    await prefs.setString(_keyPrefKey, key.base64);
    return key;
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
