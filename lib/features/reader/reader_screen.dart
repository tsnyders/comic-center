import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/reader_provider.dart';
import '../../core/theme/app_colors.dart';
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
  });

  final int mangaId;
  final int chapterId;
  final String sourceId;
  final String sourceChapterId;
  final String chapterTitle;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PageController _pageController;

  // Pill fades in when a swipe begins, fades out after idle.
  bool _pillVisible = false;

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
                  ),
                ),
              ),

              // ── Always-visible progress line ──────────────────────────
              ProgressLine(progress: readerState.progress),

              // ── Tap-to-reveal chrome ──────────────────────────────────
              AnimatedOpacity(
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

              // ── Page count pill ───────────────────────────────────────
              PagePill(
                current: readerState.currentPage + 1,
                total: readerState.totalPages,
                visible: _pillVisible && !chromeVisible,
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
            return null; // use default rendering
        }
      },
    );
  }
}
