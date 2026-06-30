import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/download_entry.dart';
import '../database/models/manga_entry.dart';
import 'database_provider.dart';
import 'settings_provider.dart';
import 'source_registry_provider.dart';

// ── Queue stream: pending + downloading + paused + failed ─────────────────────

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

/// Returns the current download status for a specific chapter ID.
/// null means the chapter is not in the download queue at all.
final chapterDownloadStatusProvider =
    StreamProvider.family.autoDispose<String?, int>((ref, chapterId) {
  final isar = ref.watch(isarProvider);
  return isar.downloadEntrys
      .filter()
      .chapterIdEqualTo(chapterId)
      .watch(fireImmediately: true)
      .map((list) => list.isEmpty ? null : list.first.status);
});

// ── Manager ───────────────────────────────────────────────────────────────────

class DownloadManager extends AsyncNotifier<void> {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));
  bool _isProcessing = false;

  @override
  Future<void> build() async {}

  Future<void> enqueue({
    required MangaEntry manga,
    required ChapterEntry chapter,
  }) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final exists = await isar.downloadEntrys
          .filter()
          .chapterIdEqualTo(chapter.id)
          .findFirst();
      if (exists != null &&
          (exists.status == DownloadStatus.pending ||
              exists.status == DownloadStatus.downloading ||
              exists.status == DownloadStatus.completed)) {
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
    });
    _processQueue();
  }

  Future<void> enqueueAll({
    required MangaEntry manga,
    required List<ChapterEntry> chapters,
  }) async {
    for (final ch in chapters) {
      await enqueue(manga: manga, chapter: ch);
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
    await isar.writeTxn(() async {
      final entry = await isar.downloadEntrys.get(downloadId);
      if (entry == null) return;
      if (entry.status == DownloadStatus.paused ||
          entry.status == DownloadStatus.failed) {
        entry
          ..status = DownloadStatus.pending
          ..errorMessage = null;
        await isar.downloadEntrys.put(entry);
      }
    });
    _processQueue();
  }

  /// This is the cancel function for the downloads
  Future<void> cancel(int downloadId) async {
    final isar = ref.read(isarProvider);
    final entry = await isar.downloadEntrys.get(downloadId);
    await isar.writeTxn(() => isar.downloadEntrys.delete(downloadId));
    if (entry != null) {
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory(
          '${docDir.path}/downloads/${entry.mangaId}/${entry.chapterId}');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  Future<void> retry(int downloadId) => resume(downloadId);

  void _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    final isar = ref.read(isarProvider);
    final location = ref.read(downloadLocationProvider);
    try {
      while (true) {
        final pending = await isar.downloadEntrys
            .filter()
            .statusEqualTo(DownloadStatus.pending)
            .findFirst();
        if (pending == null) break;
        await _downloadChapter(pending, isar, location);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _downloadChapter(
    DownloadEntry entry,
    Isar isar,
    DownloadLocation location,
  ) async {
    // Re-read from DB to guard against the race condition where the user
    // paused this item between when _processQueue picked it up and now.
    final fresh = await isar.downloadEntrys.get(entry.id);
    if (fresh == null || fresh.status != DownloadStatus.pending) return;

    await isar.writeTxn(() async {
      entry.status = DownloadStatus.downloading;
      entry.startedAt = DateTime.now();
      await isar.downloadEntrys.put(entry);
    });

    try {
      final chapter = await isar.chapterEntrys.get(entry.chapterId);
      final manga = await isar.mangaEntrys.get(entry.mangaId);
      if (chapter == null || manga == null) {
        throw Exception('Chapter/manga missing from database');
      }

      final source = ref.read(sourceByIdProvider(manga.sourceId));
      if (source == null) {
        throw Exception('Source "${manga.sourceId}" is not installed');
      }

      final pageUrls = await source.fetchPageUrls(chapter.sourceChapterId);
      await isar.writeTxn(() async {
        entry.totalPages = pageUrls.length;
        await isar.downloadEntrys.put(entry);
      });

      if (location == DownloadLocation.googleDrive) {
        throw Exception(
          'Google Drive download storage is not yet configured.\n'
          'Change to Local Storage in Settings → Downloads.',
        );
      }

      final docDir = await getApplicationDocumentsDirectory();
      final chapterDir =
          '${docDir.path}/downloads/${entry.mangaId}/${entry.chapterId}';
      await Directory(chapterDir).create(recursive: true);

      for (var i = 0; i < pageUrls.length; i++) {
        // Check if paused mid-download
        final current = await isar.downloadEntrys.get(entry.id);
        if (current?.status == DownloadStatus.paused) return;

        final padded = i.toString().padLeft(4, '0');
        await _dio.download(
          pageUrls[i],
          '$chapterDir/page_$padded${_ext(pageUrls[i])}',
          options: source.imageHeaders.isNotEmpty
              ? Options(headers: source.imageHeaders)
              : null,
        );
        await isar.writeTxn(() async {
          entry.downloadedPages = i + 1;
          await isar.downloadEntrys.put(entry);
        });
      }

      await isar.writeTxn(() async {
        entry
          ..status = DownloadStatus.completed
          ..downloadPath = chapterDir
          ..completedAt = DateTime.now();
        await isar.downloadEntrys.put(entry);
        final ch = await isar.chapterEntrys.get(entry.chapterId);
        if (ch != null) {
          ch
            ..isDownloaded = true
            ..downloadPath = chapterDir
            ..pageCount = pageUrls.length
            ..downloadedAt = DateTime.now();
          await isar.chapterEntrys.put(ch);
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

  String _ext(String url) {
    final path = url.split('?').first.toLowerCase();
    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.webp')) return '.webp';
    if (path.endsWith('.gif')) return '.gif';
    return '.jpg';
  }
}

final downloadManagerProvider =
    AsyncNotifierProvider<DownloadManager, void>(DownloadManager.new);
