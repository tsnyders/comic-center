import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/download_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/providers/database_provider.dart';
import 'package:comic_center/core/providers/download_provider.dart';
import 'package:comic_center/core/providers/library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

Future<void> _initializeLocalIsar() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final decoded = jsonDecode(await config.readAsString()) as Map<String, Object?>;
  final packages = decoded['packages'] as List<dynamic>;
  final libs = packages.cast<Map<String, dynamic>>().firstWhere(
        (package) => package['name'] == 'isar_flutter_libs',
      );
  final root = config.uri.resolve(libs['rootUri'] as String).toFilePath();
  final library = Platform.isWindows
      ? File('$root/windows/isar.dll')
      : Platform.isLinux
          ? File('$root/linux/libisar.so')
          : File('$root/macos/libisar.dylib');
  await Isar.initializeIsarCore(libraries: {Abi.current(): library.path});
}

ChapterEntry _ch(int id, double? number, {bool read = false}) => ChapterEntry()
  ..id = id
  ..mangaId = 1
  ..sourceChapterId = '$id'
  ..title = 'Ch $id'
  ..number = number
  ..isRead = read
  ..lastPageRead = read ? 0 : 3;

void main() {
  late Directory dir;
  late Isar isar;
  late ProviderContainer container;

  setUpAll(_initializeLocalIsar);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yomi_chapter_actions_');
    isar = await Isar.open(
        [MangaEntrySchema, ChapterEntrySchema, DownloadEntrySchema],
        directory: dir.path, name: 'chapter_actions', inspector: false);
    await isar.writeTxn(() async {
      await isar.mangaEntrys.put(MangaEntry()
        ..id = 1
        ..title = 'T'
        ..sourceKey = 'src::1'
        ..sourceId = 'src'
        ..sourceMangaId = '1'
        ..sourceUrl = ''
        ..inLibrary = true
        ..chapterCount = 5
        ..unreadCount = 3);
      await isar.chapterEntrys.putAll([
        _ch(1, 1, read: true),
        _ch(2, 2),
        _ch(3, 3),
        _ch(4, 4),
        _ch(5, null),
      ]);
    });
    container =
        ProviderContainer(overrides: [isarProvider.overrideWithValue(isar)]);
  });
  tearDown(() async {
    container.dispose();
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  test('markPreviousChaptersRead reads lower numbers only and recounts',
      () async {
    await container
        .read(libraryNotifierProvider.notifier)
        .markPreviousChaptersRead(1, 4);
    final read = (await isar.chapterEntrys.filter().isReadEqualTo(true).findAll())
        .map((c) => c.id)
        .toSet();
    expect(read, {1, 2, 3});
    expect((await isar.mangaEntrys.get(1))!.unreadCount, 2);
  });

  test('markChapterUnread clears progress and recounts', () async {
    await container.read(libraryNotifierProvider.notifier).markChapterUnread(1, 1);
    final ch = (await isar.chapterEntrys.get(1))!;
    expect(ch.isRead, isFalse);
    expect(ch.readAt, isNull);
    expect(ch.lastPageRead, 0);
    expect((await isar.mangaEntrys.get(1))!.unreadCount, 5);
  });

  test('deleteChapterDownload removes files, queue record and chapter state',
      () async {
    final files = Directory('${dir.path}/dl/1/2')..createSync(recursive: true);
    File('${files.path}/page_0000.jpg').writeAsBytesSync(const [1]);
    await isar.writeTxn(() async {
      final ch = (await isar.chapterEntrys.get(2))!
        ..isDownloaded = true
        ..downloadPath = files.path
        ..pageCount = 1;
      await isar.chapterEntrys.put(ch);
      await isar.downloadEntrys.put(DownloadEntry()
        ..chapterId = 2
        ..mangaId = 1
        ..mangaTitle = 'T'
        ..chapterTitle = 'Ch 2'
        ..chapterNumber = 2
        ..status = DownloadStatus.completed);
    });

    await container
        .read(downloadManagerProvider.notifier)
        .deleteChapterDownload(2);

    final ch = (await isar.chapterEntrys.get(2))!;
    expect(ch.isDownloaded, isFalse);
    expect(ch.downloadPath, isNull);
    expect(ch.pageCount, 0);
    expect(await isar.downloadEntrys.count(), 0);
    expect(files.existsSync(), isFalse);
  });
}
