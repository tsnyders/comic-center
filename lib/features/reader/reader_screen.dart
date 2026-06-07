import 'dart:ui';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/library_provider.dart';
import '../../core/providers/reader_provider.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/page_pill.dart';
import 'widgets/progress_line.dart';
import 'widgets/reader_chrome.dart';

class ReaderChapterSummary {
  const ReaderChapterSummary({
    required this.id,
    required this.sourceChapterId,
    required this.title,
  });

  final int id;
  final String sourceChapterId;
  final String title;
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    required this.sourceId,
    required this.sourceChapterId,
    required this.chapterTitle,
    this.chapters = const [],
    this.chapterIndex = -1,
  });

  final int mangaId;
  final int chapterId;
  final String sourceId;
  final String sourceChapterId;
  final String chapterTitle;

  /// Full chapter list (descending order — index 0 = latest).
  final List<ReaderChapterSummary> chapters;

  /// Index of this chapter in [chapters]. -1 if unknown.
  final int chapterIndex;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PageController _pageController;
  bool _pillVisible = false;
  bool _chapterMarkedRead = false;

  bool get _hasNextChapter =>
      widget.chapterIndex > 0 && widget.chapters.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _onPageChanged(int i, int totalPages) {
    ref.read(readerProvider.notifier).setPage(i);
    setState(() => _pillVisible = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _pillVisible = false);
    });

    if (i == totalPages - 1 && !_chapterMarkedRead) {
      _chapterMarkedRead = true;
      ref.read(libraryNotifierProvider.notifier).markChapterRead(
            mangaId: widget.mangaId,
            chapterId: widget.chapterId,
            lastPage: i,
          );
    }
  }

  void _goToNextChapter() {
    final next = widget.chapters[widget.chapterIndex - 1];
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReaderScreen(
          mangaId: widget.mangaId,
          chapterId: next.id,
          sourceId: widget.sourceId,
          sourceChapterId: next.sourceChapterId,
          chapterTitle: next.title,
          chapters: widget.chapters,
          chapterIndex: widget.chapterIndex - 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pagesAsync = ref.watch(
      chapterPagesProvider(ChapterKey(
        sourceId: widget.sourceId,
        chapterId: widget.sourceChapterId,
      )),
    );
    final readerState = ref.watch(readerProvider);
    final chromeVisible = readerState.chromeVisible;
    final isLastPage = readerState.totalPages > 0 &&
        readerState.currentPage == readerState.totalPages - 1;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.readerBackground,
      child: pagesAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        data: (pages) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(readerProvider.notifier).setTotalPages(pages.length);
          });

          return Stack(
            children: [
              // ── Page view ──────────────────────────────────────────────
              GestureDetector(
                onTap: () =>
                    ref.read(readerProvider.notifier).toggleChrome(),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (i) => _onPageChanged(i, pages.length),
                  itemBuilder: (context, i) => _ReaderPage(
                    url: pages[i],
                    index: i,
                  ),
                ),
              ),

              // ── Always-visible 2pt progress line ─────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                height: 2,
                child: ProgressLine(progress: readerState.progress),
              ),

              // ── Tap-to-reveal chrome ──────────────────────────────────
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
                    ),
                  ),
                ),
              ),

              // ── Page count pill (bottom-centre) ───────────────────────
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

              // ── Next chapter banner ────────────────────────────────────
              if (_hasNextChapter && isLastPage && !chromeVisible)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 24,
                  right: 24,
                  child: _NextChapterBanner(onTap: _goToNextChapter),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Reader Settings'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Left-to-Right'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Right-to-Left'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vertical Scroll'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

// ── Next chapter banner ────────────────────────────────────────────────────

class _NextChapterBanner extends StatelessWidget {
  const _NextChapterBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C2E).withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accent.withOpacity(0.35),
                width: 0.75,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.arrow_right_circle_fill,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Next Chapter',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Single page widget ─────────────────────────────────────────────────────

class _ReaderPage extends StatelessWidget {
  const _ReaderPage({required this.url, required this.index});

  final String url;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ExtendedImage.network(
      url,
      fit: BoxFit.contain,
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
                      style: const TextStyle(color: AppColors.textTertiary)),
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
