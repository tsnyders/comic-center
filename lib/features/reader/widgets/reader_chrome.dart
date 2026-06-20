import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_glass.dart';

/// Top + bottom chrome bars revealed by a tap on the reader canvas.
class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    super.key,
    required this.chapterTitle,
    required this.currentPage,
    required this.totalPages,
    required this.onClose,
    required this.onSettings,
    required this.onSeek,
  });

  final String chapterTitle;
  final int currentPage;
  final int totalPages;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  final ValueChanged<int> onSeek;

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
          onSeek: onSeek,
        ),
      ],
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.chapterTitle,
    required this.onClose,
    required this.onSettings,
  });

  final String chapterTitle;
  final VoidCallback onClose;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final liquid = ref.watch(glassThemeProvider) == GlassTheme.liquid;

    final content = Padding(
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
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: liquid
          ? AppGlass(borderRadius: 0, blur: 30, sheen: false, child: content)
          : ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: ColoredBox(
                  color: const Color(0xCC000000),
                  child: content,
                ),
              ),
            ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.onSeek,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final liquid = ref.watch(glassThemeProvider) == GlassTheme.liquid;

    final content = Padding(
      padding: EdgeInsets.only(
        top: 12,
        left: 24,
        right: 24,
        bottom: bottomPadding + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Scrubber(
            current: currentPage,
            total: totalPages,
            onSeek: onSeek,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: AppTextStyles.caption),
              Text(
                totalPages > 0
                    ? 'Page ${currentPage + 1} of $totalPages'
                    : 'Loading...',
                style: AppTextStyles.caption,
              ),
              Text(
                totalPages > 0 ? '$totalPages' : '--',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: liquid
          ? AppGlass(borderRadius: 0, blur: 30, sheen: false, child: content)
          : ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: ColoredBox(
                  color: const Color(0xCC000000),
                  child: content,
                ),
              ),
            ),
    );
  }
}

class _Scrubber extends StatefulWidget {
  const _Scrubber({
    required this.current,
    required this.total,
    required this.onSeek,
  });

  final int current;
  final int total;
  final ValueChanged<int> onSeek;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  double? _dragPct;

  double get _progress {
    if (_dragPct != null) return _dragPct!;
    if (widget.total <= 1) return 0.0;
    return widget.current / (widget.total - 1);
  }

  void _seek(double x, double width) {
    if (widget.total <= 1) return;
    final pct = (x / width).clamp(0.0, 1.0);
    setState(() => _dragPct = pct);
    final page = (pct * (widget.total - 1)).round();
    widget.onSeek(page);
  }

  void _endDrag() => setState(() => _dragPct = null);

  @override
  Widget build(BuildContext context) {
    final progress = _progress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final thumbLeft = (w * progress - 10).clamp(-10.0, w - 10.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _seek(d.localPosition.dx, w),
          onHorizontalDragUpdate: (d) => _seek(d.localPosition.dx, w),
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _endDrag,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Stack(
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
                // Fill — no animation during drag to stay locked to finger
                Container(
                  height: 4,
                  width: w * progress,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Thumb
                Positioned(
                  left: thumbLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: CupertinoColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x40000000), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
