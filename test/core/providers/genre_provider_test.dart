import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/extensions/models/chapter_info.dart';
import 'package:comic_center/core/extensions/models/filter.dart';
import 'package:comic_center/core/extensions/models/manga_detail.dart';
import 'package:comic_center/core/extensions/models/manga_summary.dart';
import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/providers/browse_provider.dart';
import 'package:comic_center/core/providers/database_provider.dart';
import 'package:comic_center/core/providers/library_provider.dart';
import 'package:comic_center/core/providers/preferences_provider.dart';
import 'package:comic_center/core/providers/source_registry_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GenreSource extends MangaSource {
  int detailCalls = 0;
  String? requestedGenre;
  int? requestedPage;

  @override
  String get id => 'genre_test';
  @override
  String get name => 'Genre test';
  @override
  String get baseUrl => 'https://example.test';
  @override
  String get language => 'en';
  @override
  String get version => '1.0.0';
  @override
  Uint8List get iconBytes => Uint8List(0);
  @override
  Map<String, String> get imageHeaders => const {};

  @override
  Future<List<GenreOption>> fetchGenres() async =>
      const [GenreOption(id: 'action-id', name: 'Action')];

  @override
  Future<List<MangaSummary>> fetchByGenre(String genreId,
      {int page = 1}) async {
    requestedGenre = genreId;
    requestedPage = page;
    return const [MangaSummary(id: 'a', title: 'Action title')];
  }

  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) async {
    detailCalls++;
    return MangaDetail(
      id: mangaId,
      title: 'Restored title',
      genres: const [' Action ', 'action', 'Fantasy'],
    );
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async => const [];
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async =>
      const [];
  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) async =>
      const [];
  @override
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async => const [];
  @override
  Future<List<String>> fetchPageUrls(String chapterId) async => const [];
}

class _TestRegistry extends SourceRegistryNotifier {
  _TestRegistry(this.source);

  final MangaSource source;

  @override
  List<MangaSource> build() => [source];
}

MangaEntry _entry(int id, String title, List<String> genres,
    {DateTime? lastReadAt, List<String> categories = const []}) =>
    MangaEntry()
      ..id = id
      ..title = title
      ..sourceKey = 'genre_test::$id'
      ..sourceId = 'genre_test'
      ..sourceMangaId = '$id'
      ..sourceUrl = ''
      ..inLibrary = true
      ..genres = genres
      ..categories = categories
      ..lastReadAt = lastReadAt;

Future<void> _initializeLocalIsar() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final decoded = jsonDecode(await config.readAsString()) as Map<String, Object?>;
  final packages = decoded['packages'] as List<dynamic>;
  final libs = packages.cast<Map<String, dynamic>>().firstWhere(
        (package) => package['name'] == 'isar_flutter_libs',
      );
  final root = config.uri.resolve(libs['rootUri'] as String).toFilePath();
  final library = Platform.isWindows
      ? File('$root/windows/isar.dll')
      : Platform.isLinux
          ? File('$root/linux/libisar.so')
          : File('$root/macos/libisar.dylib');
  await Isar.initializeIsarCore(libraries: {Abi.current(): library.path});
}

void main() {
  test('source genre selection uses the source-native id and requested page',
      () async {
    final source = _GenreSource();
    final container = ProviderContainer(overrides: [
      sourceByIdProvider('genre_test').overrideWith((ref) => source),
    ]);
    addTearDown(container.dispose);

    final options =
        await container.read(sourceGenresProvider('genre_test').future);
    expect(options.single.name, 'Action');
    const args = BrowseArgs(
      sourceId: 'genre_test',
      mode: BrowseMode.genre,
      genreId: 'action-id',
      page: 3,
    );
    final results = await container.read(browseMangaProvider(args).future);
    expect(results.single.title, 'Action title');
    expect(source.requestedGenre, 'action-id');
    expect(source.requestedPage, 3);
  });

  test('library genre intersects shelf filter without category collisions',
      () async {
    final entries = [
      _entry(1, 'Action', [' Action ', 'action'],
          lastReadAt: DateTime(2026), categories: ['Reading']),
      _entry(2, 'Fantasy', ['Fantasy']),
      _entry(3, 'Action unread', ['Action']),
    ];
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      libraryStreamProvider.overrideWith((ref) => Stream.value(entries)),
      downloadedMangaIdsProvider.overrideWith((ref) => Stream.value(<int>{})),
    ]);
    addTearDown(container.dispose);
    await container.read(libraryStreamProvider.future);
    await container.read(downloadedMangaIdsProvider.future);

    expect(container.read(libraryGenresProvider), ['Action', 'Fantasy']);
    container.read(libraryGenreProvider.notifier).state = 'aCtIoN';
    expect(container.read(filteredLibraryProvider).valueOrNull?.length, 2);
    container.read(shelfFilterProvider.notifier).state = ShelfFilter.reading;
    expect(container.read(filteredLibraryProvider).valueOrNull?.single.id, 1);
  });

  test('opening an older saved title persists genres and preserves user state',
      () async {
    await _initializeLocalIsar();
    final dir = await Directory.systemTemp.createTemp('comic_genre_test_');
    addTearDown(() async => dir.delete(recursive: true));
    final isar = await Isar.open([MangaEntrySchema],
        directory: dir.path, name: 'genre_test');
    addTearDown(() async => isar.close(deleteFromDisk: true));

    final saved = _entry(1, 'Restored title', ['  '],
        lastReadAt: DateTime(2026), categories: ['Favorites'])
      ..lastReadPage = 9;
    await isar.writeTxn(() => isar.mangaEntrys.put(saved));
    final source = _GenreSource();

    final result = await upsertMangaEntry(
        isar: isar, source: source, mangaId: '1');
    expect(result.genres, ['Action', 'Fantasy']);
    final persisted = await isar.mangaEntrys.get(result.id);
    expect(persisted?.genres, ['Action', 'Fantasy']);
    expect(persisted?.inLibrary, isTrue);
    expect(persisted?.categories, ['Favorites']);
    expect(persisted?.lastReadPage, 9);

    await upsertMangaEntry(isar: isar, source: source, mangaId: '1');
    expect(source.detailCalls, 1);

    // Opening from Library goes straight to detail, so it uses the metadata
    // provider rather than the source-list upsert path above.
    final libraryTitle = _entry(2, 'Restored title', [], categories: ['Later']);
    await isar.writeTxn(() => isar.mangaEntrys.put(libraryTitle));
    final container = ProviderContainer(overrides: [
      isarProvider.overrideWith((ref) => isar),
      sourceRegistryProvider.overrideWith(() => _TestRegistry(source)),
    ]);
    addTearDown(container.dispose);
    final hydrated =
        await container.read(mangaMetadataProvider(libraryTitle.id).future);
    expect(hydrated?.genres, ['Action', 'Fantasy']);
    expect((await isar.mangaEntrys.get(libraryTitle.id))?.categories, ['Later']);
    expect(source.detailCalls, 2);
  });
}
