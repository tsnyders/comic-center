import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/providers/reader_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/yomi_theme.dart';
import '../../../shared/widgets/sumi.dart';

/// Top + bottom chrome revealed by a tap on the page.
///
/// Hidden state: opacity 0, top bar −20px, bottom bar +20px, pointer-events
/// none. 250ms opacity + transform on `--ease-snap`; exit as fast as enter.
class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    super.key,
    required this.mangaTitle,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.currentPage,
    required this.totalPages,
    required this.visible,
    required this.isStrip,
    required this.onClose,
    required this.onSettings,
    required this.onSeek,
    required this.onModeChanged,
    required this.onChapterTap,
    this.onPrevChapter,
    this.onNextChapter,
  });

  final String mangaTitle;
  final String chapterTitle;
  final double? chapterNumber;
  final int currentPage;
  final int totalPages;
  final bool visible;
  final bool isStrip;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  final ValueChanged<int> onSeek;
  final ValueChanged<ReaderMode> onModeChanged;

  /// Tapping the chapter label opens the chapter picker.
  final VoidCallback onChapterTap;

  /// Null at either end of the chapter list (control shown dimmed, inert).
  final VoidCallback? onPrevChapter;
  final VoidCallback? onNextChapter;

  static const _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final ac = context.yc.ac;
    final rp = ReaderPalette.of(context);
    final look = context.look;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final title = mangaTitle.isNotEmpty ? mangaTitle : chapterTitle;
    final chapterLabel =
        chapterNumber == null ? chapterTitle : 'Ch. ${_num(chapterNumber!)}';
    final sub = totalPages > 0
        ? '$chapterLabel · Page ${currentPage + 1} / $totalPages'
        : chapterLabel;
    final mark = chapterNumber == null
        ? (look.kanji ? '読' : '—')
        : chapterMark(chapterNumber!);

    return Stack(
      children: [
        // ── Top ───────────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _Slide(
            visible: visible,
            hiddenDy: -20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [rp.bg, rp.bg.withValues(alpha: 0)],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16, MediaQuery.paddingOf(context).top + 8, 16, 12),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back',
                      child: SumiPress(
                        onTap: onClose,
                        haptic: false,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(CupertinoIcons.chevron_left,
                              size: 22, color: rp.ink),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (look.isSumi)
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: YomiText.ui(14,
                                    weight: FontWeight.w700, color: rp.ink))
                          else
                            DisplayText(title,
                                size: look.isCinema ? 18 : 22,
                                color: rp.ink,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                height: 1),
                          Semantics(
                            button: true,
                            label: 'Choose chapter',
                            child: SumiPress(
                              onTap: onChapterTap,
                              haptic: false,
                              child: Text(sub,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: YomiText.ui(11, color: rp.ink2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      button: true,
                      label: 'Reader settings',
                      child: SumiPress(
                        onTap: onSettings,
                        haptic: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Text(mark,
                              style: YomiText.display(22,
                                      color: look.isPastel ? rp.ink : ac)
                                  .copyWith(height: 1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Bottom ────────────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _Slide(
            visible: visible,
            hiddenDy: 20,
            child: Container(
              margin: look.isPastel
                  ? EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 20)
                  : null,
              decoration: look.isPastel
                  ? BoxDecoration(
                      color: rp.card,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x26503C3C),
                            blurRadius: 40,
                            offset: Offset(0, 12)),
                      ],
                    )
                  : BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [rp.bg.withValues(alpha: 0), rp.bg],
                      ),
                    ),
              child: Padding(
                padding: look.isPastel
                    ? const EdgeInsets.fromLTRB(16, 14, 16, 14)
                    : EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('${currentPage + 1}',
                              style: YomiText.ui(11, color: rp.ink2)),
                        ),
                        Expanded(
                          child: _Scrubber(
                            current: currentPage,
                            total: totalPages,
                            onSeek: onSeek,
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('$totalPages',
                              textAlign: TextAlign.right,
                              style: YomiText.ui(11, color: rp.ink2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _ChapterNav(
                          icon: CupertinoIcons.chevron_left_2,
                          label: 'Previous chapter',
                          onTap: onPrevChapter,
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ModeButton(
                                label: YomiText.label('Page', '頁'),
                                active: !isStrip,
                                onTap: () => onModeChanged(ReaderMode.page),
                              ),
                              const SizedBox(width: 6),
                              _ModeButton(
                                label: YomiText.label('Strip', '縦'),
                                active: isStrip,
                                onTap: () => onModeChanged(ReaderMode.strip),
                              ),
                            ],
                          ),
                        ),
                        _ChapterNav(
                          icon: CupertinoIcons.chevron_right_2,
                          label: 'Next chapter',
                          onTap: onNextChapter,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _num(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();
}

/// 250ms opacity + translate; translate dropped under reduced motion.
class _Slide extends StatelessWidget {
  const _Slide({
    required this.visible,
    required this.hiddenDy,
    required this.child,
  });
  final bool visible;
  final double hiddenDy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dy = visible || reduceMotion(context) ? 0.0 : hiddenDy;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: ReaderChrome._duration,
      curve: AppMotion.snap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: dy),
        duration: ReaderChrome._duration,
        curve: AppMotion.snap,
        builder: (_, v, child) =>
            Transform.translate(offset: Offset(0, v), child: child),
        child: child,
      ),
    );
  }
}

/// 2px track `#333`, ivory fill (300ms), 16px ivory knob. Tap or drag seeks.
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
    widget.onSeek((pct * (widget.total - 1)).round());
  }

  void _endDrag() => setState(() => _dragPct = null);

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final animate = _dragPct == null;
    final rp = ReaderPalette.of(context);
    final pastel = context.look.isPastel;
    final trackH = pastel ? 10.0 : 2.0;
    final knob = pastel ? 22.0 : 16.0;

    return Semantics(
      slider: true,
      label: 'Page',
      value: '${widget.current + 1} of ${widget.total}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seek(d.localPosition.dx, w),
            onTapUp: (_) => _endDrag(),
            onHorizontalDragUpdate: (d) => _seek(d.localPosition.dx, w),
            onHorizontalDragEnd: (_) => _endDrag(),
            onHorizontalDragCancel: _endDrag,
            child: SizedBox(
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: trackH,
                    decoration: BoxDecoration(
                      color: rp.scrubTrack,
                      borderRadius: BorderRadius.circular(trackH / 2),
                    ),
                  ),
                  AnimatedContainer(
                    duration: animate
                        ? const Duration(milliseconds: 300)
                        : Duration.zero,
                    curve: AppMotion.snap,
                    height: trackH,
                    width: w * progress,
                    decoration: BoxDecoration(
                      color: pastel ? context.yc.ac : rp.ink,
                      borderRadius: BorderRadius.circular(trackH / 2),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: animate
                        ? const Duration(milliseconds: 300)
                        : Duration.zero,
                    curve: AppMotion.snap,
                    left: (w * progress - knob / 2)
                        .clamp(-knob / 2, w - knob / 2),
                    child: Container(
                      width: knob,
                      height: knob,
                      decoration: BoxDecoration(
                        color: rp.ink,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Mode switch button: 8×16 padding, radius 2, 12/700, 1px `#444` border;
/// active = ivory fill, black text.
class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rp = ReaderPalette.of(context);
    final look = context.look;
    final radius = look.isPastel ? 12.0 : (look.isCinema ? 0.0 : 2.0);
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.snap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? (look.isPastel ? rp.card : rp.ink)
                : (look.isPastel ? rp.track : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(radius),
            border: look.isPastel ? null : Border.all(color: rp.border),
          ),
          child: Text(
            look.isCinema ? label.toUpperCase() : label,
            style: look.isCinema
                ? YomiText.display(13,
                    color: active ? rp.bg : rp.ink2, letterSpacing: 2)
                : YomiText.ui(12,
                    weight: FontWeight.w700,
                    color: active
                        ? (look.isPastel ? rp.ink : rp.bg)
                        : (look.isPastel ? rp.ink2 : rp.ink)),
          ),
        ),
      ),
    );
  }
}

/// Previous / next chapter chevron flanking the mode switch. Dimmed and inert
/// at either end of the chapter list.
class _ChapterNav extends StatelessWidget {
  const _ChapterNav({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rp = ReaderPalette.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: SumiPress(
        onTap: onTap,
        haptic: false,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon,
              size: 20,
              color: onTap == null ? rp.ink2.withValues(alpha: 0.4) : rp.ink),
        ),
      ),
    );
  }
}
