import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/providers/source_registry_provider.dart';
import 'package:comic_center/features/settings/import_picker_screen.dart';
import 'package:comic_center/shared/widgets/cover_image.dart';
import 'package:comic_center/shared/widgets/sumi.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/services/source_migration_test.dart'
    show MigrationTestSource;

class _Registry extends SourceRegistryNotifier {
  @override
  List<MangaSource> build() => [MigrationTestSource('native')];
}

const _manga = <Map<String, Object?>>[
  {
    'sourceKey': 'native::a',
    'sourceId': 'native',
    'title': 'Alpha',
    'author': 'Alice',
    'categories': ['Reading'],
    'chapters': [
      {'isRead': true},
      {'isRead': false}
    ],
  },
  {
    'sourceKey': 'disabled::b',
    'sourceId': 'disabled',
    'title': 'Beta',
    'author': 'Bob',
    'categories': ['Later'],
    'chapters': [
      {'isRead': false, 'lastPageRead': 2}
    ],
  },
  {
    'sourceKey': 'tachiyomi:1::c',
    'sourceId': 'tachiyomi:1',
    'sourceName': 'Missing One',
    'title': 'Gamma',
    'author': 'Carol',
    'categories': ['Reading'],
    'chapters': [],
    'lastReadAt': '2026-09-20',
  },
  {
    'sourceKey': 'tachiyomi:2::d',
    'sourceId': 'tachiyomi:2',
    'sourceName': 'Missing Two',
    'title': 'Delta',
    'categories': [],
    'chapters': [],
  },
];

void main() {
  late List<Map<String, Object?>>? result;
  late bool returned;

  Future<void> open(WidgetTester tester,
      {List<Map<String, Object?>> manga = _manga,
      List<Map<String, Object?>> skippedManga = const [],
      Set<String> defaultUnselectedSourceKeys = const {}}) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    result = null;
    returned = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [sourceRegistryProvider.overrideWith(_Registry.new)],
      child: CupertinoApp(
          home: Builder(
              builder: (context) => CupertinoButton(
                    child: const Text('Open'),
                    onPressed: () async {
                      result = await Navigator.push<List<Map<String, Object?>>>(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => ImportPickerScreen(
                                  manga: manga,
                                  connectedSources: const {
                                    'native': 'Native backup name',
                                    'disabled': 'Disabled'
                                  },
                                  unavailableSources: const [
                                    'Missing One',
                                    'Missing Two'
                                  ],
                                  existingSourceKeys: const {'native::a'},
                                  skippedManga: skippedManga,
                                  defaultUnselectedSourceKeys:
                                      defaultUnselectedSourceKeys,
                                )),
                      );
                      returned = true;
                    },
                  ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('select all/none updates counts and disables empty import',
      (tester) async {
    await open(tester);
    expect(find.text('4 of 4 selected'), findsOneWidget);
    expect(find.byType(CoverImage), findsNWidgets(4));
    expect(find.text('2 chapters · 1 read'), findsOneWidget);
    expect(find.text('Not available in Yomi'), findsNWidgets(2));
    expect(find.text('IN LIBRARY'), findsOneWidget);
    expect(find.text('native'), findsNWidgets(2));
    await tester.tap(find.text('Select none'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 4 selected'), findsOneWidget);
    expect(find.textContaining('Yomi cannot connect these sources yet:'),
        findsNothing);
    expect(find.textContaining('Enable these sources in Browse'), findsNothing);
    final button = tester.widget<SumiButton>(find.byType(SumiButton));
    expect(button.label, 'Import 0 titles');
    expect(button.enabled, false);
    await tester.tap(find.text('Import 0 titles'));
    await tester.pumpAndSettle();
    expect(returned, false);
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('Import 4 titles'), findsOneWidget);
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('Import 3 titles'), findsOneWidget);
    expect(
        tester
            .widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox).first)
            .value,
        false);
    await tester.tap(find.byType(CupertinoCheckbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import 4 titles'));
    await tester.pumpAndSettle();
    expect(returned, true);
    expect(result, _manga);
  });

  testWidgets('search by title or author keeps hidden selections',
      (tester) async {
    await open(tester);
    final search = find.byType(CupertinoSearchTextField);
    await tester.enterText(search, ' ALPHA ');
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    await tester.tap(find.text('Select none'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 4 selected'), findsOneWidget);
    await tester.enterText(search, 'bOB');
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    await tester.tap(find.text('Select none'));
    await tester.pumpAndSettle();
    expect(find.text('Import 2 titles'), findsOneWidget);
    await tester.tap(find.text('Select all'));
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.text('Import 3 titles'), findsOneWidget);
    await tester.tap(find.text('Import 3 titles'));
    await tester.pumpAndSettle();
    expect(result, _manga.skip(1).toList());
  });

  testWidgets(
      'source, category and started chips filter rows and selected warnings',
      (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('source:native')));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    // Filtering alone must not remove warnings for hidden selected entries.
    expect(find.textContaining('Missing One, Missing Two'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('source:native')));
    await tester.tap(find.byKey(const ValueKey('category:Reading')));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('category:Reading')));
    await tester.tap(find.text('Started only'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    expect(find.text('Delta'), findsNothing);
    await tester.tap(find.text('Select none'));
    await tester.pumpAndSettle();
    expect(find.text('Import 2 titles'), findsOneWidget);
    expect(
        find.textContaining(
            'Yomi cannot connect these sources yet: Missing Two.'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Yomi cannot connect these sources yet: Missing One'),
        findsNothing);
    expect(
        find.textContaining(
            'Enable these sources in Browse to read online: Disabled.'),
        findsOneWidget);
    await tester.tap(find.text('Import 2 titles'));
    await tester.pumpAndSettle();
    expect(result, [_manga[1], _manga[3]]);
  });

  testWidgets('cancel returns null', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(returned, true);
    expect(result, isNull);
  });

  testWidgets('skipped footer lists names and cross-source matches start off',
      (tester) async {
    await open(
      tester,
      skippedManga: const [
        {'title': 'Downloaded duplicate'}
      ],
      defaultUnselectedSourceKeys: const {'disabled::b'},
    );
    expect(find.text('3 of 4 selected'), findsOneWidget);
    expect(find.text('ALREADY IN LIBRARY'), findsOneWidget);
    expect(find.text('IN LIBRARY'), findsOneWidget);
    final checks =
        tester.widgetList<CupertinoCheckbox>(find.byType(CupertinoCheckbox));
    expect(checks.elementAt(0).value, true);
    expect(checks.elementAt(1).value, false);
    expect(
        find.text('1 titles skipped: already in your library with downloads'),
        findsOneWidget);
    await tester.tap(find.text('See skipped'));
    await tester.pumpAndSettle();
    expect(find.text('Skipped titles'), findsOneWidget);
    expect(find.text('Downloaded duplicate'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'large backup builds visible rows and keeps selection after scrolling',
      (tester) async {
    final manga = List.generate(
        2000,
        (index) => <String, Object?>{
              ..._manga.first,
              'sourceKey': 'native::$index',
              'title': 'Title $index',
            });
    await open(tester, manga: manga);
    expect(find.byType(CoverImage).evaluate().length, lessThan(20));
    await tester.tap(find.text('Title 0'));
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Title 0'), findsNothing);
    await tester.enterText(find.byType(CupertinoSearchTextField), 'Title 1999');
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(ListView), matching: find.text('Title 1999')),
        findsOneWidget);
    expect(find.text('1999 of 2000 selected'), findsOneWidget);
    await tester.tap(find.text('Import 1999 titles'));
    await tester.pumpAndSettle();
    expect(result, manga.skip(1).toList());
  });

  testWidgets('empty results and short viewport remain usable', (tester) async {
    await open(tester);
    tester.view.physicalSize = const Size(390, 420);
    await tester.enterText(find.byType(CupertinoSearchTextField), 'no match');
    await tester.pumpAndSettle();
    expect(find.text('No matching titles'), findsOneWidget);
    expect(find.text('Import 4 titles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
