import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/manga_entry.dart';
import 'app_logger.dart';

// ── Backup / Restore service ──────────────────────────────────────────────────
//
// File format (v2): one JSON header line, a newline, then the body.
//   {"v":2,"enc":"pbkdf2-aes256-cbc","salt":"<b64>","iter":N,"iv":"<b64>"}
//   <base64 AES-256-CBC ciphertext of the payload JSON>
// or, when no passphrase is set:
//   {"v":2,"enc":"none"}
//   <payload JSON>
// The key is PBKDF2-HMAC-SHA256(passphrase, salt, iter), so a Drive backup can
// be restored on another device. Legacy v1 files — the per-device-key envelope
// `{"enc":true,"iv":..,"data":..}` or a bare plaintext payload — still restore.
//
// Payload: library titles + chapters, the category list, and app settings
// (SharedPreferences under [settingsPrefixes]). Per-title reader overrides are
// keyed by Isar id locally, which differs across devices, so they are exported
// under the title's sourceKey and mapped back to the local id on restore.

/// A passphrase-protected backup was opened with a wrong or missing passphrase.
class BackupPassphraseException implements Exception {
  const BackupPassphraseException();
  @override
  String toString() => 'Wrong backup passphrase.';
}

class BackupService {
  static const _version = 1;
  static const _fileVersion = 2;
  static const _keyPrefKey = 'backup.encryptionKeyB64';

  /// Mirrors backupPassphrasePrefKey in settings_provider.dart.
  static const _passphrasePrefKey = 'backup.passphrase';
  static const _encPassphrase = 'pbkdf2-aes256-cbc';
  static const pbkdf2Iterations = 100000;
  static const _maxIterations = 1000000;

  /// SharedPreferences namespaces included in a backup. `backup.` is
  /// deliberately absent: the device key and passphrase never leave the device.
  static const settingsPrefixes = [
    'reader.',
    'theme.',
    'settings.',
    'library.',
    'onboarding.',
  ];
  static const _titlePrefixes = ['reader.direction.manga.', 'reader.mode.manga.'];

  // ── Export ──────────────────────────────────────────────────────────────────

  static Future<BackupFile> export({
    required Isar isar,
    required List<String> categories,
  }) async {
    final now = DateTime.now();
    final dir = await _backupDir();
    final name = 'yomi_backup_${_stamp(now)}.json';
    final file = File('${dir.path}/$name');
    final prefs = await SharedPreferences.getInstance();

    final mangas =
        await isar.mangaEntrys.filter().inLibraryEqualTo(true).findAll();

    final mangaData = await Future.wait(mangas.map((m) async {
      final chapters =
          await isar.chapterEntrys.filter().mangaIdEqualTo(m.id).findAll();
      return {
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
        'categories': m.categories,
        'lastReadChapterId': m.lastReadChapterId,
        'lastReadChapterNumber': m.lastReadChapterNumber,
        'lastReadPage': m.lastReadPage,
        'lastReadAt': m.lastReadAt?.toIso8601String(),
        'addedToLibrary': m.addedToLibrary?.toIso8601String(),
        'chapters': chapters
            .map((c) => {
                  'sourceChapterId': c.sourceChapterId,
                  'title': c.title,
                  'number': c.number,
                  'volume': c.volume,
                  'scanlator': c.scanlator,
                  'language': c.language,
                  'uploadDate': c.uploadDate?.toIso8601String(),
                  'pageCount': c.pageCount,
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
      'settings': await _exportSettings(isar, prefs),
    };

    final plainJson = const JsonEncoder.withIndent('  ').convert(payload);
    await file.writeAsString(
        await encode(plainJson, passphrase: prefs.getString(_passphrasePrefKey)));
    return BackupFile(file: file, createdAt: now, mangaCount: mangas.length);
  }

  // ── List / prune local backups ──────────────────────────────────────────────

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

  /// Deletes local backups beyond the newest [keep].
  static Future<void> prune({int keep = 3}) async {
    for (final backup in (await listBackups()).skip(keep)) {
      await backup.file.delete();
    }
  }

  // ── Restore ─────────────────────────────────────────────────────────────────

  static Future<RestoreResult> restore({
    required Isar isar,
    required File file,
    String? passphrase,
    bool restoreSettings = true,
  }) async =>
      restorePayload(
          isar: isar,
          json: await decode(file, passphrase: passphrase),
          restoreSettings: restoreSettings);

  /// True when [file] is a v2 backup encrypted with a user passphrase.
  static Future<bool> needsPassphrase(File file) async =>
      _header(await file.readAsString())?['enc'] == _encPassphrase;

  /// Reads a Yomi backup of any version and returns its payload. Throws
  /// [BackupPassphraseException] on a wrong or missing passphrase.
  static Future<Map<String, Object?>> decode(File file,
      {String? passphrase}) async {
    final raw = await file.readAsString();
    final header = _header(raw);
    final String plain;
    if (header == null) {
      // Legacy v1: device-key envelope, or a bare plaintext payload.
      final decoded = _jsonMap(raw);
      if (decoded == null) {
        throw const FormatException('Backup file is not valid JSON');
      }
      plain = decoded['enc'] == true ? await _decryptLegacy(decoded) : raw;
    } else {
      final body = raw.substring(raw.indexOf('\n') + 1);
      switch (header['enc']) {
        case 'none':
          plain = body;
        case _encPassphrase:
          if (passphrase == null) throw const BackupPassphraseException();
          final salt = header['salt'], iv = header['iv'], iter = header['iter'];
          if (salt is! String ||
              iv is! String ||
              iter is! int ||
              iter <= 0 ||
              iter > _maxIterations) {
            throw const FormatException(
                'Encrypted backup header is incomplete.');
          }
          final key = await _deriveKey(passphrase, base64Decode(salt), iter);
          try {
            plain = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc))
                .decrypt64(body.trim(), iv: enc.IV.fromBase64(iv));
          } catch (_) {
            throw const BackupPassphraseException();
          }
        default:
          throw FormatException(
              'Unsupported backup encryption "${header['enc']}".');
      }
    }
    final json = _jsonMap(plain);
    if (json == null) {
      // AES-CBC padding accepts ~1/256 wrong keys; garbage output means the
      // passphrase was wrong, not the file.
      throw header?['enc'] == _encPassphrase
          ? const BackupPassphraseException()
          : const FormatException('Backup has an unexpected structure.');
    }
    return json;
  }

  /// Counts shown before a restore is confirmed.
  static ({int titles, int chapters, int categories, int settings}) summarize(
      Map<String, Object?> json) {
    final manga = json['manga'], categories = json['categories'];
    final settings = json['settings'];
    final list = manga is List ? manga : const [];
    return (
      titles: list.length,
      chapters: list.fold(
          0,
          (n, m) =>
              n + (m is Map<String, Object?> ? _chapters(m).length : 0)),
      categories: categories is List ? categories.length : 0,
      settings: settings is Map ? settings.length : 0,
    );
  }

  /// Merge validated metadata from Yomi or Tachiyomi. Download state is never
  /// imported, and existing local files and further reading progress survive.
  static Future<RestoreResult> restorePayload({
    required Isar isar,
    required Map<String, Object?> json,
    bool restoreSettings = true,
  }) async {
    // Version Gate
    final version = json['version'];
    if (version == null) {
      throw const FormatException('Backup file is missing the version field.');
    }
    if (version != _version) {
      throw FormatException(
          'Unsupported backup version $version (expected $_version).');
    }

    final mangaList = json['manga'];
    if (mangaList is! List) {
      throw const FormatException('Backup is missing its library entries.');
    }
    final settings = json['settings'];
    if (settings != null && settings is! Map<String, Object?>) {
      throw const FormatException('Invalid settings in backup.');
    }
    final categories = _strings(json['categories']);
    // Validate required per-item fields before touching the DB
    for (final item in mangaList) {
      if (item is! Map<String, Object?>) {
        throw const FormatException('Invalid title record in backup.');
      }
      final m = item;
      final sourceKey = m['sourceKey'];
      if (sourceKey is! String || sourceKey.isEmpty) {
        throw const FormatException(
            'Backup contains a manga entry with a missing or empty sourceKey.');
      }
      for (final key in [
        'sourceId',
        'sourceMangaId',
        'sourceUrl',
        'title',
        'coverUrl',
        'author',
        'artist',
        'description',
        'status',
        'lastReadChapterId',
        'lastReadAt',
        'addedToLibrary'
      ]) {
        if (m[key] != null && m[key] is! String) {
          throw FormatException('Invalid $key in backup.');
        }
      }
      _strings(m['categories']);
      _strings(m['genres']);
      _number(m['lastReadChapterNumber']);
      _nonnegativeInt(m['lastReadPage']);
      for (final chapter in _chapters(m)) {
        if (chapter is! Map<String, Object?> ||
            chapter['sourceChapterId'] is! String ||
            (chapter['sourceChapterId'] as String).isEmpty) {
          throw const FormatException('Invalid chapter record in backup.');
        }
        for (final key in [
          'title',
          'scanlator',
          'language',
          'uploadDate',
          'readAt'
        ]) {
          if (chapter[key] != null && chapter[key] is! String) {
            throw FormatException('Invalid chapter $key in backup.');
          }
        }
        if (chapter['isRead'] != null && chapter['isRead'] is! bool) {
          throw const FormatException('Invalid chapter read state.');
        }
        _number(chapter['number']);
        _number(chapter['volume']);
        _nonnegativeInt(chapter['lastPageRead']);
        _nonnegativeInt(chapter['pageCount']);
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

        final importedReadAt = _parseDate(m['lastReadAt']);
        final useImportedResume = entry.lastReadChapterId == null ||
            (importedReadAt != null &&
                (entry.lastReadAt == null ||
                    importedReadAt.isAfter(entry.lastReadAt!)));

        entry
          ..title = (m['title'] as String?) ?? 'Unknown'
          ..sourceUrl = (m['sourceUrl'] as String?) ?? entry.sourceUrl
          ..coverUrl = m['coverUrl'] as String? ?? entry.coverUrl
          ..author = m['author'] as String? ?? entry.author
          ..artist = m['artist'] as String? ?? entry.artist
          ..description = m['description'] as String? ?? entry.description
          ..genres = {...entry.genres, ..._strings(m['genres'])}.toList()
          ..status = (m['status'] as String?) ?? 'unknown'
          ..inLibrary = true
          ..categories =
              {...entry.categories, ..._strings(m['categories'])}.toList()
          ..addedToLibrary = entry.addedToLibrary ??
              _parseDate(m['addedToLibrary']) ??
              DateTime.now()
          ..lastUpdated = DateTime.now();
        if (useImportedResume && m['lastReadChapterId'] != null) {
          entry
            ..lastReadChapterId = m['lastReadChapterId'] as String?
            ..lastReadChapterNumber = _number(m['lastReadChapterNumber'])
            ..lastReadPage = _nonnegativeInt(m['lastReadPage'])
            ..lastReadAt = importedReadAt;
        }

        await isar.mangaEntrys.put(entry);
        mangaCount++;

        for (final ch in _chapters(m)) {
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
            ..volume = _number(c['volume']) ?? cEntry.volume
            ..scanlator = c['scanlator'] as String? ?? cEntry.scanlator
            ..language = c['language'] as String? ?? cEntry.language
            ..uploadDate = _parseDate(c['uploadDate']) ?? cEntry.uploadDate
            ..isRead = cEntry.isRead ||
                ((c['isRead'] as bool?) ?? !m.containsKey('chapters'))
            ..lastPageRead =
                _max(cEntry.lastPageRead, _nonnegativeInt(c['lastPageRead']))
            ..pageCount =
                _max(cEntry.pageCount, _nonnegativeInt(c['pageCount']))
            ..readAt = _later(cEntry.readAt, _parseDate(c['readAt']));

          if (entry.lastReadChapterId == sid) {
            entry.lastReadPage = _max(entry.lastReadPage, cEntry.lastPageRead);
          }

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

    // After the library commit so per-title overrides can find their ids.
    final settingsCount = restoreSettings && settings != null
        ? await _restoreSettings(isar, settings as Map<String, Object?>)
        : 0;

    // Re-query after the transaction commits so the log proves the rows are
    // actually persisted, not just that the txn callback ran without error.
    final persistedInLibrary =
        await isar.mangaEntrys.filter().inLibraryEqualTo(true).count();
    AppLogger.instance.info('Restore: wrote $mangaCount manga / $chapterCount '
        'chapters / $settingsCount settings; inLibrary count immediately after '
        'commit = $persistedInLibrary');

    return RestoreResult(
        mangaCount: mangaCount,
        chapterCount: chapterCount,
        settingsCount: settingsCount,
        categories: categories);
  }

  static List<String> _strings(Object? value) {
    if (value == null) return [];
    if (value is! List || value.any((v) => v is! String)) {
      throw const FormatException('Invalid text list in backup.');
    }
    return value.cast<String>();
  }

  static List<Object?> _chapters(Map<String, Object?> m) {
    final value = m['chapters'] ?? m['readChapters'] ?? const [];
    if (value is! List) {
      throw const FormatException('Invalid chapters in backup.');
    }
    return value;
  }

  static double? _number(Object? value) {
    if (value == null) return null;
    if (value is! num || !value.isFinite) {
      throw const FormatException('Invalid number in backup.');
    }
    return value.toDouble();
  }

  static int _nonnegativeInt(Object? value) {
    if (value == null) return 0;
    if (value is! int || value < 0) {
      throw const FormatException('Invalid reading position in backup.');
    }
    return value;
  }

  static int _max(int a, int b) => a > b ? a : b;
  static DateTime? _later(DateTime? a, DateTime? b) =>
      a == null || (b != null && b.isAfter(a)) ? b : a;

  // ── Settings ────────────────────────────────────────────────────────────────

  static Future<Map<String, Object?>> _exportSettings(
      Isar isar, SharedPreferences prefs) async {
    final out = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      if (!settingsPrefixes.any(key.startsWith)) continue;
      final prefix = _titlePrefix(key);
      if (prefix == null) {
        out[key] = prefs.get(key);
        continue;
      }
      final id = int.tryParse(key.substring(prefix.length));
      final manga = id == null ? null : await isar.mangaEntrys.get(id);
      if (manga != null) out['$prefix${manga.sourceKey}'] = prefs.get(key);
    }
    return out;
  }

  /// Writes only keys under [settingsPrefixes]; per-title keys are mapped from
  /// sourceKey back to the local Isar id and skipped when the title is absent.
  static Future<int> _restoreSettings(
      Isar isar, Map<String, Object?> settings) async {
    final prefs = await SharedPreferences.getInstance();
    var written = 0;
    for (final entry in settings.entries) {
      var key = entry.key;
      if (!settingsPrefixes.any(key.startsWith)) continue;
      final prefix = _titlePrefix(key);
      if (prefix != null) {
        final manga = await isar.mangaEntrys
            .filter()
            .sourceKeyEqualTo(key.substring(prefix.length))
            .findFirst();
        if (manga == null) continue;
        key = '$prefix${manga.id}';
      }
      final value = entry.value;
      final ok = await switch (value) {
        bool() => prefs.setBool(key, value),
        int() => prefs.setInt(key, value),
        double() => prefs.setDouble(key, value),
        String() => prefs.setString(key, value),
        List() when value.every((v) => v is String) =>
          prefs.setStringList(key, value.cast<String>()),
        _ => Future.value(false),
      };
      if (ok) written++;
    }
    return written;
  }

  static String? _titlePrefix(String key) {
    for (final p in _titlePrefixes) {
      if (key.startsWith(p)) return p;
    }
    return null;
  }

  // ── Encryption ──────────────────────────────────────────────────────────────

  /// Wraps [payloadJson] in the v2 file format, encrypting when [passphrase]
  /// is set.
  static Future<String> encode(String payloadJson, {String? passphrase}) async {
    if (passphrase == null) {
      return '${jsonEncode({'v': _fileVersion, 'enc': 'none'})}\n$payloadJson';
    }
    final salt = enc.IV.fromSecureRandom(16);
    final iv = enc.IV.fromSecureRandom(16);
    final key = await _deriveKey(passphrase, salt.bytes, pbkdf2Iterations);
    final data = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc))
        .encrypt(payloadJson, iv: iv)
        .base64;
    final header = jsonEncode({
      'v': _fileVersion,
      'enc': _encPassphrase,
      'salt': salt.base64,
      'iter': pbkdf2Iterations,
      'iv': iv.base64,
    });
    return '$header\n$data';
  }

  static Future<enc.Key> _deriveKey(
          String passphrase, List<int> salt, int iterations) async =>
      enc.Key(await Isolate.run(
          () => pbkdf2Sha256(utf8.encode(passphrase), salt, iterations)));

  /// PBKDF2-HMAC-SHA256 (RFC 8018 §5.2), one 32-byte block.
  static Uint8List pbkdf2Sha256(
      List<int> password, List<int> salt, int iterations) {
    final mac = Hmac(sha256, password);
    var u = mac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = mac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static Future<String> _decryptLegacy(Map<String, Object?> envelope) async {
    final ivB64 = envelope['iv'], dataB64 = envelope['data'];
    if (ivB64 is! String || dataB64 is! String) {
      throw const FormatException('Encrypted backup is missing iv/data.');
    }
    final prefs = await SharedPreferences.getInstance();
    final keyB64 = prefs.getString(_keyPrefKey);
    if (keyB64 == null) {
      throw const FormatException(
          'This backup was encrypted with a key from another device. '
          'Set a backup passphrase on that device and export again.');
    }
    final key = enc.Key.fromBase64(keyB64);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    try {
      return encrypter.decrypt64(dataB64, iv: enc.IV.fromBase64(ivB64));
    } catch (e) {
      throw FormatException(
          'Could not decrypt this backup — it may have been created on a '
          'different device. ($e)');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// The v2 header line, or null for legacy files.
  static Map<String, Object?>? _header(String raw) {
    final nl = raw.indexOf('\n');
    final header = _jsonMap(nl < 0 ? raw : raw.substring(0, nl));
    return header?['v'] == _fileVersion ? header : null;
  }

  static Map<String, Object?>? _jsonMap(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

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
  const RestoreResult(
      {required this.mangaCount,
      required this.chapterCount,
      this.settingsCount = 0,
      this.categories = const []});
  final int mangaCount;
  final int chapterCount;
  final int settingsCount;
  final List<String> categories;
}
