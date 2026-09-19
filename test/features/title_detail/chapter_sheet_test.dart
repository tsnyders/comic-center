import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/providers/browse_provider.dart';
import 'package:comic_center/core/providers/download_provider.dart';
import 'package:comic_center/core/providers/library_provider.dart';
import 'package:comic_center/core/providers/preferences_provider.dart';
import 'package:comic_center/features/title_detail/title_detail_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLibrary extends LibraryNotifier {
  final calls = <String>[];
  @override
  Future<void> build() async {}
  @override
  Future<void> markPreviousChaptersRead(int mangaId, int chapterId) async =>
      calls.add('previous:$mangaId:$chapterId');
  @override
  Future<void> setChaptersRead(int mangaId, Iterable<int> chapterIds,
          {required bool read}) async =>
      calls.add('set:${chapterIds.join(',')}:$read');
}

class _FakeDownloads extends DownloadManager {
  @override
  Future<void> build() async {}
}

ChapterEntry _ch(int id, {bool read = false}) => ChapterEntry()
  ..id = id
  ..mangaId = 1
  ..sourceChapterId = '$id'
  ..title = 'Chapter $id'
  ..number = id.toDouble()
  ..isRead = read;

void main() {
  testWidgets('long-press opens the chapter sheet and selection mode works',
      (tester) async {
    final manga = MangaEntry()
      ..id = 1
      ..title = 'Title'
      ..sourceKey = 'src::1'
      ..sourceId = 'src'
      ..sourceMangaId = '1'
      ..sourceUrl = ''
      ..genres = ['Action'];
    final chapters = [_ch(3), _ch(2), _ch(1, read: true)];
    final library = _FakeLibrary();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Tall viewport so the chapter list sits on screen below the plate.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveMangaProvider(1).overrideWith((_) => Stream.value(manga)),
        liveChaptersProvider(1).overrideWith((_) => Stream.value(chapters)),
        chapterSyncProvider(1).overrideWith((_) async => chapters),
        libraryNotifierProvider.overrideWith(() => library),
        downloadManagerProvider.overrideWith(_FakeDownloads.new),
        for (final ch in chapters)
          chapterDownloadStatusProvider(ch.id)
              .overrideWith((_) => Stream.value(null)),
      ],
      child: CupertinoApp(home: TitleDetailScreen(manga: manga)),
    ));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Chapter 2'));
    await tester.pumpAndSettle();
    for (final label in [
      'Mark as read',
      'Mark previous as read',
      'Mark all as read',
      'Download',
      'Select',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Mark previous as read'));
    await tester.pumpAndSettle();
    expect(library.calls, ['previous:1:2']);

    // Read chapters offer "unread" instead.
    await tester.longPress(find.text('Chapter 1'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as unread'), findsOneWidget);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 SELECTED'), findsOneWidget);

    await tester.tap(find.text('Chapter 3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 SELECTED'), findsOneWidget);
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark read'));
    await tester.pumpAndSettle();
    expect(library.calls.last, anyOf('set:1,3:true', 'set:3,1:true'));
    expect(find.textContaining('CHAPTERS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
