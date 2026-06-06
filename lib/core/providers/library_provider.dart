import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../database/models/manga_entry.dart';
import 'database_provider.dart';

// ── Category filter ────────────────────────────────────────────────────────

final selectedCategoryProvider = StateProvider<String>((_) => 'All');

// ── Library stream (reactive — updates on any DB write) ───────────────────

final libraryStreamProvider = StreamProvider<List<MangaEntry>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.mangaEntrys
      .filter()
      .inLibraryEqualTo(true)
      .sortByLastUpdatedDesc()
      .watch(fireImmediately: true);
});

// ── Filtered view ─────────────────────────────────────────────────────────

final filteredLibraryProvider =
    Provider<AsyncValue<List<MangaEntry>>>((ref) {
  final library = ref.watch(libraryStreamProvider);
  final category = ref.watch(selectedCategoryProvider);

  return library.whenData((mangas) {
    if (category == 'All') return mangas;
    return mangas
        .where((m) => m.categories.contains(category))
        .toList();
  });
});

// ── Categories derived from library ──────────────────────────────────────

final libraryCategoriesProvider = Provider<List<String>>((ref) {
  final library = ref.watch(libraryStreamProvider).valueOrNull ?? [];
  final all = library.expand((m) => m.categories).toSet().toList()..sort();
  return ['All', ...all];
});

// ── Notifier for mutations ────────────────────────────────────────────────

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
        chapter.isRead = true;
        chapter.readAt = DateTime.now();
        chapter.lastPageRead = lastPage;
        manga.unreadCount = (manga.unreadCount - 1).clamp(0, 9999);
        manga.lastReadChapterId = chapter.sourceChapterId;
        manga.lastReadPage = lastPage;
        manga.lastReadAt = DateTime.now();
        await isar.chapterEntrys.put(chapter);
        await isar.mangaEntrys.put(manga);
      }
    });
  }

  Future<void> updateCategory(int mangaId, List<String> categories) async {
    final isar = ref.read(isarProvider);
    await isar.writeTxn(() async {
      final manga = await isar.mangaEntrys.get(mangaId);
      if (manga == null) return;
      manga.categories = categories;
      await isar.mangaEntrys.put(manga);
    });
  }
}

final libraryNotifierProvider =
    AsyncNotifierProvider<LibraryNotifier, void>(LibraryNotifier.new);
