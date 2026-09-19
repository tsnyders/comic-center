import 'package:comic_center/core/database/models/chapter_entry.dart';
import 'package:comic_center/core/providers/chapter_prefs_provider.dart';
import 'package:flutter_test/flutter_test.dart';

ChapterEntry _ch(int id, {bool read = false, bool dl = false, DateTime? at}) =>
    ChapterEntry()
      ..id = id
      ..mangaId = 1
      ..sourceChapterId = '$id'
      ..title = 'Ch $id'
      ..number = id.toDouble()
      ..isRead = read
      ..isDownloaded = dl
      ..uploadDate = at;

void main() {
  // DB order: number desc.
  final chs = [
    _ch(4, at: DateTime(2026, 1, 1)),
    _ch(3, read: true, dl: true),
    _ch(2, dl: true, at: DateTime(2026, 2, 1)),
    _ch(1, read: true, at: DateTime(2026, 1, 15)),
  ];
  List<int> ids(ChapterSort sort, ChapterFilter filter) =>
      applyChapterView(chs, sort: sort, filter: filter)
          .map((c) => c.id)
          .toList();

  test('filters and sorts; undated chapters keep to the end', () {
    expect(ids(ChapterSort.numberDesc, ChapterFilter.all), [4, 3, 2, 1]);
    expect(ids(ChapterSort.numberAsc, ChapterFilter.all), [1, 2, 3, 4]);
    expect(ids(ChapterSort.dateDesc, ChapterFilter.all), [2, 1, 4, 3]);
    expect(ids(ChapterSort.dateAsc, ChapterFilter.all), [4, 1, 2, 3]);
    expect(ids(ChapterSort.numberDesc, ChapterFilter.unread), [4, 2]);
    expect(ids(ChapterSort.numberAsc, ChapterFilter.downloaded), [2, 3]);
  });
}
