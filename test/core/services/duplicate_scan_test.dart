import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/download_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/services/duplicate_scan.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/local_isar.dart';

MangaEntry _manga(
  int id,
  String title,
  String source, {
  bool inLibrary = true,
  int chapters = 0,
  int unread = 0,
}) =>
    MangaEntry()
      ..id = id
      ..title = title
      ..sourceKey = '$source::$id'
      ..sourceId = source
      ..sourceMangaId = '$id'
      ..sourceUrl = ''
      ..inLibrary = inLibrary
      ..chapterCount = chapters
      ..unreadCount = unread;

ChapterEntry _chapter(int id, int mangaId, double number) => ChapterEntry()
  ..id = id
  ..mangaId = mangaId
  ..sourceChapterId = 'chapter-$id'
  ..title = 'Chapter $number'
  ..number = number;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('groupDuplicates reports stable stats and honours ignore keys', () {
    final first = _manga(1, 'Héro (Official)', 'z', chapters: 10, unread: 3)
      ..addedToLibrary = DateTime(2024);
    final second = _manga(2, 'Hero', 'a', chapters: 8, unread: 2)
      ..addedToLibrary = DateTime(2023);
    final outside = _manga(3, 'Hero', 'outside', inLibrary: false);
    final unique = _manga(4, 'Other', 'other');

    final groups = groupDuplicates([first, second, outside, unique],
        downloadedCounts: {1: 4});

    expect(groups, hasLength(1));
    final group = groups.single;
    expect(group.normalizedTitle, 'hero');
    expect(group.ignoreKey, 'a::2|z::1');
    expect(group.entries.map((stats) => stats.entry.id), [2, 1]);
    expect(group.entries.map((stats) => stats.chapterCount), [8, 10]);
    expect(group.entries.map((stats) => stats.readCount), [6, 7]);
    expect(group.entries.map((stats) => stats.downloadedCount), [0, 4]);
    expect(groupDuplicates([first, second], ignoredKeys: {group.ignoreKey}),
        isEmpty);
  });

  test(
      'partitionImportEntries excludes downloads and defaults cross-source off',
      () {
    final same = _manga(1, 'Alpha', 'native');
    same.sourceKey = 'native::alpha';
    final other = _manga(2, 'Beta', 'old');
    final downloaded = _manga(3, 'Gamma', 'saved');
    const backup = <Map<String, Object?>>[
      {'title': 'Alpha', 'sourceKey': 'native::alpha'},
      {'title': 'Alpha (Official)', 'sourceKey': 'new::alpha'},
      {'title': 'Beta', 'sourceKey': 'new::beta'},
      {'title': 'Gamma', 'sourceKey': 'new::gamma'},
      {'title': 'Delta', 'sourceKey': 'new::delta'},
    ];

    final partition = partitionImportEntries(
      backup,
      libraryByNormalizedTitle:
          indexLibraryTitlesForImport([same, other, downloaded], {1, 3}),
    );

    expect(partition.excluded, [backup[1], backup[3]]);
    expect(partition.included, [backup[0], backup[2], backup[4]]);
    expect(partition.defaultUnselectedSourceKeys, {'new::beta'});
  });

  test('ignoreDuplicateKey persists a sorted, unique string list', () async {
    SharedPreferences.setMockInitialValues({
      duplicateIgnorePreferenceKey: ['z|a'],
    });
    await ignoreDuplicateKey('b|c');
    await ignoreDuplicateKey('z|a');
    expect(await loadIgnoredDuplicateKeys(), {'b|c', 'z|a'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(duplicateIgnorePreferenceKey), ['b|c', 'z|a']);
  });

  group('resolveGroup with local Isar', () {
    late Directory dir;
    late Isar isar;
    late MangaEntry keep;
    late MangaEntry discard;
    late Directory movedPages;
    late Directory deletedPages;
    late Directory existingPages;
    late DuplicateGroup group;

    setUpAll(initializeLocalIsar);
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('yomi_duplicate_test_');
      isar = await Isar.open(
        [MangaEntrySchema, ChapterEntrySchema, DownloadEntrySchema],
        directory: dir.path,
        name: 'duplicates',
        inspector: false,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => dir.path);
      SharedPreferences.setMockInitialValues({
        'reader.mode.manga.2': 2,
        'chapters.sort.1': 9,
        'chapters.sort.2': 3,
      });
      movedPages = await Directory('${dir.path}/moved').create();
      deletedPages = await Directory('${dir.path}/deleted').create();
      existingPages = await Directory('${dir.path}/existing').create();
      await File('${movedPages.path}/page_0000.jpg').writeAsBytes([1]);
      await File('${deletedPages.path}/page_0000.jpg').writeAsBytes([2]);
      await File('${existingPages.path}/page_0000.jpg').writeAsBytes([3]);

      keep = _manga(1, 'The Hero', 'keep', chapters: 2, unread: 2)
        ..categories = ['Keep']
        ..addedToLibrary = DateTime(2022)
        ..lastReadAt = DateTime(2024)
        ..lastReadChapterId = 'chapter-12'
        ..lastReadChapterNumber = 2
        ..lastReadPage = 2;
      discard = _manga(2, 'The Hero (Official)', 'old', chapters: 2, unread: 0)
        ..categories = ['Other']
        ..addedToLibrary = DateTime(2020)
        ..lastReadAt = DateTime(2025)
        ..lastReadChapterId = 'chapter-21'
        ..lastReadChapterNumber = 1
        ..lastReadPage = 7;
      final keepOne = _chapter(11, 1, 1);
      final keepTwo = _chapter(12, 1, 2)
        ..isDownloaded = true
        ..downloadPath = existingPages.path
        ..pageCount = 1;
      final oldOne = _chapter(21, 2, 1)
        ..isRead = true
        ..readAt = DateTime(2025)
        ..lastPageRead = 7
        ..isDownloaded = true
        ..downloadPath = movedPages.path
        ..pageCount = 1
        ..downloadedAt = DateTime(2025);
      final oldTwo = _chapter(22, 2, 2)
        ..isRead = true
        ..lastPageRead = 4
        ..isDownloaded = true
        ..downloadPath = deletedPages.path
        ..pageCount = 1;
      await isar.writeTxn(() async {
        await isar.mangaEntrys.putAll([keep, discard]);
        await isar.chapterEntrys.putAll([keepOne, keepTwo, oldOne, oldTwo]);
        await isar.downloadEntrys.putAll([
          DownloadEntry()
            ..id = 201
            ..chapterId = 21
            ..mangaId = 2
            ..mangaTitle = discard.title
            ..chapterTitle = oldOne.title
            ..chapterNumber = 1
            ..status = DownloadStatus.completed,
          DownloadEntry()
            ..id = 202
            ..chapterId = 22
            ..mangaId = 2
            ..mangaTitle = discard.title
            ..chapterTitle = oldTwo.title
            ..chapterNumber = 2
            ..status = DownloadStatus.completed,
          DownloadEntry()
            ..id = 203
            ..chapterId = 11
            ..mangaId = 1
            ..mangaTitle = keep.title
            ..chapterTitle = keepOne.title
            ..chapterNumber = 1
            ..status = DownloadStatus.pending,
          DownloadEntry()
            ..id = 204
            ..chapterId = 12
            ..mangaId = 1
            ..mangaTitle = keep.title
            ..chapterTitle = keepTwo.title
            ..chapterNumber = 2
            ..status = DownloadStatus.completed,
        ]);
      });
      group = groupDuplicates([keep, discard], downloadedCounts: {1: 1, 2: 2})
          .single;
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
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

    test('aborts when a downloaded chapter cannot rebind without deletion',
        () async {
      await expectLater(
        resolveGroup(isar, group: group, keep: keep, deleteDownloads: false),
        throwsA(isA<StateError>().having(
            (error) => error.message, 'message', contains('cannot be moved'))),
      );
      expect(await isar.mangaEntrys.count(), 2);
      expect(await deletedPages.exists(), true);
      expect(await isar.downloadEntrys.count(), 4);
    });

    test('merges state, rebinds free downloads and deletes only conflicts',
        () async {
      await resolveGroup(isar, group: group, keep: keep, deleteDownloads: true);

      final saved = (await isar.mangaEntrys.where().findAll()).single;
      expect(saved.id, keep.id);
      expect(saved.categories, ['Keep', 'Other']);
      expect(saved.addedToLibrary, DateTime(2020));
      expect(saved.lastReadAt, DateTime(2025));
      expect(saved.lastReadChapterId, 'chapter-11');
      expect(saved.lastReadChapterNumber, 1);
      expect(saved.lastReadPage, 7);
      expect(saved.chapterCount, 2);
      expect(saved.unreadCount, 0);

      final chapters =
          await isar.chapterEntrys.where().sortByNumber().findAll();
      expect(chapters.map((chapter) => chapter.id), [11, 12]);
      expect(chapters.every((chapter) => chapter.isRead), true);
      expect(chapters.first.lastPageRead, 7);
      expect(chapters.first.isDownloaded, true);
      expect(chapters.first.downloadPath, movedPages.path);
      expect(chapters.last.downloadPath, existingPages.path);
      expect(await movedPages.exists(), true);
      expect(await existingPages.exists(), true);
      expect(await deletedPages.exists(), false);

      final queue = await isar.downloadEntrys.where().findAll();
      expect(queue.map((download) => download.id), [201, 204]);
      expect(queue.first.mangaId, keep.id);
      expect(queue.first.chapterId, 11);
      expect(queue.first.status, DownloadStatus.completed);
      expect(await isar.chapterEntrys.filter().mangaIdEqualTo(2).count(), 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reader.mode.manga.1'), 2);
      expect(prefs.getInt('chapters.sort.1'), 9);
      expect(prefs.containsKey('reader.mode.manga.2'), false);
      expect(prefs.containsKey('chapters.sort.2'), false);
    });
  });
}
