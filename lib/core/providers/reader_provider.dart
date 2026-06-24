import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_provider.dart';
import 'source_registry_provider.dart';

// ── Chapter pages ─────────────────────────────────────────────────────────────

final chapterPagesProvider =
    FutureProvider.family<List<String>, _ChapterKey>((ref, key) async {
  final source = ref.watch(sourceByIdProvider(key.sourceId));
  if (source == null) throw Exception('Source ${key.sourceId} not found');
  return source.fetchPageUrls(key.chapterId);
});

class _ChapterKey {
  const _ChapterKey({required this.sourceId, required this.chapterId});
  final String sourceId;
  final String chapterId;

  @override
  bool operator ==(Object other) =>
      other is _ChapterKey &&
      other.sourceId == sourceId &&
      other.chapterId == chapterId;

  @override
  int get hashCode => Object.hash(sourceId, chapterId);
}

ChapterKey chapterKey({required String sourceId, required String chapterId}) =>
    ChapterKey(sourceId: sourceId, chapterId: chapterId);

typedef ChapterKey = _ChapterKey;

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
