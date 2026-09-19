import 'dart:ffi';
import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/download_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/services/download_enqueue.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    dir = await Directory.systemTemp.createTemp('yomi_download_enqueue_test_');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    isar = await Isar.open(
        [MangaEntrySchema, ChapterEntrySchema, DownloadEntrySchema],
        directory: dir.path, name: 'download_enqueue', inspector: false);
    await isar.writeTxn(() => isar.mangaEntrys.put(MangaEntry()
      ..id = 1
      ..title = 'Title'
      ..sourceKey = 'src::1'
      ..sourceId = 'src'
      ..sourceMangaId = '1'
      ..sourceUrl = ''));
  });
  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  ChapterEntry chapter(int id, double number,
          {bool read = false, bool downloaded = false}) =>
      ChapterEntry()
        ..id = id
        ..mangaId = 1
        ..sourceChapterId = 'c$id'
        ..title = 'Chapter $id'
        ..number = number
        ..isRead = read
        ..isDownloaded = downloaded;

  DownloadEntry record(int chapterId, String status) => DownloadEntry()
    ..chapterId = chapterId
    ..mangaId = 1
    ..mangaTitle = 'Title'
    ..chapterTitle = 'Chapter $chapterId'
    ..chapterNumber = chapterId.toDouble()
    ..status = status
    ..queuedAt = DateTime(2026);

  Future<List<int>> pendingChapterIds() async => [
        for (final entry in await isar.downloadEntrys
            .filter()
            .statusEqualTo(DownloadStatus.pending)
            .sortByQueuedAt()
            .findAll())
          entry.chapterId,
      ];

  test('enqueueNewChapters dedupes against downloaded and queued chapters',
      () async {
    await isar.writeTxn(() async {
      await isar.chapterEntrys.putAll([
        chapter(1, 1),
        chapter(2, 2, downloaded: true),
        chapter(3, 3),
        chapter(4, 4),
        chapter(5, 5),
      ]);
      await isar.downloadEntrys.putAll([
        record(3, DownloadStatus.downloading),
        record(4, DownloadStatus.failed)..errorMessage = 'boom',
      ]);
    });

    expect(
      await enqueueNewChapters(isar, mangaId: 1, chapterIds: [1, 2, 3, 4, 5, 99]),
      3,
      reason: '1 and 5 are new, 4 is re-queued from failed',
    );
    expect(await pendingChapterIds(), [1, 4, 5]);
    expect(await isar.downloadEntrys.count(), 4);
    final retried =
        await isar.downloadEntrys.filter().chapterIdEqualTo(4).findFirst();
    expect(retried?.errorMessage, isNull);

    expect(
      await enqueueNewChapters(isar, mangaId: 1, chapterIds: [1, 2, 3, 4, 5]),
      0,
      reason: 'second call is a no-op',
    );
    expect(await isar.downloadEntrys.count(), 4);
  });

  test('enqueueAhead queues the next N unread, undownloaded chapters by number',
      () async {
    await isar.writeTxn(() => isar.chapterEntrys.putAll([
          chapter(7, 7),
          chapter(6, 6),
          chapter(4, 4, read: true),
          chapter(3, 3, downloaded: true),
          chapter(2, 2),
          chapter(1, 1),
          chapter(5, 5),
        ]));

    await enqueueAhead(isar, mangaId: 1, currentChapterId: 2);
    expect(await isar.downloadEntrys.count(), 0, reason: 'off by default');

    await (await SharedPreferences.getInstance())
        .setInt(downloadAheadPrefKey, 2);
    await enqueueAhead(isar, mangaId: 1, currentChapterId: 2);
    expect(await pendingChapterIds(), [5, 6]);
  });

  test('deleteReadDownloads removes files and state only when enabled',
      () async {
    final readDir = Directory('${dir.path}/downloads/1/1')
      ..createSync(recursive: true);
    File('${readDir.path}/page_0000.jpg').writeAsBytesSync(const [1]);
    final unreadDir = Directory('${dir.path}/downloads/1/2')
      ..createSync(recursive: true);
    await isar.writeTxn(() async {
      await isar.chapterEntrys.putAll([
        chapter(1, 1, read: true, downloaded: true)
          ..downloadPath = readDir.path
          ..pageCount = 1,
        chapter(2, 2, downloaded: true)
          ..downloadPath = unreadDir.path
          ..pageCount = 1,
      ]);
      await isar.downloadEntrys.put(record(1, DownloadStatus.completed));
    });

    await deleteReadDownloads(isar, 1);
    expect(readDir.existsSync(), isTrue, reason: 'off by default');

    await (await SharedPreferences.getInstance())
        .setBool(removeAfterReadPrefKey, true);
    await deleteReadDownloads(isar, 1);
    expect(readDir.existsSync(), isFalse);
    expect(unreadDir.existsSync(), isTrue);
    final read = (await isar.chapterEntrys.get(1))!;
    expect(read.isDownloaded, isFalse);
    expect(read.downloadPath, isNull);
    expect(read.pageCount, 0);
    expect((await isar.chapterEntrys.get(2))!.isDownloaded, isTrue);
    expect(await isar.downloadEntrys.count(), 0);
  });
}
