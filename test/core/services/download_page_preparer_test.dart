import 'dart:async';
import 'dart:io';

import 'package:comic_center/core/browser/browser_fetch.dart';
import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/download_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/providers/database_provider.dart';
import 'package:comic_center/core/providers/download_provider.dart';
import 'package:comic_center/core/services/download_enqueue.dart';
import 'package:comic_center/core/services/download_page_preparer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../support/fake_browser_fetch.dart';
import '../../support/local_isar.dart';

const _pages = [
  'https://images.example.test/001.jpg',
  'https://images.example.test/002.webp'
];

class _ControlledBrowser extends FakeBrowserFetch {
  _ControlledBrowser({this.beforeCapture})
      : super(captures: {
          'https://mkissa.to/manga/series': {
            'chapterPages': {
              'edges': [
                {
                  'pictureUrls': [
                    for (final url in _pages) {'url': url}
                  ]
                },
              ],
            },
          },
        });

  final Future<void> Function(int call)? beforeCapture;
  final navigation = <String?>[];
  int active = 0;
  int maxActive = 0;

  @override
  Future<Map<String, dynamic>> capture(
    Uri url, {
    required String jsHook,
    required String channel,
    String? afterLoad,
    Duration timeout = const Duration(seconds: 30),
    bool interactive = true,
  }) async {
    navigation.add(afterLoad);
    active++;
    if (active > maxActive) maxActive = active;
    try {
      await beforeCapture?.call(navigation.length);
      return await super.capture(url,
          jsHook: jsHook,
          channel: channel,
          afterLoad: afterLoad,
          timeout: timeout,
          interactive: interactive);
    } finally {
      active--;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Isar isar;
  late BrowserFetch previousBrowser;
  late _ControlledBrowser browser;
  late DownloadPagePreparer preparer;
  ProviderContainer? container;
  late int scheduled;
  var checkpoint = '';

  setUpAll(initializeLocalIsar);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('yomi_page_preparer_');
    isar = await Isar.open(
      [MangaEntrySchema, ChapterEntrySchema, DownloadEntrySchema],
      directory: directory.path,
      name: 'page_preparer',
      inspector: false,
    );
    previousBrowser = BrowserFetch.instance;
    browser = _ControlledBrowser();
    BrowserFetch.instance = browser;
    scheduled = 0;
    preparer = DownloadPagePreparer(isar, scheduleQueue: () async {
      scheduled++;
      expect(await isar.downloadEntrys.filter().pageUrlsIsNotEmpty().count(),
          greaterThan(0),
          reason: 'Persist pages before scheduling image work');
    });
    await isar.writeTxn(() => isar.mangaEntrys.put(MangaEntry()
      ..id = 1
      ..title = 'Title'
      ..sourceKey = 'all_manga_en::series'
      ..sourceId = 'all_manga_en'
      ..sourceMangaId = 'series'
      ..sourceUrl = ''));
  });
  tearDown(() async {
    container?.dispose();
    container = null;
    preparer.stop();
    BrowserFetch.instance = previousBrowser;
    await isar.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  Future<void> queue(List<int> ids) async {
    await isar.writeTxn(() => isar.chapterEntrys.putAll([
          for (final id in ids)
            ChapterEntry()
              ..id = id
              ..mangaId = 1
              ..sourceChapterId = 'series|$id'
              ..title = 'Chapter $id'
              ..number = id.toDouble(),
        ]));
    await enqueueNewChapters(isar, mangaId: 1, chapterIds: ids);
  }

  Future<DownloadEntry> entry(int chapterId) async => (await isar.downloadEntrys
      .filter()
      .chapterIdEqualTo(chapterId)
      .findFirst())!;

  Future<DownloadEntry> waitForEntry(
    int chapterId,
    bool Function(DownloadEntry) matches,
  ) async {
    // Poll persisted state with a bound: rapid writes may be coalesced by
    // Isar's query watchers while another asynchronous query is running.
    for (var attempt = 0; attempt < 100; attempt++) {
      final current = await entry(chapterId);
      if (matches(current)) return current;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final current = await entry(chapterId);
    throw TimeoutException('$checkpoint: Last state: ${current.status}, '
        'retries=${current.retryCount}, message=${current.errorMessage}, '
        'captures=${browser.navigation.length}');
  }

  Future<DownloadManager> startManager() async {
    container =
        ProviderContainer(overrides: [isarProvider.overrideWithValue(isar)]);
    await container!.read(downloadManagerProvider.future);
    return container!.read(downloadManagerProvider.notifier);
  }

  test(
      'shows preparation then persists ordered pages and total before scheduling',
      () async {
    await queue([1]);
    final entered = Completer<void>();
    final release = Completer<void>();
    BrowserFetch.instance = _ControlledBrowser(beforeCapture: (_) async {
      entered.complete();
      await release.future;
    });
    final pass = preparer.prepare();
    await entered.future;
    expect((await entry(1)).errorMessage, preparingDownloadPages);
    expect((await entry(1)).status, DownloadStatus.pending);
    expect(scheduled, 0);
    release.complete();
    await pass;
    final stored = await entry(1);
    expect(stored.pageUrls, _pages);
    expect(stored.totalPages, 2);
    expect(stored.errorMessage, isNull);
    expect(stored.status, DownloadStatus.pending);
    expect(scheduled, 1);
    await preparer.prepare();
    expect(scheduled, 1, reason: 'Prepared entries are reused');
  });

  test(
      'serializes overlapping passes and includes chapters enqueued during capture',
      () async {
    await queue([2, 1]);
    final entered = Completer<void>();
    final release = Completer<void>();
    browser = _ControlledBrowser(beforeCapture: (call) async {
      if (call == 1) {
        entered.complete();
        await release.future;
      }
    });
    BrowserFetch.instance = browser;
    final first = preparer.prepare();
    await entered.future;
    await queue([3]);
    final overlapping = preparer.prepare();
    expect(browser.navigation, hasLength(1));
    release.complete();
    await Future.wait([first, overlapping]);
    expect(browser.maxActive, 1);
    expect(browser.navigation, [
      contains('/chapter-2-sub'),
      contains('/chapter-1-sub'),
      contains('/chapter-3-sub'),
    ]);
    expect(scheduled, 3);
  });

  test('a cancelled site check fails only that entry and can be retried',
      () async {
    await queue([1, 2]);
    browser = _ControlledBrowser(beforeCapture: (call) async {
      if (call == 1) throw const BrowserChallengeCancelled();
    });
    BrowserFetch.instance = browser;
    await preparer.prepare();
    final failed = await entry(1);
    expect(failed.status, DownloadStatus.failed);
    expect(failed.errorMessage, contains('Site check cancelled'));
    expect(failed.retryCount, 1);
    expect(failed.pageUrls, isEmpty);
    expect((await entry(2)).pageUrls, _pages);
    expect(scheduled, 1);

    await enqueueNewChapters(isar, mangaId: 1, chapterIds: [1]);
    await preparer.prepare();
    expect((await entry(1)).pageUrls, _pages);
    expect((await entry(1)).errorMessage, isNull);
    expect(scheduled, 2);
  });

  test('isolates invalid page responses and continues the queue', () async {
    await queue([1, 2]);
    browser = _ControlledBrowser(beforeCapture: (call) async {
      if (call == 1) throw StateError('Invalid page response');
    });
    BrowserFetch.instance = browser;
    await preparer.prepare();
    expect((await entry(1)).status, DownloadStatus.failed);
    expect((await entry(1)).errorMessage, contains('Invalid page response'));
    expect((await entry(2)).pageUrls, _pages);
  });

  test('leaves non-browser sources to the worker', () async {
    await queue([1]);
    await isar.writeTxn(() async {
      final manga = (await isar.mangaEntrys.get(1))!;
      manga.sourceId = 'mangapill_en';
      await isar.mangaEntrys.put(manga);
    });
    await preparer.prepare();
    expect(browser.navigation, isEmpty);
    expect((await entry(1)).pageUrls, isEmpty);
    expect((await entry(1)).errorMessage, isNull);
    expect(scheduled, 0);
  });

  test('skips prepared, paused, failed, and completed entries', () async {
    await queue([1, 2, 3, 4]);
    await isar.writeTxn(() async {
      final prepared = (await entry(1))..pageUrls = _pages;
      final paused = (await entry(2))..status = DownloadStatus.paused;
      final failed = (await entry(3))..status = DownloadStatus.failed;
      final completed = (await entry(4))..status = DownloadStatus.completed;
      await isar.downloadEntrys.putAll([prepared, paused, failed, completed]);
    });
    await preparer.prepare();
    expect(browser.navigation, isEmpty);
    expect(scheduled, 0);
  });

  test(
      'requeue during capture discards the old result and serially prepares again',
      () async {
    await queue([1]);
    final entered = Completer<void>();
    final release = Completer<void>();
    browser = _ControlledBrowser(beforeCapture: (call) async {
      if (call == 1) {
        entered.complete();
        await release.future;
      }
    });
    BrowserFetch.instance = browser;
    final first = preparer.prepare();
    await entered.future;
    await isar.writeTxn(() async {
      final current = (await entry(1))..status = DownloadStatus.paused;
      await isar.downloadEntrys.put(current);
    });
    await enqueueNewChapters(isar, mangaId: 1, chapterIds: [1]);
    final next = preparer.prepare();
    release.complete();
    await Future.wait([first, next]);
    expect(browser.navigation, hasLength(2));
    expect(browser.maxActive, 1);
    expect(scheduled, 1);
    expect((await entry(1)).pageUrls, _pages);
  });

  test(
      'waits for an unavailable browser without failing and prepares on the next trigger',
      () async {
    await queue([1]);
    BrowserFetch.instance = const UnavailableBrowserFetch();
    await preparer.prepare();
    final waiting = await entry(1);
    expect(waiting.status, DownloadStatus.pending);
    expect(waiting.errorMessage, waitingForDownloadPages);
    expect(waiting.retryCount, 0);
    expect(scheduled, 0);
    BrowserFetch.instance = browser;
    await preparer.prepare();
    expect((await entry(1)).pageUrls, _pages);
  });

  test(
      'browser disappearing during capture stays pending without retry backoff',
      () async {
    await queue([1]);
    BrowserFetch.instance = _ControlledBrowser(beforeCapture: (_) async {
      throw const BrowserFetchUnavailable();
    });
    await preparer.prepare();
    expect((await entry(1)).status, DownloadStatus.pending);
    expect((await entry(1)).errorMessage, waitingForDownloadPages);
    expect((await entry(1)).retryCount, 0);
    BrowserFetch.instance = browser;
    await preparer.prepare();
    expect((await entry(1)).pageUrls, _pages);
  });

  for (final action in ['pause', 'cancel', 'dispose']) {
    test('$action during capture cannot revive the download or schedule work',
        () async {
      await queue([1]);
      final entered = Completer<void>();
      final release = Completer<void>();
      BrowserFetch.instance = _ControlledBrowser(beforeCapture: (_) async {
        entered.complete();
        await release.future;
      });
      final pass = preparer.prepare();
      await entered.future;
      final current = await entry(1);
      if (action == 'dispose') {
        preparer.stop();
      } else {
        await isar.writeTxn(() async {
          if (action == 'cancel') {
            await isar.downloadEntrys.delete(current.id);
          } else {
            current.status = DownloadStatus.paused;
            await isar.downloadEntrys.put(current);
          }
        });
      }
      release.complete();
      await pass;
      expect(scheduled, 0);
      final after = await isar.downloadEntrys.get(current.id);
      if (action == 'cancel') {
        expect(after, isNull);
      } else {
        expect(after!.pageUrls, isEmpty);
        expect(after.status,
            action == 'pause' ? DownloadStatus.paused : DownloadStatus.pending);
      }
    });
  }

  test('manager prepares startup entries when the browser mounts later',
      () async {
    await queue([1]);
    BrowserFetch.instance = const UnavailableBrowserFetch();
    await startManager();
    await waitForEntry(1, (e) => e.errorMessage == waitingForDownloadPages);
    expect((await entry(1)).retryCount, 0);
    BrowserFetch.instance = _ControlledBrowser(beforeCapture: (_) async {
      throw const BrowserChallengeCancelled();
    });
    final failed =
        await waitForEntry(1, (e) => e.status == DownloadStatus.failed);
    expect(failed.errorMessage, contains('Site check cancelled'));
    expect(failed.retryCount, 1);
  });

  test('manager waits after an unavailable capture without spinning', () async {
    await queue([1]);
    browser = _ControlledBrowser(beforeCapture: (_) async {
      throw const BrowserFetchUnavailable();
    });
    BrowserFetch.instance = browser;
    await startManager();
    await waitForEntry(1, (e) => e.errorMessage == waitingForDownloadPages);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(browser.navigation, hasLength(1));
    expect((await entry(1)).retryCount, 0);
    BrowserFetch.instance = _ControlledBrowser(beforeCapture: (_) async {
      throw const BrowserChallengeCancelled();
    });
    await waitForEntry(1, (e) => e.status == DownloadStatus.failed);
  });

  test(
      'manager observes direct enqueue and prepares all foreground retry paths',
      () async {
    browser = _ControlledBrowser(beforeCapture: (_) async {
      throw const BrowserChallengeCancelled();
    });
    BrowserFetch.instance = browser;
    final manager = await startManager();
    // Same helper used by background library updates and download-ahead.
    checkpoint = 'direct enqueue';
    await queue([1]);
    var failed = await waitForEntry(1, (e) => e.retryCount == 1);
    final manga = (await isar.mangaEntrys.get(1))!;
    final chapter = (await isar.chapterEntrys.get(1))!;
    checkpoint = 'enqueue';
    await manager.enqueue(manga: manga, chapter: chapter);
    failed = await waitForEntry(1, (e) => e.retryCount == 2);
    checkpoint = 'enqueueAll';
    await manager.enqueueAll(manga: manga, chapters: [chapter]);
    failed = await waitForEntry(1, (e) => e.retryCount == 3);
    checkpoint = 'retry';
    await manager.retry(failed.id);
    failed = await waitForEntry(1, (e) => e.retryCount == 4);
    await isar.writeTxn(() async {
      failed.status = DownloadStatus.paused;
      await isar.downloadEntrys.put(failed);
    });
    checkpoint = 'resume';
    await manager.resume(failed.id);
    await waitForEntry(1, (e) => e.retryCount == 5);
    checkpoint = 'retryAllFailed';
    await manager.retryAllFailed();
    failed = await waitForEntry(1, (e) => e.retryCount == 6);
    expect(failed.status, DownloadStatus.failed);
    expect(browser.navigation, hasLength(6));
    expect(browser.maxActive, 1);
  });
}
