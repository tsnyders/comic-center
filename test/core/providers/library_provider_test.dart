import 'dart:ffi';
import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/providers/database_provider.dart';
import 'package:comic_center/core/providers/library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

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
    dir = await Directory.systemTemp.createTemp('yomi_progress_test_');
    isar = await Isar.open([MangaEntrySchema, ChapterEntrySchema],
        directory: dir.path, name: 'progress', inspector: false);
  });
  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  test('saveChapterProgress stores the page without marking the chapter read',
      () async {
    final manga = MangaEntry()
      ..title = 'Title'
      ..sourceKey = 'src::1'
      ..sourceId = 'src'
      ..sourceMangaId = '1'
      ..sourceUrl = ''
      ..inLibrary = true;
    final chapter = ChapterEntry()
      ..sourceChapterId = 'c7'
      ..title = 'Chapter 7'
      ..number = 7;
    late int mangaId;
    late int chapterId;
    await isar.writeTxn(() async {
      mangaId = await isar.mangaEntrys.put(manga);
      chapter.mangaId = mangaId;
      chapterId = await isar.chapterEntrys.put(chapter);
    });
    final container =
        ProviderContainer(overrides: [isarProvider.overrideWithValue(isar)]);
    addTearDown(container.dispose);

    await container
        .read(libraryNotifierProvider.notifier)
        .saveChapterProgress(mangaId: mangaId, chapterId: chapterId, page: 20);

    final savedChapter = (await isar.chapterEntrys.get(chapterId))!;
    expect(savedChapter.lastPageRead, 20);
    expect(savedChapter.isRead, isFalse);
    final savedManga = (await isar.mangaEntrys.get(mangaId))!;
    expect(savedManga.lastReadPage, 20);
    expect(savedManga.lastReadChapterId, 'c7');
    expect(savedManga.lastReadChapterNumber, 7);
    expect(savedManga.lastReadAt, isNotNull);
  });
}
