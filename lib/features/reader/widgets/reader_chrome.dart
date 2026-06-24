import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_glass.dart';

/// Top + bottom chrome bars revealed by a tap on the reader canvas.
///
/// [visible] drives the 200ms opacity + 8px translate animation:
/// the top bar slides -8px (up) when hidden; the bottom bar slides +8px (down).
class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    super.key,
    required this.chapterTitle,
    required this.currentPage,
    required this.totalPages,
    required this.visible,
    required this.onClose,
    required this.onSettings,
    required this.onSeek,
  });

  final String chapterTitle;
  final int currentPage;
  final int totalPages;
  final bool visible;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _TopBar(
          chapterTitle: chapterTitle,
          visible: visible,
          onClose: onClose,
          onSettings: onSettings,
        ),
        _BottomBar(
          currentPage: currentPage,
          totalPages: totalPages,
          visible: visible,
          onSeek: onSeek,
        ),
      ],
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.chapterTitle,
    required this.visible,
    required this.onClose,
    required this.onSettings,
  });

  final String chapterTitle;
  final bool visible;
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

    final bar = liquid
        ? AppGlass(borderRadius: 0, blur: 26, sheen: false, child: content)
        : ClipRect(
            child: BackdropFilter(
              // Spec: blur-26
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  // Spec: gradient white@10 → black@45
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x1AFFFFFF), // white 10%
                      Color(0x73000000), // black 45%
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      // hairline per spec
                      color: Color(0x24FFFFFF), // white ~14%
                      width: AppRadius.hairline,
                    ),
                  ),
                ),
                child: content,
              ),
            ),
          );

    // 200ms opacity + 8px upward translate when hiding (spec).
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: visible ? 0.0 : -8.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          builder: (_, dy, child) =>
              Transform.translate(offset: Offset(0, dy), child: child),
          child: bar,
        ),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.visible,
    required this.onSeek,
  });

  final int currentPage;
  final int totalPages;
  final bool visible;
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
              const Text('1', style: AppTextStyles.caption),
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

    final bar = liquid
        ? AppGlass(borderRadius: 0, blur: 26, sheen: false, child: content)
        : ClipRect(
            child: BackdropFilter(
              // Spec: blur-26 (matches top bar)
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0x1AFFFFFF), // white 10%
                      Color(0x73000000), // black 45%
                    ],
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Color(0x24FFFFFF), // white ~14%
                      width: AppRadius.hairline,
                    ),
                  ),
                ),
                child: content,
              ),
            ),
          );

    // 200ms opacity + 8px downward translate when hiding (spec).
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: visible ? 0.0 : 8.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          builder: (_, dy, child) =>
              Transform.translate(offset: Offset(0, dy), child: child),
          child: bar,
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
                // Track — 4px, white@22% per spec
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x38FFFFFF), // white 22%
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
