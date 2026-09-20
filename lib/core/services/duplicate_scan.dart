import 'dart:math' as math;

import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/download_entry.dart';
import '../database/models/manga_entry.dart';
import 'download_enqueue.dart';
import 'source_migration.dart';

const duplicateIgnorePreferenceKey = 'library.duplicates.ignored';

class DuplicateEntryStats {
  const DuplicateEntryStats({
    required this.entry,
    required this.chapterCount,
    required this.readCount,
    required this.downloadedCount,
    required this.addedToLibrary,
  });

  final MangaEntry entry;
  final int chapterCount;
  final int readCount;
  final int downloadedCount;
  final DateTime? addedToLibrary;
}

class DuplicateGroup {
  const DuplicateGroup({
    required this.normalizedTitle,
    required this.title,
    required this.ignoreKey,
    required this.entries,
  });

  final String normalizedTitle;
  final String title;
  final String ignoreKey;
  final List<DuplicateEntryStats> entries;
}

List<DuplicateGroup> groupDuplicates(
  List<MangaEntry> library, {
  Map<int, int> downloadedCounts = const {},
  Set<String> ignoredKeys = const {},
}) {
  final byTitle = <String, List<MangaEntry>>{};
  // ponytail: duplicate detection is exact after migration-title
  // normalisation. It deliberately does not use fuzzy title similarity.
  for (final manga in library.where((entry) => entry.inLibrary)) {
    final title = normalizeMigrationTitle(manga.title);
    byTitle.putIfAbsent(title, () => []).add(manga);
  }

  final groups = <DuplicateGroup>[];
  for (final group in byTitle.entries) {
    if (group.value.length < 2) continue;
    final entries = [...group.value]
      ..sort((a, b) => a.sourceKey.compareTo(b.sourceKey));
    final ignoreKey = entries.map((entry) => entry.sourceKey).join('|');
    if (ignoredKeys.contains(ignoreKey)) continue;
    groups.add(DuplicateGroup(
      normalizedTitle: group.key,
      title: entries.first.title,
      ignoreKey: ignoreKey,
      entries: [
        for (final entry in entries)
          DuplicateEntryStats(
            entry: entry,
            chapterCount: math.max(0, entry.chapterCount),
            readCount: (entry.chapterCount - entry.unreadCount)
                .clamp(0, math.max(0, entry.chapterCount))
                .toInt(),
            downloadedCount: downloadedCounts[entry.id] ?? 0,
            addedToLibrary: entry.addedToLibrary,
          ),
      ],
    ));
  }
  groups.sort((a, b) => a.normalizedTitle.compareTo(b.normalizedTitle));
  return groups;
}

Future<List<DuplicateGroup>> findDuplicateGroups(
  Isar isar, {
  Set<String> ignoredKeys = const {},
}) async {
  final library = await isar.mangaEntrys
      .filter()
      .inLibraryEqualTo(true)
      .sortByTitle()
      .findAll();
  final downloaded =
      await isar.chapterEntrys.filter().isDownloadedEqualTo(true).findAll();
  final counts = <int, int>{};
  for (final chapter in downloaded) {
    counts.update(chapter.mangaId, (count) => count + 1, ifAbsent: () => 1);
  }
  return groupDuplicates(
    library,
    downloadedCounts: counts,
    ignoredKeys: ignoredKeys,
  );
}

Future<Set<String>> loadIgnoredDuplicateKeys() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(duplicateIgnorePreferenceKey) ?? const [])
      .toSet();
}

Future<void> ignoreDuplicateKey(String ignoreKey) async {
  final prefs = await SharedPreferences.getInstance();
  final ignored =
      (prefs.getStringList(duplicateIgnorePreferenceKey) ?? const []).toSet()
        ..add(ignoreKey);
  final sorted = ignored.toList()..sort();
  if (!await prefs.setStringList(duplicateIgnorePreferenceKey, sorted)) {
    throw StateError('Could not remember this duplicate choice.');
  }
}

typedef LibraryImportMatch = ({MangaEntry entry, bool hasDownloads});

Map<String, List<LibraryImportMatch>> indexLibraryTitlesForImport(
  List<MangaEntry> library,
  Set<int> downloadedMangaIds,
) {
  final indexed = <String, List<LibraryImportMatch>>{};
  for (final entry in library.where((manga) => manga.inLibrary)) {
    final title = normalizeMigrationTitle(entry.title);
    indexed.putIfAbsent(title, () => []).add((
      entry: entry,
      hasDownloads: downloadedMangaIds.contains(entry.id),
    ));
  }
  return indexed;
}

class ImportEntryPartition {
  const ImportEntryPartition({
    required this.included,
    required this.excluded,
    required this.defaultUnselectedSourceKeys,
  });

  final List<Map<String, Object?>> included;
  final List<Map<String, Object?>> excluded;
  final Set<String> defaultUnselectedSourceKeys;
}

ImportEntryPartition partitionImportEntries(
  List<Map<String, Object?>> backup, {
  required Map<String, List<LibraryImportMatch>> libraryByNormalizedTitle,
}) {
  final included = <Map<String, Object?>>[];
  final excluded = <Map<String, Object?>>[];
  final defaultUnselected = <String>{};
  for (final manga in backup) {
    final title = manga['title'] as String? ?? '';
    final sourceKey = manga['sourceKey'] as String? ?? '';
    final matches = libraryByNormalizedTitle[normalizeMigrationTitle(title)] ??
        const <LibraryImportMatch>[];
    // An exact source key merges into its existing row and keeps the picker's
    // established selected-by-default behaviour, including local downloads.
    if (matches.any((match) => match.entry.sourceKey == sourceKey)) {
      included.add(manga);
      continue;
    }
    if (matches.any((match) => match.hasDownloads)) {
      excluded.add(manga);
      continue;
    }
    included.add(manga);
    if (matches.isNotEmpty) defaultUnselected.add(sourceKey);
  }
  return ImportEntryPartition(
    included: included,
    excluded: excluded,
    defaultUnselectedSourceKeys: defaultUnselected,
  );
}

Future<void> resolveGroup(
  Isar isar, {
  required DuplicateGroup group,
  required MangaEntry keep,
  required bool deleteDownloads,
}) async {
  final groupIds = group.entries.map((stats) => stats.entry.id).toSet();
  if (!groupIds.contains(keep.id)) {
    throw StateError('The title selected to keep is not in this group.');
  }

  final current = (await isar.mangaEntrys.getAll(groupIds.toList()))
      .whereType<MangaEntry>()
      .toList();
  if (current.length != groupIds.length ||
      current.any((entry) =>
          !entry.inLibrary ||
          normalizeMigrationTitle(entry.title) != group.normalizedTitle)) {
    throw StateError(
        'This duplicate group changed. Scan again before applying.');
  }
  final destination = current.firstWhere((entry) => entry.id == keep.id);
  final discarded = current.where((entry) => entry.id != keep.id).toList()
    ..sort((a, b) => a.sourceKey.compareTo(b.sourceKey));
  if (discarded.isEmpty) return;

  final allChapters = await isar.chapterEntrys.where().findAll();
  final chaptersByManga = <int, List<ChapterEntry>>{};
  for (final chapter
      in allChapters.where((chapter) => groupIds.contains(chapter.mangaId))) {
    chaptersByManga.putIfAbsent(chapter.mangaId, () => []).add(chapter);
  }
  final keepChapters = chaptersByManga[destination.id] ?? const [];
  final discardedChapters = [
    for (final manga in discarded)
      ...chaptersByManga[manga.id] ?? const <ChapterEntry>[],
  ];
  final mergedChapters = mapChapterState(discardedChapters, keepChapters);
  final downloadMerge = planChapterDownloadMerge(
    discardedChapters,
    mergedChapters,
    deleteUnmatched: deleteDownloads,
    blockedMessage: 'Some downloaded chapters cannot be moved to the title '
        'you chose. Allow their deletion or keep both titles.',
  );

  final deletePaths = <String>[];
  for (final chapter in downloadMerge.downloadsToDelete) {
    deletePaths.add(await chapterDownloadPath(
      mangaId: chapter.mangaId,
      chapterId: chapter.id,
      path: chapter.downloadPath,
    ));
  }

  final prefs = await SharedPreferences.getInstance();
  for (final manga in discarded) {
    await copyTitlePreferences(prefs, fromId: manga.id, toId: destination.id);
  }

  final latestRead = _latestReadEntry([destination, ...discarded]);
  final latestNumber = latestRead == null
      ? null
      : _lastReadNumber(latestRead, chaptersByManga[latestRead.id] ?? const []);
  final latestChapter = latestNumber == null
      ? null
      : _firstChapterWithNumber(mergedChapters, latestNumber);
  final queue = await isar.downloadEntrys.where().findAll();
  final discardedIds = discarded.map((entry) => entry.id).toSet();

  await isar.writeTxn(() async {
    await mergeDownloadQueueRows(
      isar,
      sourceQueue: queue
          .where((download) => discardedIds.contains(download.mangaId))
          .toList(),
      targetQueue: queue
          .where((download) => download.mangaId == destination.id)
          .toList(),
      destination: destination,
      targetsBySourceChapterId: downloadMerge.targetsBySourceChapterId,
    );

    destination
      ..inLibrary = true
      ..categories = {
        ...destination.categories,
        for (final manga in discarded) ...manga.categories,
      }.toList()
      ..addedToLibrary = [destination, ...discarded]
          .map((entry) => entry.addedToLibrary)
          .fold<DateTime?>(null, earliestDate)
      ..chapterCount = mergedChapters.length
      ..unreadCount = mergedChapters.where((chapter) => !chapter.isRead).length;
    if (latestRead != null) {
      destination
        ..lastReadAt = latestRead.lastReadAt
        ..lastReadChapterId = latestChapter?.sourceChapterId
        ..lastReadChapterNumber = latestChapter?.number ?? latestNumber
        ..lastReadPage = latestChapter == null
            ? latestRead.lastReadPage
            : math.max(latestRead.lastReadPage, latestChapter.lastPageRead);
    }

    await isar.chapterEntrys.putAll(mergedChapters);
    await isar.mangaEntrys.put(destination);
    for (final manga in discarded) {
      await deleteMangaRows(
        isar,
        manga: manga,
        chapters: chaptersByManga[manga.id] ?? const [],
      );
    }
  });

  await removeTitlePreferences(prefs, discardedIds);
  await deleteDownloadPaths(deletePaths);
}

MangaEntry? _latestReadEntry(List<MangaEntry> entries) {
  MangaEntry? latest;
  for (final entry in entries) {
    if (entry.lastReadAt == null) continue;
    if (latest == null || entry.lastReadAt!.isAfter(latest.lastReadAt!)) {
      latest = entry;
    }
  }
  return latest;
}

double? _lastReadNumber(MangaEntry manga, List<ChapterEntry> chapters) {
  for (final chapter in chapters) {
    if (chapter.sourceChapterId == manga.lastReadChapterId) {
      return chapter.number ?? manga.lastReadChapterNumber;
    }
  }
  return manga.lastReadChapterNumber;
}

ChapterEntry? _firstChapterWithNumber(
    List<ChapterEntry> chapters, double number) {
  for (final chapter in chapters) {
    if (sameChapterNumber(chapter.number, number)) return chapter;
  }
  return null;
}
