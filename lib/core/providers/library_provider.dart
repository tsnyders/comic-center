import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/manga_entry.dart';
import 'database_provider.dart';

// ── Category persistence ──────────────────────────────────────────────────────

class _CategoryStore {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/yomi_categories.json');
  }

  static Future<List<String>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      return (jsonDecode(await f.readAsString()) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<String> cats) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(cats));
  }
}

// ── Category notifier ─────────────────────────────────────────────────────────

class CategoryNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() => _CategoryStore.load();

  /// Merge backup category names in one persisted update.
  Future<void> merge(Iterable<String> names) async {
    final current = await future;
    final updated = {
      ...current,
      ...names.map((name) => name.trim()).where((name) => name.isNotEmpty),
    }.toList()
      ..sort();
    await _CategoryStore.save(updated);
    state = AsyncData(updated);
  }

  Future<void> add(String name) async {
    final t = name.trim();
    if (t.isEmpty) return;
    final current = await future;
    if (current.contains(t)) return;
    final updated = [...current, t]..sort();
    await _CategoryStore.save(updated);
    state = AsyncData(updated);
  }

  Future<void> remove(String name) async {
    final current = await future;
    final updated = current.where((c) => c != name).toList();
    await _CategoryStore.save(updated);
    state = AsyncData(updated);
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final mangas = await isar.mangaEntrys.where().findAll();
      for (final m in mangas) {
        if (m.categories.contains(name)) {
          m.categories = m.categories.where((c) => c != name).toList();
          await isar.mangaEntrys.put(m);
        }
      }
    });
  }

  Future<void> rename(String oldName, String newName) async {
    final t = newName.trim();
    if (t.isEmpty) return;
    final current = await future;
    final updated = current.map((c) => c == oldName ? t : c).toList()..sort();
    await _CategoryStore.save(updated);
    state = AsyncData(updated);
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final mangas = await isar.mangaEntrys.where().findAll();
      for (final m in mangas) {
        if (m.categories.contains(oldName)) {
          m.categories = m.categories.map((c) => c == oldName ? t : c).toList();
          await isar.mangaEntrys.put(m);
        }
      }
    });
  }
}

final categoryNotifierProvider =
    AsyncNotifierProvider<CategoryNotifier, List<String>>(CategoryNotifier.new);

// ── Shelf filter (Sumi chips) ─────────────────────────────────────────────────

/// Built-in chips. Any other value is a user category name.
abstract final class ShelfFilter {
  static const all = 'All';
  static const reading = 'Reading';
  static const finished = 'Finished';
  static const downloaded = 'Downloaded';
  static const builtIn = [all, reading, finished, downloaded];
}

final shelfFilterProvider = StateProvider<String>((_) => ShelfFilter.all);

/// Genre selection is independent of the built-in shelf and user categories.
final libraryGenreProvider = StateProvider<String?>((_) => null);

/// Manga ids with at least one downloaded chapter.
final downloadedMangaIdsProvider = StreamProvider<Set<int>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.chapterEntrys
      .filter()
      .isDownloadedEqualTo(true)
      .watch(fireImmediately: true)
      .map((chs) => chs.map((c) => c.mangaId).toSet());
});

/// Started and nothing left unread.
bool isFinished(MangaEntry m) =>
    m.lastReadAt != null && m.chapterCount > 0 && m.unreadCount == 0;

// ── Library stream ─────────────────────────────────────────────────────────────

final libraryStreamProvider = StreamProvider<List<MangaEntry>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.mangaEntrys
      .filter()
      .inLibraryEqualTo(true)
      .sortByLastUpdatedDesc()
      .watch(fireImmediately: true);
});

// ── Filtered view ──────────────────────────────────────────────────────────────

final filteredLibraryProvider = Provider<AsyncValue<List<MangaEntry>>>((ref) {
  final library = ref.watch(libraryStreamProvider);
  final filter = ref.watch(shelfFilterProvider);
  final genre = ref.watch(libraryGenreProvider)?.trim().toLowerCase();
  final downloaded =
      ref.watch(downloadedMangaIdsProvider).valueOrNull ?? const <int>{};

  return library.whenData((mangas) {
    final shelf = switch (filter) {
      ShelfFilter.all => mangas,
      ShelfFilter.reading =>
        mangas.where((m) => m.lastReadAt != null && !isFinished(m)).toList(),
      ShelfFilter.finished => mangas.where(isFinished).toList(),
      ShelfFilter.downloaded =>
        mangas.where((m) => downloaded.contains(m.id)).toList(),
      _ => mangas.where((m) => m.categories.contains(filter)).toList(),
    };
    if (genre == null || genre.isEmpty) return shelf;
    return shelf
        .where((m) => m.genres.any((g) => g.trim().toLowerCase() == genre))
        .toList();
  });
});

// ── Continue reading (recently read, in-progress titles) ──────────────────────

final continueReadingProvider = Provider<List<MangaEntry>>((ref) {
  final library = ref.watch(libraryStreamProvider).valueOrNull ?? [];
  final reading = library.where((m) => m.lastReadAt != null).toList()
    ..sort((a, b) => b.lastReadAt!.compareTo(a.lastReadAt!));
  return reading.take(12).toList();
});

// ── Categories derived from library + custom list ──────────────────────────────

final libraryCategoriesProvider = Provider<List<String>>((ref) {
  final library = ref.watch(libraryStreamProvider).valueOrNull ?? [];
  final customCats = ref.watch(categoryNotifierProvider).valueOrNull ?? [];
  final fromManga = library.expand((m) => m.categories).toSet();
  final all = {...customCats, ...fromManga}.toList()..sort();
  return ['All', ...all];
});

// ── All genres across the library (for filter chip panel) ─────────────────────

final libraryGenresProvider = Provider<List<String>>((ref) {
  final library = ref.watch(libraryStreamProvider).valueOrNull ?? [];
  final byName = <String, String>{};
  for (final genre in library.expand((m) => m.genres)) {
    final name = genre.trim();
    if (name.isNotEmpty) byName.putIfAbsent(name.toLowerCase(), () => name);
  }
  final genres = byName.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return genres;
});

// ── Library notifier ──────────────────────────────────────────────────────────

class LibraryNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addToLibrary(MangaEntry manga) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      manga
        ..inLibrary = true
        ..addedToLibrary = DateTime.now();
      await isar.mangaEntrys.put(manga);
    });
  }

  Future<void> removeFromLibrary(int mangaId) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final manga = await isar.mangaEntrys.get(mangaId);
      if (manga == null) return;
      manga.inLibrary = false;
      await isar.mangaEntrys.put(manga);
    });
  }

  Future<void> updateCategories(int mangaId, List<String> categories) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final manga = await isar.mangaEntrys.get(mangaId);
      if (manga == null) return;
      manga.categories = categories;
      await isar.mangaEntrys.put(manga);
    });
  }

  Future<void> markChapterRead({
    required int mangaId,
    required int chapterId,
    required int lastPage,
  }) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final manga = await isar.mangaEntrys.get(mangaId);
      final chapter = await isar.chapterEntrys.get(chapterId);
      if (manga == null || chapter == null) return;
      if (!chapter.isRead) {
        chapter
          ..isRead = true
          ..readAt = DateTime.now()
          ..lastPageRead = lastPage;
        await isar.chapterEntrys.put(chapter);

        final unread = await isar.chapterEntrys
            .filter()
            .mangaIdEqualTo(mangaId)
            .isReadEqualTo(false)
            .count();
        manga
          ..unreadCount = unread
          ..lastReadChapterId = chapter.sourceChapterId
          ..lastReadChapterNumber = chapter.number
          ..lastReadPage = lastPage
          ..lastReadAt = DateTime.now();

        await isar.mangaEntrys.put(manga);
      }
    });
  }

  /// Marks every chapter of [mangaId] as read and zeroes the unread count.
  Future<void> markAllChaptersRead(int mangaId) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final chapters =
          await isar.chapterEntrys.filter().mangaIdEqualTo(mangaId).findAll();
      final now = DateTime.now();
      for (final c in chapters) {
        if (!c.isRead) {
          c
            ..isRead = true
            ..readAt = now;
          await isar.chapterEntrys.put(c);
        }
      }
      final manga = await isar.mangaEntrys.get(mangaId);
      final unread = await isar.chapterEntrys
          .filter()
          .mangaIdEqualTo(mangaId)
          .isReadEqualTo(false)
          .count();
      if (manga != null) {
        manga.unreadCount = unread;
        await isar.mangaEntrys.put(manga);
      }
    });
  }

  // Legacy alias kept for callers that use the old name.
  Future<void> updateCategory(int mangaId, List<String> categories) =>
      updateCategories(mangaId, categories);

  /// Mid-chapter progress. Leaves `isRead` alone — [markChapterRead] flips
  /// that when the last page is reached.
  Future<void> saveChapterProgress({
    required int mangaId,
    required int chapterId,
    required int page,
  }) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final manga = await isar.mangaEntrys.get(mangaId);
      final chapter = await isar.chapterEntrys.get(chapterId);
      if (manga == null || chapter == null) return;
      chapter.lastPageRead = page;
      await isar.chapterEntrys.put(chapter);
      manga
        ..lastReadChapterId = chapter.sourceChapterId
        ..lastReadChapterNumber = chapter.number
        ..lastReadPage = page
        ..lastReadAt = DateTime.now();
      await isar.mangaEntrys.put(manga);
    });
  }
}

final libraryNotifierProvider =
    AsyncNotifierProvider<LibraryNotifier, void>(LibraryNotifier.new);
