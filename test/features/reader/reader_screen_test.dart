import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:comic_center/core/providers/library_provider.dart';
import 'package:comic_center/core/providers/preferences_provider.dart';
import 'package:comic_center/core/providers/reader_provider.dart';
import 'package:comic_center/core/services/device_profile.dart';
import 'package:comic_center/features/reader/reader_screen.dart';
import 'package:comic_center/shared/widgets/sumi.dart';
import 'package:extended_image/extended_image.dart';
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

/// Exercise real image decodes without Windows file mappings outliving a test.
class _MemoryPage implements File {
  _MemoryPage(this.path, this.bytes);
  @override
  final String path;
  final Uint8List bytes;
  @override
  Future<int> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
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
      {required int index,
      bool isWebtoon = false,
      List<String> pageUrls = pages}) async {
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
          )).overrideWith((_) async => pageUrls),
      ],
      child: CupertinoApp(
        home: ReaderScreen(
          mangaId: 1,
          chapterId: ch.id,
          sourceId: 'src',
          sourceChapterId: ch.sourceChapterId,
          chapterTitle: ch.title,
          chapterNumber: ch.number,
          isWebtoon: isWebtoon,
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
    final size = tester.getSize(find.byType(ExtendedImageGesturePageView));
    await tester.tapAt(Offset(size.width * 0.9, size.height / 2)); // tap zone
    await animate(tester, const Duration(milliseconds: 400));
  }

  Future<void> revealChrome(WidgetTester tester) async {
    final size = tester.getSize(find.byType(ExtendedImageGesturePageView));
    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await animate(tester, const Duration(milliseconds: 400));
  }

  Future<void> doubleTapAt(WidgetTester tester, Offset position) async {
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> settleRoute(WidgetTester tester) =>
      animate(tester, const Duration(seconds: 1)); // transition + old dispose

  for (final strip in [false, true]) {
    for (final lowSpec in [false, true]) {
      testWidgets(
          '${strip ? 'strip' : 'paged'} releases decoded pages, lowSpec=$lowSpec',
          (tester) async {
        final previous = DeviceProfile.current;
        final cache = PaintingBinding.instance.imageCache;
        final oldLimit = cache.maximumSizeBytes;
        DeviceProfile.current =
            DeviceProfile(reducedMotion: false, lowSpec: lowSpec);
        cache.maximumSizeBytes = DeviceProfile.current.imageCacheBytes;
        cache.clear();
        cache.clearLiveImages();
        addTearDown(() {
          DeviceProfile.current = previous;
          cache.clear();
          cache.clearLiveImages();
          cache.maximumSizeBytes = oldLimit;
        });

        final bytes = await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(const Color(0xFF987654), BlendMode.src);
          final picture = recorder.endRecording();
          final image = await picture.toImage(2400, 900);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          picture.dispose();
          return data!.buffer.asUint8List();
        });
        await IOOverrides.runZoned(() async {
          final urls = [
            for (var i = 0; i < 20; i++)
              Uri.file('${Directory.systemTemp.path}/yomi-memory/$i.png')
                  .toString(),
          ];
          await pumpReader(tester, index: 1, isWebtoon: strip, pageUrls: urls);

          Future<void> loadVisible() async {
            for (var i = 0; i < 100; i++) {
              await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 10)));
              await tester.pump();
              final states = tester
                  .stateList(find.byType(ExtendedImage))
                  .cast<ExtendedImageState>();
              if (states.isNotEmpty &&
                  states.every((state) => state.extendedImageInfo != null)) {
                return;
              }
            }
            fail('Local reader images did not decode');
          }

          await loadVisible();
          final firstImage = tester
              .widgetList<ExtendedImage>(find.byType(ExtendedImage))
              .first
              .image;
          final context = tester.element(find.byType(ReaderScreen));
          final expectedWidth = (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context) *
                  (lowSpec ? 1.25 : 2.0))
              .round()
              .clamp(1, 2400);
          expect(
              tester
                  .stateList(find.byType(ExtendedImage))
                  .cast<ExtendedImageState>()
                  .first
                  .extendedImageInfo!
                  .image
                  .width,
              expectedWidth);

          // Keep unrelated art in the cache: reader disposal must be selective.
          final cover = MemoryImage(bytes!);
          for (var i = 1; i <= 6; i++) {
            if (strip) {
              final scrollable =
                  tester.state<ScrollableState>(find.byType(Scrollable).first);
              scrollable.position.jumpTo(i * 600.0);
            } else {
              final pageView = tester.widget<ExtendedImageGesturePageView>(
                  find.byType(ExtendedImageGesturePageView));
              pageView.controller.jumpToPage(i);
            }
            await tester.pump();
            await loadVisible();
          }
          final offscreen = await firstImage.obtainCacheStatus(
              configuration: ImageConfiguration.empty);
          expect(offscreen?.keepAlive, isFalse);
          if (strip) {
            // These strips are half a viewport tall: viewport + one screen on
            // either side must not retain the old twelve-image window.
            expect(find.byType(ExtendedImage).evaluate().length,
                lessThanOrEqualTo(8));
          }
          expect(cache.currentSizeBytes,
              lessThanOrEqualTo(DeviceProfile.current.imageCacheBytes));
          await tester.runAsync(() => precacheImage(cover, context));
          await tester.pump();

          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(cache.currentSize, 1); // only the unrelated cover
          expect(
              (await cover.obtainCacheStatus(
                      configuration: ImageConfiguration.empty))
                  ?.keepAlive,
              isTrue);
          expect(tester.takeException(), isNull);
        }, createFile: (path) => _MemoryPage(path, bytes!));
      });
    }
  }

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

  testWidgets('strip zoom toggles and keeps vertical scrolling at 1x and 2x',
      (tester) async {
    await pumpReader(tester, index: 1, isWebtoon: true);
    await animate(tester, const Duration(milliseconds: 300));

    final viewerFinder = find.byType(InteractiveViewer);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final zoom = viewer.transformationController!;
    final tapPosition = tester.getCenter(viewerFinder);

    expect(zoom.value.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    await doubleTapAt(tester, tapPosition);
    expect(zoom.value.getMaxScaleOnAxis(), closeTo(2.0, 0.01));

    final scrollable = tester.state<ScrollableState>(find.descendant(
      of: viewerFinder,
      matching: find.byType(Scrollable),
    ));
    expect(scrollable.position.pixels, 0);
    final zoomedX = zoom.value.getTranslation().x;
    await tester.timedDrag(
      viewerFinder,
      const Offset(-100, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(zoom.value.getTranslation().x, lessThan(zoomedX));

    await tester.drag(viewerFinder, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
    expect(scrollable.position.pixels, greaterThan(0));

    await doubleTapAt(tester, tapPosition);
    expect(zoom.value.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    final oneXScrollOffset = scrollable.position.pixels;
    await tester.drag(viewerFinder, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
    expect(scrollable.position.pixels, greaterThan(oneXScrollOffset));

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('paged double-tap does not turn the page', (tester) async {
    await pumpReader(tester, index: 1);
    await animate(tester, const Duration(milliseconds: 300));

    final pageViewFinder = find.byType(ExtendedImageGesturePageView);
    final rect = tester.getRect(pageViewFinder);
    final edge = Offset(rect.left + rect.width * 0.9, rect.center.dy);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );

    expect(container.read(readerProvider).currentPage, 0);
    await doubleTapAt(tester, edge);
    expect(container.read(readerProvider).currentPage, 0);

    await tester.pumpWidget(const SizedBox());
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
