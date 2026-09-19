import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/features/history/history_screen.dart';
import 'package:comic_center/shared/widgets/chapter_feed_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _manga = MangaEntry()
  ..id = 1
  ..title = 'Alpha'
  ..sourceKey = 's::1'
  ..sourceId = 's'
  ..sourceMangaId = '1'
  ..sourceUrl = '';

Future<void> _pump(WidgetTester tester, List<FeedItem> items) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      historyFeedProvider.overrideWith((_) => Stream.value(items)),
    ],
    child: const CupertinoApp(home: HistoryScreen()),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('lists read chapters, confirms clearing, offers removal',
      (tester) async {
    final chapter = ChapterEntry()
      ..id = 3
      ..mangaId = 1
      ..sourceChapterId = 'c3'
      ..title = 'Chapter 3'
      ..number = 3
      ..isRead = true
      ..readAt = DateTime(2026, 9, 17, 9, 5);

    await _pump(tester, [(manga: _manga, chapter: chapter)]);

    expect(tester.takeException(), isNull);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Chapter 3'), findsOneWidget);
    expect(find.text('SEP 17'), findsOneWidget);

    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    expect(find.text('Clear history?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Clear history?'), findsNothing);

    await tester.longPress(find.text('Chapter 3'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from history'), findsOneWidget);
  });

  testWidgets('shows the empty state and disables clearing', (tester) async {
    await _pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.text('Nothing read yet'), findsOneWidget);
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    expect(find.text('Clear history?'), findsNothing);
  });
}
