import 'dart:typed_data';

import 'package:comic_center/core/extensions/models/chapter_info.dart';
import 'package:comic_center/core/extensions/models/filter.dart';
import 'package:comic_center/core/extensions/models/manga_detail.dart';
import 'package:comic_center/core/extensions/models/manga_summary.dart';
import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/providers/browse_provider.dart';
import 'package:comic_center/core/providers/source_registry_provider.dart';
import 'package:comic_center/features/browse/source_manga_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _GenreSource extends MangaSource {
  bool genresFail = false;
  bool genresSupported = true;
  final requests = <String>[];

  @override
  String get id => 'genre-test';
  @override
  String get name => 'Test Source';
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
  Future<List<GenreOption>> fetchGenres() async {
    if (genresFail) throw StateError('Genres unavailable');
    return genresSupported
        ? const [GenreOption(id: 'source-action', name: 'Action')]
        : [];
  }

  Future<List<MangaSummary>> _listing(String request) async {
    requests.add(request);
    return [MangaSummary(id: request, title: '$request result')];
  }

  @override
  Future<List<MangaSummary>> fetchByGenre(String genreId, {int page = 1}) =>
      _listing(genreId);
  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) => _listing('popular');
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) =>
      _listing('latest');
  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) =>
      _listing('search:$query');
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

Future<void> _withSource(
  WidgetTester tester,
  _GenreSource source,
  Future<void> Function(ProviderContainer) verify,
) async {
  final container = ProviderContainer(overrides: [
    sourceByIdProvider(source.id).overrideWithValue(source),
  ]);
  try {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: CupertinoApp(home: SourceMangaScreen(sourceId: source.id)),
    ));
    await tester.pumpAndSettle();
    await verify(container);
  } finally {
    // Dispose while still inside the widget-test callback, before Flutter
    // verifies that no cache timers remain pending.
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  }
}

void main() {
  testWidgets('genre selects native results and clears when switching modes',
      (tester) async {
    final source = _GenreSource();
    await _withSource(tester, source, (container) async {
      expect(find.text('popular result'), findsOneWidget);

      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(source.requests, contains('source-action'));
      expect(find.text('source-action result'), findsOneWidget);
      expect(find.text('popular result'), findsNothing);
      expect(container.read(browseModeProvider(source.id)), BrowseMode.genre);

      await tester.tap(find.text('Latest'));
      await tester.pumpAndSettle();
      expect(find.text('latest result'), findsOneWidget);
      expect(container.read(browseGenreProvider(source.id)), isNull);

      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All genres'));
      await tester.pumpAndSettle();
      expect(find.text('popular result'), findsOneWidget);
      expect(container.read(browseGenreProvider(source.id)), isNull);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('search clears genre and clearing query restores popular',
      (tester) async {
    final source = _GenreSource();
    await _withSource(tester, source, (container) async {
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoSearchTextField), 'hero');
      await tester.pumpAndSettle();
      expect(find.text('search:hero result'), findsOneWidget);
      expect(container.read(browseGenreProvider(source.id)), isNull);
      await tester.enterText(find.byType(CupertinoSearchTextField), '');
      await tester.pumpAndSettle();
      expect(find.text('popular result'), findsOneWidget);
    });
  });

  testWidgets('genre loading failure can be retried without losing listing',
      (tester) async {
    final source = _GenreSource()..genresFail = true;
    await _withSource(tester, source, (_) async {
      expect(find.text('popular result'), findsOneWidget);
      expect(find.text('Retry loading genres'), findsOneWidget);
      source.genresFail = false;
      await tester.tap(find.text('Retry loading genres'));
      await tester.pumpAndSettle();
      expect(find.text('Action'), findsOneWidget);
    });
  });

  testWidgets('unsupported source keeps popular and latest usable',
      (tester) async {
    await _withSource(tester, _GenreSource()..genresSupported = false, (_) async {
      expect(find.text('Genre browsing is unavailable for this source.'),
          findsOneWidget);
      expect(find.text('All genres'), findsNothing);
      await tester.tap(find.text('Latest'));
      await tester.pumpAndSettle();
      expect(find.text('latest result'), findsOneWidget);
    });
  });
}
