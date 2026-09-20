import 'dart:convert';
import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/providers/database_provider.dart';
import 'package:comic_center/core/providers/library_provider.dart';
import 'package:comic_center/core/services/backup_service.dart';
import 'package:comic_center/core/services/tachiyomi_backup.dart';
import 'package:comic_center/features/settings/backup_restore_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../core/services/tachiyomi_backup_test.dart' show backupFixture;
import '../../support/local_isar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Isar isar;
  late ProviderContainer container;
  final calls = <MethodCall>[];
  String? selected;
  setUpAll(initializeLocalIsar);
  setUp(() async {
    calls.clear();
    selected = null;
    dir = await Directory.systemTemp.createTemp('yomi_picker_test_');
    isar = await Isar.open([MangaEntrySchema, ChapterEntrySchema],
        directory: dir.path, name: 'restore_picker', inspector: false);
    container =
        ProviderContainer(overrides: [isarProvider.overrideWithValue(isar)]);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path);
    messenger.setMockMethodCallHandler(const MethodChannel('yomi/platform'),
        (call) async {
      calls.add(call);
      return selected;
    });
  });
  tearDown(() async {
    container.dispose();
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

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.runAsync(() async {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const CupertinoApp(home: BackupRestoreScreen())));
      for (var i = 0;
          i < 200 &&
              find.byType(CupertinoActivityIndicator).evaluate().isNotEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
      'restore offers all three sources and cancel keeps library untouched',
      (tester) async {
    await open(tester);
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('System storage'), findsOneWidget);
    await tester.tap(find.text('Import from Tachiyomi'));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'pickBackup');
    expect(calls.single.arguments, {'tachiyomi': true});
    expect(find.text('Import backup'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system storage uses the general file picker', (tester) async {
    await open(tester);
    await tester.tap(find.text('System storage'));
    await tester.pumpAndSettle();
    expect(calls.single.arguments, {'tachiyomi': false});
  });

  testWidgets(
      'Tachiyomi picker cancellation leaves Isar untouched and cleans temporary file',
      (tester) async {
    final file = File('${dir.path}/selected.backup');
    await tester.runAsync(
        () => file.writeAsBytes(backupFixture(sourceName: 'Missing source')));
    selected = file.path;
    await open(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import from Tachiyomi'));
      // Wait for the file read and background decode to reach the preview.
      for (var i = 0;
          i < 200 && find.text('Import backup').evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    // The import activity indicator intentionally stays active behind preview.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Import backup'), findsOneWidget);
    expect(find.text('1 of 1 selected'), findsOneWidget);
    expect(
        find.textContaining(
            'Yomi cannot connect these sources yet: Missing source.'),
        findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Cancel'));
      for (var i = 0; i < 200 && await file.exists(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(await tester.runAsync(file.exists), false);
    expect(await tester.runAsync(() => isar.mangaEntrys.count()), 0);
    expect(await tester.runAsync(() => isar.chapterEntrys.count()), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tachiyomi picker imports only the chosen fixture title',
      (tester) async {
    final fixture = File('test/fixtures/tachiyomi/library.tachibk');
    final backup = TachiyomiBackup.decode(fixture.readAsBytesSync());
    // The excluded title already needs migration: it must not inflate the offer.
    await tester
        .runAsync(() => isar.writeTxn(() => isar.mangaEntrys.put(MangaEntry()
          ..title = 'Existing excluded title'
          ..sourceKey = backup.manga.first['sourceKey'] as String
          ..sourceId = backup.manga.first['sourceId'] as String
          ..sourceMangaId = backup.manga.first['sourceMangaId'] as String
          ..sourceUrl = backup.manga.first['sourceUrl'] as String
          ..inLibrary = true)));
    final file = File('${dir.path}/selected.tachibk');
    await tester.runAsync(() => fixture.copy(file.path));
    selected = file.path;
    await open(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import from Tachiyomi'));
      for (var i = 0;
          i < 200 && find.text('Import backup').evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2 of 2 selected'), findsOneWidget);
    expect(find.text('IN LIBRARY'), findsOneWidget);
    await tester.tap(find.text('Synthetic manga'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Import 1 titles'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import 1 titles'));
      for (var i = 0;
          i < 200 &&
              (find.text('Restore complete').evaluate().isEmpty ||
                  await file.exists());
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Restored 1 titles, 1 chapter records'),
        findsOneWidget);
    expect(find.text('Migrate 1 titles'), findsOneWidget);
    final titles =
        await tester.runAsync(() => isar.mangaEntrys.where().findAll());
    expect(
        titles!.map((manga) => manga.title),
        unorderedEquals(
            ['Existing excluded title', 'Synthetic unavailable comic']));
    final chapters =
        await tester.runAsync(() => isar.chapterEntrys.where().findAll());
    expect(chapters, hasLength(1));
    expect(chapters!.single.isRead, true);
    expect(container.read(categoryNotifierProvider).valueOrNull, isEmpty);
    expect(await tester.runAsync(file.exists), false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid file reports an error before offering import',
      (tester) async {
    final file = File('${dir.path}/invalid.backup');
    await tester.runAsync(() => file.writeAsString('not a backup'));
    selected = file.path;
    await open(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import from Tachiyomi'));
      for (var i = 0;
          i < 200 &&
              (find.text('Could not restore').evaluate().isEmpty ||
                  await file.exists());
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Could not restore'), findsOneWidget);
    expect(find.text('Import backup'), findsNothing);
    expect(await tester.runAsync(file.exists), false);
  });

  testWidgets('encrypted backup asks for its passphrase, then previews counts',
      (tester) async {
    // Real I/O and the PBKDF2 isolate only progress under runAsync.
    Future<void> tapAndWaitFor(Finder tap, Finder until) =>
        tester.runAsync(() async {
          await tester.tap(tap);
          for (var i = 0; i < 400 && until.evaluate().isEmpty; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }
        });
    final backups = Directory('${dir.path}/backups')..createSync();
    final file = File('${backups.path}/yomi_backup_20260101_0900.json');
    await tester
        .runAsync(() async => file.writeAsString(await BackupService.encode(
            jsonEncode({
              'version': 1,
              'categories': ['Reading'],
              'settings': {'reader.direction': 1, 'theme.look': 2},
              'manga': [
                {
                  'sourceKey': 'a::1',
                  'title': 'A',
                  'chapters': [
                    {'sourceChapterId': 'c1'},
                    {'sourceChapterId': 'c2'},
                  ],
                }
              ],
            }),
            passphrase: 'correct horse')));
    await open(tester);
    final saved = find.textContaining('20260101');
    expect(saved, findsOneWidget);

    await tapAndWaitFor(saved, find.text('Backup passphrase'));
    await tester.enterText(find.byType(CupertinoTextField), 'battery staple');
    await tapAndWaitFor(find.text('Unlock'), find.text('Could not restore'));
    expect(find.text('Wrong backup passphrase.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tapAndWaitFor(saved, find.text('Backup passphrase'));
    await tester.enterText(find.byType(CupertinoTextField), 'correct horse');
    await tapAndWaitFor(find.text('Unlock'), find.text('Restore backup'));
    expect(
        find.textContaining(
            '1 titles, 2 chapter records, 1 categories and 2 settings'),
        findsOneWidget);
    expect(find.text('Restore settings too'), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsOneWidget);
    // The restore flow started under runAsync, so let its cancel path finish
    // there too (the busy indicator clears) before settling on the fake clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('Cancel'));
      for (var i = 0;
          i < 200 &&
              find.byType(CupertinoActivityIndicator).evaluate().isNotEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Restore backup'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
