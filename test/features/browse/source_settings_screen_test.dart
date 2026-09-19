import 'dart:typed_data';

import 'package:comic_center/core/extensions/models/chapter_info.dart';
import 'package:comic_center/core/extensions/models/filter.dart';
import 'package:comic_center/core/extensions/models/manga_detail.dart';
import 'package:comic_center/core/extensions/models/manga_summary.dart';
import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/providers/preferences_provider.dart';
import 'package:comic_center/features/browse/source_settings_screen.dart';
import 'package:comic_center/shared/widgets/sumi.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PrefSource extends MangaSource {
  @override
  String get id => 'pref-test';
  @override
  String get name => 'Pref Source';
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
  List<SourcePreference> get preferences => const [
        TogglePreference(key: 'flag', title: 'Flag'),
        SelectPreference(
          key: 'lang',
          title: 'Language',
          options: ['English', 'Japanese'],
          values: ['en', 'ja'],
          defaultValue: 'en',
        ),
        MultiSelectPreference(
          key: 'ratings',
          title: 'Ratings',
          options: ['Safe', 'Erotica'],
          values: ['safe', 'erotica'],
          defaultValue: ['safe'],
        ),
      ];

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) =>
      throw UnimplementedError();
  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) =>
      throw UnimplementedError();
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

void main() {
  testWidgets('writes toggle, select and multi-select under source.<id>.<key>',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: CupertinoApp(home: SourceSettingsScreen(source: _PrefSource())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SumiToggle));
    await tester.pumpAndSettle();
    expect(prefs.getBool('source.pref-test.flag'), isTrue);

    await tester.tap(find.text('Japanese'));
    await tester.pumpAndSettle();
    expect(prefs.getString('source.pref-test.lang'), 'ja');

    await tester.tap(find.text('Erotica'));
    await tester.pumpAndSettle();
    expect(prefs.getStringList('source.pref-test.ratings'), ['safe', 'erotica']);

    await tester.tap(find.text('Safe'));
    await tester.pumpAndSettle();
    expect(prefs.getStringList('source.pref-test.ratings'), ['erotica']);
  });
}
