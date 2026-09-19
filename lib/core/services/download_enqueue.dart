import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/download_entry.dart';
import '../database/models/manga_entry.dart';
import 'download_background_service.dart';

/// Riverpod-free download helpers shared by the UI `DownloadManager` and the
/// background library-update isolate (which has no ProviderContainer).
/// Preferences are read straight from SharedPreferences by these keys; the
/// matching StateProviders live in settings_provider.dart.
const autoDownloadNewChaptersPrefKey = 'settings.autoDownloadNewChapters';
const removeAfterReadPrefKey = 'settings.removeAfterRead';
const downloadAheadPrefKey = 'settings.downloadAhead';

/// Queues [chapterIds] of [mangaId], skipping chapters that are already
/// downloaded or already pending/downloading/completed in the queue. Paused
/// and failed records are re-queued. Returns how many were queued and
/// schedules the background queue when that is more than zero.
Future<int> enqueueNewChapters(
  Isar isar, {
  required int mangaId,
  required List<int> chapterIds,
}) async {
  final manga = await isar.mangaEntrys.get(mangaId);
  if (manga == null || chapterIds.isEmpty) return 0;

  var queued = 0;
  final now = DateTime.now();
  await isar.writeTxn(() async {
    for (final chapterId in chapterIds) {
      final chapter = await isar.chapterEntrys.get(chapterId);
      if (chapter == null ||
          chapter.mangaId != mangaId ||
          chapter.isDownloaded) {
        continue;
      }

      final existing = await isar.downloadEntrys
          .filter()
          .chapterIdEqualTo(chapterId)
          .findFirst();
      if (existing != null &&
          existing.status != DownloadStatus.paused &&
          existing.status != DownloadStatus.failed) {
        continue;
      }

      final entry = existing ??
          (DownloadEntry()
            ..chapterId = chapterId
            ..mangaId = mangaId
            ..mangaTitle = manga.title
            ..chapterTitle = chapter.title
            ..chapterNumber = chapter.number ?? 0);
      entry
        ..status = DownloadStatus.pending
        ..errorMessage = null
        // Offset keeps the caller's order under sortByQueuedAt.
        ..queuedAt = now.add(Duration(milliseconds: queued));
      await isar.downloadEntrys.put(entry);
      queued++;
    }
  });

  if (queued > 0) await DownloadBackgroundService.scheduleQueue();
  return queued;
}

/// Queues the next N ("Download ahead" setting) unread, not-downloaded
/// chapters after [currentChapterId], by ascending chapter number.
Future<void> enqueueAhead(
  Isar isar, {
  required int mangaId,
  required int currentChapterId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final ahead = prefs.getInt(downloadAheadPrefKey) ?? 0;
  if (ahead <= 0) return;

  final number = (await isar.chapterEntrys.get(currentChapterId))?.number;
  if (number == null) return;

  final next = await isar.chapterEntrys
      .filter()
      .mangaIdEqualTo(mangaId)
      .numberGreaterThan(number)
      .isReadEqualTo(false)
      .isDownloadedEqualTo(false)
      .sortByNumber()
      .limit(ahead)
      .findAll();
  if (next.isEmpty) return;
  await enqueueNewChapters(
    isar,
    mangaId: mangaId,
    chapterIds: [for (final chapter in next) chapter.id],
  );
}

/// When "Remove downloaded chapter after reading" is on, deletes every read,
/// downloaded chapter of [mangaId].
// ponytail: also removes the chapter still open in the reader (it is marked
// read on its last page). Decoded pages stay in the image cache, but paging
// back to an evicted page fails. Move the call to reader close if that bites.
Future<void> deleteReadDownloads(Isar isar, int mangaId) async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(removeAfterReadPrefKey) ?? false)) return;

  final read = await isar.chapterEntrys
      .filter()
      .mangaIdEqualTo(mangaId)
      .isReadEqualTo(true)
      .isDownloadedEqualTo(true)
      .findAll();
  await deleteChapterDownloads(
    isar,
    mangaId: mangaId,
    chapterIds: [for (final chapter in read) chapter.id],
  );
}

/// Removes the on-disk pages and queue records for [chapterIds] of [mangaId]
/// and clears the chapters' downloaded state so the reader streams again.
Future<void> deleteChapterDownloads(
  Isar isar, {
  required int mangaId,
  required List<int> chapterIds,
}) async {
  if (chapterIds.isEmpty) return;
  final documents = await getApplicationDocumentsDirectory();
  final paths = <String>[];

  await isar.writeTxn(() async {
    for (final chapterId in chapterIds) {
      await isar.downloadEntrys
          .filter()
          .chapterIdEqualTo(chapterId)
          .deleteAll();
      final chapter = await isar.chapterEntrys.get(chapterId);
      paths.add(chapter?.downloadPath ??
          '${documents.path}/downloads/$mangaId/$chapterId');
      if (chapter == null) continue;
      chapter
        ..isDownloaded = false
        ..downloadPath = null
        ..pageCount = 0
        ..downloadedAt = null;
      await isar.chapterEntrys.put(chapter);
    }
  });

  for (final path in paths) {
    final directory = Directory(path);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
