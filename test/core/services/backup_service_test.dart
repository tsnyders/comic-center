import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/services/backup_service.dart';
import 'package:comic_center/core/services/tachiyomi_backup.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tachiyomi_backup_test.dart' show backupFixture;

/// The bundled isar_flutter_libs binary: no download, so files running in
/// parallel under `flutter test` cannot race on a half-written library.
Future<void> _initializeLocalIsar() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final decoded =
      jsonDecode(await config.readAsString()) as Map<String, Object?>;
  final packages = decoded['packages'] as List<dynamic>;
  final libs = packages
      .cast<Map<String, dynamic>>()
      .firstWhere((package) => package['name'] == 'isar_flutter_libs');
  final root = config.uri.resolve(libs['rootUri'] as String).toFilePath();
  final library = Platform.isWindows
      ? File('$root/windows/isar.dll')
      : Platform.isLinux
          ? File('$root/linux/libisar.so')
          : File('$root/macos/libisar.dylib');
  await Isar.initializeIsarCore(libraries: {Abi.current(): library.path});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Isar isar;

  setUpAll(_initializeLocalIsar);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yomi_backup_test_');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    // Isar instance names are process-wide; keep every test's unique.
    isar = await Isar.open([MangaEntrySchema, ChapterEntrySchema],
        directory: dir.path,
        name: 'backup_${DateTime.now().microsecondsSinceEpoch}',
        inspector: false);
  });
  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    // Windows releases Isar's file handles a beat after close; under a full
    // parallel `flutter test` run that beat is long enough to fail the delete.
    for (var attempt = 0;; attempt++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        if (attempt == 40) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test(
      'Tachiyomi restore persists metadata, repeat import merges and keeps downloads',
      () async {
    final backup = TachiyomiBackup.decode(backupFixture());
    final result =
        await BackupService.restorePayload(isar: isar, json: backup.payload);
    expect(result.categories, ['Reading']);
    var manga = (await isar.mangaEntrys.where().findAll()).single;
    var chapters = await isar.chapterEntrys.where().sortByNumber().findAll();
    expect(manga.chapterCount, 3);
    expect(manga.unreadCount, 2);
    expect(chapters[1].lastPageRead, 7);
    expect(
        chapters.every((c) => !c.isDownloaded && c.downloadPath == null), true);
    await isar.writeTxn(() async {
      chapters[1]
        ..lastPageRead = 15
        ..isDownloaded = true
        ..downloadPath = '/existing/local';
      await isar.chapterEntrys.put(chapters[1]);
      manga
        ..lastReadPage = 15
        ..lastReadAt = DateTime(2026)
        ..categories = ['Existing'];
      await isar.mangaEntrys.put(manga);
    });
    await BackupService.restorePayload(isar: isar, json: backup.payload);
    expect(await isar.mangaEntrys.count(), 1);
    expect(await isar.chapterEntrys.count(), 3);
    chapters = await isar.chapterEntrys.where().sortByNumber().findAll();
    manga = (await isar.mangaEntrys.where().findAll()).single;
    expect(chapters[1].lastPageRead, 15);
    expect(chapters[1].downloadPath, '/existing/local');
    expect(manga.lastReadPage, 15);
    expect(manga.categories, containsAll(['Existing', 'Reading']));
  });

  test(
      'export and restore retain partial/unread chapters without downloaded files',
      () async {
    await BackupService.restorePayload(
        isar: isar, json: TachiyomiBackup.decode(backupFixture()).payload);
    final before =
        (await isar.chapterEntrys.where().sortByNumber().findAll())[1];
    await isar.writeTxn(() async {
      before
        ..isDownloaded = true
        ..downloadPath = '/private/pages'
        ..pageCount = 20;
      await isar.chapterEntrys.put(before);
    });
    final exported =
        await BackupService.export(isar: isar, categories: ['Reading']);
    await isar.writeTxn(() async {
      await isar.clear();
    });
    final restored =
        await BackupService.restore(isar: isar, file: exported.file);
    expect(restored.categories, ['Reading']);
    final chapters = await isar.chapterEntrys.where().sortByNumber().findAll();
    expect(chapters.length, 3);
    expect(chapters[1].lastPageRead, 7);
    expect(chapters[1].isRead, false);
    expect(
        chapters.every((c) => !c.isDownloaded && c.downloadPath == null), true);
    expect((await isar.mangaEntrys.where().findAll()).single.sourceUrl,
        '/manga/123/example');
  });

  test('malformed later record cannot partially change the library', () async {
    final payload = TachiyomiBackup.decode(backupFixture()).payload;
    final records = payload['manga'] as List<Map<String, Object?>>;
    records.add({'sourceKey': 'broken', 'title': 42});
    await expectLater(BackupService.restorePayload(isar: isar, json: payload),
        throwsFormatException);
    expect(await isar.mangaEntrys.count(), 0);
    expect(await isar.chapterEntrys.count(), 0);
  });

  test('legacy Yomi readChapters backups remain readable', () async {
    final file = File('${dir.path}/old.json');
    await file.writeAsString(jsonEncode({
      'version': 1,
      'manga': [
        {
          'sourceKey': 'old::a',
          'sourceId': 'old',
          'sourceMangaId': 'a',
          'title': 'Old title',
          'readChapters': [
            {
              'sourceChapterId': 'c1',
              'title': 'Chapter 1',
              'number': 1,
              'isRead': true,
              'lastPageRead': 4,
            }
          ],
        }
      ],
    }));
    await BackupService.restore(isar: isar, file: file);
    expect((await isar.chapterEntrys.where().findAll()).single.isRead, true);
  });

  test('PBKDF2-HMAC-SHA256 matches the reference vectors', () {
    String hex(List<int> bytes) =>
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final password = utf8.encode('password'), salt = utf8.encode('salt');
    expect(hex(BackupService.pbkdf2Sha256(password, salt, 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    expect(hex(BackupService.pbkdf2Sha256(password, salt, 2)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
  });

  test('passphrase backup round-trips and rejects a wrong passphrase',
      () async {
    await BackupService.restorePayload(
        isar: isar, json: TachiyomiBackup.decode(backupFixture()).payload);
    SharedPreferences.setMockInitialValues({'backup.passphrase': 'correct horse'});
    final exported =
        await BackupService.export(isar: isar, categories: ['Reading']);
    final header = (await exported.file.readAsString()).split('\n').first;
    expect(header, contains('"enc":"pbkdf2-aes256-cbc"'));
    expect(header, isNot(contains('correct horse')));
    expect(await BackupService.needsPassphrase(exported.file), true);
    await isar.writeTxn(() => isar.clear());

    await expectLater(
        BackupService.restore(
            isar: isar, file: exported.file, passphrase: 'battery staple'),
        throwsA(isA<BackupPassphraseException>()));
    await expectLater(BackupService.restore(isar: isar, file: exported.file),
        throwsA(isA<BackupPassphraseException>()));
    expect(await isar.mangaEntrys.count(), 0);

    final restored = await BackupService.restore(
        isar: isar, file: exported.file, passphrase: 'correct horse');
    expect(restored.mangaCount, 1);
    expect(restored.categories, ['Reading']);
    expect(await isar.chapterEntrys.count(), 3);
  });

  test('unencrypted v2 export and legacy device-key backups still restore',
      () async {
    await BackupService.restorePayload(
        isar: isar, json: TachiyomiBackup.decode(backupFixture()).payload);
    final exported = await BackupService.export(isar: isar, categories: []);
    expect((await exported.file.readAsString()).split('\n').first,
        '{"v":2,"enc":"none"}');
    expect(await BackupService.needsPassphrase(exported.file), false);
    await isar.writeTxn(() => isar.clear());
    expect((await BackupService.restore(isar: isar, file: exported.file))
        .mangaCount, 1);

    final key = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(16);
    SharedPreferences.setMockInitialValues(
        {'backup.encryptionKeyB64': key.base64});
    final payload = jsonEncode({
      'version': 1,
      'manga': [
        {
          'sourceKey': 'old::b',
          'title': 'Old',
          'chapters': [
            {'sourceChapterId': 'c1', 'isRead': true}
          ],
        }
      ],
    });
    final data = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc))
        .encrypt(payload, iv: iv)
        .base64;
    final legacy = File('${dir.path}/v1.json');
    await legacy
        .writeAsString(jsonEncode({'enc': true, 'iv': iv.base64, 'data': data}));
    expect(await BackupService.needsPassphrase(legacy), false);
    await BackupService.restore(isar: isar, file: legacy);
    expect(
        await isar.mangaEntrys.filter().sourceKeyEqualTo('old::b').count(), 1);
  });

  test('settings round-trip remaps per-title overrides by sourceKey',
      () async {
    await BackupService.restorePayload(
        isar: isar, json: TachiyomiBackup.decode(backupFixture()).payload);
    final title = (await isar.mangaEntrys.where().findAll()).single;
    SharedPreferences.setMockInitialValues({
      'reader.direction': 1,
      'theme.look': 2,
      'onboarding.genres': ['Action'],
      'reader.direction.manga.${title.id}': 3,
      'reader.mode.manga.999': 0, // no such title: dropped
      'backup.encryptionKeyB64': 'secret', // never exported
      'other.key': true,
    });
    final exported = await BackupService.export(isar: isar, categories: []);
    final json = await BackupService.decode(exported.file);
    expect(json['settings'], {
      'reader.direction': 1,
      'theme.look': 2,
      'onboarding.genres': ['Action'],
      'reader.direction.manga.${title.sourceKey}': 3,
    });
    expect(BackupService.summarize(json),
        (titles: 1, chapters: 3, categories: 0, settings: 4));

    // A new device gives the same title a different Isar id.
    await isar.writeTxn(() => isar.clear());
    await isar.writeTxn(() => isar.mangaEntrys.put(MangaEntry()
      ..sourceKey = 'filler::x'
      ..sourceId = 'filler'
      ..sourceMangaId = 'x'
      ..sourceUrl = ''
      ..title = 'Filler'));
    SharedPreferences.setMockInitialValues({'reader.direction': 0});
    final result = await BackupService.restore(isar: isar, file: exported.file);
    expect(result.settingsCount, 4);
    final newId = (await isar.mangaEntrys
            .filter()
            .sourceKeyEqualTo(title.sourceKey)
            .findFirst())!
        .id;
    expect(newId, isNot(title.id));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('reader.direction.manga.$newId'), 3);
    expect(prefs.getInt('reader.direction'), 1);
    expect(prefs.getStringList('onboarding.genres'), ['Action']);
    expect(prefs.getKeys(), isNot(contains('other.key')));

    SharedPreferences.setMockInitialValues({});
    await BackupService.restore(
        isar: isar, file: exported.file, restoreSettings: false);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('prune keeps the newest three local backups', () async {
    final backups = Directory('${dir.path}/backups')..createSync();
    for (final stamp in [
      '20260101_0900',
      '20260102_0900',
      '20260103_0900',
      '20260104_0900'
    ]) {
      File('${backups.path}/yomi_backup_$stamp.json').writeAsStringSync('{}');
    }
    await BackupService.prune();
    expect(
        (await BackupService.listBackups())
            .map((b) => b.file.uri.pathSegments.last),
        [
          'yomi_backup_20260104_0900.json',
          'yomi_backup_20260103_0900.json',
          'yomi_backup_20260102_0900.json',
        ]);
  });
}
