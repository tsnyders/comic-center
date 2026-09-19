import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models/chapter_entry.dart';
import 'preferences_provider.dart';

// ── Per-title chapter list view (persisted) ───────────────────────────────────

/// Number sorts keep DB order (number desc) so unnumbered chapters stay put.
enum ChapterSort {
  numberDesc('Newest first'),
  numberAsc('Oldest first'),
  dateDesc('Latest upload'),
  dateAsc('Earliest upload');

  const ChapterSort(this.label);
  final String label;
}

enum ChapterFilter {
  all('Show all'),
  unread('Unread only'),
  downloaded('Downloaded only');

  const ChapterFilter(this.label);
  final String label;
}

final chapterSortProvider =
    StateProvider.family<ChapterSort, int>((ref, mangaId) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final key = 'chapters.sort.$mangaId';
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => prefs.setInt(key, next.index));
  return readEnumPref(prefs, key, ChapterSort.values, ChapterSort.numberDesc);
});

final chapterFilterProvider =
    StateProvider.family<ChapterFilter, int>((ref, mangaId) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final key = 'chapters.filter.$mangaId';
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => prefs.setInt(key, next.index));
  return readEnumPref(prefs, key, ChapterFilter.values, ChapterFilter.all);
});

/// Applies [filter] then [sort] to [chapters] (DB order: number desc).
/// Date sorts are stable; undated chapters sink to the end.
List<ChapterEntry> applyChapterView(
  List<ChapterEntry> chapters, {
  required ChapterSort sort,
  required ChapterFilter filter,
}) {
  final kept = switch (filter) {
    ChapterFilter.all => chapters,
    ChapterFilter.unread => chapters.where((c) => !c.isRead),
    ChapterFilter.downloaded => chapters.where((c) => c.isDownloaded),
  }.toList();
  switch (sort) {
    case ChapterSort.numberDesc:
      return kept;
    case ChapterSort.numberAsc:
      return kept.reversed.toList();
    case ChapterSort.dateDesc:
    case ChapterSort.dateAsc:
      final sign = sort == ChapterSort.dateDesc ? -1 : 1;
      final indexed = kept.indexed.toList()
        ..sort((a, b) {
          final da = a.$2.uploadDate;
          final db = b.$2.uploadDate;
          if (da == null || db == null) {
            if (da == null && db == null) return a.$1 - b.$1;
            return da == null ? 1 : -1;
          }
          final r = da.compareTo(db) * sign;
          return r != 0 ? r : a.$1 - b.$1;
        });
      return [for (final (_, c) in indexed) c];
  }
}
