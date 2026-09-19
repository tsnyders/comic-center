import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/services/backup_service.dart';
import 'package:comic_center/core/services/tachiyomi_backup.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tachiyomi_backup_test.dart' show backupFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Isar isar;

  setUpAll(() async {
    final local = File('build/windows/x64/runner/Debug/isar.dll');
    await Isar.initializeIsarCore(
        libraries:
            local.existsSync() ? {Abi.windowsX64: local.absolute.path} : {},
        download: true);
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yomi_backup_test_');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    isar = await Isar.open([MangaEntrySchema, ChapterEntrySchema],
        directory: dir.path, name: 'backup', inspector: false);
  });
  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
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
}
