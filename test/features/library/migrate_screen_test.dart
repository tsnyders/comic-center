import 'dart:io';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/download_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/extensions/models/manga_summary.dart';
import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/providers/database_provider.dart';
import 'package:comic_center/core/providers/preferences_provider.dart';
import 'package:comic_center/core/providers/source_registry_provider.dart';
import 'package:comic_center/features/browse/global_search_screen.dart';
import 'package:comic_center/features/library/migrate_screen.dart';
import 'package:comic_center/shared/widgets/cover_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/source_migration_test.dart'
    show MigrationTestSource, migrationManga;
import '../../support/local_isar.dart';

class _Registry extends SourceRegistryNotifier {
  _Registry(this.sources);
  final List<MangaSource> sources;
  @override
  List<MangaSource> build() => sources;
}

void main() {
  late Isar isar;
  late Directory dir;
  late ProviderContainer container;
  late MigrationTestSource source;
  setUpAll(initializeLocalIsar);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yomi_migration_widget_');
    isar = await Isar.open(
        [MangaEntrySchema, ChapterEntrySchema, DownloadEntrySchema],
        directory: dir.path, name: 'migration_widget', inspector: false);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    source = MigrationTestSource('Installed', results: const [
      MangaSummary(id: 'target', title: 'Hero (Official)'),
      MangaSummary(id: 'weak', title: 'Hero Again'),
    ]);
    container = ProviderContainer(overrides: [
      isarProvider.overrideWithValue(isar),
      sharedPreferencesProvider.overrideWithValue(prefs),
      sourceRegistryProvider.overrideWith(() => _Registry([source])),
    ]);
    await isar.writeTxn(() => isar.mangaEntrys.putAll([
          migrationManga(1),
          migrationManga(2, source: 'Installed', title: 'Available title'),
        ]));
  });
  tearDown(() async {
    container.dispose();
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  // Isar streams need real async turns; repeating activity indicators cannot
  // settle. Poll only until the named UI state arrives, with a fixed ceiling.
  Future<void> animate(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> until(WidgetTester tester, Finder finder,
      {bool absent = false}) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && finder.evaluate().isEmpty != absent; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await animate(tester);
    expect(finder, absent ? findsNothing : findsWidgets);
  }

  Future<void> open(WidgetTester tester,
      {MigrateScreen screen = const MigrateScreen()}) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: CupertinoApp(home: screen)));
    await until(tester, find.byType(SearchResultRow));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  }

  testWidgets(
      'list shows missing source titles; picker ranks covers, source and score',
      (tester) async {
    await open(tester);
    expect(find.text('Hero'), findsOneWidget);
    expect(find.text('tachiyomi:99 · Unavailable'), findsOneWidget);
    expect(find.text('Available title'), findsNothing);
    await tester.tap(find.text('Hero'));
    await until(tester, find.text('Hero (Official)'));
    expect(source.queries, ['Hero']);
    expect(find.text('Installed · 100% match'), findsOneWidget);
    expect(find.text('Installed · 67% match'), findsOneWidget);
    final field = tester.widget<CupertinoSearchTextField>(
        find.byType(CupertinoSearchTextField));
    expect(field.controller!.text, 'Hero');
    final rows = tester
        .widgetList<SearchResultRow>(find.byType(SearchResultRow))
        .toList();
    expect(rows.first.item.title, 'Hero (Official)');
    expect(rows.first.headers, source.imageHeaders);
    expect(find.byType(CoverImage), findsNWidgets(2));

    await tester.enterText(
        find.byType(CupertinoSearchTextField), 'Another Hero');
    await tester.pump(const Duration(milliseconds: 350));
    await until(tester, find.text('Hero (Official)'));
    expect(source.queries.last, 'Another Hero');
    await tester.tap(find.text('Hero (Official)'));
    await animate(tester);
    expect(find.text('Migrate source?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await animate(tester);
    expect(await tester.runAsync(() => isar.mangaEntrys.get(1)), isNotNull);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'bulk selection accepts installed titles and confirmed picker migrates',
      (tester) async {
    await open(tester, screen: const MigrateScreen(titleIds: {2}));
    await tester.tap(find.text('Available title'));
    await until(tester, find.text('Hero (Official)'));
    await tester.tap(find.text('Hero (Official)'));
    await animate(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Migrate'));
      for (var i = 0; i < 200 && await isar.mangaEntrys.get(2) != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await until(tester, find.text('No titles need a source.'));
    final moved = await tester.runAsync(() => isar.mangaEntrys
        .filter()
        .sourceKeyEqualTo('Installed::target')
        .findFirst());
    expect(moved?.inLibrary, true);
    expect(await tester.runAsync(() => isar.mangaEntrys.get(2)), isNull);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'bulk migrates high confidence and leaves weak matches for manual choice',
      (tester) async {
    await tester.runAsync(() => isar.writeTxn(
        () => isar.mangaEntrys.put(migrationManga(3, title: 'Villain'))));
    await open(tester);
    await tester.tap(find.text('Migrate all best matches'));
    await animate(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Migrate'));
      for (var i = 0;
          i < 200 &&
              find.textContaining('left for manual choice').evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await until(tester, find.text('1 migrated · 1 left for manual choice'));
    await until(tester, find.text('Hero'), absent: true);
    expect(find.text('Villain'), findsOneWidget);
    expect(await tester.runAsync(() => isar.mangaEntrys.get(1)), isNull);
    expect(await tester.runAsync(() => isar.mangaEntrys.get(3)), isNotNull);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('empty search explains retry instead of losing the old title',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    source.results = [];
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: MigrateScreen(manga: migrationManga(1)))));
    await until(tester, find.text('No matches found'));
    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    expect(await tester.runAsync(() => isar.mangaEntrys.get(1)), isNotNull);
    await close(tester);
  });
}
