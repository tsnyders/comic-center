import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/download_entry.dart';
import '../database/models/manga_entry.dart';
import 'database_provider.dart';

// ── Active download queue stream ─────────────────────────────────────────

final downloadQueueProvider = StreamProvider<List<DownloadEntry>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.downloadEntrys
      .filter()
      .statusEqualTo(DownloadStatus.downloading)
      .or()
      .statusEqualTo(DownloadStatus.pending)
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

// ── Manager ───────────────────────────────────────────────────────────────

class DownloadManager extends AsyncNotifier<void> {
  final _dio = Dio();
  bool _isProcessing = false;

  @override
  Future<void> build() async {}

  Future<void> enqueue({
    required MangaEntry manga,
    required ChapterEntry chapter,
  }) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final entry = DownloadEntry()
        ..chapterId = chapter.id
        ..mangaId = manga.id
        ..mangaTitle = manga.title
        ..chapterTitle = chapter.title
        ..chapterNumber = chapter.number ?? 0
        ..status = DownloadStatus.pending
        ..queuedAt = DateTime.now();
      await isar.downloadEntrys.put(entry);
    });
    _processQueue();
  }

  Future<void> pause(int downloadId) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final entry = await isar.downloadEntrys.get(downloadId);
      if (entry == null) return;
      entry.status = DownloadStatus.paused;
      await isar.downloadEntrys.put(entry);
    });
  }

  Future<void> cancel(int downloadId) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() => isar.downloadEntrys.delete(downloadId));
  }

  void _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    final isar = ref.read(isarProvider);

    try {
      while (true) {
        final pending = await isar.downloadEntrys
            .filter()
            .statusEqualTo(DownloadStatus.pending)
            .findFirst();
        if (pending == null) break;
        await _downloadChapter(pending, isar);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _downloadChapter(
    DownloadEntry entry,
    Isar isar,
  ) async {
    // Mark as downloading
    await isar.writeTxn(() async {
      entry.status = DownloadStatus.downloading;
      entry.startedAt = DateTime.now();
      await isar.downloadEntrys.put(entry);
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final chapterDir =
          '${dir.path}/downloads/${entry.mangaId}/${entry.chapterId}';

      // TODO: fetch page URLs via the source and download each page
      // This is Phase 3 territory — stub for now.

      await isar.writeTxn(() async {
        entry
          ..status = DownloadStatus.completed
          ..downloadPath = chapterDir
          ..completedAt = DateTime.now();
        await isar.downloadEntrys.put(entry);

        final chapter = await isar.chapterEntrys.get(entry.chapterId);
        if (chapter != null) {
          chapter
            ..isDownloaded = true
            ..downloadPath = chapterDir
            ..downloadedAt = DateTime.now();
          await isar.chapterEntrys.put(chapter);
        }
      });
    } catch (e) {
      await isar.writeTxn(() async {
        entry
          ..status = DownloadStatus.failed
          ..errorMessage = e.toString()
          ..retryCount = entry.retryCount + 1;
        await isar.downloadEntrys.put(entry);
      });
    }
  }
}

final downloadManagerProvider =
    AsyncNotifierProvider<DownloadManager, void>(DownloadManager.new);
