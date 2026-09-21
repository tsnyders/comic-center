import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/services/device_profile.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';

/// ============================================================================
/// Yomi widget kit — the small vocabulary every screen shares. Each widget
/// reads the current look's radii, fonts and shadows, and branches on the
/// look only where the three prototypes differ in shape (chips, marks,
/// progress, back button). Names keep the Sumi prefix from the first look.
/// ============================================================================

// ── Motion helpers ────────────────────────────────────────────────────────────

/// True when decorative motion (stagger, rotation, scale) should be dropped.
/// Opacity fades are kept.
bool reduceMotion(BuildContext context) =>
    DeviceProfile.current.reducedMotion ||
    MediaQuery.maybeDisableAnimationsOf(context) == true;

/// `sumiRise`: content fades from 0 and rises 10px → 0 over [duration]
/// (400ms, 500ms on Onboarding). Re-runs whenever [trigger] changes.
class SumiRise extends StatefulWidget {
  const SumiRise({
    super.key,
    required this.child,
    this.trigger,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
  });

  final Widget child;
  final Object? trigger;
  final Duration duration;
  final Duration delay;

  @override
  State<SumiRise> createState() => _SumiRiseState();
}

class _SumiRiseState extends State<SumiRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    _ctrl.value = 0;
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void didUpdateWidget(SumiRise old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _run();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = !reduceMotion(context);
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _t.value,
        child: rise
            ? Transform.translate(
                offset: Offset(0, 10 * (1 - _t.value)), child: child)
            : child,
      ),
    );
  }
}

/// `.y-stagger`: entrance for the first six items, dropped under reduced motion.
class SumiStagger extends StatelessWidget {
  const SumiStagger({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ponytail: only the initial six items enter; later/recycled rows must not
    // allocate controllers or fade layers just because the user is scrolling.
    if (index >= AppMotion.staggerMax || reduceMotion(context)) return child;
    return SumiRise(
      duration: AppMotion.base,
      delay: AppMotion.stagger(index),
      child: child,
    );
  }
}

/// Press feedback — scale to 0.94 over 180ms. Opacity-only under reduced motion.
class SumiPress extends StatefulWidget {
  const SumiPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.pressScale,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<SumiPress> createState() => _SumiPressState();
}

class _SumiPressState extends State<SumiPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down && !reduced ? widget.scale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.snap,
        child: AnimatedOpacity(
          opacity: _down && reduced ? 0.7 : 1.0,
          duration: AppMotion.fast,
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Text ──────────────────────────────────────────────────────────────────────

/// Section overline. Pass the Latin label and its kanji pair; the look decides
/// whether to show "LIBRARY · 庫", "LIBRARY" or "Library".
class SumiOverline extends StatelessWidget {
  const SumiOverline(this.latin, {super.key, this.kanji, this.color});
  final String latin;
  final String? kanji;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        YomiText.label(latin, kanji),
        style: YomiText.overline(color ?? context.yc.fg2),
      );
}

/// Display-face text with the look's case rule applied (Cinema uppercases).
class DisplayText extends StatelessWidget {
  const DisplayText(
    this.text, {
    super.key,
    required this.size,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.letterSpacing,
    this.height,
  });

  final String text;
  final double size;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final double? letterSpacing;
  final double? height;

  @override
  Widget build(BuildContext context) {
    var style = YomiText.display(size,
        color: color ?? context.yc.fg, letterSpacing: letterSpacing);
    if (height != null) style = style.copyWith(height: height);
    return Text(
      YomiText.displayCase(text),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: style,
    );
  }
}

// ── Controls ──────────────────────────────────────────────────────────────────

/// Primary button: fill `fg`, text `bg` 16/700, look radius (54 tall).
class SumiButton extends StatelessWidget {
  const SumiButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 54,
    this.radius,
    this.fontSize = 16,
    this.enabled = true,
    this.child,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double? radius;
  final double fontSize;
  final bool enabled;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final cinema = context.look.isCinema;
    return SumiPress(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppMotion.base,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? c.fg : c.card,
          borderRadius: BorderRadius.circular(radius ?? context.radii.button),
        ),
        child: child ??
            (cinema
                ? Text(
                    label.toUpperCase(),
                    style: YomiText.display(fontSize + 2,
                        color: enabled ? c.bg : c.fg2, letterSpacing: 2),
                  )
                : Text(
                    label,
                    style: YomiText.ui(fontSize,
                        weight: FontWeight.w700, color: enabled ? c.bg : c.fg2),
                  )),
      ),
    );
  }
}

/// Square icon button — 1px `line` (Sumi / Cinema) or a `card` tile with the
/// look's soft shadow (Pastel).
class SumiSquareButton extends StatelessWidget {
  const SumiSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 50,
    this.radius,
    this.iconSize = 20,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double? radius;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final look = context.look;
    return SumiPress(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: look.isPastel ? c.card : null,
          border: look.isPastel ? null : Border.all(color: c.line),
          borderRadius: BorderRadius.circular(radius ?? context.radii.button),
          boxShadow: look.cardShadow,
        ),
        child: Icon(icon,
            size: iconSize, color: color ?? (onTap == null ? c.fg2 : c.fg)),
      ),
    );
  }
}

/// Back button on a plate: Sumi 36px circle in `bg`, Cinema 40px square
/// scrim, Pastel 40px rounded `card` tile.
class SumiBackButton extends StatelessWidget {
  const SumiBackButton({super.key, this.onTap, this.icon, this.color});
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final look = context.look;
    final (double size, Color bg, double radius) = switch (look.look) {
      YomiLook.sumi => (36, c.bg, 18),
      YomiLook.cinema => (40, const Color(0x66000000), 0),
      YomiLook.pastel => (40, c.card, 14),
    };
    return Semantics(
      button: true,
      label: 'Back',
      child: SumiPress(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: look.cardShadow,
          ),
          child: Icon(icon ?? CupertinoIcons.chevron_left,
              size: 20,
              color: color ?? (look.isCinema ? const Color(0xFFF1EBE2) : c.fg)),
        ),
      ),
    );
  }
}

/// Filter chip. Sumi: 7×14, radius 2, active = `fg` fill. Cinema: uppercase
/// condensed, active = `fg` border only. Pastel: `card` pill, radius 16,
/// active = `fg` fill.
class SumiChip extends StatelessWidget {
  const SumiChip({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final look = context.look;
    const clear = Color(0x00000000);
    final (
      Color fill,
      Color border,
      Color text,
      TextStyle style,
      EdgeInsets pad
    ) = switch (look.look) {
      YomiLook.sumi => (
          active ? c.fg : clear,
          active ? c.fg : c.line,
          active ? c.bg : c.fg,
          YomiText.ui(13, weight: active ? FontWeight.w700 : FontWeight.w400),
          const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        ),
      YomiLook.cinema => (
          clear,
          active ? c.fg : c.line,
          active ? c.fg : c.fg2,
          YomiText.display(13, letterSpacing: 1.5),
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      YomiLook.pastel => (
          active ? c.fg : c.card,
          clear,
          active ? c.bg : c.fg,
          YomiText.ui(13, weight: FontWeight.w700),
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
    };
    final chip = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.snap,
      padding: pad,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(context.radii.chip),
        border: Border.all(color: border),
      ),
      child: Text(YomiText.displayCase(label),
          style: style.copyWith(color: text)),
    );
    return Semantics(
      button: onTap != null,
      selected: onTap == null ? null : active,
      child: onTap == null
          ? chip
          : SumiPress(
              onTap: onTap,
              scale: AppMotion.activeScale,
              child: chip,
            ),
    );
  }
}

/// 40×24 toggle. On = accent (Pastel: rose); off = look grey. Knob 18px
/// white slides 3 → 19 over 180ms. Square in Cinema.
class SumiToggle extends StatelessWidget {
  const SumiToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.yomi;
    final r = context.look.isCinema ? 0.0 : 12.0;
    return Semantics(
      label: label,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.snap,
          width: 40,
          height: 24,
          decoration: BoxDecoration(
            color: value ? t.toggleOn : t.toggleOff,
            borderRadius: BorderRadius.circular(r),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.fast,
                curve: AppMotion.snap,
                top: 3,
                left: value ? 19 : 3,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(r == 0 ? 0 : 9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seal stamp — 40×40, 2px `ac` border, radius 4, kanji in `ac`, rotated −6°.
class SumiSeal extends StatelessWidget {
  const SumiSeal({super.key, this.kanji = '読', this.size = 40});
  final String kanji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return Transform.rotate(
      angle: -6 * 3.14159265 / 180,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: c.ac, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(kanji, style: YomiText.display(size * 0.55, color: c.ac)),
      ),
    );
  }
}

/// Header mark at the right of a screen title: Sumi seal · Cinema tracked
/// wordmark · Pastel nothing.
class LookMark extends StatelessWidget {
  const LookMark({super.key});

  @override
  Widget build(BuildContext context) => switch (context.look.look) {
        YomiLook.sumi => const SumiSeal(),
        YomiLook.cinema => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('YOMI',
                style: YomiText.display(16,
                    color: context.yc.fg, letterSpacing: 5)),
          ),
        YomiLook.pastel => const SizedBox.shrink(),
      };
}

/// 2:3 cover frame — `card` fill, 1px `line`, look radius. Same shape at every
/// Hero end (grid tile, continue block, detail plate).
class SumiCoverFrame extends StatelessWidget {
  const SumiCoverFrame({
    super.key,
    required this.child,
    this.radius,
    this.shadow = false,
  });
  final Widget child;
  final double? radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final look = context.look;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(radius ?? context.radii.cover),
        border: look.isPastel ? null : Border.all(color: c.line),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: look.isPastel
                      ? const Color(0x33503C3C)
                      : const Color(0x80000000),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ── Washi grain ───────────────────────────────────────────────────────────────

/// Full-screen tiled noise at 35%, pointer-transparent. Sumi only.
class WashiGrain extends StatelessWidget {
  const WashiGrain({super.key});

  @override
  Widget build(BuildContext context) {
    if (DeviceProfile.current.lowSpec || !context.look.grain) {
      return const SizedBox.shrink();
    }
    return const IgnorePointer(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            // BoxDecoration's blend mode only affected its transparent color;
            // the image already uses srcOver. Retain that appearance and cache
            // its painting independently of the scrolling content underneath.
            image: DecorationImage(
              image: AssetImage('assets/images/washi_grain.png'),
              repeat: ImageRepeat.repeat,
              opacity: 0.35,
              filterQuality: FilterQuality.none,
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

// ── Yin-yang ──────────────────────────────────────────────────────────────────

/// Ivory / ink yin-yang (prototype `viewBox 0 0 100 100`).
class YinYang extends StatelessWidget {
  const YinYang({super.key, this.size = 64});
  final double size;

  static const ivory = Color(0xFFF2EDE3);
  static const ink = Color(0xFF0B0B0A);

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: const _YinYangPainter(),
      );
}

class _YinYangPainter extends CustomPainter {
  const _YinYangPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s, s);
    final ivory = Paint()..color = YinYang.ivory;
    final ink = Paint()..color = YinYang.ink;
    canvas.drawCircle(const Offset(50, 50), 48, ivory);
    // M50 2 a48 48 0 0 1 0 96 a24 24 0 0 1 0 -48 a24 24 0 0 0 0 -48 z
    final path = Path()
      ..moveTo(50, 2)
      ..arcToPoint(const Offset(50, 98),
          radius: const Radius.circular(48), clockwise: true)
      ..arcToPoint(const Offset(50, 50),
          radius: const Radius.circular(24), clockwise: true)
      ..arcToPoint(const Offset(50, 2),
          radius: const Radius.circular(24), clockwise: false)
      ..close();
    canvas.drawPath(path, ink);
    canvas.drawCircle(const Offset(50, 26), 7, ink);
    canvas.drawCircle(const Offset(50, 74), 7, ivory);
  }

  @override
  bool shouldRepaint(_YinYangPainter old) => false;
}

// ── Enso ──────────────────────────────────────────────────────────────────────

/// Two-stroke enso circle with 読 inside (Sumi onboarding mark).
class Enso extends StatelessWidget {
  const Enso({super.key, this.size = 160});
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = context.yc.fg;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _EnsoPainter(fg)),
          Align(
            alignment: const Alignment(0, 0.18),
            child: Text('読',
                style: TextStyle(
                    fontFamily: 'YujiSyuku', fontSize: size * 0.39, color: fg)),
          ),
        ],
      ),
    );
  }
}

class _EnsoPainter extends CustomPainter {
  const _EnsoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    canvas.scale(s, s);
    final thick = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final a = Path()
      ..moveTo(100, 22)
      ..relativeCubicTo(46, -6, 82, 30, 78, 74)
      ..relativeCubicTo(-4, 46, -44, 82, -88, 76)
      ..relativeCubicTo(-38, -5, -70, -40, -66, -80)
      ..relativeCubicTo(3, -30, 24, -56, 52, -64);
    final b = Path()
      ..moveTo(104, 20)
      ..relativeCubicTo(44, -2, 78, 34, 74, 74);
    canvas.drawPath(a, thick);
    canvas.drawPath(b, thin);
  }

  @override
  bool shouldRepaint(_EnsoPainter old) => old.color != color;
}

// ── Progress ──────────────────────────────────────────────────────────────────

/// Continue-block progress: Sumi hand-drawn stroke · Cinema 2px rule ·
/// Pastel 10px rounded bar. Fill animates 300ms.
class LookProgress extends StatelessWidget {
  const LookProgress(
      {super.key, required this.progress, this.onAccent = false});
  final double progress;

  /// Drawn on an accent-filled card (Pastel continue card).
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final look = context.look;
    final p = progress.clamp(0.0, 1.0);
    if (look.isSumi) return BrushProgress(progress: p);
    final (double h, Color track, Color fill) = look.isPastel
        ? (
            10.0,
            onAccent ? const Color(0x99FFFFFF) : c.line,
            onAccent ? c.onAccent : c.fg,
          )
        : (2.0, c.fg.withValues(alpha: 0.2), c.ac);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: p),
      duration: const Duration(milliseconds: 300),
      curve: AppMotion.snap,
      builder: (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(h / 2),
        child: SizedBox(
          height: h,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: track)),
              FractionallySizedBox(
                widthFactor: v,
                alignment: Alignment.centerLeft,
                child: ColoredBox(color: fill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Library continue block: 3px `line` track, 5px `ac` fill, round caps.
class BrushProgress extends StatelessWidget {
  const BrushProgress({super.key, required this.progress, this.height = 12});
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 300),
      curve: AppMotion.snap,
      builder: (_, p, __) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _BrushPainter(p, c.line, c.ac),
      ),
    );
  }
}

class _BrushPainter extends CustomPainter {
  const _BrushPainter(this.progress, this.track, this.fill);
  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 220, size.height / 12);
    // M2 7 c40-4 80 2 120-1 s60-3 96 0
    final path = Path()
      ..moveTo(2, 7)
      ..relativeCubicTo(40, -4, 80, 2, 120, -1)
      ..relativeCubicTo(20, -1.5, 60, -3, 96, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (progress <= 0) return;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * progress),
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BrushPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}

// ── Sumi splatter (Discover plate) ────────────────────────────────────────────

/// Filter-free fallback: plain ellipses in `fg` at 55% (prototype viewBox
/// 390×300).
class SumiSplatter extends StatelessWidget {
  const SumiSplatter({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _SplatterPainter(context.yc.fg.withValues(alpha: 0.55)),
      );
}

class _SplatterPainter extends CustomPainter {
  const _SplatterPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 390, size.height / 300);
    final p = Paint()..color = color;
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(300, 90), width: 160, height: 120),
        p);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(250, 180), width: 60, height: 44),
        p);
    canvas.drawCircle(const Offset(345, 190), 10, p);
    canvas.drawCircle(const Offset(210, 60), 6, p);
  }

  @override
  bool shouldRepaint(_SplatterPainter old) => old.color != color;
}

// ── Numerals and marks ────────────────────────────────────────────────────────

const _kanjiDigits = ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

/// Kanji numeral for a chapter / volume number.
///
/// 1–99 use the traditional form (15 → 十五, 23 → 二十三). Larger numbers use
/// positional digits (123 → 一二三) so the label stays narrow. A fractional
/// part is appended after a middle dot (12.5 → 十二·5).
String kanjiNumeral(num n) {
  if (n < 0) return '−${kanjiNumeral(-n)}';
  final whole = n.floor();
  final frac = n - whole;
  final buf = StringBuffer();
  if (whole < 10) {
    buf.write(_kanjiDigits[whole]);
  } else if (whole < 100) {
    final tens = whole ~/ 10;
    final ones = whole % 10;
    if (tens > 1) buf.write(_kanjiDigits[tens]);
    buf.write('十');
    if (ones > 0) buf.write(_kanjiDigits[ones]);
  } else {
    for (final ch in whole.toString().split('')) {
      buf.write(_kanjiDigits[int.parse(ch)]);
    }
  }
  if (frac > 0) {
    buf.write('·${_fraction(frac)}');
  }
  return buf.toString();
}

String _fraction(num frac) {
  var f = frac.toStringAsFixed(2).substring(2);
  while (f.endsWith('0')) {
    f = f.substring(0, f.length - 1);
  }
  return f;
}

/// Chapter numeral in the current look: Sumi kanji (十五), Cinema two-digit
/// reel numbers (08), Pastel plain (15).
String chapterMark(num n, {YomiLookSpec? spec}) {
  final s = spec ?? YomiText.spec;
  if (s.kanji) return kanjiNumeral(n);
  final whole = n.floor();
  final frac = n - whole;
  final base = s.isCinema ? whole.toString().padLeft(2, '0') : '$whole';
  return frac <= 0 ? base : '$base.${_fraction(frac)}';
}

/// Single brush mark that tags a title: its first grapheme, upper-cased.
String kanjiTag(String title) {
  final t = title.trim();
  if (t.isEmpty) return '読';
  return t.characters.first.toUpperCase();
}

/// Kanji for a BCP-47 language tag (Discover source rows).
String languageKanji(String lang) =>
    switch (lang.toLowerCase().split('-').first) {
      'en' => '英',
      'ja' => '日',
      'ko' => '韓',
      'zh' => '中',
      'fr' => '仏',
      'es' => '西',
      'de' => '独',
      'pt' => '葡',
      'it' => '伊',
      'ru' => '露',
      _ => lang.isEmpty ? '源' : lang.characters.first.toUpperCase(),
    };

// ── Accent swatches ───────────────────────────────────────────────────────────

/// The look's four curated accents as 22px swatches; selected gets a `fg` ring.
class AccentSwatches extends StatelessWidget {
  const AccentSwatches(
      {super.key, required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final spec = context.look;
    final c = context.yc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < spec.accents.length; i++)
          Semantics(
            button: true,
            selected: i == selected,
            label: spec.accentNames[i],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.snap,
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == selected ? c.fg : const Color(0x00000000),
                    width: 1.5,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: spec.accents[i],
                    shape: BoxShape.circle,
                    border: Border.all(color: c.line),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
