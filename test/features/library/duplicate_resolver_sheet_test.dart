import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/download_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/services/duplicate_scan.dart';
import 'package:comic_center/features/library/duplicate_resolver_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../support/local_isar.dart';

MangaEntry _manga(int id, String title, String source) => MangaEntry()
  ..id = id
  ..title = title
  ..sourceKey = '$source::$id'
  ..sourceId = source
  ..sourceMangaId = '$id'
  ..sourceUrl = ''
  ..inLibrary = true;

DuplicateGroup _group({
  required int offset,
  int firstDownloads = 0,
  int secondDownloads = 0,
  int firstRead = 0,
  int secondRead = 0,
}) {
  final first = _manga(offset + 1, 'Hero $offset', 'a');
  final second = _manga(offset + 2, 'Hero $offset', 'b');
  return DuplicateGroup(
    normalizedTitle: 'hero $offset',
    title: 'Hero $offset',
    ignoreKey: '${first.sourceKey}|${second.sourceKey}',
    entries: [
      DuplicateEntryStats(
        entry: first,
        chapterCount: 10,
        readCount: firstRead,
        downloadedCount: firstDownloads,
        addedToLibrary: DateTime(2020),
      ),
      DuplicateEntryStats(
        entry: second,
        chapterCount: 12,
        readCount: secondRead,
        downloadedCount: secondDownloads,
        addedToLibrary: DateTime(2021),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Isar isar;

  setUpAll(initializeLocalIsar);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yomi_duplicate_widget_');
    isar = await Isar.open(
      [MangaEntrySchema, ChapterEntrySchema, DownloadEntrySchema],
      directory: dir.path,
      name: 'duplicate_widget',
      inspector: false,
    );
  });
  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    for (var attempt = 0;; attempt++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        if (attempt == 40) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  Future<void> open(
    WidgetTester tester,
    List<DuplicateGroup> groups, {
    DuplicateResolveCallback? onResolve,
    DuplicateIgnoreCallback? onIgnore,
  }) async {
    tester.view.physicalSize = const Size(700, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CupertinoApp(
      home: Builder(
        builder: (context) => CupertinoButton(
          child: const Text('Open'),
          onPressed: () => showCupertinoDialog<void>(
            context: context,
            builder: (_) => DuplicateResolverSheet(
              isar: isar,
              groups: groups,
              sourceNames: const {'a': 'Source A', 'b': 'Source B'},
              onResolve: onResolve,
              onIgnore: onIgnore,
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to the entry with the most downloads', (tester) async {
    final group =
        _group(offset: 0, firstDownloads: 0, secondDownloads: 2, firstRead: 9);
    await open(tester, [group], onResolve: (_, __, ___) async {});

    expect(find.text('2 downloaded'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('keep:2')),
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('keep:1')),
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsNothing,
    );
  });

  testWidgets('keep both persists and removes only that group', (tester) async {
    final first = _group(offset: 10);
    final second = _group(offset: 20);
    String? ignored;
    await open(tester, [first, second], onIgnore: (key) async => ignored = key);

    await tester.tap(find.text('Keep both').first);
    await tester.pumpAndSettle();
    expect(ignored, first.ignoreKey);
    expect(find.text('Hero 10'), findsNothing);
    expect(find.text('Hero 20'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('apply uses the selected keep entry', (tester) async {
    final group =
        _group(offset: 30, firstRead: 1, secondRead: 8, secondDownloads: 1);
    MangaEntry? kept;
    bool? deleteDownloads;
    await open(tester, [group], onResolve: (_, keep, delete) async {
      kept = keep;
      deleteDownloads = delete;
    });

    await tester.tap(find.byKey(const ValueKey('keep:31')));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 downloaded chapters?'), findsOneWidget);
    await tester.tap(find.text('Delete & Apply'));
    await tester.pumpAndSettle();
    expect(kept?.id, 31);
    expect(deleteDownloads, true);
    expect(find.text('Duplicate titles'), findsNothing);
  });
}
