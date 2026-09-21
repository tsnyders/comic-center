import 'dart:io';

import 'package:comic_center/core/browser/browser_fetch.dart';
import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/download_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/extensions/extension_factory.dart';
import 'package:comic_center/core/extensions/sources/mangapill_source.dart';
import 'package:comic_center/core/services/download_background_service.dart';
import 'package:comic_center/core/services/download_page_preparer.dart';
import 'package:comic_center/core/services/downloaded_chapter_files.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../support/fake_browser_fetch.dart';
import '../../support/local_isar.dart';

class _ImageAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromBytes([1, 2, 3], 200);
  }

  @override
  void close({bool force = false}) {}
}

class _HttpPageSource extends MangaPillSource {
  int pageCalls = 0;
  bool fail = false;

  @override
  Future<List<String>> fetchPageUrls(String chapterId) async {
    pageCalls++;
    if (fail) throw StateError('Page discovery failed');
    return ['https://images.example.test/$chapterId.jpg'];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Isar isar;
  late BrowserFetch previousBrowser;
  late _ImageAdapter adapter;
  late DownloadQueueProcessor worker;
  late _HttpPageSource httpSource;
  late Dio dio;

  setUpAll(initializeLocalIsar);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yomi_queue_processor_');
    isar = await Isar.open(
      [MangaEntrySchema, ChapterEntrySchema, DownloadEntrySchema],
      directory: directory.path,
      name: 'queue_processor',
      inspector: false,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path);
    previousBrowser = BrowserFetch.instance;
    BrowserFetch.instance = const UnavailableBrowserFetch();
    adapter = _ImageAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    httpSource = _HttpPageSource();
    worker = DownloadQueueProcessor(
        dio: dio,
        sourceFactory: (id) =>
            id == 'mangapill_en' ? httpSource : ExtensionFactory.create(id));
  });
  tearDown(() async {
    worker.stop();
    dio.close(force: true);
    BrowserFetch.instance = previousBrowser;
    await isar.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  Future<DownloadEntry> queue(int id,
      {String sourceId = 'all_manga_en',
      List<String> pages = const [],
      String? message}) async {
    final entry = DownloadEntry()
      ..chapterId = id
      ..mangaId = id
      ..mangaTitle = 'Title $id'
      ..chapterTitle = 'Chapter 1'
      ..chapterNumber = 1
      ..queuedAt = DateTime(2026, 1, 1, 0, id)
      ..pageUrls = pages
      ..errorMessage = message;
    await isar.writeTxn(() async {
      await isar.mangaEntrys.put(MangaEntry()
        ..id = id
        ..title = 'Title $id'
        ..sourceKey = '$sourceId::$id'
        ..sourceId = sourceId
        ..sourceMangaId = '$id'
        ..sourceUrl = '');
      await isar.chapterEntrys.put(ChapterEntry()
        ..id = id
        ..mangaId = id
        ..sourceChapterId = 'series|$id'
        ..title = 'Chapter 1'
        ..number = 1);
      await isar.downloadEntrys.put(entry);
    });
    return entry;
  }

  test('stored AllManga pages download without a browser and open offline',
      () async {
    final pages = [
      'https://images.example.test/001.jpg',
      'https://images.example.test/002.webp',
    ];
    final queued = await queue(1);
    BrowserFetch.instance = FakeBrowserFetch(captures: {
      'https://mkissa.to/manga/series': {
        'chapterPages': {
          'edges': [
            {
              'pictureUrls': [
                for (final url in pages) {'url': url}
              ]
            },
          ],
        },
      },
    });
    await DownloadPagePreparer(isar).prepare();
    // Reopen the database and remove the browser to model the durable handoff
    // to the WorkManager isolate, which cannot access the foreground fetcher.
    await isar.close();
    isar = await Isar.open(
      [MangaEntrySchema, ChapterEntrySchema, DownloadEntrySchema],
      directory: directory.path,
      name: 'queue_processor',
      inspector: false,
    );
    BrowserFetch.instance = const UnavailableBrowserFetch();
    await worker.processQueue(isar);
    final done = (await isar.downloadEntrys.get(queued.id))!;
    expect(done.status, DownloadStatus.completed);
    expect(done.totalPages, 2);
    expect(done.downloadedPages, 2);
    expect(done.retryCount, 0);
    expect(done.pageUrls, pages);
    expect(adapter.requests.map((r) => r.uri.toString()), pages);
    for (final request in adapter.requests) {
      expect(request.headers['Referer'], 'https://allmanga.to/');
      expect(request.headers['User-Agent'], BrowserFetch.instance.userAgent);
    }
    final chapter = (await isar.chapterEntrys.get(1))!;
    expect(chapter.isDownloaded, isTrue);
    expect(chapter.pageCount, 2);
    final local = await resolveChapterPagePaths(
      downloadPath: chapter.downloadPath,
      isMarkedDownloaded: chapter.isDownloaded,
      expectedPageCount: chapter.pageCount,
      fetchNetworkPages: () =>
          throw StateError('Offline reader must not fetch pages'),
    );
    expect(local, hasLength(2));
    for (final path in local) {
      expect(await File(path).readAsBytes(), [1, 2, 3]);
    }
  });

  test(
      'unprepared browser entries stay pending without blocking a normal source',
      () async {
    final waiting = await queue(1);
    final ordinary = await queue(2, sourceId: 'mangapill_en');
    await worker.processQueue(isar).timeout(const Duration(seconds: 5));
    final deferred = (await isar.downloadEntrys.get(waiting.id))!;
    expect(deferred.status, DownloadStatus.pending);
    expect(deferred.errorMessage, waitingForDownloadPages);
    expect(deferred.retryCount, 0);
    expect(deferred.startedAt, isNull);
    expect((await isar.chapterEntrys.get(1))!.isDownloaded, isFalse);
    expect((await isar.downloadEntrys.get(ordinary.id))!.status,
        DownloadStatus.completed);
    expect(httpSource.pageCalls, 1);
    expect(adapter.requests, hasLength(1));
    await worker.processQueue(isar).timeout(const Duration(seconds: 5));
    expect((await isar.downloadEntrys.get(waiting.id))!.retryCount, 0);
    expect(adapter.requests, hasLength(1));
  });

  test('preserves the preparation marker and consumes pages on the next run',
      () async {
    final queued = await queue(1, message: preparingDownloadPages);
    await worker.processQueue(isar).timeout(const Duration(seconds: 5));
    final waiting = (await isar.downloadEntrys.get(queued.id))!;
    expect(waiting.status, DownloadStatus.pending);
    expect(waiting.errorMessage, preparingDownloadPages);
    expect(adapter.requests, isEmpty);
    await isar.writeTxn(() async {
      waiting.pageUrls = ['https://images.example.test/001.jpg'];
      await isar.downloadEntrys.put(waiting);
    });
    await worker.processQueue(isar);
    expect((await isar.downloadEntrys.get(queued.id))!.status,
        DownloadStatus.completed);
  });

  test(
      'non-browser discovery errors retain the existing failure and retry behavior',
      () async {
    final queued = await queue(1, sourceId: 'mangapill_en');
    httpSource.fail = true;
    await worker.processQueue(isar);
    final failed = (await isar.downloadEntrys.get(queued.id))!;
    expect(failed.status, DownloadStatus.failed);
    expect(failed.retryCount, 1);
    expect(failed.errorMessage, contains('Page discovery failed'));
    expect(httpSource.pageCalls, 1);
    expect(adapter.requests, isEmpty);
  });
}
