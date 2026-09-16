import 'dart:async';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/providers/browse_provider.dart';
import 'package:comic_center/features/title_detail/title_detail_screen.dart';
import 'package:comic_center/shared/widgets/sumi.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('detail shows each genre as a read-only chip', (tester) async {
    final manga = MangaEntry()
      ..id = 1
      ..title = 'Genre title'
      ..sourceKey = 'src::1'
      ..sourceId = 'src'
      ..sourceMangaId = '1'
      ..sourceUrl = ''
      ..genres = ['Action', 'Adventure', 'Fantasy'];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveMangaProvider(1).overrideWith((_) => Stream.value(manga)),
        liveChaptersProvider(1)
            .overrideWith((_) => Stream.value(<ChapterEntry>[])),
        chapterSyncProvider(1).overrideWith((_) async => <ChapterEntry>[]),
      ],
      child: CupertinoApp(home: TitleDetailScreen(manga: manga)),
    ));
    await tester.pumpAndSettle();
    for (final genre in manga.genres) {
      expect(find.text(genre), findsOneWidget);
      final chip = tester.widget<SumiChip>(find.widgetWithText(SumiChip, genre));
      expect(chip.onTap, isNull);
      expect(find.descendant(of: find.widgetWithText(SumiChip, genre),
          matching: find.byType(SumiPress)), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing metadata refreshes once and live genres appear',
      (tester) async {
    final manga = MangaEntry()
      ..id = 2
      ..title = 'Existing title'
      ..sourceKey = 'src::2'
      ..sourceId = 'src'
      ..sourceMangaId = '2'
      ..sourceUrl = '';
    final updates = StreamController<MangaEntry?>();
    addTearDown(updates.close);
    var refreshes = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveMangaProvider(2).overrideWith((_) => updates.stream),
        liveChaptersProvider(2)
            .overrideWith((_) => Stream.value(<ChapterEntry>[])),
        chapterSyncProvider(2).overrideWith((_) async => <ChapterEntry>[]),
        mangaMetadataProvider(2).overrideWith((_) async {
          refreshes++;
          return manga;
        }),
      ],
      child: CupertinoApp(home: TitleDetailScreen(manga: manga)),
    ));
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    expect(find.text('GENRES'), findsNothing);

    manga.genres = [' Fantasy ', 'fantasy', ''];
    updates.add(manga);
    await tester.pumpAndSettle();
    expect(find.text('Fantasy'), findsOneWidget);
    expect(find.text('fantasy'), findsNothing);
    expect(refreshes, 1);
    expect(tester.takeException(), isNull);
  });
}
