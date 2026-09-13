import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/services/device_profile.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';

/// ============================================================================
/// Sumi widget kit — the small vocabulary every redesigned screen shares.
/// Overlines, entrance motion, press feedback, toggles, chips, buttons, the
/// washi grain, the yin-yang mark, kanji helpers.
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

/// `.y-stagger`: 35ms per item, capped at 6. Dropped under reduced motion.
class SumiStagger extends StatelessWidget {
  const SumiStagger({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
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

/// `LIBRARY · 庫` — 11px, tracked 2, secondary text (or [color]).
class SumiOverline extends StatelessWidget {
  const SumiOverline(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: YomiText.overline(color ?? context.yc.fg2));
}

// ── Controls ──────────────────────────────────────────────────────────────────

/// Primary button: fill `fg`, text `bg` 16/700, radius 6 (54 tall).
class SumiButton extends StatelessWidget {
  const SumiButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 54,
    this.radius = 6,
    this.fontSize = 16,
    this.enabled = true,
    this.child,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double radius;
  final double fontSize;
  final bool enabled;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return SumiPress(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppMotion.base,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? c.fg : c.card,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child ??
            Text(
              label,
              style: YomiText.ui(fontSize,
                  weight: FontWeight.w700, color: enabled ? c.bg : c.fg2),
            ),
      ),
    );
  }
}

/// 1px `line` square with an icon — download / categories buttons.
class SumiSquareButton extends StatelessWidget {
  const SumiSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 50,
    this.radius = 4,
    this.iconSize = 20,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double radius;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return SumiPress(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(icon,
            size: iconSize, color: color ?? (onTap == null ? c.fg2 : c.fg)),
      ),
    );
  }
}

/// 36px circle in `bg` with a chevron — sits on the detail plate.
class SumiBackButton extends StatelessWidget {
  const SumiBackButton({super.key, this.onTap, this.icon});
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return Semantics(
      button: true,
      label: 'Back',
      child: SumiPress(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
          child:
              Icon(icon ?? CupertinoIcons.chevron_left, size: 20, color: c.fg),
        ),
      ),
    );
  }
}

/// Filter chip: 7×14 padding, radius 2. Active = `fg` fill, `bg` text, 700.
class SumiChip extends StatelessWidget {
  const SumiChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return Semantics(
      button: true,
      selected: active,
      child: SumiPress(
        onTap: onTap,
        scale: AppMotion.activeScale,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.snap,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? c.fg : const Color(0x00000000),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: active ? c.fg : c.line),
          ),
          child: Text(
            label,
            style: YomiText.ui(13,
                weight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? c.bg : c.fg),
          ),
        ),
      ),
    );
  }
}

/// 40×24 toggle. On = `ac`; off = Sumi grey. Knob 18px white slides 3 → 19
/// over 180ms.
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
    final c = context.yc;
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
            color: value ? c.ac : context.yomi.toggleOff,
            borderRadius: BorderRadius.circular(12),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
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
        child: Text(kanji, style: YomiText.kanji(size * 0.55, color: c.ac)),
      ),
    );
  }
}

/// 2:3 cover frame — `card` fill, 1px `line`, radius 4. Same shape at every
/// Hero end (grid tile, continue block, detail plate).
class SumiCoverFrame extends StatelessWidget {
  const SumiCoverFrame({
    super.key,
    required this.child,
    this.radius = 4,
    this.shadow = false,
  });
  final Widget child;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.line),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 40,
                  offset: Offset(0, 20),
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

/// Full-screen tiled noise, overlay-blended at 35%, pointer-transparent.
/// Skipped on low-spec hardware (one extra full-screen blend per frame).
class WashiGrain extends StatelessWidget {
  const WashiGrain({super.key});

  @override
  Widget build(BuildContext context) {
    if (DeviceProfile.current.lowSpec) return const SizedBox.shrink();
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Transparent colour satisfies BoxDecoration's blend-mode assert
          // and contributes nothing; only the tiled grain is blended.
          color: Color(0x00000000),
          backgroundBlendMode: BlendMode.overlay,
          image: DecorationImage(
            image: AssetImage('assets/images/washi_grain.png'),
            repeat: ImageRepeat.repeat,
            opacity: 0.35,
            filterQuality: FilterQuality.none,
          ),
        ),
        child: SizedBox.expand(),
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

/// Two-stroke enso circle with 読 inside (onboarding mark).
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
            child: Text('読', style: YomiText.kanji(size * 0.39, color: fg)),
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

// ── Hand-drawn progress stroke ────────────────────────────────────────────────

/// Library continue block: 3px `line` track, 5px `ac` fill, round caps.
/// Fill length animates 300ms.
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

// ── Kanji helpers ─────────────────────────────────────────────────────────────

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
    var f = frac.toStringAsFixed(2).substring(2);
    while (f.endsWith('0')) {
      f = f.substring(0, f.length - 1);
    }
    buf.write('·$f');
  }
  return buf.toString();
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
