import 'dart:async';
import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/download_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/extensions/models/chapter_info.dart';
import 'package:comic_center/core/extensions/models/filter.dart';
import 'package:comic_center/core/extensions/models/manga_detail.dart';
import 'package:comic_center/core/extensions/models/manga_summary.dart';
import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/services/source_migration.dart';
import 'package:comic_center/core/services/downloaded_chapter_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/local_isar.dart';

class MigrationTestSource extends MangaSource {
  MigrationTestSource(
    this.id, {
    this.results = const [MangaSummary(id: 'target', title: 'Hero')],
    this.chapters = const [
      ChapterInfo(id: 'c1', title: 'One', number: 1),
      ChapterInfo(id: 'c2', title: 'Two', number: 2),
      ChapterInfo(id: 'c3', title: 'Three', number: 3),
    ],
    this.onSearch,
    this.failChapters = false,
  });
  @override
  final String id;
  List<MangaSummary> results;
  final List<ChapterInfo> chapters;
  final Future<List<MangaSummary>> Function(String)? onSearch;
  final bool failChapters;
  final queries = <String>[];
  @override
  String get name => id;
  @override
  String get baseUrl => 'https://example.invalid';
  @override
  String get language => 'en';
  @override
  String get version => '1';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders =>
      const {'Referer': 'https://example.invalid'};
  @override
  Future<List<MangaSummary>> search(String query,
      {int page = 1, List<SourceFilter> filters = const []}) async {
    queries.add(query);
    return onSearch == null ? results : await onSearch!(query);
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async => [];
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async => [];
  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async =>
      MangaDetail(id: mangaId, title: 'Hero', genres: const ['Action']);
  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    if (failChapters) throw StateError('offline');
    return chapters;
  }

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async => [];
}

MangaEntry migrationManga(int id,
        {String source = 'tachiyomi:99', String title = 'Hero'}) =>
    MangaEntry()
      ..id = id
      ..title = title
      ..sourceKey = '$source::$id'
      ..sourceId = source
      ..sourceMangaId = '$id'
      ..sourceUrl = ''
      ..inLibrary = true;

ChapterEntry _chapter(int id, double? number, {int mangaId = 1}) =>
    ChapterEntry()
      ..id = id
      ..mangaId = mangaId
      ..sourceChapterId = 'c$id'
      ..title = 'Chapter $id'
      ..number = number;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalises Latin/combining accents, annotations, punctuation and years',
      () {
    expect(normalizeMigrationTitle('HÉRO: Café (Official) Season 12 [2024]'),
        'hero cafe');
    expect(normalizeMigrationTitle('He\u0301ro — Café'), 'hero cafe');
    expect(normalizeMigrationTitle('魔王 Season 2'), '魔王');
    expect(normalizeMigrationTitle('20th Century Boys'), '20th century boys');
    expect(
        normalizeMigrationTitle('Season of the Witch'), 'season of the witch');
  });
  test('token Dice ranks equivalent, partial and unrelated titles', () {
    expect(migrationTitleSimilarity('The Hero', 'Hero, The (official)'), 1);
    expect(migrationTitleSimilarity('The Hero', 'Hero'), closeTo(2 / 3, 1e-9));
    expect(migrationTitleSimilarity('The Hero', 'Villain'), 0);
    expect(migrationTitleSimilarity('!?', ''), 0);
    expect(migrationTitleSimilarity('魔王', '王様'), 0);
  });
  test('chapter mapping merges scanlator duplicates and never mutates inputs',
      () {
    final old = [
      _chapter(1, 2)
        ..scanlator = 'A'
        ..isRead = true
        ..readAt = DateTime(2025)
        ..lastPageRead = 8,
      _chapter(2, 2)
        ..scanlator = 'B'
        ..readAt = DateTime(2026)
        ..lastPageRead = 12,
    ];
    final fresh = [
      _chapter(3, 2)..scanlator = 'A',
      _chapter(4, 2 + 0.0000005)..scanlator = 'C'
    ];
    final mapped = mapChapterState(old, fresh);
    for (final chapter in mapped) {
      expect(chapter.isRead, true);
      expect(chapter.lastPageRead, 12);
      expect(chapter.readAt, DateTime(2026));
    }
    expect(fresh.every((c) => !c.isRead && c.lastPageRead == 0), true);
    expect(old.first.lastPageRead, 8);
    expect(mapped.first.scanlator, 'A');
  });
  test(
      'missing/null/non-finite numbers do not match; destination progress stays',
      () {
    final mapped = mapChapterState([
      _chapter(1, null)..isRead = true,
      _chapter(2, 1)..isRead = true,
      _chapter(3, double.nan)..isRead = true,
    ], [
      _chapter(4, null),
      _chapter(5, 2),
      _chapter(6, 1.000002),
      _chapter(7, 1)
        ..isRead = true
        ..lastPageRead = 30
        ..readAt = DateTime(2027),
      _chapter(8, double.nan),
    ]);
    expect(mapped.map((c) => c.isRead), [false, false, false, true, false]);
    expect(mapped[3].lastPageRead, 30);
    expect(mapped[3].readAt, DateTime(2027));
  });
  test('search ranks, deduplicates, excludes self and isolates failure/timeout',
      () async {
    final manga = migrationManga(1, source: 'good', title: 'The Hero');
    final good = MigrationTestSource('good', results: const [
      MangaSummary(id: '1', title: 'The Hero'),
      MangaSummary(id: 'weak', title: 'Hero'),
      MangaSummary(id: 'exact', title: 'Héro, The (official) Season 2 (2020)'),
      MangaSummary(id: 'exact', title: 'duplicate'),
      MangaSummary(id: '', title: 'The Hero'),
    ]);
    final broken = MigrationTestSource('broken',
        onSearch: (_) async => throw StateError('offline'));
    final slow = MigrationTestSource('slow',
        onSearch: (_) => Completer<List<MangaSummary>>().future);
    final results = await findCandidates(manga, [broken, slow, good],
        perSourceTimeout: const Duration(milliseconds: 10));
    expect(results.map((c) => c.summary.id), ['exact', 'weak']);
    expect(results.first.score, 1);
    expect(good.queries, ['The Hero']);
  });
  test('search starts four workers and bounds concurrency across all sources',
      () async {
    var active = 0;
    var peak = 0;
    final sources = List.generate(
        10,
        (i) => MigrationTestSource('$i', onSearch: (_) async {
              active++;
              if (active > peak) peak = active;
              await Future<void>.delayed(const Duration(milliseconds: 10));
              active--;
              return const [MangaSummary(id: 'target', title: 'Hero')];
            }));
    expect((await findCandidates(migrationManga(1), sources)).length, 10);
    expect(peak, 4);
    expect(active, 0);
  });

  group('migrate with local Isar', () {
    late Isar isar;
    late Directory dir;
    late MangaEntry old;
    late SharedPreferences prefs;
    const target = MangaSummary(id: 'target', title: 'Hero');
    const keys = [
      'reader.direction.manga.',
      'reader.mode.manga.',
      'chapters.sort.',
      'chapters.filter.'
    ];
    setUpAll(initializeLocalIsar);
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('yomi_migration_test_');
      isar = await Isar.open(
          [MangaEntrySchema, ChapterEntrySchema, DownloadEntrySchema],
          directory: dir.path, name: 'migration', inspector: false);
      SharedPreferences.setMockInitialValues(
          {for (final key in keys) '${key}1': 1});
      prefs = await SharedPreferences.getInstance();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => dir.path);
      old = migrationManga(1)
        ..categories = ['Reading']
        ..addedToLibrary = DateTime(2020)
        ..lastReadAt = DateTime(2026)
        ..lastReadChapterId = 'c102'
        ..lastReadChapterNumber = 2
        ..lastReadPage = 7;
      await isar.writeTxn(() async {
        await isar.mangaEntrys.put(old);
        await isar.chapterEntrys.putAll([
          _chapter(101, 1)
            ..isRead = true
            ..readAt = DateTime(2025)
            ..lastPageRead = 9,
          _chapter(102, 2)..lastPageRead = 7,
          _chapter(103, null)..isRead = true,
          _chapter(104, 99),
        ]);
      });
    });
    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    Future<File> download({double? number = 2}) async {
      final folder = await Directory('${dir.path}/old-pages').create();
      final file =
          await File('${folder.path}/page_0000.jpg').writeAsBytes([1, 2, 3]);
      await isar.writeTxn(() async {
        final chapter = (await isar.chapterEntrys.get(102))!
          ..number = number
          ..isDownloaded = true
          ..downloadPath = folder.path
          ..pageCount = 1
          ..downloadedAt = DateTime(2026);
        await isar.chapterEntrys.put(chapter);
        await isar.downloadEntrys.putAll([
          DownloadEntry()
            ..id = 201
            ..mangaId = 1
            ..chapterId = 102
            ..mangaTitle = 'Hero'
            ..chapterTitle = 'Two'
            ..chapterNumber = 2
            ..status = DownloadStatus.completed
            ..downloadPath = folder.path
            ..totalPages = 1
            ..downloadedPages = 1,
          DownloadEntry()
            ..id = 202
            ..mangaId = 1
            ..chapterId = 104
            ..mangaTitle = 'Hero'
            ..chapterTitle = 'Missing'
            ..chapterNumber = 99
            ..status = DownloadStatus.pending,
        ]);
      });
      return file;
    }

    test('lists only library titles with uninstalled sources', () async {
      await isar.writeTxn(() => isar.mangaEntrys.putAll([
            migrationManga(2, source: 'installed'),
            migrationManga(3)..inLibrary = false,
          ]));
      expect(
          (await titlesNeedingMigration(isar, {'installed'})).map((m) => m.id),
          [1]);
    });
    test(
        'moves metadata, progress, downloads, queue ids and all four preferences',
        () async {
      final file = await download();
      final moved = await migrate(isar,
          from: old, to: MigrationTestSource('new'), target: target);
      expect(moved.id, isNot(old.id));
      expect(moved.sourceKey, 'new::target');
      expect(moved.inLibrary, true);
      expect(moved.genres, ['Action']);
      expect(moved.categories, ['Reading']);
      expect(moved.addedToLibrary, DateTime(2020));
      expect(moved.lastReadAt, DateTime(2026));
      expect(moved.lastReadChapterId, 'c2');
      expect(moved.lastReadChapterNumber, 2);
      expect(moved.lastReadPage, 7);
      expect(moved.chapterCount, 3);
      expect(moved.unreadCount, 2);
      final chapters = await isar.chapterEntrys
          .filter()
          .mangaIdEqualTo(moved.id)
          .sortByNumber()
          .findAll();
      expect(chapters.first.isRead, true);
      expect(chapters.first.readAt, DateTime(2025));
      expect(chapters.first.lastPageRead, 9);
      expect(chapters[1].lastPageRead, 7);
      expect(chapters[1].isDownloaded, true);
      expect(chapters[1].downloadPath, file.parent.path);
      expect(chapters[1].downloadedAt, DateTime(2026));
      expect(chapters[1].pageCount, 1);
      expect(await file.readAsBytes(), [1, 2, 3]);
      final localPages = await resolveChapterPagePaths(
          downloadPath: chapters[1].downloadPath,
          isMarkedDownloaded: chapters[1].isDownloaded,
          expectedPageCount: chapters[1].pageCount,
          fetchNetworkPages: () => throw StateError('Must stay offline'));
      expect(localPages.map((path) => File(path).uri), [file.uri]);
      final queue = await isar.downloadEntrys.where().findAll();
      expect(queue.single.id, 201);
      expect(queue.single.mangaId, moved.id);
      expect(queue.single.chapterId, chapters[1].id);
      expect(queue.single.downloadPath, file.parent.path);
      expect(await isar.mangaEntrys.get(old.id), isNull);
      expect(
          await isar.chapterEntrys.filter().mangaIdEqualTo(old.id).count(), 0);
      for (final key in keys) {
        expect(prefs.getInt('$key${moved.id}'), 1);
        expect(prefs.containsKey('$key${old.id}'), false);
      }
    });
    test(
        'merges an existing library target without regressing its progress or prefs',
        () async {
      final existing = migrationManga(2, source: 'new')
        ..sourceKey = 'new::target'
        ..sourceMangaId = 'target'
        ..categories = ['Favourite']
        ..addedToLibrary = DateTime(2019)
        ..lastReadAt = DateTime(2027)
        ..lastReadChapterId = 'c3'
        ..lastReadChapterNumber = 3
        ..lastReadPage = 20;
      await prefs.setInt('reader.mode.manga.2', 2);
      await isar.writeTxn(() async {
        await isar.mangaEntrys.put(existing);
        await isar.chapterEntrys.put(_chapter(200, 3, mangaId: 2)
          ..sourceChapterId = 'c3'
          ..isRead = true
          ..lastPageRead = 20);
      });
      final moved = await migrate(isar,
          from: old, to: MigrationTestSource('new'), target: target);
      expect(moved.id, 2);
      expect(await isar.mangaEntrys.count(), 1);
      expect(moved.categories, unorderedEquals(['Reading', 'Favourite']));
      expect(moved.addedToLibrary, DateTime(2019));
      expect(moved.lastReadAt, DateTime(2027));
      expect(moved.lastReadChapterId, 'c3');
      expect(moved.lastReadPage, 20);
      expect(moved.unreadCount, 1);
      expect(prefs.getInt('reader.mode.manga.2'), 2);
    });
    test(
        'installed-source title also migrates; discard deletes files and stale queue',
        () async {
      old.sourceId = 'installed';
      await isar.writeTxn(() => isar.mangaEntrys.put(old));
      final file = await download();
      final moved = await migrate(isar,
          from: old,
          to: MigrationTestSource('new'),
          target: target,
          keepDownloads: false);
      expect(await file.exists(), false);
      expect(await isar.downloadEntrys.count(), 0);
      expect(
          await isar.chapterEntrys.filter().isDownloadedEqualTo(true).count(),
          0);
      expect(moved.lastReadPage, 7);
      expect(moved.unreadCount, 2);
    });
    test('failed or empty chapter fetch keeps old data and preferences',
        () async {
      for (final source in [
        MigrationTestSource('failed', failChapters: true),
        MigrationTestSource('empty', chapters: [])
      ]) {
        await expectLater(migrate(isar, from: old, to: source, target: target),
            throwsStateError);
        expect(await isar.mangaEntrys.get(old.id), isNotNull);
        expect(await isar.chapterEntrys.filter().mangaIdEqualTo(old.id).count(),
            4);
        expect(prefs.getInt('reader.mode.manga.1'), 1);
      }
    });
    test(
        'unmatched downloaded chapter blocks keep; explicit discard can proceed',
        () async {
      final file = await download(number: null);
      final source = MigrationTestSource('new');
      await expectLater(migrate(isar, from: old, to: source, target: target),
          throwsStateError);
      expect(await file.exists(), true);
      expect(await isar.mangaEntrys.get(old.id), isNotNull);
      expect((await isar.downloadEntrys.get(201))!.mangaId, old.id);
      await migrate(isar,
          from: old, to: source, target: target, keepDownloads: false);
      expect(await file.exists(), false);
    });
    test(
        'scanlator duplicates share progress but only one owns the local files',
        () async {
      await download();
      final moved = await migrate(isar,
          from: old,
          to: MigrationTestSource('new', chapters: const [
            ChapterInfo(id: 'a', title: 'Two A', number: 2, scanlator: 'A'),
            ChapterInfo(id: 'b', title: 'Two B', number: 2, scanlator: 'B'),
          ]),
          target: target);
      final chapters =
          await isar.chapterEntrys.filter().mangaIdEqualTo(moved.id).findAll();
      expect(chapters.where((c) => c.isDownloaded).length, 1);
      expect(chapters.map((c) => c.lastPageRead), [7, 7]);
    });
    test('active old transfer is removed while completed downloads move',
        () async {
      final file = await download();
      await isar.writeTxn(() async {
        final row = (await isar.downloadEntrys.get(202))!
          ..status = DownloadStatus.downloading;
        await isar.downloadEntrys.put(row);
      });
      final moved = await migrate(isar,
          from: old, to: MigrationTestSource('new'), target: target);
      expect(await isar.downloadEntrys.get(202), isNull);
      expect((await isar.downloadEntrys.get(201))!.mangaId, moved.id);
      expect(await isar.mangaEntrys.get(old.id), isNull);
      expect(await file.exists(), true);
    });
  });
}
