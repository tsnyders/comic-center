import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/providers/library_provider.dart';
import 'package:comic_center/core/providers/preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MangaEntry _m(int id, String title,
        {int unread = 0, int chapters = 0, DateTime? read, DateTime? added}) =>
    MangaEntry()
      ..id = id
      ..title = title
      ..sourceKey = 'src::$id'
      ..sourceId = 'src'
      ..sourceMangaId = '$id'
      ..sourceUrl = ''
      ..inLibrary = true
      ..unreadCount = unread
      ..chapterCount = chapters
      ..lastReadAt = read
      ..addedToLibrary = added;

void main() {
  final entries = [
    _m(1, 'beta', unread: 5, chapters: 10, read: DateTime(2026, 1, 2)),
    _m(2, 'Alpha', unread: 0, chapters: 30, added: DateTime(2026, 3, 1)),
    _m(3, 'gamma', unread: 5, chapters: 20, read: DateTime(2026, 1, 1)),
  ];

  List<int> order(LibrarySort sort, bool asc) =>
      ([...entries]..sort((a, b) => compareLibrary(sort, asc, a, b)))
          .map((m) => m.id)
          .toList();

  test('compareLibrary orders by each key, both directions, ties by title',
      () {
    expect(order(LibrarySort.alphabetical, true), [2, 1, 3]);
    expect(order(LibrarySort.alphabetical, false), [3, 1, 2]);
    // Never-read titles sort as oldest.
    expect(order(LibrarySort.lastRead, false), [1, 3, 2]);
    expect(order(LibrarySort.lastRead, true), [2, 3, 1]);
    // Equal unread counts fall back to title (beta before gamma).
    expect(order(LibrarySort.unreadCount, false), [1, 3, 2]);
    expect(order(LibrarySort.totalChapters, true), [1, 3, 2]);
    expect(order(LibrarySort.dateAdded, false), [2, 1, 3]);
  });

  test('filteredLibraryProvider applies the persisted sort', () async {
    SharedPreferences.setMockInitialValues({
      'library.sort': LibrarySort.alphabetical.index,
      'library.sortAsc': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      libraryStreamProvider.overrideWith((_) => Stream.value(entries)),
      downloadedMangaIdsProvider.overrideWith((_) => Stream.value(<int>{})),
    ]);
    addTearDown(container.dispose);
    await container.read(libraryStreamProvider.future);
    await container.read(downloadedMangaIdsProvider.future);

    expect(container.read(filteredLibraryProvider).valueOrNull?.map((m) => m.id),
        [2, 1, 3]);
    container.read(librarySortAscendingProvider.notifier).state = false;
    expect(container.read(filteredLibraryProvider).valueOrNull?.map((m) => m.id),
        [3, 1, 2]);
    expect(prefs.getBool('library.sortAsc'), isFalse);
  });
}
