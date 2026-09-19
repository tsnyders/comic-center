import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/features/updates/updates_screen.dart';
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
  ..sourceUrl = ''
  ..inLibrary = true;

Future<void> _pump(WidgetTester tester, List<FeedItem> items) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      updatesFeedProvider.overrideWith((_) => Stream.value(items)),
    ],
    child: const CupertinoApp(home: UpdatesScreen()),
  ));
  await tester.pump(); // stream delivers
  await tester.pump(const Duration(seconds: 2)); // entrance animations
}

void main() {
  testWidgets('groups arrivals by day and offers read/download actions',
      (tester) async {
    final now = DateTime.now();
    final today = ChapterEntry()
      ..id = 1
      ..mangaId = 1
      ..sourceChapterId = 'c12'
      ..title = 'Chapter 12'
      ..number = 12
      ..dateFetched = now;
    final yesterday = ChapterEntry()
      ..id = 2
      ..mangaId = 1
      ..sourceChapterId = 'c11'
      ..title = 'Chapter 11'
      ..number = 11
      ..isRead = true
      ..isDownloaded = true
      ..dateFetched = now.subtract(const Duration(days: 1));

    await _pump(tester, [
      (manga: _manga, chapter: today),
      (manga: _manga, chapter: yesterday),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text('Alpha'), findsNWidgets(2));
    expect(find.text('Chapter 12'), findsOneWidget);
    expect(find.text('Update library'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);

    await tester.longPress(find.text('Chapter 12'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing has arrived',
      (tester) async {
    await _pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.text('No new chapters'), findsOneWidget);
  });
}
