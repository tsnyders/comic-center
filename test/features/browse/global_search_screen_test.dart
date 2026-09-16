import 'dart:typed_data';

import 'package:comic_center/core/extensions/models/chapter_info.dart';
import 'package:comic_center/core/extensions/models/filter.dart';
import 'package:comic_center/core/extensions/models/manga_detail.dart';
import 'package:comic_center/core/extensions/models/manga_summary.dart';
import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/providers/source_registry_provider.dart';
import 'package:comic_center/features/browse/browse_screen.dart';
import 'package:comic_center/features/browse/global_search_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SearchSource extends MangaSource {
  _SearchSource(this.id, this.name, {this.fail = false});

  @override
  final String id;
  @override
  final String name;
  bool fail;
  final requests = <(String, int)>[];

  @override
  String get baseUrl => 'https://example.invalid';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => const {};

  @override
  Future<List<MangaSummary>> search(String query,
      {int page = 1, List<SourceFilter> filters = const []}) async {
    requests.add((query, page));
    if (fail) throw StateError('Source unavailable');
    if (page > 2) return [];
    return [MangaSummary(id: '$id-$page', title: '$name page $page')];
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async => [];
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async => [];
  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) =>
      throw UnimplementedError();
  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) =>
      throw UnimplementedError();
  @override
  Future<List<String>> fetchPageUrls(String chapterId) =>
      throw UnimplementedError();
}

class _TestRegistry extends SourceRegistryNotifier {
  _TestRegistry(this.sources);
  final List<MangaSource> sources;

  @override
  List<MangaSource> build() => sources;
}

void main() {
  testWidgets('Discover search queries every installed source in sections',
      (tester) async {
    final dex = _SearchSource('dex', 'MangaDex');
    final asura = _SearchSource('asura', 'AsuraScans', fail: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sourceRegistryProvider.overrideWith(() => _TestRegistry([dex, asura])),
      ],
      child: const CupertinoApp(home: BrowseScreen()),
    ));

    await tester.tap(find.text('Search titles, authors'));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'hero');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(dex.requests, contains(('hero', 1)));
    expect(asura.requests, contains(('hero', 1)));
    expect(
        find.textContaining(RegExp('MangaDex results', caseSensitive: false)),
        findsOneWidget);
    expect(
        find.textContaining(RegExp('AsuraScans results', caseSensitive: false)),
        findsOneWidget);
    expect(find.text('MangaDex page 1'), findsOneWidget);
    expect(find.textContaining('Source unavailable'), findsOneWidget);

    asura.fail = false;
    await tester.tap(find.text('Retry AsuraScans'));
    await tester.pumpAndSettle();
    expect(find.text('AsuraScans page 1'), findsOneWidget);
  });

  testWidgets('source sections load more without losing earlier results',
      (tester) async {
    final dex = _SearchSource('dex', 'MangaDex');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sourceRegistryProvider.overrideWith(() => _TestRegistry([dex])),
      ],
      child: const CupertinoApp(home: GlobalSearchScreen()),
    ));
    await tester.enterText(find.byType(CupertinoSearchTextField), 'hero');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load more MangaDex'));
    await tester.pumpAndSettle();
    expect(dex.requests, contains(('hero', 2)));
    expect(find.text('MangaDex page 1'), findsOneWidget);
    expect(find.text('MangaDex page 2'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'villain');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(dex.requests, contains(('villain', 1)));
    expect(dex.requests, isNot(contains(('villain', 2))));
    expect(find.text('MangaDex page 2'), findsNothing);
  });

  testWidgets('search starts for sources below the visible viewport',
      (tester) async {
    final sources = [
      for (var index = 0; index < 12; index++)
        _SearchSource('source-$index', 'Source $index'),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sourceRegistryProvider.overrideWith(() => _TestRegistry(sources)),
      ],
      child: const CupertinoApp(home: GlobalSearchScreen()),
    ));
    await tester.enterText(find.byType(CupertinoSearchTextField), 'hero');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    for (final source in sources) {
      expect(source.requests, contains(('hero', 1)),
          reason: '${source.name} should search before scrolling');
    }
  });
}
