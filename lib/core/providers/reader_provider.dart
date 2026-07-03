import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_provider.dart';
import 'provider_cache.dart';
import 'source_registry_provider.dart';

// ── Chapter pages ─────────────────────────────────────────────────────────────

// autoDispose: without it every chapter ever opened kept its page list (and
// provider machinery) alive for the whole session. The reader holds a watch
// while open, and the next-chapter prefetch holds a manual subscription, so
// the cache lives exactly as long as someone needs it.
final chapterPagesProvider = FutureProvider.autoDispose
    .family<List<String>, ChapterKey>((ref, key) async {
  // Re-opening a chapter within the TTL (e.g. backing out to check the
  // chapter list, or flipping between the last two chapters) costs nothing;
  // afterwards the page list ages out instead of accumulating per chapter.
  ref.cacheFor(const Duration(minutes: 15));

  // Serve from local storage when the chapter is downloaded
  if (key.downloadPath != null) {
    final dir = Directory(key.downloadPath!);
    if (await dir.exists()) {
      final pages = await dir
          .list()
          .where((e) => e is File && e.path.contains('page_'))
          .map((e) => e.path)
          .toList()
        ..sort();
      if (pages.isNotEmpty) return pages;
    }
  }

  // Fall back to network fetch
  final source = ref.watch(sourceByIdProvider(key.sourceId));
  if (source == null) throw Exception('Source ${key.sourceId} not found');
  final pages = await source.fetchPageUrls(key.chapterId);
  if (pages.isEmpty) {
    throw Exception(
        'No pages were found for this chapter. The source may have removed it.');
  }
  return pages;
});

class ChapterKey {
  const ChapterKey({
    required this.sourceId,
    required this.chapterId,
    this.downloadPath,
  });
  final String sourceId;
  final String chapterId;
  final String? downloadPath;

  @override
  bool operator ==(Object other) =>
      other is ChapterKey &&
      other.sourceId == sourceId &&
      other.chapterId == chapterId &&
      other.downloadPath == downloadPath;

  @override
  int get hashCode => Object.hash(sourceId, chapterId, downloadPath);
}


// ── Reading options ───────────────────────────────────────────────────────────

enum ReadingDirection { ltr, rtl, vertical }
enum PageScaleMode    { fitWidth, fitHeight, original }
enum ReaderBackground { black, white, sepia }

final readingDirectionProvider = StateProvider<ReadingDirection>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('reader.direction', next.index));
  return readEnumPref(prefs, 'reader.direction', ReadingDirection.values,
      ReadingDirection.ltr);
});

/// Per-title reading direction override. `null` means "use the global
/// [readingDirectionProvider] default" — webtoon manhwa and Japanese manga
/// have opposite natural defaults, so a per-title override avoids having to
/// flip the global setting every time the user switches between genres.
final mangaReadingDirectionProvider =
    StateProvider.family<ReadingDirection?, int>((ref, mangaId) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final key = 'reader.direction.manga.$mangaId';
  ref.listenSelf((_, next) {
    if (next == null) {
      prefs.remove(key);
    } else {
      prefs.setInt(key, next.index);
    }
  });
  final i = prefs.getInt(key);
  if (i == null || i < 0 || i >= ReadingDirection.values.length) return null;
  return ReadingDirection.values[i];
});

/// The direction actually used by the reader for [mangaId]: the per-title
/// override if one is set, otherwise the global default.
final effectiveReadingDirectionProvider =
    Provider.family<ReadingDirection, int>((ref, mangaId) {
  final override = ref.watch(mangaReadingDirectionProvider(mangaId));
  return override ?? ref.watch(readingDirectionProvider);
});

final pageScaleModeProvider = StateProvider<PageScaleMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('reader.pageScale', next.index));
  return readEnumPref(
      prefs, 'reader.pageScale', PageScaleMode.values, PageScaleMode.fitWidth);
});

final readerBackgroundProvider = StateProvider<ReaderBackground>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('reader.background', next.index));
  return readEnumPref(prefs, 'reader.background', ReaderBackground.values,
      ReaderBackground.black);
});

// ── Reader UI state ───────────────────────────────────────────────────────────

class ReaderState {
  const ReaderState({
    this.currentPage  = 0,
    this.totalPages   = 0,
    this.chromeVisible = false,
  });

  final int  currentPage;
  final int  totalPages;
  final bool chromeVisible;

  double get progress =>
      totalPages == 0 ? 0.0 : (currentPage + 1) / totalPages;

  ReaderState copyWith({int? currentPage, int? totalPages, bool? chromeVisible}) =>
      ReaderState(
        currentPage   : currentPage   ?? this.currentPage,
        totalPages    : totalPages    ?? this.totalPages,
        chromeVisible : chromeVisible ?? this.chromeVisible,
      );

  @override
  bool operator ==(Object other) =>
      other is ReaderState &&
      other.currentPage == currentPage &&
      other.totalPages == totalPages &&
      other.chromeVisible == chromeVisible;

  @override
  int get hashCode => Object.hash(currentPage, totalPages, chromeVisible);
}

class ReaderNotifier extends Notifier<ReaderState> {
  @override
  ReaderState build() => const ReaderState();

  void setTotalPages(int total) {
    if (state.totalPages == total) return;
    state = state.copyWith(totalPages: total, currentPage: 0);
  }

  void setPage(int page) => state = state.copyWith(currentPage: page);

  void toggleChrome() =>
      state = state.copyWith(chromeVisible: !state.chromeVisible);

  void hideChrome() => state = state.copyWith(chromeVisible: false);
}

final readerProvider =
    NotifierProvider<ReaderNotifier, ReaderState>(ReaderNotifier.new);
