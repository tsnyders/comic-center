import 'dart:async';
import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../core/providers/library_provider.dart';
import '../../core/providers/reader_provider.dart';
import '../../core/services/app_logger.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/page_pill.dart';
import 'widgets/progress_line.dart';
import 'widgets/reader_chrome.dart';

/// Lightweight description of a chapter passed to the reader for navigation.
class ReaderChapterSummary {
  const ReaderChapterSummary({
    required this.id,
    required this.sourceChapterId,
    required this.title,
    this.downloadPath,
  });
  final int id;
  final String sourceChapterId;
  final String title;
  final String? downloadPath;
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    required this.sourceId,
    required this.sourceChapterId,
    required this.chapterTitle,
    this.downloadPath,
    this.isWebtoon = false,
    this.chapters = const [],
    this.chapterIndex = -1,
  });

  final int mangaId;
  final int chapterId;
  final String sourceId;
  final String sourceChapterId;
  final String chapterTitle;
  final String? downloadPath;
  final bool isWebtoon;
  final List<ReaderChapterSummary> chapters;
  final int chapterIndex;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  static const _platform   = MethodChannel('yomi/platform');
  static const _volumeKeys = EventChannel('yomi/volume_keys');

  late final PageController   _pageController;
  late final ScrollController _scrollController;

  bool   _pillVisible         = false;
  double _webtoonProgress     = 0.0;
  Timer? _pillHideTimer;
  bool   _chapterMarkedRead   = false;
  StreamSubscription<dynamic>? _volumeSub;

  @override
  void initState() {
    super.initState();
    _pageController   = PageController();
    _scrollController = ScrollController();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (widget.isWebtoon) {
      _scrollController.addListener(_onWebtoonScroll);
    }
    _enableVolumeKeys();
  }

  @override
  void dispose() {
    _pillHideTimer?.cancel();
    _volumeSub?.cancel();
    if (Platform.isAndroid) {
      _platform.invokeMethod<void>('setVolumeKeyIntercept', {'enabled': false});
    }
    _restoreBrightness();
    _pageController.dispose();
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  // ── Volume-key page turning ──────────────────────────────────────────────

  void _enableVolumeKeys() {
    // Volume-key page turning is backed by an Android-only platform channel;
    // iOS apps can't intercept the hardware volume buttons, so skip entirely.
    if (!Platform.isAndroid) return;
    _platform.invokeMethod<void>('setVolumeKeyIntercept', {'enabled': true});
    _volumeSub = _volumeKeys.receiveBroadcastStream().listen((event) {
      if (event == 'down') {
        _turnPage(forward: true);
      } else if (event == 'up') {
        _turnPage(forward: false);
      }
    });
  }

  void _turnPage({required bool forward}) {
    final reader = ref.read(readerProvider);
    final total = reader.totalPages;
    if (total == 0) return;
    final target =
        (forward ? reader.currentPage + 1 : reader.currentPage - 1)
            .clamp(0, total - 1);
    if (target == reader.currentPage) return;
    HapticFeedback.selectionClick();
    if (widget.isWebtoon) {
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
      AppLogger.instance.warn('Failed to reset screen brightness on reader close', e, st);
    }
  }

  // ── Next chapter navigation ──────────────────────────────────────────────

  bool get _hasNextChapter =>
      widget.chapterIndex > 0 && widget.chapters.isNotEmpty;

  ReaderChapterSummary get _nextSummary =>
      widget.chapters[widget.chapterIndex - 1];

  void _goToNextChapter(BuildContext context) {
    HapticFeedback.lightImpact();
    final nextIdx = widget.chapterIndex - 1;
    final next = widget.chapters[nextIdx];
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ReaderScreen(
          mangaId: widget.mangaId,
          chapterId: next.id,
          sourceId: widget.sourceId,
          sourceChapterId: next.sourceChapterId,
          chapterTitle: next.title,
          downloadPath: next.downloadPath,
          isWebtoon: widget.isWebtoon,
          chapters: widget.chapters,
          chapterIndex: nextIdx,
        ),
      ),
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
    final page  = total > 0
        ? (rawProgress * total).floor().clamp(0, total - 1)
        : 0;

    if (ref.read(readerProvider).currentPage != page) {
      ref.read(readerProvider.notifier).setPage(page);
    }

    setState(() {
      _webtoonProgress = rawProgress;
      _pillVisible     = true;
    });

    _pillHideTimer?.cancel();
    _pillHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _pillVisible = false);
    });

    // Mark as read when 95% through the webtoon
    if (rawProgress >= 0.95 && total > 0) {
      _tryMarkAsRead(total - 1);
    }
  }

  // ── Seek (chrome scrubber) ───────────────────────────────────────────────

  void _onSeek(int page) {
    if (widget.isWebtoon) {
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

  @override
  Widget build(BuildContext context) {
    final chapterKey = ChapterKey(
      sourceId: widget.sourceId,
      chapterId: widget.sourceChapterId,
      downloadPath: widget.downloadPath,
    );
    final pagesAsync = ref.watch(chapterPagesProvider(chapterKey));
    final readerState   = ref.watch(readerProvider);
    final direction     = ref.watch(effectiveReadingDirectionProvider(widget.mangaId));
    final background    = ref.watch(readerBackgroundProvider);
    final chromeVisible = readerState.chromeVisible;

    final bgColor = switch (background) {
      ReaderBackground.black => AppColors.readerBackground,
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
                color: AppColors.accent,
                onPressed: () => ref.invalidate(chapterPagesProvider(chapterKey)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (pages) {
          final currentTotal = ref.read(readerProvider).totalPages;
          if (currentTotal != pages.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(readerProvider.notifier).setTotalPages(pages.length);
              }
            });
          }

          return Stack(
            children: [
              // ── Content ──────────────────────────────────────────────────
              if (widget.isWebtoon)
                _buildWebtoonView(context, pages, chromeVisible)
              else
                _buildPagedView(context, pages, direction, background, chromeVisible),

              // ── Always-visible 2px progress line — pinned at the very top ──
              // Sits at top:0 (above the safe-area notch) so it is always
              // visible regardless of chrome state, per spec.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 2,
                child: ProgressLine(
                  progress: widget.isWebtoon
                      ? _webtoonProgress
                      : readerState.progress,
                ),
              ),

              // ── Tap-to-reveal chrome (200ms opacity + 8px translate) ───────
              // Top bar slides -8px (upward) when hiding; bottom bar +8px.
              // The translate is applied per-bar inside ReaderChrome.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !chromeVisible,
                  child: ReaderChrome(
                    chapterTitle: widget.chapterTitle,
                    currentPage: readerState.currentPage,
                    totalPages: readerState.totalPages,
                    visible: chromeVisible,
                    onClose: () => Navigator.of(context).pop(),
                    onSettings: () => _showSettings(context),
                    onSeek: _onSeek,
                  ),
                ),
              ),

              // ── Page/image count pill ─────────────────────────────────────
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 90,
                left: 0,
                right: 0,
                child: PagePill(
                  current: readerState.currentPage + 1,
                  total: readerState.totalPages,
                  visible: _pillVisible && !chromeVisible,
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
  ) {
    final isVertical = direction == ReadingDirection.vertical;
    final isRtl      = direction == ReadingDirection.rtl;

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
        itemCount: pages.length,
        onPageChanged: (i) {
          ref.read(readerProvider.notifier).setPage(i);
          setState(() => _pillVisible = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _pillVisible = false);
          });
          if (i == pages.length - 1) _tryMarkAsRead(i);
        },
        itemBuilder: (context, i) => _ReaderPage(
          url: pages[i],
          index: i,
          background: background,
        ),
      ),
    );
  }

  // ── Webtoon view (manhwa / continuous vertical scroll) ───────────────────

  Widget _buildWebtoonView(
    BuildContext context,
    List<String> pages,
    bool chromeVisible,
  ) {
    final hasFooter = _hasNextChapter;
    return GestureDetector(
      onTap: () => ref.read(readerProvider.notifier).toggleChrome(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: pages.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == pages.length) {
            return _NextChapterFooter(
              title: _nextSummary.title,
              onTap: () => _goToNextChapter(context),
            );
          }
          return _WebtoonPage(url: pages[i], index: i);
        },
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _ReaderSettingsSheet(
        isWebtoon: widget.isWebtoon,
        mangaId: widget.mangaId,
      ),
    );
  }
}

// ── Reader settings bottom sheet ───────────────────────────────────────────

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet({required this.isWebtoon, required this.mangaId});
  final bool isWebtoon;
  final int mangaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction      = ref.watch(readingDirectionProvider);
    final titleOverride  = ref.watch(mangaReadingDirectionProvider(mangaId));
    final scale          = ref.watch(pageScaleModeProvider);
    final background     = ref.watch(readerBackgroundProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

          Text('Reader Settings',
              style: AppTextStyles.sectionTitle
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 20),

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
        ],
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
      AppLogger.instance.warn('Failed to read current screen brightness', e, st);
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
              activeColor: AppColors.accent,
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
                color: selected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.borderStrong,
                  width: 0.5,
                ),
              ),
              child: Text(
                opt.$2,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? AppColors.textOnAccent : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
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
  });

  final String url;
  final int index;
  final ReaderBackground background;

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
      PageScaleMode.fitWidth  => BoxFit.fitWidth,
      PageScaleMode.fitHeight => BoxFit.fitHeight,
      PageScaleMode.original  => BoxFit.none,
    };

    final gestureConfig = GestureConfig(
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

    if (url.startsWith('/') || url.startsWith('file://')) {
      return ExtendedImage.file(
        File(url),
        fit: fit,
        mode: ExtendedImageMode.gesture,
        initGestureConfigHandler: (_) => gestureConfig,
        loadStateChanged: _loadStateOverlay,
      );
    }

    return ExtendedImage.network(
      url,
      fit: fit,
      mode: ExtendedImageMode.gesture,
      initGestureConfigHandler: (_) => gestureConfig,
      loadStateChanged: _loadStateOverlay,
    );
  }
}

// ── Webtoon strip image (full-width, natural height) ──────────────────────

class _WebtoonPage extends StatelessWidget {
  const _WebtoonPage({required this.url, required this.index});

  final String url;
  final int index;

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

    if (url.startsWith('/') || url.startsWith('file://')) {
      return ExtendedImage.file(
        File(url),
        fit: BoxFit.fitWidth,
        width: screenWidth,
        mode: ExtendedImageMode.none,
        cacheWidth: cacheWidth,
        loadStateChanged: (s) => _loadStateOverlay(s, screenWidth),
      );
    }

    return ExtendedImage.network(
      url,
      fit: BoxFit.fitWidth,
      width: screenWidth,
      mode: ExtendedImageMode.none,
      cacheWidth: cacheWidth,
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xCC0A0A0D),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0x1FFFFFFF), width: 0.75),
        ),
        child: const Icon(
          CupertinoIcons.chevron_right_2,
          color: Color(0xFFF3F0E9),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0x40FF6F61), // AppColors.accent, faint
              width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.arrow_right_circle_fill,
                color: AppColors.accent, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Chapter',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.chevron_right,
                color: AppColors.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}
