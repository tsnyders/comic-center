import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models/chapter_entry.dart';
import '../services/downloaded_chapter_files.dart';
import 'database_provider.dart';
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

  // Re-read durable state instead of trusting the navigation-time snapshot.
  // A background worker may have completed after the reader route was built.
  final isar = ref.watch(isarProvider);
  final chapter = await isar.chapterEntrys.get(key.databaseChapterId);
  final downloadPath = chapter?.downloadPath ?? key.downloadPath;
  final isMarkedDownloaded = chapter?.isDownloaded ?? false;

  final pages = await resolveChapterPagePaths(
    downloadPath: downloadPath,
    isMarkedDownloaded: isMarkedDownloaded,
    expectedPageCount: chapter?.pageCount ?? 0,
    fetchNetworkPages: () async {
      final source = ref.watch(sourceByIdProvider(key.sourceId));
      if (source == null) throw Exception('Source ${key.sourceId} not found');
      return source.fetchPageUrls(key.sourceChapterId);
    },
  );
  if (pages.isEmpty) {
    throw Exception(
        'No pages were found for this chapter. The source may have removed it.');
  }
  return pages;
});

class ChapterKey {
  const ChapterKey({
    required this.databaseChapterId,
    required this.sourceId,
    required this.sourceChapterId,
    this.downloadPath,
  });
  final int databaseChapterId;
  final String sourceId;
  final String sourceChapterId;
  final String? downloadPath;

  @override
  bool operator ==(Object other) =>
      other is ChapterKey &&
      other.databaseChapterId == databaseChapterId &&
      other.sourceId == sourceId &&
      other.sourceChapterId == sourceChapterId &&
      other.downloadPath == downloadPath;

  @override
  int get hashCode =>
      Object.hash(databaseChapterId, sourceId, sourceChapterId, downloadPath);
}

// ── Reading options ───────────────────────────────────────────────────────────

enum ReadingDirection { ltr, rtl, vertical }

enum PageScaleMode { fitWidth, fitHeight, original }

enum ReaderBackground { black, white, sepia }

final readingDirectionProvider = StateProvider<ReadingDirection>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('reader.direction', next.index));
  return readEnumPref(
      prefs, 'reader.direction', ReadingDirection.values, ReadingDirection.ltr);
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
    this.currentPage = 0,
    this.totalPages = 0,
    this.chromeVisible = false,
  });

  final int currentPage;
  final int totalPages;
  final bool chromeVisible;

  double get progress => totalPages == 0 ? 0.0 : (currentPage + 1) / totalPages;

  ReaderState copyWith(
          {int? currentPage, int? totalPages, bool? chromeVisible}) =>
      ReaderState(
        currentPage: currentPage ?? this.currentPage,
        totalPages: totalPages ?? this.totalPages,
        chromeVisible: chromeVisible ?? this.chromeVisible,
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

// ── Reader mode (Page · 頁 / Strip · 縦) ──────────────────────────────────────

/// `auto` follows the title's webtoon detection; `page` / `strip` force it.
enum ReaderMode { auto, page, strip }

final defaultReaderModeProvider = StateProvider<ReaderMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('reader.mode', next.index));
  return readEnumPref(prefs, 'reader.mode', ReaderMode.values, ReaderMode.auto);
});

/// Per-title override. `null` means "use [defaultReaderModeProvider]".
final mangaReaderModeProvider =
    StateProvider.family<ReaderMode?, int>((ref, mangaId) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final key = 'reader.mode.manga.$mangaId';
  ref.listenSelf((_, next) {
    if (next == null) {
      prefs.remove(key);
    } else {
      prefs.setInt(key, next.index);
    }
  });
  final i = prefs.getInt(key);
  if (i == null || i < 0 || i >= ReaderMode.values.length) return null;
  return ReaderMode.values[i];
});

/// Whether [mangaId] reads as a continuous strip. [detectedWebtoon] is the
/// source / genre detection used when the effective mode is `auto`.
bool resolveStripMode(ReaderMode effective, {required bool detectedWebtoon}) =>
    switch (effective) {
      ReaderMode.auto => detectedWebtoon,
      ReaderMode.page => false,
      ReaderMode.strip => true,
    };

final effectiveReaderModeProvider =
    Provider.family<ReaderMode, int>((ref, mangaId) {
  final override = ref.watch(mangaReaderModeProvider(mangaId));
  return override ?? ref.watch(defaultReaderModeProvider);
});
