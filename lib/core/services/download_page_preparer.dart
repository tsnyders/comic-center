import 'package:isar/isar.dart';

import '../browser/browser_fetch.dart';
import '../database/models/chapter_entry.dart';
import '../database/models/download_entry.dart';
import '../database/models/manga_entry.dart';
import '../extensions/extension_factory.dart';
import 'download_background_service.dart';

/// Resolves browser-only pages in the foreground; the worker owns image bytes.
class DownloadPagePreparer {
  DownloadPagePreparer(this.isar, {Future<void> Function()? scheduleQueue})
      : _scheduleQueue =
            scheduleQueue ?? DownloadBackgroundService.scheduleQueue;

  final Isar isar;
  final Future<void> Function() _scheduleQueue;
  Future<void>? _running;
  bool _stopped = false;
  bool _requested = false;

  void stop() => _stopped = true;

  /// Concurrent triggers share one pass. Re-querying after each capture also
  /// picks up chapters enqueued while the browser was busy.
  Future<void> prepare() {
    _requested = true;
    return _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    while (_requested && !_stopped) {
      _requested = false;
      await _preparePending();
    }
  }

  Future<void> _preparePending() async {
    final visited = <int>{};
    while (!_stopped) {
      final entry = await isar.downloadEntrys
          .filter()
          .statusEqualTo(DownloadStatus.pending)
          .pageUrlsIsEmpty()
          .optional(visited.isNotEmpty,
              (query) => query.not().anyOf(visited, (q, id) => q.idEqualTo(id)))
          .sortByQueuedAt()
          .findFirst();
      if (entry == null || _stopped) return;
      visited.add(entry.id);

      final manga = await isar.mangaEntrys.get(entry.mangaId);
      final source =
          manga == null ? null : ExtensionFactory.create(manga.sourceId);
      if (source == null || !source.needsBrowserForPages) continue;
      if (BrowserFetch.instance is UnavailableBrowserFetch) {
        await _updatePending(entry, (current) {
          current.errorMessage = waitingForDownloadPages;
        });
        return;
      }

      final claimed = await _updatePending(entry, (current) {
        current.errorMessage = preparingDownloadPages;
      });
      if (!claimed || _stopped) continue;

      List<String> pages;
      try {
        final chapter = await isar.chapterEntrys.get(entry.chapterId);
        if (chapter == null) {
          throw StateError('Chapter is missing from the database');
        }
        pages = await source.fetchPageUrls(chapter.sourceChapterId);
        if (pages.isEmpty) {
          throw StateError('The source returned no pages for this chapter');
        }
      } on BrowserFetchUnavailable {
        await _updatePending(entry, (current) {
          current.errorMessage = waitingForDownloadPages;
        });
        return;
      } catch (error) {
        await _updatePending(entry, (current) {
          current
            ..status = DownloadStatus.failed
            ..errorMessage = error.toString()
            ..retryCount = current.retryCount + 1;
        });
        continue;
      }

      final stored = await _updatePending(entry, (current) {
        current
          ..pageUrls = pages
          ..totalPages = pages.length
          ..errorMessage = null;
      });
      if (stored) await _scheduleQueue();
    }
  }

  /// Re-read in the transaction so a slow capture cannot revive a cancelled,
  /// paused, or re-queued download or overwrite another isolate's work.
  Future<bool> _updatePending(
    DownloadEntry entry,
    void Function(DownloadEntry) update,
  ) async {
    if (_stopped) return false;
    return isar.writeTxn(() async {
      final current = await isar.downloadEntrys.get(entry.id);
      if (_stopped ||
          current == null ||
          current.status != DownloadStatus.pending ||
          current.pageUrls.isNotEmpty ||
          current.queuedAt != entry.queuedAt) {
        return false;
      }
      update(current);
      await isar.downloadEntrys.put(current);
      return true;
    });
  }
}
