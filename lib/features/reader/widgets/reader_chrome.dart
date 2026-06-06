import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Top + bottom chrome bars revealed by a tap on the reader canvas.
class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    super.key,
    required this.chapterTitle,
    required this.currentPage,
    required this.totalPages,
    required this.onClose,
    required this.onSettings,
  });

  final String chapterTitle;
  final int currentPage;
  final int totalPages;
  final VoidCallback onClose;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _TopBar(
          chapterTitle: chapterTitle,
          onClose: onClose,
          onSettings: onSettings,
        ),
        _BottomBar(
          currentPage: currentPage,
          totalPages: totalPages,
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.chapterTitle,
    required this.onClose,
    required this.onSettings,
  });

  final String chapterTitle;
  final VoidCallback onClose;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: const Color(0xCC000000),
            padding: EdgeInsets.only(
              top: topPadding + 4,
              left: 20,
              right: 20,
              bottom: 12,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: const Text(
                    '✕',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    chapterTitle,
                    style: AppTextStyles.readerChapterTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onSettings,
                  child: const Icon(
                    CupertinoIcons.ellipsis,
                    color: CupertinoColors.white,
                    size: 20,
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: const Color(0xCC000000),
            padding: EdgeInsets.only(
              top: 12,
              left: 24,
              right: 24,
              bottom: bottomPadding + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scrubber
                _Scrubber(current: currentPage, total: totalPages),
                const SizedBox(height: 6),
                // Labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1', style: AppTextStyles.caption),
                    Text(
                      'Page ${currentPage + 1} of $totalPages',
                      style: AppTextStyles.caption,
                    ),
                    Text('$totalPages', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (current + 1) / total;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            // Track
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Fill
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 4,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Thumb
            Positioned(
              left: (constraints.maxWidth * progress) - 10,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: CupertinoColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
