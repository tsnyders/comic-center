import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/reader_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/page_pill.dart';
import 'widgets/progress_line.dart';
import 'widgets/reader_chrome.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    required this.sourceId,
    required this.sourceChapterId,
    required this.chapterTitle,
    this.isWebtoon = false,
  });

  final int mangaId;
  final int chapterId;
  final String sourceId;
  final String sourceChapterId;
  final String chapterTitle;

  /// When true the reader uses a continuous vertical ListView (webtoon/manhwa
  /// style) instead of the page-by-page PageView used for manga.
  final bool isWebtoon;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PageController   _pageController;
  late final ScrollController _scrollController;

  bool   _pillVisible      = false;
  double _webtoonProgress  = 0.0;
  Timer? _pillHideTimer;

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
  }

  @override
  void dispose() {
    _pillHideTimer?.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
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
    final pagesAsync = ref.watch(
      chapterPagesProvider(ChapterKey(
        sourceId: widget.sourceId,
        chapterId: widget.sourceChapterId,
      )),
    );
    final readerState   = ref.watch(readerProvider);
    final direction     = ref.watch(readingDirectionProvider);
    final background    = ref.watch(readerBackgroundProvider);
    final chromeVisible = readerState.chromeVisible;

    final bgColor = switch (background) {
      ReaderBackground.black => AppColors.readerBackground,
      ReaderBackground.white => const Color(0xFFFFFFFF),
      ReaderBackground.sepia => const Color(0xFFF5E6C8),
    };

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: pagesAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: const TextStyle(color: AppColors.textSecondary)),
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

              // ── Always-visible 2pt progress line ─────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                height: 2,
                child: ProgressLine(
                  progress: widget.isWebtoon
                      ? _webtoonProgress
                      : readerState.progress,
                ),
              ),

              // ── Tap-to-reveal chrome ──────────────────────────────────────
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: chromeVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !chromeVisible,
                    child: ReaderChrome(
                      chapterTitle: widget.chapterTitle,
                      currentPage: readerState.currentPage,
                      totalPages: readerState.totalPages,
                      onClose: () => Navigator.of(context).pop(),
                      onSettings: () => _showSettings(context),
                      onSeek: _onSeek,
                    ),
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
      onTap: () => ref.read(readerProvider.notifier).toggleChrome(),
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
    return GestureDetector(
      onTap: () => ref.read(readerProvider.notifier).toggleChrome(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: pages.length,
        itemBuilder: (context, i) => _WebtoonPage(
          url: pages[i],
          index: i,
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _ReaderSettingsSheet(isWebtoon: widget.isWebtoon),
    );
  }
}

// ── Reader settings bottom sheet ───────────────────────────────────────────

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet({required this.isWebtoon});
  final bool isWebtoon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction  = ref.watch(readingDirectionProvider);
    final scale      = ref.watch(pageScaleModeProvider);
    final background = ref.watch(readerBackgroundProvider);

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

          // Direction setting only shown for paged manga mode.
          if (!isWebtoon) ...[
            Text('DIRECTION',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: 8),
            _OptionRow<ReadingDirection>(
              value: direction,
              options: const [
                (ReadingDirection.ltr, 'Left → Right'),
                (ReadingDirection.rtl, 'Right → Left'),
                (ReadingDirection.vertical, 'Vertical'),
              ],
              onChanged: (v) =>
                  ref.read(readingDirectionProvider.notifier).state = v,
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

          Text('BACKGROUND',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 8),
          _OptionRow<ReaderBackground>(
            value: background,
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

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = value == opt.$1;
        return GestureDetector(
          onTap: () => onChanged(opt.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    selected ? AppColors.accent : AppColors.borderStrong,
                width: 0.5,
              ),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                fontSize: 13,
                color: selected
                    ? CupertinoColors.white
                    : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(pageScaleModeProvider);

    final fit = switch (scale) {
      PageScaleMode.fitWidth  => BoxFit.fitWidth,
      PageScaleMode.fitHeight => BoxFit.fitHeight,
      PageScaleMode.original  => BoxFit.none,
    };

    return ExtendedImage.network(
      url,
      fit: fit,
      mode: ExtendedImageMode.gesture,
      initGestureConfigHandler: (_) => GestureConfig(
        minScale: 0.9,
        animationMinScale: 0.7,
        maxScale: 3.5,
        animationMaxScale: 4.0,
        speed: 1.0,
        inertialSpeed: 100.0,
        initialScale: 1.0,
        inPageView: true,
        initialAlignment: InitialAlignment.center,
      ),
      loadStateChanged: (state) {
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
                      style: const TextStyle(
                          color: AppColors.textTertiary)),
                ],
              ),
            );
          case LoadState.completed:
            return null;
        }
      },
    );
  }
}

// ── Webtoon strip image (full-width, natural height) ──────────────────────

class _WebtoonPage extends StatelessWidget {
  const _WebtoonPage({required this.url, required this.index});

  final String url;
  final int index;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return ExtendedImage.network(
      url,
      fit: BoxFit.fitWidth,
      width: screenWidth,
      // height is unconstrained — image renders at full width, natural height.
      mode: ExtendedImageMode.none,
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            // Placeholder tall enough to be visible while loading.
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
                        style: const TextStyle(
                            color: AppColors.textTertiary)),
                  ],
                ),
              ),
            );
          case LoadState.completed:
            return null; // natural dimensions
        }
      },
    );
  }
}
