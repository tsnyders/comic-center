import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_glass_spec.dart';

/// The single translucent-surface primitive used across the whole app.
///
/// It renders one of two materials depending on [glassThemeProvider], each
/// tuned per mode via [AppGlassSpec] (four tuned specs total):
///
/// * [GlassTheme.frosty] — `BackdropFilter` blur + specular sheen + hairline
///   border: a tinted, sheen-lit frosted pane.
/// * [GlassTheme.liquid] — a real-time refraction lens from `liquid_glass_easy`
///   (`LiquidGlassLens`): clearer, brighter-rimmed, little body tint.
///
/// Any of [borderRadius] / [blur] / [tint] / [sheen] left null falls back to
/// the active [AppGlassSpec], so most call sites can simply wrap content and
/// inherit the design-system material; pass a value only to override (e.g.
/// `borderRadius: 0` for a full-bleed bar, or a large radius for a pill).
class AppGlass extends ConsumerWidget {
  const AppGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur,
    this.padding,
    this.tint,
    this.sheen,
  });

  final Widget child;

  /// Corner radius. Null → spec radius. Pass a large value for a pill/circle.
  final double? borderRadius;

  /// Backdrop blur strength (frosty) / beneath-glass blur (liquid). Null → spec.
  final double? blur;

  final EdgeInsetsGeometry? padding;

  /// Base tint mixed under the glass. Null → spec tint.
  final Color? tint;

  /// Whether to draw the top specular highlight (frosty only). Null → spec.
  final bool? sheen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(glassThemeProvider);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final spec = AppGlassSpec.of(theme, isDark);

    final r = borderRadius ?? spec.radius;
    final b = blur ?? spec.blur;

    return switch (theme) {
      GlassTheme.frosty => _FrostyGlass(
          borderRadius: r,
          blur: b,
          padding: padding,
          tint: tint ?? spec.tint,
          sheen: sheen ?? spec.sheen,
          sheenColor: spec.sheenColor,
          borderColor: spec.borderColor,
          borderWidth: spec.borderWidth,
          child: child,
        ),
      GlassTheme.liquid => _LiquidGlass(
          borderRadius: r,
          blur: b,
          padding: padding,
          tint: tint ?? spec.tint,
          borderColor: spec.borderColor,
          borderWidth: spec.borderWidth,
          child: child,
        ),
    };
  }
}

// ── Frosty implementation (BackdropFilter) ───────────────────────────────────

class _FrostyGlass extends StatelessWidget {
  const _FrostyGlass({
    required this.child,
    required this.borderRadius,
    required this.blur,
    required this.padding,
    required this.tint,
    required this.sheen,
    required this.sheenColor,
    required this.borderColor,
    required this.borderWidth,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final bool sheen;
  final Color sheenColor;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: radius,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: sheen
              ? Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: borderRadius > 0 ? borderRadius + 10 : 18,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(borderRadius),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [sheenColor, sheenColor.withOpacity(0.0)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: padding ?? EdgeInsets.zero,
                      child: child,
                    ),
                  ],
                )
              : Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
        ),
      ),
    );
  }
}

// ── Liquid implementation (liquid_glass_easy) ────────────────────────────────

class _LiquidGlass extends StatelessWidget {
  const _LiquidGlass({
    required this.child,
    required this.borderRadius,
    required this.blur,
    required this.padding,
    required this.tint,
    required this.borderColor,
    required this.borderWidth,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLens(
      style: LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: borderRadius,
          borderWidth: borderWidth,
          borderColor: borderColor,
        ),
        appearance: LiquidGlassAppearance(
          color: tint,
          blur: LiquidGlassBlur(sigmaX: blur * 0.4, sigmaY: blur * 0.4),
        ),
        refraction: const LiquidGlassRefraction(
          distortion: 0.09,
          distortionWidth: 24,
          chromaticAberration: 0.004,
        ),
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}
