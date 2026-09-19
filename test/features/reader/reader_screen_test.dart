import 'package:comic_center/core/providers/library_provider.dart';
import 'package:comic_center/core/providers/preferences_provider.dart';
import 'package:comic_center/core/providers/reader_provider.dart';
import 'package:comic_center/features/reader/reader_screen.dart';
import 'package:comic_center/shared/widgets/sumi.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records progress writes instead of touching Isar.
class _FakeLibrary extends LibraryNotifier {
  final saved = <(int, int)>[]; // (chapterId, page)
  final markedRead = <int>[];

  @override
  Future<void> saveChapterProgress({
    required int mangaId,
    required int chapterId,
    required int page,
  }) async =>
      saved.add((chapterId, page));

  @override
  Future<void> markChapterRead({
    required int mangaId,
    required int chapterId,
    required int lastPage,
  }) async =>
      markedRead.add(chapterId);
}

void main() {
  const pages = ['https://x.test/1', 'https://x.test/2', 'https://x.test/3'];
  // Newest-first, like the detail screen. Chapter 1 is already read.
  final chapters = [
    for (var n = 3; n >= 1; n--)
      ReaderChapterSummary(
        id: n,
        sourceChapterId: 'c$n',
        title: 'Chapter $n',
        number: n.toDouble(),
        isRead: n == 1,
      ),
  ];

  Future<_FakeLibrary> pumpReader(WidgetTester tester,
      {required int index}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final library = _FakeLibrary();
    final ch = chapters[index];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryNotifierProvider.overrideWith(() => library),
        for (final c in chapters)
          chapterPagesProvider(ChapterKey(
            databaseChapterId: c.id,
            sourceId: 'src',
            sourceChapterId: c.sourceChapterId,
          )).overrideWith((_) async => pages),
      ],
      child: CupertinoApp(
        home: ReaderScreen(
          mangaId: 1,
          chapterId: ch.id,
          sourceId: 'src',
          sourceChapterId: ch.sourceChapterId,
          chapterTitle: ch.title,
          chapterNumber: ch.number,
          chapters: chapters,
          chapterIndex: index,
        ),
      ),
    ));
    await tester.pump(); // pages future resolves
    await tester.pump(); // post-frame: total pages + start page
    return library;
  }

  // Pumps [d] across several frames: a ticker's first frame after start() is
  // elapsed 0, and a route push, its page future and the reader-state reset
  // each need a frame of their own to land.
  Future<void> animate(WidgetTester tester, Duration d) async {
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(d ~/ 4);
    }
  }

  Future<void> turnPage(WidgetTester tester) async {
    final size = tester.getSize(find.byType(PageView));
    await tester.tapAt(Offset(size.width * 0.9, size.height / 2)); // tap zone
    await animate(tester, const Duration(milliseconds: 300));
  }

  Future<void> revealChrome(WidgetTester tester) async {
    final size = tester.getSize(find.byType(PageView));
    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await animate(tester, const Duration(milliseconds: 300));
  }

  Future<void> settleRoute(WidgetTester tester) =>
      animate(tester, const Duration(seconds: 1)); // transition + old dispose

  testWidgets('page turns save progress after a pause and on close',
      (tester) async {
    final library = await pumpReader(tester, index: 1); // Chapter 2

    await turnPage(tester);
    expect(library.saved, isEmpty); // debounced
    await tester.pump(const Duration(seconds: 1));
    expect(library.saved, [(2, 1)]);

    await turnPage(tester); // last page
    expect(library.markedRead, [2]);
    await tester.pumpWidget(const SizedBox()); // close before the timer fires
    expect(library.saved, [(2, 1), (2, 2)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chrome steps to the previous chapter and the picker jumps',
      (tester) async {
    await pumpReader(tester, index: 1); // Chapter 2
    await turnPage(tester);
    await revealChrome(tester);
    expect(find.text('Ch. 2 · Page 2 / 3'), findsOneWidget);

    // Previous = older = Chapter 1. Same page count, so this also proves the
    // app-wide reader state is reset rather than left on page 2.
    await tester.tap(find.byIcon(CupertinoIcons.chevron_left_2));
    await settleRoute(tester);
    expect(find.text('Ch. 1 · Page 1 / 3'), findsOneWidget);
    final prev = tester.widget<SumiPress>(find.ancestor(
        of: find.byIcon(CupertinoIcons.chevron_left_2),
        matching: find.byType(SumiPress)));
    expect(prev.onTap, isNull); // oldest chapter: inert

    await tester.tap(find.text('Ch. 1 · Page 1 / 3')); // chapter picker
    await animate(tester, const Duration(milliseconds: 400)); // sheet slide-in
    expect(find.text('Chapter 3'), findsOneWidget);
    await tester.tap(find.text('Chapter 3'));
    await settleRoute(tester);
    expect(find.text('Ch. 3 · Page 1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
