import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/services/download_enqueue.dart';
import 'reader_screen.dart';

/// Sources that publish exclusively long-strip webtoons / manhwa / manhua.
/// Titles from these default to the continuous strip reader so the tall
/// images are never cut off by the page reader.
const _webtoonSources = <String>{
  'demonicscans_en',
  'asurascans_en',
  'reaperscans_en',
  'flamescans_en',
};

/// True when [manga] should default to Strip · 縦 (the user can still override
/// per title from the reader's mode switch).
bool isWebtoonManga(MangaEntry manga) {
  if (_webtoonSources.contains(manga.sourceId)) return true;
  return manga.genres.any((g) {
    final lower = g.toLowerCase();
    return lower == 'manhwa' || lower == 'webtoon' || lower == 'manhua';
  });
}

/// Push the reader for `chapters[index]` (chapters newest-first). Opens at the
/// chapter's last read page unless it was finished, so "Continue" lands where
/// the reader left off.
void openReader(
  BuildContext context, {
  required MangaEntry manga,
  required List<ChapterEntry> chapters,
  required int index,
}) {
  if (index < 0 || index >= chapters.length) return;
  HapticFeedback.selectionClick();
  final target = chapters[index];
  final summaries = chapters
      .map((c) => ReaderChapterSummary(
            id: c.id,
            sourceChapterId: c.sourceChapterId,
            title: c.title,
            number: c.number,
            downloadPath: c.downloadPath,
            isRead: c.isRead,
          ))
      .toList();
  Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReaderScreen(
        mangaId: manga.id,
        mangaTitle: manga.title,
        chapterId: target.id,
        sourceId: manga.sourceId,
        sourceChapterId: target.sourceChapterId,
        chapterTitle: target.title,
        chapterNumber: target.number,
        downloadPath: target.downloadPath,
        isWebtoon: isWebtoonManga(manga),
        chapters: summaries,
        chapterIndex: index,
        initialPage: target.isRead ? 0 : target.lastPageRead,
      ),
    ),
  );
  if (Isar.getInstance() case final isar?) {
    unawaited(enqueueAhead(isar,
        mangaId: manga.id, currentChapterId: target.id));
  }
}
