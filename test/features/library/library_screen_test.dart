import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/providers/library_provider.dart';
import 'package:comic_center/core/providers/preferences_provider.dart';
import 'package:comic_center/features/library/library_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression: a title with reading history (lastReadAt set) shows the
// Continue block. That block once laid out infinitely tall inside its sliver
// (stretch row, unbounded height) — a debug-only assert in test, silently
// blank below the header in release — hiding the chips and the whole grid.
void main() {
  testWidgets('shelf still renders when a title has reading history',
      (tester) async {
    final manga = MangaEntry()
      ..id = 1
      ..title = 'Restored title'
      ..sourceKey = 'src::1'
      ..sourceId = 'src'
      ..sourceMangaId = '1'
      ..sourceUrl = ''
      ..inLibrary = true
      ..chapterCount = 10
      ..lastReadChapterNumber = 3
      ..lastReadAt = DateTime(2026, 7, 18)
      ..lastUpdated = DateTime(2026, 7, 18);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryStreamProvider.overrideWith((_) => Stream.value([manga])),
        downloadedMangaIdsProvider.overrideWith((_) => Stream.value(<int>{})),
      ],
      child: const CupertinoApp(home: LibraryScreen()),
    ));
    await tester.pump(); // stream delivers
    await tester.pump(const Duration(seconds: 2)); // entrance animations

    expect(tester.takeException(), isNull);
    expect(find.text('All 1'), findsOneWidget); // chips are below the block
    expect(find.text('Restored title'), findsWidgets); // block + grid card
  });
}
