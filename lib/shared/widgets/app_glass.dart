import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../core/providers/settings_provider.dart';

/// The single translucent-surface primitive used across the whole app.
///
/// It renders one of two materials depending on [glassThemeProvider]:
///
/// * [GlassTheme.frosty] — the original `BackdropFilter` blur + specular
///   sheen + hairline border (the app's long-standing look, kept as default).
/// * [GlassTheme.liquid] — a real-time refraction lens from
///   `liquid_glass_easy` (`LiquidGlassLens`), which bends the live content
///   behind it. On Android/iOS (Impeller) this works anywhere with no
///   background plumbing.
///
/// Both paths size themselves to [child] (plus [padding]), so call sites are
/// identical regardless of the active theme — wrap content and go.
class AppGlass extends ConsumerWidget {
  const AppGlass({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.blur = 24,
    this.padding,
    this.tint,
    this.sheen = true,
  });

  final Widget child;

  /// Corner radius. Pass a large value (≥ height/2) for a pill/circle.
  final double borderRadius;

  /// Backdrop blur strength (frosty) / beneath-glass blur (liquid).
  final double blur;

  final EdgeInsetsGeometry? padding;

  /// Base tint mixed under the glass. When null, a brightness-appropriate
  /// default is used.
  final Color? tint;

  /// Whether to draw the top specular highlight (frosty only).
  final bool sheen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(glassThemeProvider);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return switch (theme) {
      GlassTheme.frosty => _FrostyGlass(
          borderRadius: borderRadius,
          blur: blur,
          padding: padding,
          tint: tint,
          sheen: sheen,
          isDark: isDark,
          child: child,
        ),
      GlassTheme.liquid => _LiquidGlass(
          borderRadius: borderRadius,
          blur: blur,
          padding: padding,
          tint: tint,
          isDark: isDark,
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
    required this.isDark,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool sheen;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final baseTint = tint ??
        (isDark ? const Color(0x40000000) : const Color(0x66FFFFFF));
    final highlight =
        isDark ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? CupertinoColors.white.withOpacity(0.26)
        : CupertinoColors.black.withOpacity(0.08);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                highlight.withOpacity(isDark ? 0.20 : 0.45),
                highlight.withOpacity(isDark ? 0.05 : 0.18),
                baseTint,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(color: borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0x33000000),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: sheen
              ? Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: borderRadius,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(borderRadius),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              highlight.withOpacity(isDark ? 0.28 : 0.5),
                              highlight.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child,
                  ],
                )
              : child,
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
    required this.isDark,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final baseTint = tint ??
        (isDark ? const Color(0x26FFFFFF) : const Color(0x40FFFFFF));

    return LiquidGlassLens(
      style: LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: borderRadius,
          borderWidth: 1.0,
          borderColor: isDark
              ? CupertinoColors.white.withOpacity(0.30)
              : CupertinoColors.white.withOpacity(0.55),
        ),
        appearance: LiquidGlassAppearance(
          color: baseTint,
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
