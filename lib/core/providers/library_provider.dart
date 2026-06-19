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

// ── Library filter providers ──────────────────────────────────────────────────

final selectedCategoryProvider = StateProvider<String>((_) => 'All');
final librarySearchProvider    = StateProvider<String>((_) => '');
final libraryStatusFilterProvider  = StateProvider<String?>((_) => null);
final libraryGenreFilterProvider   = StateProvider<List<String>>((_) => const []);

/// Number of columns in the library grid (2 or 3). In-memory only.
final libraryGridColumnsProvider = StateProvider<int>((_) => 2);

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
  final library  = ref.watch(libraryStreamProvider);
  final category = ref.watch(selectedCategoryProvider);
  final search   = ref.watch(librarySearchProvider);
  final status   = ref.watch(libraryStatusFilterProvider);
  final genres   = ref.watch(libraryGenreFilterProvider);

  return library.whenData((mangas) {
    var result = mangas;
    if (category != 'All') {
      result = result.where((m) => m.categories.contains(category)).toList();
    }
    if (search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      result = result.where((m) => m.title.toLowerCase().contains(q)).toList();
    }
    if (status != null && status.isNotEmpty) {
      result = result.where((m) => m.status == status).toList();
    }
    if (genres.isNotEmpty) {
      result = result
          .where((m) => genres.every((g) => m.genres.contains(g)))
          .toList();
    }
    return result;
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
  final library    = ref.watch(libraryStreamProvider).valueOrNull ?? [];
  final customCats = ref.watch(categoryNotifierProvider).valueOrNull ?? [];
  final fromManga  = library.expand((m) => m.categories).toSet();
  final all        = {...customCats, ...fromManga}.toList()..sort();
  return ['All', ...all];
});

// ── All genres across the library (for filter chip panel) ─────────────────────

final libraryGenresProvider = Provider<List<String>>((ref) {
  final library = ref.watch(libraryStreamProvider).valueOrNull ?? [];
  final genres  = library.expand((m) => m.genres).toSet().toList()..sort();
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
      final manga   = await isar.mangaEntrys.get(mangaId);
      final chapter = await isar.chapterEntrys.get(chapterId);
      if (manga == null || chapter == null) return;
      if (!chapter.isRead) {
        chapter
          ..isRead    = true
          ..readAt    = DateTime.now()
          ..lastPageRead = lastPage;
        manga
          ..unreadCount         = (manga.unreadCount - 1).clamp(0, 9999)
          ..lastReadChapterId   = chapter.sourceChapterId
          ..lastReadPage        = lastPage
          ..lastReadAt          = DateTime.now();
        await isar.chapterEntrys.put(chapter);
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
      if (manga != null) {
        manga.unreadCount = 0;
        await isar.mangaEntrys.put(manga);
      }
    });
  }

  // Legacy alias kept for callers that use the old name.
  Future<void> updateCategory(int mangaId, List<String> categories) =>
      updateCategories(mangaId, categories);
}

final libraryNotifierProvider =
    AsyncNotifierProvider<LibraryNotifier, void>(LibraryNotifier.new);
