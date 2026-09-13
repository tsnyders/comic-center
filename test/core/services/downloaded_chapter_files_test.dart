import 'dart:io';

import 'package:comic_center/core/database/models/download_entry.dart';
import 'package:comic_center/core/services/download_background_service.dart';
import 'package:comic_center/core/services/downloaded_chapter_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('downloaded chapter page resolution', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'yomi_downloaded_chapter_test_',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('uses complete local pages without touching the network', () async {
      await File('${temporaryDirectory.path}/page_0001.webp')
          .writeAsBytes(const [2]);
      await File('${temporaryDirectory.path}/page_0000.jpg')
          .writeAsBytes(const [1]);
      await File('${temporaryDirectory.path}/page_0002.jpg.part')
          .writeAsBytes(const [3]);
      await File('${temporaryDirectory.path}/notes.txt')
          .writeAsString('ignored');
      var networkCalled = false;

      final pages = await resolveChapterPagePaths(
        downloadPath: temporaryDirectory.path,
        isMarkedDownloaded: true,
        expectedPageCount: 2,
        fetchNetworkPages: () async {
          networkCalled = true;
          return const ['https://example.com/page.jpg'];
        },
      );

      expect(networkCalled, isFalse);
      expect(pages, [
        '${temporaryDirectory.path}${Platform.pathSeparator}page_0000.jpg',
        '${temporaryDirectory.path}${Platform.pathSeparator}page_0001.webp',
      ]);
    });

    test('never falls back to network for a missing downloaded copy', () async {
      var networkCalled = false;

      await expectLater(
        resolveChapterPagePaths(
          downloadPath: '${temporaryDirectory.path}/missing',
          isMarkedDownloaded: true,
          expectedPageCount: 1,
          fetchNetworkPages: () async {
            networkCalled = true;
            return const ['https://example.com/page.jpg'];
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(networkCalled, isFalse);
    });

    test('uses network only for chapters that are not downloaded', () async {
      final pages = await resolveChapterPagePaths(
        downloadPath: null,
        isMarkedDownloaded: false,
        expectedPageCount: 0,
        fetchNetworkPages: () async => const ['https://example.com/page.jpg'],
      );

      expect(pages, const ['https://example.com/page.jpg']);
    });

    test('rejects an incomplete local copy without using the network',
        () async {
      await File('${temporaryDirectory.path}/page_0000.jpg')
          .writeAsBytes(const [1]);
      var networkCalled = false;

      await expectLater(
        resolveChapterPagePaths(
          downloadPath: temporaryDirectory.path,
          isMarkedDownloaded: true,
          expectedPageCount: 2,
          fetchNetworkPages: () async {
            networkCalled = true;
            return const ['https://example.com/page.jpg'];
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(networkCalled, isFalse);
    });

    test('normalizes supported page extensions', () {
      expect(downloadedPageExtension('https://x.test/a.PNG?token=1'), '.png');
      expect(downloadedPageExtension('https://x.test/a.jpeg'), '.jpeg');
      expect(downloadedPageExtension('https://x.test/no-extension'), '.jpg');
    });
  });

  group('completed queue retention', () {
    test('expires completed records at two minutes', () {
      final completedAt = DateTime.utc(2026, 9, 13, 10);
      final entry = DownloadEntry()
        ..status = DownloadStatus.completed
        ..completedAt = completedAt;

      expect(
        isCompletedDownloadExpired(
          entry,
          completedAt.add(const Duration(minutes: 1, seconds: 59)),
        ),
        isFalse,
      );
      expect(
        isCompletedDownloadExpired(
          entry,
          completedAt.add(const Duration(minutes: 2)),
        ),
        isTrue,
      );
    });

    test('does not expire paused or failed records', () {
      final now = DateTime.utc(2026, 9, 13, 10);
      final entry = DownloadEntry()
        ..status = DownloadStatus.paused
        ..completedAt = now.subtract(const Duration(hours: 1));

      expect(isCompletedDownloadExpired(entry, now), isFalse);
      entry.status = DownloadStatus.failed;
      expect(isCompletedDownloadExpired(entry, now), isFalse);
    });
  });
}
