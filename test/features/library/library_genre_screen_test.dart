import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/providers/library_provider.dart';
import 'package:comic_center/features/library/library_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MangaEntry _manga(int id, String title, List<String> genres) => MangaEntry()
  ..id = id
  ..title = title
  ..sourceKey = 'src::$id'
  ..sourceId = 'src'
  ..sourceMangaId = '$id'
  ..sourceUrl = ''
  ..inLibrary = true
  ..genres = genres
  ..lastUpdated = DateTime(2026, 9, 16);

void main() {
  testWidgets('genre combines with shelf filters and All genres resets it',
      (tester) async {
    final mangas = [
      _manga(1, 'Action title', ['Action']),
      _manga(2, 'Romance title', ['Romance']),
      _manga(3, 'No genres title', []),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        libraryStreamProvider.overrideWith((_) => Stream.value(mangas)),
        downloadedMangaIdsProvider.overrideWith((_) => Stream.value({1})),
        libraryCategoriesProvider.overrideWithValue(['All']),
        continueReadingProvider.overrideWithValue([]),
      ],
      child: const CupertinoApp(home: LibraryScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();
    expect(find.text('Action title'), findsOneWidget);
    expect(find.text('Romance title'), findsNothing);
    expect(find.text('No genres title'), findsNothing);

    await tester.tap(find.text('Downloaded'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Romance'));
    await tester.pumpAndSettle();
    expect(find.text('No titles match this filter.'), findsOneWidget);

    await tester.tap(find.text('All genres'));
    await tester.pumpAndSettle();
    expect(find.text('Action title'), findsOneWidget);
    expect(find.text('Romance title'), findsNothing);

    await tester.tap(find.text('All 3'));
    await tester.pumpAndSettle();
    expect(find.text('Romance title'), findsOneWidget);
    expect(find.text('No genres title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
