import 'dart:math' as math;

import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/download_entry.dart';
import '../database/models/manga_entry.dart';
import '../extensions/models/manga_summary.dart';
import '../extensions/source_interface.dart';
import '../providers/browse_provider.dart';
import 'download_enqueue.dart';

Future<List<MangaEntry>> titlesNeedingMigration(
    Isar isar, Set<String> installedSourceIds) async {
  final titles = await isar.mangaEntrys
      .filter()
      .inLibraryEqualTo(true)
      .sortByTitle()
      .findAll();
  return titles.where((m) => !installedSourceIds.contains(m.sourceId)).toList();
}

class MigrationCandidate {
  const MigrationCandidate(this.source, this.summary, this.score);
  final MangaSource source;
  final MangaSummary summary;
  final double score;
}

String normalizeMigrationTitle(String title) {
  var text = title.toLowerCase();
  // ponytail: fold Latin diacritics inline; preserve other scripts, without
  // attempting translation or romanisation of alternative titles.
  const folds = {
    'a': 'àáâãäåāăąǎạảấầẩẫậắằẳẵặ',
    'c': 'çćĉċč',
    'd': 'ďđð',
    'e': 'èéêëēĕėęěẹẻẽếềểễệ',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįıǐịỉ',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņňŋ',
    'o': 'òóôõöøōŏőǒơọỏốồổỗộớờởỡợ',
    'r': 'ŕŗř',
    's': 'śŝşšș',
    't': 'ţťŧț',
    'u': 'ùúûüũūŭůűųǔưụủứừửữự',
    'w': 'ŵ',
    'y': 'ýÿŷỳỵỷỹ',
    'z': 'źżž',
    'ae': 'æ',
    'oe': 'œ',
    'ss': 'ß',
    'th': 'þ',
  };
  for (final fold in folds.entries) {
    for (final rune in fold.value.runes) {
      text = text.replaceAll(String.fromCharCode(rune), fold.key);
    }
  }
  text = text
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\(\s*official\s*\)'), ' ')
      .replaceAll(RegExp(r'\bseason\s+\d+\b'), ' ');
  text = RegExp(r'[\p{L}\p{N}]+', unicode: true)
      .allMatches(text)
      .map((m) => m.group(0)!)
      .join(' ');
  return text.replaceFirst(RegExp(r'\s+(?:19|20)\d{2}$'), '').trim();
}

/// Token Dice, in [0, 1]. Empty/punctuation-only titles never score a match.
double migrationTitleSimilarity(String a, String b) {
  final left = normalizeMigrationTitle(a);
  final right = normalizeMigrationTitle(b);
  if (left.isEmpty || right.isEmpty) return 0;
  final x = left.split(' ').toSet();
  final y = right.split(' ').toSet();
  return 2 * x.intersection(y).length / (x.length + y.length);
}

Future<List<MigrationCandidate>> findCandidates(
  MangaEntry manga,
  List<MangaSource> sources, {
  Duration perSourceTimeout = const Duration(seconds: 12),
}) async {
  final candidates = <MigrationCandidate>[];
  var next = 0;
  Future<void> worker() async {
    while (next < sources.length) {
      final source = sources[next++];
      try {
        final results =
            await source.search(manga.title).timeout(perSourceTimeout);
        final seen = <String>{};
        for (final result in results) {
          if (result.id.trim().isEmpty ||
              !seen.add(result.id) ||
              '${source.id}::${result.id}' == manga.sourceKey) {
            continue;
          }
          candidates.add(MigrationCandidate(source, result,
              migrationTitleSimilarity(manga.title, result.title)));
        }
      } catch (_) {
        // One broken source must not hide the other sources' results.
      }
    }
  }

  // ponytail: first search page only, four workers. MangaSource has no cancel
  // API, so timed-out transport requests finish under the source's own timeout.
  await Future.wait(
      List.generate(math.min(4, sources.length), (_) => worker()));
  candidates.sort((a, b) {
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    final source = a.source.id.compareTo(b.source.id);
    return source != 0 ? source : a.summary.id.compareTo(b.summary.id);
  });
  return candidates;
}

bool sameChapterNumber(double? a, double? b) =>
    a != null && b != null && a.isFinite && b.isFinite && (a - b).abs() <= 1e-6;

DateTime? latestDate(DateTime? a, DateTime? b) => a == null
    ? b
    : b == null || a.isAfter(b)
        ? a
        : b;

DateTime? earliestDate(DateTime? a, DateTime? b) => a == null
    ? b
    : b == null || a.isBefore(b)
        ? a
        : b;

/// Returns fresh destination rows; neither input is mutated. All scanlator
/// variants of a number share the furthest read state. Null numbers never match.
/// Downloads are deliberately handled separately, one file set per chapter.
List<ChapterEntry> mapChapterState(
    List<ChapterEntry> oldChapters, List<ChapterEntry> newChapters) {
  return newChapters.map((chapter) {
    final mapped = ChapterEntry()
      ..id = chapter.id
      ..mangaId = chapter.mangaId
      ..sourceChapterId = chapter.sourceChapterId
      ..title = chapter.title
      ..number = chapter.number
      ..volume = chapter.volume
      ..scanlator = chapter.scanlator
      ..language = chapter.language
      ..isRead = chapter.isRead
      ..isDownloaded = chapter.isDownloaded
      ..downloadPath = chapter.downloadPath
      ..pageCount = chapter.pageCount
      ..lastPageRead = chapter.lastPageRead
      ..uploadDate = chapter.uploadDate
      ..readAt = chapter.readAt
      ..downloadedAt = chapter.downloadedAt
      ..dateFetched = chapter.dateFetched;
    for (final old in oldChapters) {
      if (!sameChapterNumber(old.number, chapter.number)) continue;
      mapped
        ..isRead = mapped.isRead || old.isRead
        ..readAt = latestDate(mapped.readAt, old.readAt)
        ..lastPageRead = math.max(mapped.lastPageRead, old.lastPageRead);
    }
    return mapped;
  }).toList();
}

const titlePreferencePrefixes = [
  'reader.direction.manga.',
  'reader.mode.manga.',
  'chapters.sort.',
  'chapters.filter.',
];

/// Copies per-title preferences without replacing values already chosen for
/// the destination title.
Future<void> copyTitlePreferences(
  SharedPreferences prefs, {
  required int fromId,
  required int toId,
}) async {
  for (final prefix in titlePreferencePrefixes) {
    final value = prefs.getInt('$prefix$fromId');
    if (value != null && !prefs.containsKey('$prefix$toId')) {
      if (!await prefs.setInt('$prefix$toId', value)) {
        throw StateError(
            'Could not copy reading preferences. Your old title is kept.');
      }
    }
  }
}

Future<void> removeTitlePreferences(
    SharedPreferences prefs, Iterable<int> mangaIds) async {
  for (final mangaId in mangaIds) {
    for (final prefix in titlePreferencePrefixes) {
      await prefs.remove('$prefix$mangaId');
    }
  }
}

class ChapterDownloadMerge {
  const ChapterDownloadMerge({
    required this.targetsBySourceChapterId,
    required this.downloadsToDelete,
  });

  final Map<int, ChapterEntry> targetsBySourceChapterId;
  final List<ChapterEntry> downloadsToDelete;
}

/// Rebinds exact-number downloads onto free destination chapters. Destination
/// rows are mutated so they can be persisted with the mapped reading state.
ChapterDownloadMerge planChapterDownloadMerge(
  List<ChapterEntry> sourceChapters,
  List<ChapterEntry> destinationChapters, {
  required bool deleteUnmatched,
  String blockedMessage = 'Some downloads have no free matching chapter. '
      'Choose another match or allow their deletion. Your old title is kept.',
}) {
  final targets = <int, ChapterEntry>{};
  final deletions = <ChapterEntry>[];
  for (final chapter in sourceChapters.where((c) => c.isDownloaded)) {
    final matches = destinationChapters
        .where((c) =>
            sameChapterNumber(chapter.number, c.number) && !c.isDownloaded)
        .toList()
      ..sort((a, b) => (b.scanlator == chapter.scanlator ? 1 : 0)
          .compareTo(a.scanlator == chapter.scanlator ? 1 : 0));
    // ponytail: never guess for unnumbered downloads, and never let two
    // chapter variants share one directory (deleting either would break both).
    if (matches.isEmpty) {
      if (!deleteUnmatched) throw StateError(blockedMessage);
      deletions.add(chapter);
      continue;
    }
    final match = matches.first
      ..isDownloaded = true
      ..downloadPath = chapter.downloadPath
      ..pageCount = chapter.pageCount
      ..downloadedAt = chapter.downloadedAt;
    targets[chapter.id] = match;
  }
  return ChapterDownloadMerge(
      targetsBySourceChapterId: targets, downloadsToDelete: deletions);
}

/// Moves completed download rows to their rebound chapter and removes every
/// stale/active row that still belongs to a discarded title.
Future<void> mergeDownloadQueueRows(
  Isar isar, {
  required List<DownloadEntry> sourceQueue,
  required List<DownloadEntry> targetQueue,
  required MangaEntry destination,
  required Map<int, ChapterEntry> targetsBySourceChapterId,
}) async {
  final targetChapterIds =
      targetsBySourceChapterId.values.map((chapter) => chapter.id).toSet();
  for (final download in targetQueue) {
    if (targetChapterIds.contains(download.chapterId)) {
      await isar.downloadEntrys.delete(download.id);
    }
  }
  for (final download in sourceQueue) {
    final match = targetsBySourceChapterId[download.chapterId];
    if (match == null) {
      await isar.downloadEntrys.delete(download.id);
      continue;
    }
    download
      ..mangaId = destination.id
      ..chapterId = match.id
      ..mangaTitle = destination.title
      ..chapterTitle = match.title
      ..chapterNumber = match.number!
      ..downloadPath = match.downloadPath
      ..status = DownloadStatus.completed
      ..totalPages = match.pageCount
      ..downloadedPages = match.pageCount
      ..completedAt = match.downloadedAt ?? DateTime.now()
      ..errorMessage = null;
    await isar.downloadEntrys.put(download);
  }
}

/// Removes a title and all rows that cannot outlive it. Call inside the
/// caller's transaction, after any valid download rows have been rebound.
Future<void> deleteMangaRows(
  Isar isar, {
  required MangaEntry manga,
  required List<ChapterEntry> chapters,
}) async {
  await isar.downloadEntrys.filter().mangaIdEqualTo(manga.id).deleteAll();
  await isar.chapterEntrys.deleteAll(chapters.map((c) => c.id).toList());
  await isar.mangaEntrys.delete(manga.id);
}

Future<MangaEntry> migrate(
  Isar isar, {
  required MangaEntry from,
  required MangaSource to,
  required MangaSummary target,
  bool keepDownloads = true,
}) async {
  if (from.sourceKey == '${to.id}::${target.id}') {
    throw StateError('Choose a different title or source.');
  }
  if (await isar.mangaEntrys.get(from.id) == null) {
    throw StateError('This title has already moved or was removed.');
  }
  final destination = await upsertMangaEntry(
      isar: isar, source: to, mangaId: target.id, summary: target);
  await refreshMangaChapters(
      isar: isar,
      source: to,
      mangaId: destination.id,
      sourceMangaId: target.id);
  if (await isar.chapterEntrys
          .filter()
          .mangaIdEqualTo(destination.id)
          .count() ==
      0) {
    throw StateError(
        'The new source returned no chapters. Your old title is kept.');
  }

  final prefs = await SharedPreferences.getInstance();
  if (!keepDownloads) {
    final chapters =
        await isar.chapterEntrys.filter().mangaIdEqualTo(from.id).findAll();
    await deleteChapterDownloads(isar,
        mangaId: from.id, chapterIds: chapters.map((c) => c.id).toList());
  }

  final migrated = await isar.writeTxn(() async {
    final old = await isar.mangaEntrys.get(from.id);
    final entry = await isar.mangaEntrys.get(destination.id);
    if (old == null || entry == null) {
      throw StateError('The title was removed.');
    }
    final oldChapters =
        await isar.chapterEntrys.filter().mangaIdEqualTo(old.id).findAll();
    final newChapters = mapChapterState(oldChapters,
        await isar.chapterEntrys.filter().mangaIdEqualTo(entry.id).findAll());
    final queue =
        await isar.downloadEntrys.filter().mangaIdEqualTo(old.id).findAll();
    final targetQueue =
        await isar.downloadEntrys.filter().mangaIdEqualTo(entry.id).findAll();
    final downloadMerge = planChapterDownloadMerge(
        keepDownloads ? oldChapters : const <ChapterEntry>[], newChapters,
        deleteUnmatched: false,
        blockedMessage: 'Some downloads have no free matching chapter. '
            'Choose another match or turn off Keep downloads. Your old title is kept.');

    // ponytail: preferences/files cannot roll back with Isar. Copy only after
    // validation and before deleting the old row; remove old keys after commit.
    // Existing destination overrides win when merging two library titles.
    await copyTitlePreferences(prefs, fromId: old.id, toId: entry.id);

    // Removing queue rows also cancels active requests. The existing worker
    // rechecks the row/status inside its completion transaction before writing.
    // A target queue row must not overwrite the transferred local pages.
    await mergeDownloadQueueRows(isar,
        sourceQueue: queue,
        targetQueue: targetQueue,
        destination: entry,
        targetsBySourceChapterId: downloadMerge.targetsBySourceChapterId);
    entry
      ..inLibrary = true
      ..categories = {...entry.categories, ...old.categories}.toList()
      ..addedToLibrary = earliestDate(entry.addedToLibrary, old.addedToLibrary)
      ..chapterCount = newChapters.length
      ..unreadCount = newChapters.where((c) => !c.isRead).length;
    if (entry.lastReadAt == null ||
        (old.lastReadAt != null &&
            !old.lastReadAt!.isBefore(entry.lastReadAt!))) {
      double? number = old.lastReadChapterNumber;
      for (final chapter in oldChapters) {
        if (chapter.sourceChapterId == old.lastReadChapterId) {
          number = chapter.number ?? number;
          break;
        }
      }
      final matches =
          newChapters.where((c) => sameChapterNumber(number, c.number));
      final match = matches.isEmpty ? null : matches.first;
      entry
        ..lastReadAt = old.lastReadAt
        ..lastReadChapterId = match?.sourceChapterId
        ..lastReadChapterNumber = match?.number
        ..lastReadPage =
            match == null ? 0 : math.max(old.lastReadPage, match.lastPageRead);
    }
    await isar.chapterEntrys.putAll(newChapters);
    await isar.mangaEntrys.put(entry);
    await deleteMangaRows(isar, manga: old, chapters: oldChapters);
    return entry;
  });
  await removeTitlePreferences(prefs, [from.id]);
  return migrated;
}
