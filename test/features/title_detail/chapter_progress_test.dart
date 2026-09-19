import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/providers/download_provider.dart';
import 'package:comic_center/features/title_detail/widgets/chapter_list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('imported partial progress is visible without a page count',
      (tester) async {
    final chapter = ChapterEntry()
      ..id = 1
      ..mangaId = 1
      ..sourceChapterId = 'chapter'
      ..title = 'Chapter 1'
      ..lastPageRead = 7;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chapterDownloadStatusProvider(1).overrideWith((_) => Stream.value(null))
      ],
      child: CupertinoApp(
          home: CupertinoPageScaffold(
              child: ChapterListTile(chapter: chapter, onTap: () {}))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Page 8'), findsOneWidget);
    expect(find.text('Unread'), findsNothing);
  });
}
