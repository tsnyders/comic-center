import 'dart:io';
import 'dart:typed_data';

import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/database/models/manga_entry.dart';
import 'package:comic_center/core/extensions/models/chapter_info.dart';
import 'package:comic_center/core/extensions/models/filter.dart';
import 'package:comic_center/core/extensions/models/manga_detail.dart';
import 'package:comic_center/core/extensions/models/manga_summary.dart';
import 'package:comic_center/core/extensions/source_interface.dart';
import 'package:comic_center/core/services/library_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../support/local_isar.dart';

class _FakeSource extends MangaSource {
  _FakeSource(this.id, {this.chapters = const {}, this.fail = false});

  @override
  final String id;
  final Map<String, List<String>> chapters;
  final bool fail;
  final fetched = <String>[];

  @override
  String get name => id;
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
  Future<List<ChapterInfo>> fetchChapterList(String mangaId) async {
    fetched.add(mangaId);
    if (fail) throw StateError('Source unavailable');
    return [
      for (final id in chapters[mangaId] ?? const <String>[])
        ChapterInfo(id: id, title: id, number: double.parse(id.substring(1))),
    ];
  }

  @override
  Future<List<MangaSummary>> fetchPopular({int page = 1}) async => [];
  @override
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1}) async => [];
  @override
  Future<List<MangaSummary>> search(String query,
          {int page = 1, List<SourceFilter> filters = const []}) async =>
      [];
  @override
  Future<MangaDetail> fetchMangaDetail(String mangaId) =>
      throw UnimplementedError();
  @override
  Future<List<String>> fetchPageUrls(String chapterId) =>
      throw UnimplementedError();
}

MangaEntry _manga(int id, String sourceId, {bool inLibrary = true}) =>
    MangaEntry()
      ..id = id
      ..title = 'Title $id'
      ..sourceKey = '$sourceId::$id'
      ..sourceId = sourceId
      ..sourceMangaId = '$id'
      ..sourceUrl = ''
      ..inLibrary = inLibrary;

void main() {
  late Directory dir;
  late Isar isar;

  setUpAll(initializeLocalIsar);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yomi_update_test_');
    isar = await Isar.open([MangaEntrySchema, ChapterEntrySchema],
        directory: dir.path, name: 'update', inspector: false);
  });
  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  test('counts only new chapters, isolates failing titles, reports progress',
      () async {
    final good = _FakeSource('good', chapters: {
      '1': ['c1', 'c2'],
      '2': ['c3'],
      '4': ['c9'],
    });
    final bad = _FakeSource('bad', fail: true);
    await isar.writeTxn(() => isar.mangaEntrys.putAll([
          _manga(1, 'good'),
          _manga(2, 'good'),
          _manga(3, 'bad'),
          _manga(4, 'good', inLibrary: false),
          _manga(5, 'missing'),
        ]));
    // Title 1 already knows c1 (read): only c2 is new, and c1 keeps its state.
    await isar.writeTxn(() => isar.chapterEntrys.put(ChapterEntry()
      ..mangaId = 1
      ..sourceChapterId = 'c1'
      ..title = 'c1'
      ..isRead = true));

    final progress = <(int, int)>[];
    final result = await updateLibrary(isar, [good, bad],
        onProgress: (done, total) => progress.add((done, total)));

    expect(result.newChapters, 2);
    expect(result.updatedTitles, 2);
    expect(result.errors.keys, unorderedEquals([3, 5]));
    expect(progress.first, (0, 4));
    expect(progress.last, (4, 4));
    expect(good.fetched, unorderedEquals(['1', '2'])); // off-shelf skipped

    final c2 = await isar.chapterEntrys
        .filter()
        .sourceChapterIdEqualTo('c2')
        .findFirst();
    expect(c2?.dateFetched, isNotNull);
    final c1 = await isar.chapterEntrys
        .filter()
        .sourceChapterIdEqualTo('c1')
        .findFirst();
    expect(c1?.isRead, isTrue);
    expect(c1?.dateFetched, isNull);
    expect((await isar.mangaEntrys.get(1))?.unreadCount, 1);

    final again = await updateLibrary(isar, [good, bad]);
    expect(again.newChapters, 0);
    expect(again.updatedTitles, 0);
    expect(again.errors.keys, unorderedEquals([3, 5]));
  });
}
