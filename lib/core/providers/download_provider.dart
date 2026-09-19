import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/download_entry.dart';
import '../database/models/manga_entry.dart';
import '../services/app_logger.dart';
import '../services/download_background_service.dart';
import '../services/download_enqueue.dart';
import 'database_provider.dart';

final downloadQueueProvider = StreamProvider<List<DownloadEntry>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.downloadEntrys
      .filter()
      .statusEqualTo(DownloadStatus.downloading)
      .or()
      .statusEqualTo(DownloadStatus.pending)
      .or()
      .statusEqualTo(DownloadStatus.paused)
      .or()
      .statusEqualTo(DownloadStatus.failed)
      .sortByQueuedAt()
      .watch(fireImmediately: true);
});

final downloadHistoryProvider = StreamProvider<List<DownloadEntry>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.downloadEntrys
      .filter()
      .statusEqualTo(DownloadStatus.completed)
      .sortByCompletedAtDesc()
      .watch(fireImmediately: true);
});

/// Returns the current queue status for a chapter. Completed queue records are
/// intentionally removed after two minutes; the durable downloaded state lives
/// on [ChapterEntry.isDownloaded].
final chapterDownloadStatusProvider =
    StreamProvider.family.autoDispose<String?, int>((ref, chapterId) {
  final isar = ref.watch(isarProvider);
  return isar.downloadEntrys
      .filter()
      .chapterIdEqualTo(chapterId)
      .watch(fireImmediately: true)
      .map((list) => list.isEmpty ? null : list.first.status);
});

/// A title with at least one downloaded chapter (Downloads → "Downloaded").
class DownloadedTitle {
  const DownloadedTitle({
    required this.mangaId,
    required this.title,
    required this.chapterCount,
    required this.bytes,
  });

  final int mangaId;
  final String title;
  final int chapterCount;
  final int bytes;
}

final downloadedTitlesProvider = StreamProvider<List<DownloadedTitle>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.chapterEntrys
      .filter()
      .isDownloadedEqualTo(true)
      .watch(fireImmediately: true)
      .asyncMap((chapters) async {
    final documents = await getApplicationDocumentsDirectory();
    final counts = <int, int>{};
    for (final chapter in chapters) {
      counts.update(chapter.mangaId, (n) => n + 1, ifAbsent: () => 1);
    }
    final titles = <DownloadedTitle>[];
    for (final entry in counts.entries) {
      final manga = await isar.mangaEntrys.get(entry.key);
      titles.add(DownloadedTitle(
        mangaId: entry.key,
        title: manga?.title ?? 'Unknown title',
        chapterCount: entry.value,
        bytes: await _directorySize(
          Directory('${documents.path}/downloads/${entry.key}'),
        ),
      ));
    }
    titles.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return titles;
  });
});

Future<int> _directorySize(Directory directory) async {
  if (!await directory.exists()) return 0;
  var total = 0;
  await for (final entity
      in directory.list(recursive: true, followLinks: false)) {
    if (entity is File) total += await entity.length();
  }
  return total;
}

class DownloadManager extends AsyncNotifier<void> {
  static const _platform = MethodChannel('yomi/platform');
  static bool _notificationPermissionRequested = false;

  DownloadQueueProcessor? _fallbackProcessor;
  bool _fallbackIsRunning = false;
  Timer? _historyCleanupTimer;
  StreamSubscription<List<DownloadEntry>>? _completedSubscription;

  @override
  Future<void> build() async {
    final isar = ref.read(isarProvider);
    _completedSubscription = isar.downloadEntrys
        .filter()
        .statusEqualTo(DownloadStatus.completed)
        .watch(fireImmediately: true)
        .listen((entries) => _scheduleInAppHistoryCleanup(isar, entries));
    ref.onDispose(() {
      _historyCleanupTimer?.cancel();
      unawaited(_completedSubscription?.cancel());
      _fallbackProcessor?.stop();
    });
  }

  Future<void> enqueue({
    required MangaEntry manga,
    required ChapterEntry chapter,
  }) =>
      enqueueAll(manga: manga, chapters: [chapter]);

  Future<void> enqueueAll({
    required MangaEntry manga,
    required List<ChapterEntry> chapters,
  }) async {
    final isar = ref.read(isarProvider);
    await _requestNotificationPermission();
    final queued = await enqueueNewChapters(
      isar,
      mangaId: manga.id,
      chapterIds: [for (final chapter in chapters) chapter.id],
    );
    // enqueueNewChapters schedules the Android worker itself; other
    // platforms run the queue in-process.
    if (queued > 0 && !Platform.isAndroid) await _runFallbackProcessor(isar);
  }

  /// Android 13+ needs runtime consent before the download notification can
  /// be shown. Asked once per process; MainActivity skips it below API 33.
  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid || _notificationPermissionRequested) return;
    _notificationPermissionRequested = true;
    try {
      await _platform.invokeMethod<void>('requestNotificationPermission');
    } catch (e, st) {
      AppLogger.instance.warn('Notification permission request failed', e, st);
    }
  }

  Future<void> pause(int downloadId) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final entry = await isar.downloadEntrys.get(downloadId);
      if (entry == null) return;
      if (entry.status == DownloadStatus.pending ||
          entry.status == DownloadStatus.downloading) {
        entry.status = DownloadStatus.paused;
        await isar.downloadEntrys.put(entry);
      }
    });
  }

  Future<void> resume(int downloadId) async {
    final isar = ref.read(isarProvider);
    var shouldSchedule = false;
    await isar.writeTxn(() async {
      final entry = await isar.downloadEntrys.get(downloadId);
      if (entry == null) return;
      if (entry.status == DownloadStatus.paused ||
          entry.status == DownloadStatus.failed) {
        entry
          ..status = DownloadStatus.pending
          ..errorMessage = null
          ..queuedAt = DateTime.now();
        await isar.downloadEntrys.put(entry);
        shouldSchedule = true;
      }
    });
    if (shouldSchedule) await _scheduleQueue(isar);
  }

  Future<void> retry(int downloadId) => resume(downloadId);

  Future<void> retryAllFailed() async {
    final isar = ref.read(isarProvider);
    final failed = await isar.downloadEntrys
        .filter()
        .statusEqualTo(DownloadStatus.failed)
        .findAll();
    if (failed.isEmpty) return;
    await isar.writeTxn(() async {
      final now = DateTime.now();
      for (final entry in failed) {
        entry
          ..status = DownloadStatus.pending
          ..errorMessage = null
          ..queuedAt = now;
        await isar.downloadEntrys.put(entry);
      }
    });
    await _scheduleQueue(isar);
  }

  /// Puts a queued item ahead of every other pending one. The processor
  /// always takes the oldest queuedAt, so the item borrows an earlier stamp.
  Future<void> moveToTop(int downloadId) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final entry = await isar.downloadEntrys.get(downloadId);
      if (entry == null || entry.status != DownloadStatus.pending) return;
      final first = await isar.downloadEntrys
          .filter()
          .statusEqualTo(DownloadStatus.pending)
          .sortByQueuedAt()
          .findFirst();
      final earliest = first?.queuedAt ?? DateTime.now();
      entry.queuedAt = earliest.subtract(const Duration(seconds: 1));
      await isar.downloadEntrys.put(entry);
    });
  }

  Future<void> cancel(int downloadId) => deleteDownload(downloadId);

  Future<void> cancelAll() async {
    final isar = ref.read(isarProvider);
    final active = await isar.downloadEntrys
        .filter()
        .not()
        .statusEqualTo(DownloadStatus.completed)
        .findAll();
    final byManga = <int, List<int>>{};
    for (final entry in active) {
      (byManga[entry.mangaId] ??= []).add(entry.chapterId);
    }
    for (final entry in byManga.entries) {
      await deleteChapterDownloads(
        isar,
        mangaId: entry.key,
        chapterIds: entry.value,
      );
    }
  }

  /// Removes a queued or completed download: the files on disk, the queue
  /// record, and the chapter's downloaded state so the reader streams again.
  Future<void> deleteDownload(int downloadId) async {
    final isar = ref.read(isarProvider);
    final entry = await isar.downloadEntrys.get(downloadId);
    if (entry == null) return;
    await deleteChapterDownloads(
      isar,
      mangaId: entry.mangaId,
      chapterIds: [entry.chapterId],
    );
  }

  /// Deletes every downloaded and queued chapter of [mangaId].
  Future<void> deleteAllForManga(int mangaId) async {
    final isar = ref.read(isarProvider);
    final downloaded = await isar.chapterEntrys
        .filter()
        .mangaIdEqualTo(mangaId)
        .isDownloadedEqualTo(true)
        .findAll();
    final queued =
        await isar.downloadEntrys.filter().mangaIdEqualTo(mangaId).findAll();
    await deleteChapterDownloads(
      isar,
      mangaId: mangaId,
      chapterIds: {
        for (final chapter in downloaded) chapter.id,
        for (final entry in queued) entry.chapterId,
      }.toList(),
    );
  }

  Future<void> _scheduleQueue(Isar isar) {
    if (Platform.isAndroid) return DownloadBackgroundService.scheduleQueue();
    return _runFallbackProcessor(isar);
  }

  Future<void> _runFallbackProcessor(Isar isar) async {
    if (_fallbackIsRunning) return;
    _fallbackIsRunning = true;
    _fallbackProcessor = DownloadQueueProcessor();
    try {
      await _fallbackProcessor!.processQueue(isar);
    } finally {
      _fallbackProcessor = null;
      _fallbackIsRunning = false;
    }
  }

  void _scheduleInAppHistoryCleanup(
    Isar isar,
    List<DownloadEntry> entries,
  ) {
    _historyCleanupTimer?.cancel();
    if (entries.isEmpty) return;

    final expiries = entries
        .map((entry) => entry.completedAt?.add(completedDownloadRetention))
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (expiries.isEmpty) return;

    final delay = expiries.first.difference(DateTime.now());
    _historyCleanupTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(deleteExpiredCompletedDownloadRecords(isar)),
    );
  }
}

final downloadManagerProvider =
    AsyncNotifierProvider<DownloadManager, void>(DownloadManager.new);
