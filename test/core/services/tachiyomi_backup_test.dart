import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:comic_center/core/services/tachiyomi_backup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads independently encoded protobuf fixture', () {
    final result = TachiyomiBackup.decode(
        File('test/fixtures/tachiyomi/library.tachibk').readAsBytesSync());
    expect(result.mangaCount, 2);
    expect(result.chapterCount, 2);
    expect(result.categories, ['Manhwa']);
    expect(result.manga.first['sourceKey'],
        'mangadex_en_v5::00000000-0000-4000-8000-000000000001');
    expect(result.manga.first['lastReadPage'], 9);
    expect(result.manga.last['sourceId'], 'tachiyomi:9223372036854775807');
    expect(result.unavailableSources, ['Unavailable source (JA)']);
  });

  test('converts supported comic and manga URLs to native reader IDs', () {
    for (final example in [
      (
        'MangaDex (EN)',
        '/title/00000000-0000-4000-8000-000000000001',
        '/chapter/00000000-0000-4000-8000-000000000002',
        'mangadex_en_v5',
        '00000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000002'
      ),
      (
        'ReadComicOnline',
        '/Comic/Example',
        '/Comic/Example/Issue-1?id=12',
        'readcomiconline_en',
        'Example',
        'Comic/Example/Issue-1?id=12'
      ),
      (
        'ComicExtra',
        '/comic/example',
        '/example/chapter-1/full',
        'comicextra_en',
        'example',
        'example/chapter-1'
      ),
      (
        'DemonicScans',
        '/manga/example',
        '/chaptered.php?manga=12&chapter=1',
        'demonicscans_en',
        'example',
        'chaptered.php?manga=12&chapter=1'
      ),
    ]) {
      final result = TachiyomiBackup.decode([
        ...pbBytes(1, [
          ...pbInt(1, 42),
          ...pbText(2, example.$2),
          ...pbText(3, 'Example'),
          ...pbBytes(16, fixtureChapter(example.$3, 1))
        ]),
        ...pbBytes(101, [...pbText(1, example.$1), ...pbInt(2, 42)]),
      ]);
      final manga = result.manga.single;
      expect(manga['sourceId'], example.$4);
      expect(manga['sourceMangaId'], example.$5);
      expect(
          (manga['chapters'] as List<Map<String, Object?>>)
              .single['sourceChapterId'],
          example.$6);
    }
  });

  test(
      'imports gzip library, categories, full chapter list and partial progress',
      () {
    final result = TachiyomiBackup.decode(gzip.encode(backupFixture()));
    expect(result.mangaCount, 1);
    expect(result.chapterCount, 3);
    expect(result.categories, ['Reading']);
    expect(result.unavailableSources, isEmpty);
    final manga = result.manga.single;
    expect(manga['sourceKey'], 'mangapill_en::123/example');
    expect(manga['lastReadChapterId'], 'chapters/123-2');
    expect(manga['lastReadPage'], 7);
    expect(manga['lastReadChapterNumber'], 2.5);
    expect(manga['categories'], ['Reading']);
    expect(manga['genres'], ['Action', '冒険']);
    final chapters = manga['chapters'] as List<Map<String, Object?>>;
    expect(chapters[0]['isRead'], true);
    expect(chapters[1]['isRead'], false);
    expect(chapters[1]['lastPageRead'], 7);
    expect(chapters[2]['isRead'], false);
    final serialized = jsonEncode(result.payload);
    for (final field in [
      'downloadPath',
      'isDownloaded',
      'downloadedAt',
      'tracking'
    ]) {
      expect(serialized, isNot(contains(field)));
    }
  });

  test('preserves unknown source IDs without rounding or title-only matching',
      () {
    final result =
        TachiyomiBackup.decode(backupFixture(sourceName: 'Unavailable (JA)'));
    expect(result.manga.single['sourceId'], 'tachiyomi:9007199254740993');
    expect(result.manga.single['sourceMangaId'], '/manga/123/example');
    expect(result.unavailableSources, ['Unavailable (JA)']);
  });

  test('preserves entries from incompatible language variants', () {
    final result =
        TachiyomiBackup.decode(backupFixture(sourceName: 'MangaPill (JA)'));
    expect(result.unavailableSources, ['MangaPill (JA)']);
  });

  test('supports old source/history field zero and packed category IDs', () {
    final result = TachiyomiBackup.decode(backupFixture(legacy: true));
    expect(result.manga.single['sourceId'], 'mangapill_en');
    expect(result.manga.single['lastReadPage'], 7);
    expect(result.manga.single['categories'], ['Reading']);
  });

  test('supports newer category IDs and skips non-library entries', () {
    final result = TachiyomiBackup.decode(backupFixture(modern: true));
    expect(result.manga.single['categories'], ['Reading']);
    expect(
        TachiyomiBackup.decode(backupFixture(favorite: false)).manga, isEmpty);
  });

  test('unknown protobuf fields do not break forward compatibility', () {
    final result = TachiyomiBackup.decode([
      ...backupFixture(),
      ...pbBytes(999, [1, 2, 3])
    ]);
    expect(result.mangaCount, 1);
  });

  test('rejects truncated, malformed, empty, JSON and image files', () {
    for (final bytes in <List<int>>[
      [],
      [10, 100, 1],
      [10, 1, 128],
      [15],
      [8, 1],
      utf8.encode('{"version": 1}'),
      [0x89, 0x50, 0x4e, 0x47],
      gzip.encode([10, 20]),
      [0x1f, 0x8b, 0],
      pbBytes(1, pbText(3, 'Missing source and URL')),
    ]) {
      expect(() => TachiyomiBackup.decode(bytes), throwsFormatException);
    }
  });
}

// Wire fixtures use the published Tachiyomi/Mihon ProtoNumber tags, without
// sharing encoding code with the importer. See docs/TACHIYOMI_IMPORT.md.
List<int> backupFixture({
  String sourceName = 'MangaPill (EN)',
  bool legacy = false,
  bool modern = false,
  bool favorite = true,
}) {
  const source = 9007199254740993;
  final category = modern ? 42 : 2;
  return [
    ...pbBytes(1, [
      ...pbInt(1, source),
      ...pbText(2, '/manga/123/example'),
      ...pbText(3, 'Example 漫画'),
      ...pbText(7, 'Action'),
      ...pbText(7, '冒険'),
      ...pbInt(8, 1),
      ...pbInt(13, 1700000000000),
      ...pbBytes(16, fixtureChapter('/chapters/123-1', 1, read: true)),
      ...pbBytes(16, fixtureChapter('/chapters/123-2', 2.5, page: 7)),
      ...pbBytes(16, fixtureChapter('/chapters/123-3', 3)),
      ...pbBytes(17, pbVarint(category)),
      ...pbInt(100, favorite ? 1 : 0),
      ...pbBytes(legacy ? 102 : 104, [
        ...pbText(legacy ? 0 : 1, '/chapters/123-2'),
        ...pbInt(legacy ? 1 : 2, 1700001000000),
      ]),
    ]),
    ...pbBytes(2, [
      ...pbText(1, 'Reading'),
      ...pbInt(2, 2),
      if (modern) ...pbInt(3, 42),
    ]),
    ...pbBytes(legacy ? 100 : 101, [
      ...pbText(legacy ? 0 : 1, sourceName),
      ...pbInt(legacy ? 1 : 2, source),
    ]),
  ];
}

List<int> fixtureChapter(String url, double number,
        {bool read = false, int page = 0}) =>
    [
      ...pbText(1, url),
      ...pbText(2, 'Chapter $number'),
      ...pbInt(4, read ? 1 : 0),
      ...pbInt(6, page),
      ...pbVarint((9 << 3) | 5),
      ...(ByteData(4)..setFloat32(0, number, Endian.little))
          .buffer
          .asUint8List(),
    ];

List<int> pbText(int tag, String text) => pbBytes(tag, utf8.encode(text));
List<int> pbBytes(int tag, List<int> bytes) =>
    [...pbVarint((tag << 3) | 2), ...pbVarint(bytes.length), ...bytes];
List<int> pbInt(int tag, int value) =>
    [...pbVarint(tag << 3), ...pbVarint(value)];
List<int> pbVarint(int value) {
  final bytes = <int>[];
  do {
    final part = value & 127;
    value = value >>> 7;
    bytes.add(part | (value == 0 ? 0 : 128));
  } while (value != 0);
  return bytes;
}
