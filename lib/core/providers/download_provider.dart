import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/download_entry.dart';
import '../database/models/manga_entry.dart';
import '../services/download_background_service.dart';
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

class DownloadManager extends AsyncNotifier<void> {
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
  }) async {
    final isar = ref.read(isarProvider);
    var shouldSchedule = false;
    await isar.writeTxn(() async {
      final existing = await isar.downloadEntrys
          .filter()
          .chapterIdEqualTo(chapter.id)
          .findFirst();

      if (existing != null) {
        if (existing.status == DownloadStatus.pending ||
            existing.status == DownloadStatus.downloading ||
            existing.status == DownloadStatus.completed) {
          return;
        }
        existing
          ..status = DownloadStatus.pending
          ..errorMessage = null
          ..queuedAt = DateTime.now();
        await isar.downloadEntrys.put(existing);
        shouldSchedule = true;
        return;
      }

      final entry = DownloadEntry()
        ..chapterId = chapter.id
        ..mangaId = manga.id
        ..mangaTitle = manga.title
        ..chapterTitle = chapter.title
        ..chapterNumber = chapter.number ?? 0
        ..status = DownloadStatus.pending
        ..queuedAt = DateTime.now();
      await isar.downloadEntrys.put(entry);
      shouldSchedule = true;
    });

    if (shouldSchedule) await _scheduleQueue(isar);
  }

  Future<void> enqueueAll({
    required MangaEntry manga,
    required List<ChapterEntry> chapters,
  }) async {
    final isar = ref.read(isarProvider);
    var shouldSchedule = false;
    await isar.writeTxn(() async {
      for (final chapter in chapters) {
        final existing = await isar.downloadEntrys
            .filter()
            .chapterIdEqualTo(chapter.id)
            .findFirst();
        if (existing != null) {
          if (existing.status == DownloadStatus.paused ||
              existing.status == DownloadStatus.failed) {
            existing
              ..status = DownloadStatus.pending
              ..errorMessage = null
              ..queuedAt = DateTime.now();
            await isar.downloadEntrys.put(existing);
            shouldSchedule = true;
          }
          continue;
        }

        await isar.downloadEntrys.put(DownloadEntry()
          ..chapterId = chapter.id
          ..mangaId = manga.id
          ..mangaTitle = manga.title
          ..chapterTitle = chapter.title
          ..chapterNumber = chapter.number ?? 0
          ..status = DownloadStatus.pending
          ..queuedAt = DateTime.now());
        shouldSchedule = true;
      }
    });

    if (shouldSchedule) await _scheduleQueue(isar);
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

  Future<void> cancel(int downloadId) async {
    final isar = ref.read(isarProvider);
    final entry = await isar.downloadEntrys.get(downloadId);
    await isar.writeTxn(() => isar.downloadEntrys.delete(downloadId));
    if (entry == null) return;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documentsDirectory.path}/downloads/${entry.mangaId}/${entry.chapterId}',
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> retry(int downloadId) => resume(downloadId);

  Future<void> _scheduleQueue(Isar isar) async {
    if (Platform.isAndroid) {
      await DownloadBackgroundService.scheduleQueue();
      return;
    }

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
