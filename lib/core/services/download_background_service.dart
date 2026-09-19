import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../database/isar_service.dart';
import '../database/models/chapter_entry.dart';
import '../database/models/download_entry.dart';
import '../database/models/manga_entry.dart';
import '../extensions/extension_factory.dart';
import '../extensions/source_interface.dart';
import 'app_logger.dart';
import 'downloaded_chapter_files.dart';
import 'library_update_service.dart';

const completedDownloadRetention = Duration(minutes: 2);

const _downloadQueueTask = 'yomi.download.queue';
const _downloadCleanupTask = 'yomi.download.cleanup';
const _downloadQueueWork = 'yomi-download-queue';
const _downloadCleanupWorkPrefix = 'yomi-download-cleanup';
const _downloadLocationPreference = 'settings.downloadLocation';
const _wifiOnlyPreference = 'settings.wifiOnly';

DownloadQueueProcessor? _activeBackgroundProcessor;

@pragma('vm:entry-point')
void downloadCallbackDispatcher() {
  Workmanager().executeTask(
    (taskName, inputData) async {
      DartPluginRegistrant.ensureInitialized();
      final isar = Isar.getInstance() ?? await IsarService.init();

      try {
        if (taskName == _downloadQueueTask) {
          final processor = DownloadQueueProcessor();
          _activeBackgroundProcessor = processor;
          await processor.processQueue(isar);
          _activeBackgroundProcessor = null;
          return true;
        }

        if (taskName == _downloadCleanupTask) {
          await deleteExpiredCompletedDownloadRecords(isar);
          return true;
        }

        if (taskName == libraryUpdateTask) {
          return runLibraryUpdateTask(isar);
        }

        return false;
      } catch (error, stackTrace) {
        AppLogger.instance.error(
          'Background download task failed',
          error,
          stackTrace,
        );
        return false;
      } finally {
        _activeBackgroundProcessor = null;
      }
    },
    onTaskStopped: (_, __) async {
      _activeBackgroundProcessor?.stop();
    },
  );
}

abstract final class DownloadBackgroundService {
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(downloadCallbackDispatcher);
  }

  /// Repairs queue state left by the old in-process downloader or by an OS
  /// interruption, then makes sure every pending item has durable work behind
  /// it. This is safe to call on every app launch.
  static Future<void> reconcileOnStartup(Isar isar) async {
    if (!Platform.isAndroid) return;
    await deleteDuplicateDownloadRecords(isar);
    await deleteExpiredCompletedDownloadRecords(isar);

    final interrupted = await isar.downloadEntrys
        .filter()
        .statusEqualTo(DownloadStatus.downloading)
        .findAll();
    if (interrupted.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final entry in interrupted) {
          entry
            ..status = DownloadStatus.pending
            ..errorMessage = null;
          await isar.downloadEntrys.put(entry);
        }
      });
    }

    final completed = await isar.downloadEntrys
        .filter()
        .statusEqualTo(DownloadStatus.completed)
        .findAll();
    for (final entry in completed) {
      final completedAt = entry.completedAt;
      if (completedAt == null) continue;
      final delay = completedAt
          .add(completedDownloadRetention)
          .difference(DateTime.now());
      await scheduleCleanup(
        entry.id,
        delay: delay.isNegative ? Duration.zero : delay,
      );
    }

    final pending = await isar.downloadEntrys
        .filter()
        .statusEqualTo(DownloadStatus.pending)
        .findFirst();
    if (pending != null) await scheduleQueue();
  }

  static Future<void> scheduleQueue() async {
    if (!Platform.isAndroid) return;
    final preferences = await SharedPreferences.getInstance();
    final wifiOnly = preferences.getBool(_wifiOnlyPreference) ?? false;
    await Workmanager().registerOneOffTask(
      _downloadQueueWork,
      _downloadQueueTask,
      // APPEND_OR_REPLACE keeps enqueue operations sequential without letting
      // an old failed chain permanently poison future downloads.
      existingWorkPolicy: ExistingWorkPolicy.update,
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
        requiresStorageNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 15),
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'Downloading chapters',
        notificationText: 'Yomi will keep downloading in the background',
        notificationChannelId: 'yomi_chapter_downloads',
        notificationChannelName: 'Chapter downloads',
        foregroundServiceType: ForegroundServiceType.dataSync,
      ),
    );
  }

  static Future<void> scheduleCleanup(
    int downloadId, {
    Duration delay = completedDownloadRetention,
  }) async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerOneOffTask(
      '$_downloadCleanupWorkPrefix-$downloadId',
      _downloadCleanupTask,
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}

class DownloadQueueProcessor {
  DownloadQueueProcessor({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ));

  final Dio _dio;
  CancelToken? _activeRequest;
  bool _stopRequested = false;

  void stop() {
    _stopRequested = true;
    _activeRequest?.cancel('Background worker stopped');
  }

  Future<void> processQueue(Isar isar) async {
    await _recoverInterruptedEntries(isar);

    while (!_stopRequested) {
      final pending = await isar.downloadEntrys
          .filter()
          .statusEqualTo(DownloadStatus.pending)
          .sortByQueuedAt()
          .findFirst();
      if (pending == null) return;
      await _downloadChapter(isar, pending.id);
    }
  }

  Future<void> _recoverInterruptedEntries(Isar isar) async {
    final entries = await isar.downloadEntrys
        .filter()
        .statusEqualTo(DownloadStatus.downloading)
        .findAll();
    if (entries.isEmpty) return;

    await isar.writeTxn(() async {
      for (final entry in entries) {
        entry
          ..status = DownloadStatus.pending
          ..errorMessage = null;
        await isar.downloadEntrys.put(entry);
      }
    });
  }

  Future<void> _downloadChapter(Isar isar, int downloadId) async {
    var entry = await isar.downloadEntrys.get(downloadId);
    if (entry == null || entry.status != DownloadStatus.pending) return;

    await isar.writeTxn(() async {
      final current = await isar.downloadEntrys.get(downloadId);
      if (current == null || current.status != DownloadStatus.pending) return;
      current
        ..status = DownloadStatus.downloading
        ..startedAt = DateTime.now()
        ..errorMessage = null;
      await isar.downloadEntrys.put(current);
    });

    entry = await isar.downloadEntrys.get(downloadId);
    if (entry == null || entry.status != DownloadStatus.downloading) return;
    final chapterId = entry.chapterId;

    final cancelToken = CancelToken();
    _activeRequest = cancelToken;
    final statusSubscription = isar.downloadEntrys
        .watchObject(downloadId, fireImmediately: true)
        .listen((current) {
      if (current == null || current.status != DownloadStatus.downloading) {
        cancelToken.cancel('Download paused or cancelled');
      }
    });

    try {
      final chapter = await isar.chapterEntrys.get(entry.chapterId);
      final manga = await isar.mangaEntrys.get(entry.mangaId);
      if (chapter == null || manga == null) {
        throw StateError('Chapter or manga is missing from the database');
      }

      final source = ExtensionFactory.create(manga.sourceId);
      if (source == null) {
        throw StateError('Source "${manga.sourceId}" is not installed');
      }

      final preferences = await SharedPreferences.getInstance();
      if ((preferences.getInt(_downloadLocationPreference) ?? 0) != 0) {
        throw StateError(
          'Google Drive download storage is not yet configured. '
          'Change to Local Storage in Settings → Downloads.',
        );
      }

      final pageUrls = await source.fetchPageUrls(chapter.sourceChapterId);
      if (pageUrls.isEmpty) {
        throw StateError('The source returned no pages for this chapter');
      }
      await _updateTotalPages(isar, downloadId, pageUrls.length);

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final chapterDirectory = Directory(
        '${documentsDirectory.path}/downloads/${entry.mangaId}/${entry.chapterId}',
      );
      await chapterDirectory.create(recursive: true);

      final expectedPaths = <String>{
        for (var index = 0; index < pageUrls.length; index++)
          '${chapterDirectory.path}/page_${index.toString().padLeft(4, '0')}'
              '${downloadedPageExtension(pageUrls[index])}',
      };
      final existingPages =
          await findDownloadedPagePaths(chapterDirectory.path);
      for (final existingPage in existingPages) {
        if (!expectedPaths.contains(existingPage)) {
          await File(existingPage).delete();
        }
      }

      for (var index = 0; index < pageUrls.length; index++) {
        if (_stopRequested) {
          await _returnToPending(isar, downloadId);
          return;
        }
        final current = await isar.downloadEntrys.get(downloadId);
        if (current == null || current.status != DownloadStatus.downloading) {
          return;
        }

        final pageName = 'page_${index.toString().padLeft(4, '0')}'
            '${downloadedPageExtension(pageUrls[index])}';
        final destination = File('${chapterDirectory.path}/$pageName');
        final partial = File('${destination.path}.part');

        if (await destination.exists() && await destination.length() > 0) {
          await _updateDownloadedPages(isar, downloadId, index + 1);
          continue;
        }
        if (await partial.exists()) await partial.delete();

        await _dio.download(
          pageUrls[index],
          partial.path,
          cancelToken: cancelToken,
          deleteOnError: true,
          options: _downloadOptions(source),
        );

        final afterRequest = await isar.downloadEntrys.get(downloadId);
        if (afterRequest == null ||
            afterRequest.status != DownloadStatus.downloading) {
          if (await partial.exists()) await partial.delete();
          return;
        }

        if (await destination.exists()) await destination.delete();
        await partial.rename(destination.path);
        await _updateDownloadedPages(isar, downloadId, index + 1);
      }

      final downloadedPages =
          await findDownloadedPagePaths(chapterDirectory.path);
      if (downloadedPages.length != pageUrls.length) {
        throw FileSystemException(
          'Downloaded ${downloadedPages.length} of ${pageUrls.length} pages',
          chapterDirectory.path,
        );
      }

      final completedAt = DateTime.now();
      await isar.writeTxn(() async {
        final current = await isar.downloadEntrys.get(downloadId);
        if (current == null || current.status != DownloadStatus.downloading) {
          return;
        }
        current
          ..status = DownloadStatus.completed
          ..downloadPath = chapterDirectory.path
          ..downloadedPages = pageUrls.length
          ..completedAt = completedAt
          ..errorMessage = null;
        await isar.downloadEntrys.put(current);

        final currentChapter = await isar.chapterEntrys.get(chapterId);
        if (currentChapter != null) {
          currentChapter
            ..isDownloaded = true
            ..downloadPath = chapterDirectory.path
            ..pageCount = pageUrls.length
            ..downloadedAt = completedAt;
          await isar.chapterEntrys.put(currentChapter);
        }
      });

      await DownloadBackgroundService.scheduleCleanup(downloadId);
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error)) {
        if (_stopRequested) await _returnToPending(isar, downloadId);
        return;
      }
      await _markFailed(isar, downloadId, error, stackTrace);
    } catch (error, stackTrace) {
      await _markFailed(isar, downloadId, error, stackTrace);
    } finally {
      await statusSubscription.cancel();
      if (identical(_activeRequest, cancelToken)) _activeRequest = null;
    }
  }

  Options? _downloadOptions(MangaSource source) => source.imageHeaders.isEmpty
      ? null
      : Options(headers: source.imageHeaders);

  Future<void> _updateTotalPages(
    Isar isar,
    int downloadId,
    int totalPages,
  ) async {
    await isar.writeTxn(() async {
      final current = await isar.downloadEntrys.get(downloadId);
      if (current == null || current.status != DownloadStatus.downloading) {
        return;
      }
      current.totalPages = totalPages;
      await isar.downloadEntrys.put(current);
    });
  }

  Future<void> _updateDownloadedPages(
    Isar isar,
    int downloadId,
    int downloadedPages,
  ) async {
    await isar.writeTxn(() async {
      final current = await isar.downloadEntrys.get(downloadId);
      if (current == null || current.status != DownloadStatus.downloading) {
        return;
      }
      current.downloadedPages = downloadedPages;
      await isar.downloadEntrys.put(current);
    });
  }

  Future<void> _returnToPending(Isar isar, int downloadId) async {
    await isar.writeTxn(() async {
      final current = await isar.downloadEntrys.get(downloadId);
      if (current == null || current.status != DownloadStatus.downloading) {
        return;
      }
      current.status = DownloadStatus.pending;
      await isar.downloadEntrys.put(current);
    });
  }

  Future<void> _markFailed(
    Isar isar,
    int downloadId,
    Object error,
    StackTrace stackTrace,
  ) async {
    await isar.writeTxn(() async {
      final current = await isar.downloadEntrys.get(downloadId);
      if (current == null || current.status != DownloadStatus.downloading) {
        return;
      }
      current
        ..status = DownloadStatus.failed
        ..errorMessage = error.toString()
        ..retryCount = current.retryCount + 1;
      await isar.downloadEntrys.put(current);
    });
    AppLogger.instance.warn(
      'Chapter download $downloadId failed',
      error,
      stackTrace,
    );
  }
}

bool isCompletedDownloadExpired(
  DownloadEntry entry,
  DateTime now,
) {
  final completedAt = entry.completedAt;
  return entry.status == DownloadStatus.completed &&
      completedAt != null &&
      !completedAt.add(completedDownloadRetention).isAfter(now);
}

Future<int> deleteDuplicateDownloadRecords(Isar isar) async {
  final entries = await isar.downloadEntrys.where().findAll();
  final keepByChapter = <int, DownloadEntry>{};
  final duplicateIds = <int>[];

  for (final entry in entries) {
    final existing = keepByChapter[entry.chapterId];
    if (existing == null) {
      keepByChapter[entry.chapterId] = entry;
      continue;
    }

    if (_isPreferredDownloadRecord(entry, existing)) {
      duplicateIds.add(existing.id);
      keepByChapter[entry.chapterId] = entry;
    } else {
      duplicateIds.add(entry.id);
    }
  }

  if (duplicateIds.isEmpty) return 0;
  return isar.writeTxn(() => isar.downloadEntrys.deleteAll(duplicateIds));
}

bool _isPreferredDownloadRecord(
  DownloadEntry candidate,
  DownloadEntry existing,
) {
  final candidateRank = _downloadStatusRank(candidate.status);
  final existingRank = _downloadStatusRank(existing.status);
  if (candidateRank != existingRank) return candidateRank > existingRank;

  final candidateTime =
      candidate.completedAt ?? candidate.startedAt ?? candidate.queuedAt;
  final existingTime =
      existing.completedAt ?? existing.startedAt ?? existing.queuedAt;
  if (candidateTime == null) return false;
  if (existingTime == null) return true;
  return candidateTime.isAfter(existingTime);
}

int _downloadStatusRank(String status) => switch (status) {
      DownloadStatus.completed => 5,
      DownloadStatus.downloading => 4,
      DownloadStatus.pending => 3,
      DownloadStatus.paused => 2,
      DownloadStatus.failed => 1,
      _ => 0,
    };

Future<int> deleteExpiredCompletedDownloadRecords(
  Isar isar, {
  DateTime? now,
}) async {
  final completed = await isar.downloadEntrys
      .filter()
      .statusEqualTo(DownloadStatus.completed)
      .findAll();
  final currentTime = now ?? DateTime.now();
  final expiredIds = completed
      .where((entry) => isCompletedDownloadExpired(entry, currentTime))
      .map((entry) => entry.id)
      .toList();
  if (expiredIds.isEmpty) return 0;
  return isar.writeTxn(() => isar.downloadEntrys.deleteAll(expiredIds));
}
