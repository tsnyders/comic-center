import 'dart:async';
import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../core/providers/library_provider.dart';
import '../../core/providers/reader_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/device_profile.dart';
import '../../core/services/downloaded_chapter_files.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/sumi.dart';
import 'widgets/page_pill.dart';
import 'widgets/progress_line.dart';
import 'widgets/reader_chrome.dart';

/// Lightweight description of a chapter passed to the reader for navigation.
class ReaderChapterSummary {
  const ReaderChapterSummary({
    required this.id,
    required this.sourceChapterId,
    required this.title,
    this.number,
    this.downloadPath,
    this.isRead = false,
  });
  final int id;
  final String sourceChapterId;
  final String title;
  final double? number;
  final String? downloadPath;

  /// Snapshot at open time (the chapter picker dims read chapters).
  final bool isRead;
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    required this.sourceId,
    required this.sourceChapterId,
    required this.chapterTitle,
    this.mangaTitle = '',
    this.chapterNumber,
    this.downloadPath,
    this.isWebtoon = false,
    this.chapters = const [],
    this.chapterIndex = -1,
    this.initialPage = 0,
  });

  final int mangaId;
  final int chapterId;
  final String sourceId;
  final String sourceChapterId;
  final String chapterTitle;
  final String mangaTitle;
  final double? chapterNumber;
  final String? downloadPath;

  /// Source / genre detection. The effective mode may override it (Page · 頁
  /// / Strip · 縦 switch in the chrome, persisted per title).
  final bool isWebtoon;
  final List<ReaderChapterSummary> chapters;
  final int chapterIndex;

  /// Page to open on (the chapter's last read page for "Continue").
  final int initialPage;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  static const _platform = MethodChannel('yomi/platform');
  static const _volumeKeys = EventChannel('yomi/volume_keys');

  late PageController _pageController;
  late final ScrollController _scrollController;

  /// Effective mode for this build (see [effectiveReaderModeProvider]).
  bool _strip = false;
  bool _didInit = false;

  // Driven directly (without setState) from the scroll/page-change callbacks so
  // that scrolling a webtoon or turning a page does NOT rebuild the entire
  // reader Stack (image list + chrome) every frame — only the tiny progress
  // line and page pill repaint, via ValueListenableBuilder.
  final ValueNotifier<bool> _pillVisible = ValueNotifier(false);
  final ValueNotifier<double> _webtoonProgress = ValueNotifier(0.0);
  Timer? _pillHideTimer;
  bool _chapterMarkedRead = false;

  // Warms chapterPagesProvider for the next chapter once the reader is 80%
  // through the current one, so tapping "next" doesn't sit on a spinner while
  // page URLs are fetched. Held as a manual subscription because the provider
  // is autoDispose — closing it (in dispose) releases the prefetched data.
  ProviderSubscription<AsyncValue<List<String>>>? _nextChapterPrefetch;

  // Mid-chapter progress, debounced so a fast flick through pages costs one
  // Isar write rather than one per page. Flushed on dispose. The notifier is
  // captured here because `ref` is unusable once the widget is disposed.
  late final LibraryNotifier _library;
  Timer? _progressTimer;
  int _pendingPage = -1;

  /// The reader that owns the app-wide toggles (volume keys, keep screen on,
  /// brightness, system UI). Next/previous chapter *replaces* the route, and
  /// the outgoing screen is disposed after the incoming one's initState, so
  /// only the last reader standing hands them back to the app.
  static _ReaderScreenState? _active;
  static StreamSubscription<dynamic>? _volumeSub;

  @override
  void initState() {
    super.initState();
    _active = this;
    _library = ref.read(libraryNotifierProvider.notifier);
    _pageController = PageController(initialPage: widget.initialPage);
    _scrollController = ScrollController();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Only fires while the strip view is attached; harmless otherwise.
    _scrollController.addListener(_onWebtoonScroll);
    _enableVolumeKeys();
    _setKeepScreenOn(ref.read(keepScreenOnProvider));
  }

  @override
  void dispose() {
    _flushProgress();
    _pillHideTimer?.cancel();
    _nextChapterPrefetch?.close();
    if (_active == this) {
      _active = null;
      _volumeSub?.cancel();
      _volumeSub = null;
      if (Platform.isAndroid) {
        _platform
            .invokeMethod<void>('setVolumeKeyIntercept', {'enabled': false});
      }
      _setKeepScreenOn(false);
      _restoreBrightness();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    }
    _pillVisible.dispose();
    _webtoonProgress.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Volume-key page turning ──────────────────────────────────────────────

  void _enableVolumeKeys() {
    // Volume-key page turning is backed by an Android-only platform channel;
    // iOS apps can't intercept the hardware volume buttons, so skip entirely.
    if (!Platform.isAndroid) return;
    _platform.invokeMethod<void>('setVolumeKeyIntercept', {'enabled': true});
    // One stream for whichever reader is active: a second listen makes the
    // EventChannel cancel the first, which would kill the sink under the
    // incoming reader when the outgoing one unsubscribes.
    _volumeSub ??= _volumeKeys.receiveBroadcastStream().listen((event) {
      if (event == 'down') {
        _active?._turnPage(forward: true);
      } else if (event == 'up') {
        _active?._turnPage(forward: false);
      }
    });
  }

  void _turnPage({required bool forward}) {
    final reader = ref.read(readerProvider);
    final total = reader.totalPages;
    if (total == 0) return;
    final target = (forward ? reader.currentPage + 1 : reader.currentPage - 1)
        .clamp(0, total - 1);
    if (target == reader.currentPage) return;
    if (ref.read(hapticsProvider)) HapticFeedback.selectionClick();
    if (_strip) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        (target / total) * _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (e, st) {
      AppLogger.instance
          .warn('Failed to reset screen brightness on reader close', e, st);
    }
  }

  // ── Keep screen on ───────────────────────────────────────────────────────

  void _setKeepScreenOn(bool on) {
    if (!Platform.isAndroid) return;
    _platform.invokeMethod<void>('setKeepScreenOn', {'enabled': on});
  }

  // ── Reading progress (debounced) ─────────────────────────────────────────

  void _queueProgress(int page) {
    _pendingPage = page;
    _progressTimer?.cancel();
    _progressTimer = Timer(const Duration(seconds: 1), _flushProgress);
  }

  void _flushProgress() {
    _progressTimer?.cancel();
    if (_pendingPage < 0) return;
    final page = _pendingPage;
    _pendingPage = -1;
    _library.saveChapterProgress(
        mangaId: widget.mangaId, chapterId: widget.chapterId, page: page);
  }

  // ── Chapter navigation (chapters are newest-first) ───────────────────────

  bool get _hasNextChapter =>
      widget.chapterIndex > 0 && widget.chapters.isNotEmpty;

  bool get _hasPrevChapter =>
      widget.chapterIndex >= 0 &&
      widget.chapterIndex < widget.chapters.length - 1;

  ReaderChapterSummary get _nextSummary =>
      widget.chapters[widget.chapterIndex - 1];

  void _goToNextChapter(BuildContext context) =>
      _openChapter(context, widget.chapterIndex - 1);

  void _goToPrevChapter(BuildContext context) =>
      _openChapter(context, widget.chapterIndex + 1);

  void _openChapter(BuildContext context, int index) {
    HapticFeedback.lightImpact();
    final target = widget.chapters[index];
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ReaderScreen(
          mangaId: widget.mangaId,
          mangaTitle: widget.mangaTitle,
          chapterId: target.id,
          sourceId: widget.sourceId,
          sourceChapterId: target.sourceChapterId,
          chapterTitle: target.title,
          chapterNumber: target.number,
          downloadPath: target.downloadPath,
          isWebtoon: widget.isWebtoon,
          chapters: widget.chapters,
          chapterIndex: index,
        ),
      ),
    );
  }

  void _showChapterPicker(BuildContext context) {
    if (widget.chapters.isEmpty) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => _ChapterPickerSheet(
        chapters: widget.chapters,
        currentIndex: widget.chapterIndex,
        onSelect: (i) {
          Navigator.of(sheetContext).pop();
          if (i != widget.chapterIndex) _openChapter(context, i);
        },
      ),
    );
  }

  // ── Next chapter prefetch ────────────────────────────────────────────────

  void _maybePrefetchNextChapter(double progress) {
    if (_nextChapterPrefetch != null || progress < 0.8 || !_hasNextChapter) {
      return;
    }
    final next = _nextSummary;
    _nextChapterPrefetch = ref.listenManual(
      chapterPagesProvider(ChapterKey(
        databaseChapterId: next.id,
        sourceId: widget.sourceId,
        sourceChapterId: next.sourceChapterId,
        downloadPath: next.downloadPath,
      )),
      (_, __) {},
    );
  }

  // ── Auto-mark as read ────────────────────────────────────────────────────

  void _tryMarkAsRead(int lastPage) {
    if (_chapterMarkedRead) return;
    _chapterMarkedRead = true;
    ref.read(libraryNotifierProvider.notifier).markChapterRead(
          mangaId: widget.mangaId,
          chapterId: widget.chapterId,
          lastPage: lastPage,
        );
  }

  // ── Webtoon scroll tracking ───────────────────────────────────────────────

  void _onWebtoonScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;

    final rawProgress = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    final total = ref.read(readerProvider).totalPages;
    // Epsilon: the ratio round-trip (page/total → pixels → page) can land a
    // hair under the integer and floor to the previous page.
    final page = total > 0
        ? (rawProgress * total + 1e-6).floor().clamp(0, total - 1)
        : 0;

    // Push the page index to the provider only when the *integer* page
    // actually changes (a few times per chapter), never every frame.
    if (ref.read(readerProvider).currentPage != page) {
      ref.read(readerProvider.notifier).setPage(page);
      _queueProgress(page);
    }

    // Per-frame values go through ValueNotifiers — no setState, so the image
    // list is not rebuilt while scrolling.
    _webtoonProgress.value = rawProgress;
    _showPillBriefly();

    _maybePrefetchNextChapter(rawProgress);

    // Mark as read when 95% through the webtoon
    if (rawProgress >= 0.95 && total > 0) {
      _tryMarkAsRead(total - 1);
    }
  }

  /// Show the page-count pill and schedule it to fade after 2s. Uses a single
  /// cancellable timer (not stacked `Future.delayed`s) and drives visibility
  /// through the [_pillVisible] notifier so no full rebuild is triggered.
  void _showPillBriefly() {
    _pillVisible.value = true;
    _pillHideTimer?.cancel();
    _pillHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _pillVisible.value = false;
    });
  }

  // ── Seek (chrome scrubber) ───────────────────────────────────────────────

  void _onSeek(int page) {
    if (_strip) {
      if (!_scrollController.hasClients) return;
      final total = ref.read(readerProvider).totalPages;
      if (total == 0) return;
      _scrollController.animateTo(
        (page / total) * _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Page · 頁 / Strip · 縦 ───────────────────────────────────────────────

  /// Persisted per title. Keeps the current page across the view swap.
  void _setMode(ReaderMode mode) {
    final page = ref.read(readerProvider).currentPage;
    final total = ref.read(readerProvider).totalPages;
    final toStrip = mode == ReaderMode.strip;
    if (toStrip == _strip) return;
    if (!toStrip) {
      _pageController.dispose();
      _pageController = PageController(initialPage: page);
    }
    ref.read(mangaReaderModeProvider(widget.mangaId).notifier).state = mode;
    if (toStrip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients || total == 0) return;
        _scrollController.jumpTo(
            (page / total) * _scrollController.position.maxScrollExtent);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterKey = ChapterKey(
      databaseChapterId: widget.chapterId,
      sourceId: widget.sourceId,
      sourceChapterId: widget.sourceChapterId,
      downloadPath: widget.downloadPath,
    );
    final pagesAsync = ref.watch(chapterPagesProvider(chapterKey));
    final readerState = ref.watch(readerProvider);
    ref.listen(keepScreenOnProvider, (_, on) => _setKeepScreenOn(on));
    final direction =
        ref.watch(effectiveReadingDirectionProvider(widget.mangaId));
    final background = ref.watch(readerBackgroundProvider);
    final chromeVisible = readerState.chromeVisible;
    final strip = resolveStripMode(
      ref.watch(effectiveReaderModeProvider(widget.mangaId)),
      detectedWebtoon: widget.isWebtoon,
    );
    final imageHeaders =
        ref.watch(sourceByIdProvider(widget.sourceId))?.imageHeaders;
    _strip = strip;

    // Pastel keeps its cream (or plum) canvas instead of pure black.
    final bgColor = switch (background) {
      ReaderBackground.black =>
        context.look.isPastel ? context.yc.bg : AppColors.readerBackground,
      ReaderBackground.white => AppColors.readerWhite,
      ReaderBackground.sepia => AppColors.readerSepia,
    };

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: pagesAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle,
                  color: AppColors.textTertiary, size: 32),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                color: context.yc.ac,
                onPressed: () =>
                    ref.invalidate(chapterPagesProvider(chapterKey)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (pages) {
          // readerProvider is app-wide, so always reset it here: when the
          // page count matches the previous chapter, setTotalPages alone is
          // a no-op and the stale page would stick (and skip the resume jump).
          if (!_didInit) {
            _didInit = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              // Land on the requested page ("Continue" → last read page).
              final start = widget.initialPage.clamp(0, pages.length - 1);
              ref.read(readerProvider.notifier)
                ..setTotalPages(pages.length)
                ..setPage(start);
              if (start > 0 && strip && _scrollController.hasClients) {
                _scrollController.jumpTo((start / pages.length) *
                    _scrollController.position.maxScrollExtent);
              }
            });
          }

          return Stack(
            children: [
              // ── Content ──────────────────────────────────────────────────
              if (strip)
                _buildWebtoonView(context, pages, chromeVisible, imageHeaders)
              else
                _buildPagedView(context, pages, direction, background,
                    chromeVisible, imageHeaders),

              // ── Always-visible 2px progress line — pinned at the very top ──
              // Sits at top:0 (above the safe-area notch) so it is always
              // visible regardless of chrome state, per spec.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 2,
                child: strip
                    // Webtoon progress updates every scroll frame — isolate it
                    // in a ValueListenableBuilder so only this 2px line repaints.
                    ? ValueListenableBuilder<double>(
                        valueListenable: _webtoonProgress,
                        builder: (_, p, __) => ProgressLine(progress: p),
                      )
                    : ProgressLine(progress: readerState.progress),
              ),

              // ── Tap-to-reveal chrome (200ms opacity + 8px translate) ───────
              // Top bar slides -8px (upward) when hiding; bottom bar +8px.
              // The translate is applied per-bar inside ReaderChrome.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !chromeVisible,
                  child: ReaderChrome(
                    mangaTitle: widget.mangaTitle,
                    chapterTitle: widget.chapterTitle,
                    chapterNumber: widget.chapterNumber,
                    currentPage: readerState.currentPage,
                    totalPages: readerState.totalPages,
                    visible: chromeVisible,
                    isStrip: strip,
                    onClose: () => Navigator.of(context).pop(),
                    onSettings: () => _showSettings(context),
                    onSeek: _onSeek,
                    onModeChanged: _setMode,
                    onChapterTap: () => _showChapterPicker(context),
                    onPrevChapter: _hasPrevChapter
                        ? () => _goToPrevChapter(context)
                        : null,
                    onNextChapter: _hasNextChapter
                        ? () => _goToNextChapter(context)
                        : null,
                  ),
                ),
              ),

              // ── Page/image count pill ─────────────────────────────────────
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 90,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _pillVisible,
                  builder: (_, pillVisible, __) => PagePill(
                    current: readerState.currentPage + 1,
                    total: readerState.totalPages,
                    visible: pillVisible && !chromeVisible,
                  ),
                ),
              ),

              // ── Persistent next-chapter button (bottom-right, below the
              //     page count pill) — visible the whole time you read ───────
              if (_hasNextChapter && !chromeVisible)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 30,
                  right: 16,
                  child: _NextChapterButton(
                    onTap: () => _goToNextChapter(context),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Paged view (manga) ───────────────────────────────────────────────────

  Widget _buildPagedView(
    BuildContext context,
    List<String> pages,
    ReadingDirection direction,
    ReaderBackground background,
    bool chromeVisible,
    Map<String, String>? imageHeaders,
  ) {
    final isVertical = direction == ReadingDirection.vertical;
    final isRtl = direction == ReadingDirection.rtl;

    return GestureDetector(
      // Left/right edge tap zones turn the page (the non-hardware-key
      // alternative to Android's volume-button paging — also useful on
      // Android as a faster alternative to swiping). Middle third toggles
      // chrome. Zones are swapped under RTL so "tap toward the spine"
      // always means "go forward," matching swipe direction. Vertical
      // paging has no left/right concept, so it keeps tap-to-toggle only.
      onTapUp: (details) {
        if (isVertical) {
          ref.read(readerProvider.notifier).toggleChrome();
          return;
        }
        final width = MediaQuery.sizeOf(context).width;
        final x = details.localPosition.dx;
        if (x < width / 3) {
          _turnPage(forward: isRtl);
        } else if (x > width * 2 / 3) {
          _turnPage(forward: !isRtl);
        } else {
          ref.read(readerProvider.notifier).toggleChrome();
        }
      },
      // Swipe down to dismiss the reader (horizontal paging only, where
      // vertical drags are otherwise unused).
      onVerticalDragEnd: isVertical
          ? null
          : (details) {
              if ((details.primaryVelocity ?? 0) > 320) {
                Navigator.of(context).maybePop();
              }
            },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
        reverse: isRtl,
        // Pre-builds the adjacent page so its image is decoded before the
        // swipe starts, instead of showing a spinner mid-gesture.
        allowImplicitScrolling: true,
        itemCount: pages.length,
        onPageChanged: (i) {
          ref.read(readerProvider.notifier).setPage(i);
          _queueProgress(i);
          _showPillBriefly();
          _maybePrefetchNextChapter((i + 1) / pages.length);
          if (i == pages.length - 1) _tryMarkAsRead(i);
        },
        itemBuilder: (context, i) => _ReaderPage(
          url: pages[i],
          index: i,
          background: background,
          headers: imageHeaders,
        ),
      ),
    );
  }

  // ── Webtoon view (manhwa / continuous vertical scroll) ───────────────────

  Widget _buildWebtoonView(
    BuildContext context,
    List<String> pages,
    bool chromeVisible,
    Map<String, String>? imageHeaders,
  ) {
    final hasFooter = _hasNextChapter;
    final gap = ref.watch(stripGapProvider).toDouble();
    return GestureDetector(
      onTap: () => ref.read(readerProvider.notifier).toggleChrome(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        // The default cache extent (250px) means strips start loading only as
        // they reach the viewport edge — the visible "image pops in while I
        // scroll" stall. Read ahead by whole screens instead; low-spec devices
        // get a smaller window to bound decoded-image memory.
        scrollCacheExtent: DeviceProfile.current.lowSpec
            ? const ScrollCacheExtent.viewport(1.0)
            : const ScrollCacheExtent.viewport(2.5),
        itemCount: pages.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == pages.length) {
            return _NextChapterFooter(
              title: _nextSummary.title,
              onTap: () => _goToNextChapter(context),
            );
          }
          final page = _WebtoonPage(
            url: pages[i],
            index: i,
            headers: imageHeaders,
          );
          return gap > 0
              ? Padding(padding: EdgeInsets.only(bottom: gap), child: page)
              : page;
        },
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _ReaderSettingsSheet(
        isWebtoon: _strip,
        mangaId: widget.mangaId,
      ),
    );
  }
}

// ── Reader bottom sheets ───────────────────────────────────────────────────

/// Shared frame: card surface, drag handle, display title, safe-area inset.
class _ReaderSheet extends StatelessWidget {
  const _ReaderSheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rp = ReaderPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: rp.card,
        border: Border(top: BorderSide(color: rp.border)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          DisplayText(title, size: 26, color: rp.ink),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet({required this.isWebtoon, required this.mangaId});
  final bool isWebtoon;
  final int mangaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(readingDirectionProvider);
    final rp = ReaderPalette.of(context);
    final titleOverride = ref.watch(mangaReadingDirectionProvider(mangaId));
    final scale = ref.watch(pageScaleModeProvider);
    final background = ref.watch(readerBackgroundProvider);
    final keepOn = ref.watch(keepScreenOnProvider);
    final gap = ref.watch(stripGapProvider);

    return _ReaderSheet(
      title: YomiText.label('Reader', '読'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isWebtoon) ...[
            Text('DIRECTION',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: 8),
            _OptionRow<ReadingDirection>(
              value: direction,
              groupLabel: 'Reading Direction',
              options: const [
                (ReadingDirection.ltr, 'Left → Right'),
                (ReadingDirection.rtl, 'Right → Left'),
                (ReadingDirection.vertical, 'Vertical'),
              ],
              onChanged: (v) =>
                  ref.read(readingDirectionProvider.notifier).state = v,
            ),
            const SizedBox(height: 16),

            // Per-title override — manhwa/webtoon and manga have opposite
            // natural defaults, so this avoids flipping the global setting
            // every time the user switches between genres.
            Text('FOR THIS TITLE',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: 8),
            _OptionRow<ReadingDirection?>(
              value: titleOverride,
              groupLabel: 'Reading Direction For This Title',
              options: const [
                (null, 'Use Default'),
                (ReadingDirection.ltr, 'L→R'),
                (ReadingDirection.rtl, 'R→L'),
                (ReadingDirection.vertical, 'Vertical'),
              ],
              onChanged: (v) => ref
                  .read(mangaReadingDirectionProvider(mangaId).notifier)
                  .state = v,
            ),
            const SizedBox(height: 16),
          ],
          if (!isWebtoon) ...[
            Text('PAGE SCALE',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: 8),
            _OptionRow<PageScaleMode>(
              value: scale,
              groupLabel: 'Page Scale',
              options: const [
                (PageScaleMode.fitWidth, 'Fit Width'),
                (PageScaleMode.fitHeight, 'Fit Height'),
                (PageScaleMode.original, 'Original'),
              ],
              onChanged: (v) =>
                  ref.read(pageScaleModeProvider.notifier).state = v,
            ),
            const SizedBox(height: 16),
          ],
          if (isWebtoon) ...[
            Text('GAP BETWEEN IMAGES',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: 8),
            _OptionRow<int>(
              value: gap,
              groupLabel: 'Gap between images',
              options: const [(0, 'None'), (4, '4 px'), (8, '8 px')],
              onChanged: (v) => ref.read(stripGapProvider.notifier).state = v,
            ),
            const SizedBox(height: 16),
          ],
          Text('BRIGHTNESS',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 8),
          const _BrightnessSlider(),
          const SizedBox(height: 16),
          Text('BACKGROUND',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 8),
          _OptionRow<ReaderBackground>(
            value: background,
            groupLabel: 'Background',
            options: const [
              (ReaderBackground.black, 'Black'),
              (ReaderBackground.white, 'White'),
              (ReaderBackground.sepia, 'Sepia'),
            ],
            onChanged: (v) =>
                ref.read(readerBackgroundProvider.notifier).state = v,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Keep screen on',
                    style: YomiText.ui(13, color: rp.ink)),
              ),
              SumiToggle(
                label: 'Keep screen on',
                value: keepOn,
                onChanged: (v) =>
                    ref.read(keepScreenOnProvider.notifier).state = v,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Jump to any chapter of the title. Newest-first, like the detail screen.
class _ChapterPickerSheet extends StatefulWidget {
  const _ChapterPickerSheet({
    required this.chapters,
    required this.currentIndex,
    required this.onSelect,
  });
  final List<ReaderChapterSummary> chapters;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  State<_ChapterPickerSheet> createState() => _ChapterPickerSheetState();
}

class _ChapterPickerSheetState extends State<_ChapterPickerSheet> {
  static const _rowHeight = 48.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Open with the current chapter a couple of rows down.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(((widget.currentIndex - 2) * _rowHeight)
          .clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rp = ReaderPalette.of(context);
    final ac = context.look.isPastel ? rp.ink : context.yc.ac;
    final height = (widget.chapters.length * _rowHeight)
        .clamp(_rowHeight, MediaQuery.sizeOf(context).height * 0.55);
    return _ReaderSheet(
      title: YomiText.label('Chapters', '章'),
      child: SizedBox(
        height: height,
        child: ListView.builder(
          controller: _scroll,
          itemExtent: _rowHeight,
          itemCount: widget.chapters.length,
          itemBuilder: (context, i) {
            final ch = widget.chapters[i];
            final current = i == widget.currentIndex;
            return Semantics(
              button: true,
              selected: current,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelect(i),
                child: Opacity(
                  opacity: ch.isRead && !current ? 0.55 : 1.0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          ch.number == null ? '—' : chapterMark(ch.number!),
                          style: YomiText.display(18,
                              color: current ? ac : rp.ink2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ch.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: YomiText.ui(14,
                              weight:
                                  current ? FontWeight.w700 : FontWeight.w400,
                              color: rp.ink),
                        ),
                      ),
                      if (current)
                        Icon(CupertinoIcons.checkmark_alt, size: 16, color: ac),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Reader brightness control backed by the platform screen brightness.
class _BrightnessSlider extends StatefulWidget {
  const _BrightnessSlider();

  @override
  State<_BrightnessSlider> createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<_BrightnessSlider> {
  double _value = 0.5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final current = await ScreenBrightness().current;
      if (mounted) setState(() => _value = current.clamp(0.0, 1.0));
    } catch (e, st) {
      AppLogger.instance
          .warn('Failed to read current screen brightness', e, st);
    }
  }

  Future<void> _set(double v) async {
    final previous = _value;
    setState(() => _value = v);
    try {
      await ScreenBrightness().setScreenBrightness(v);
    } catch (e, st) {
      AppLogger.instance.error('Failed to set screen brightness', e, st);
      // Snap the slider back to the last value that actually applied, so the
      // UI never shows a brightness the device isn't really at.
      if (mounted) setState(() => _value = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(CupertinoIcons.sun_min,
            size: 18, color: AppColors.textTertiary),
        Expanded(
          child: Semantics(
            label: 'Brightness',
            slider: true,
            value: '${(_value * 100).round()}%',
            child: CupertinoSlider(
              value: _value,
              activeColor: context.yc.ac,
              onChanged: _set,
            ),
          ),
        ),
        const Icon(CupertinoIcons.sun_max_fill,
            size: 18, color: AppColors.textSecondary),
      ],
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.value,
    required this.options,
    required this.onChanged,
    required this.groupLabel,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  /// Read by screen readers as part of each option's label, e.g.
  /// "Reading Direction: Vertical" — so VoiceOver/TalkBack announce what the
  /// control does, not just the selected option's name in isolation.
  final String groupLabel;

  @override
  Widget build(BuildContext context) {
    final rp = ReaderPalette.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = value == opt.$1;
        return Semantics(
          label: '$groupLabel: ${opt.$2}',
          selected: selected,
          button: true,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(opt.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? rp.ink : const Color(0x00000000),
                borderRadius: BorderRadius.circular(context.radii.chip),
                border: Border.all(
                  color: selected ? rp.ink : rp.border,
                ),
              ),
              child: Text(
                opt.$2,
                style: YomiText.ui(13,
                    weight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? rp.bg : rp.ink),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Paged manga image ──────────────────────────────────────────────────────

class _ReaderPage extends ConsumerWidget {
  const _ReaderPage({
    required this.url,
    required this.index,
    required this.background,
    this.headers,
  });

  final String url;
  final int index;
  final ReaderBackground background;
  final Map<String, String>? headers;

  Widget? _loadStateOverlay(ExtendedImageState state) {
    switch (state.extendedImageLoadState) {
      case LoadState.loading:
        return const Center(child: CupertinoActivityIndicator());
      case LoadState.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle,
                  color: AppColors.textTertiary, size: 32),
              const SizedBox(height: 8),
              Text('Failed to load page ${index + 1}',
                  style: const TextStyle(color: AppColors.textTertiary)),
            ],
          ),
        );
      case LoadState.completed:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(pageScaleModeProvider);

    final fit = switch (scale) {
      PageScaleMode.fitWidth => BoxFit.fitWidth,
      PageScaleMode.fitHeight => BoxFit.fitHeight,
      PageScaleMode.original => BoxFit.none,
    };

    // Cap the decoded bitmap width. Manga source pages are frequently
    // 2000px+ wide; decoding them at full resolution on a ~1080px screen
    // wastes CPU on every swipe and fills the image cache, forcing GC pauses
    // that show up as page-turn jank. High-spec devices decode at 2× the
    // physical screen width so pinch-zoom (up to 3.5×) stays crisp; low-spec
    // devices trade some zoom sharpness for ~60% less memory and decode work
    // per page. `cacheWidth` only ever downsamples — smaller source images
    // are left untouched.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final zoomHeadroom = DeviceProfile.current.lowSpec ? 1.25 : 2.0;
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * dpr * zoomHeadroom).round();

    // Eager per-page eviction only on low-spec devices, where heap headroom
    // matters more than back-swipe re-decode. Elsewhere the (bounded, LRU)
    // global image cache keeps recently read pages warm so paging backwards
    // doesn't re-decode.
    final evictOnDispose = DeviceProfile.current.lowSpec;

    if (url.startsWith('/') || url.startsWith('file://')) {
      return ExtendedImage.file(
        localPageFile(url),
        fit: fit,
        mode: ExtendedImageMode.gesture,
        initGestureConfigHandler: _gestureConfig,
        loadStateChanged: _loadStateOverlay,
        cacheWidth: cacheWidth,
        clearMemoryCacheWhenDispose: evictOnDispose,
      );
    }

    return ExtendedImage.network(
      url,
      headers: headers,
      fit: fit,
      mode: ExtendedImageMode.gesture,
      initGestureConfigHandler: _gestureConfig,
      loadStateChanged: _loadStateOverlay,
      cacheWidth: cacheWidth,
      clearMemoryCacheWhenDispose: evictOnDispose,
    );
  }

  static GestureConfig _gestureConfig(ExtendedImageState _) => GestureConfig(
        minScale: 0.9,
        animationMinScale: 0.7,
        maxScale: 3.5,
        animationMaxScale: 4.0,
        speed: 1.0,
        inertialSpeed: 100.0,
        initialScale: 1.0,
        inPageView: true,
        initialAlignment: InitialAlignment.center,
      );
}

// ── Webtoon strip image (full-width, natural height) ──────────────────────

class _WebtoonPage extends StatelessWidget {
  const _WebtoonPage({
    required this.url,
    required this.index,
    this.headers,
  });

  final String url;
  final int index;
  final Map<String, String>? headers;

  Widget? _loadStateOverlay(ExtendedImageState state, double screenWidth) {
    switch (state.extendedImageLoadState) {
      case LoadState.loading:
        return SizedBox(
          width: screenWidth,
          height: screenWidth * 1.5,
          child: const Center(child: CupertinoActivityIndicator()),
        );
      case LoadState.failed:
        return SizedBox(
          width: screenWidth,
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.exclamationmark_circle,
                    color: AppColors.textTertiary, size: 32),
                const SizedBox(height: 8),
                Text('Failed to load image ${index + 1}',
                    style: const TextStyle(color: AppColors.textTertiary)),
              ],
            ),
          ),
        );
      case LoadState.completed:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Decode at display resolution, not source resolution — webtoon strips
    // can be 2000px+ wide; a 60-page chapter decoded at full source size
    // can consume 150-300MB of RAM. Capping to screen width * DPR keeps
    // every visible page sharp while bounding memory per image.
    final cacheWidth =
        (screenWidth * MediaQuery.devicePixelRatioOf(context)).round();

    // See _ReaderPage: eager eviction only where heap headroom is scarce;
    // otherwise let the bounded LRU cache keep back-scroll smooth.
    final evictOnDispose = DeviceProfile.current.lowSpec;

    if (url.startsWith('/') || url.startsWith('file://')) {
      return ExtendedImage.file(
        localPageFile(url),
        fit: BoxFit.fitWidth,
        width: screenWidth,
        mode: ExtendedImageMode.none,
        cacheWidth: cacheWidth,
        clearMemoryCacheWhenDispose: evictOnDispose,
        loadStateChanged: (s) => _loadStateOverlay(s, screenWidth),
      );
    }

    return ExtendedImage.network(
      url,
      headers: headers,
      fit: BoxFit.fitWidth,
      width: screenWidth,
      mode: ExtendedImageMode.none,
      cacheWidth: cacheWidth,
      clearMemoryCacheWhenDispose: evictOnDispose,
      loadStateChanged: (s) => _loadStateOverlay(s, screenWidth),
    );
  }
}

// ── Next chapter – persistent floating button ─────────────────────────────────

/// Small circular liquid-glass button that stays in the bottom-right corner
/// the entire time you read, so the next chapter is always one tap away.
class _NextChapterButton extends StatelessWidget {
  const _NextChapterButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rp = ReaderPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: rp.bg.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: rp.border),
        ),
        child: Icon(
          CupertinoIcons.chevron_right_2,
          color: rp.ink,
          size: 22,
        ),
      ),
    );
  }
}

// ── Next chapter – webtoon footer ─────────────────────────────────────────────

class _NextChapterFooter extends StatelessWidget {
  const _NextChapterFooter({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final rp = ReaderPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: rp.card,
          borderRadius: BorderRadius.circular(context.radii.card),
          border: Border.all(color: rp.border),
        ),
        child: Row(
          children: [
            context.look.kanji
                ? Text('次', style: YomiText.display(26, color: context.yc.ac))
                : Icon(CupertinoIcons.arrow_right_circle_fill,
                    color: context.yc.ac, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Chapter',
                    style: AppTextStyles.caption.copyWith(color: rp.ink2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: rp.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right, color: rp.ink2, size: 16),
          ],
        ),
      ),
    );
  }
}
