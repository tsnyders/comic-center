import 'package:flutter/cupertino.dart';

import '../providers/settings_provider.dart' show GlassTheme;

/// ============================================================================
/// Comic Center — AppGlass styling spec  ("Ink & Glass" redesign)
///
/// One primitive, two materials, two modes = four tuned specs. Frosty and
/// Liquid are deliberately distinct so switching themes reads as a real change
/// of material — Frosty is a tinted, sheen-lit frosted pane; Liquid is a
/// clearer, brighter-rimmed refraction lens with little body tint.
///
/// [GlassTheme] itself lives in `core/providers/settings_provider.dart` (with
/// its persisted provider + label extension); this file only describes how each
/// theme/mode pair should be painted.
/// ============================================================================

class AppGlassSpec {
  const AppGlassSpec({
    required this.tint,
    required this.blur,
    required this.borderColor,
    required this.borderWidth,
    required this.sheen,
    required this.sheenColor,
    this.radius = 16,
  });

  /// Body tint mixed under the glass.
  final Color tint;
  /// Backdrop blur sigma (frosty) / beneath-glass blur (liquid uses ~0.4×).
  final double blur;
  final Color borderColor;
  final double borderWidth;
  /// Paint the top specular highlight? (Frosty yes; Liquid renders its own rim.)
  final bool sheen;
  final Color sheenColor;
  /// Default corner radius (callers may override for pills/full-bleed bars).
  final double radius;

  // ── Frosty ──────────────────────────────────────────────────────────
  static const frostyDark = AppGlassSpec(
    tint:        Color(0x9E14141E), // rgba(20,20,30,0.62)
    blur:        24,
    borderColor: Color(0x29FFFFFF), // white 16%
    borderWidth: 0.75,
    sheen:       true,
    sheenColor:  Color(0x38FFFFFF), // white 22%
  );
  static const frostyLight = AppGlassSpec(
    tint:        Color(0xA8FFFFFF), // white 66%
    blur:        24,
    borderColor: Color(0x14000000), // black 8%
    borderWidth: 0.75,
    sheen:       true,
    sheenColor:  Color(0xD9FFFFFF), // white 85%
  );

  // ── Liquid (refraction lens — brighter rim, less tint, less blur) ─────
  static const liquidDark = AppGlassSpec(
    tint:        Color(0x1AFFFFFF), // white 10%
    blur:        16,
    borderColor: Color(0x4DFFFFFF), // white 30%
    borderWidth: 1.0,
    sheen:       false,
    sheenColor:  Color(0x00000000),
  );
  static const liquidLight = AppGlassSpec(
    tint:        Color(0x57FFFFFF), // white 34%
    blur:        16,
    borderColor: Color(0x99FFFFFF), // white 60%
    borderWidth: 1.0,
    sheen:       false,
    sheenColor:  Color(0x00000000),
  );

  static AppGlassSpec of(GlassTheme theme, bool isDark) =>
      switch ((theme, isDark)) {
        (GlassTheme.frosty, true)  => frostyDark,
        (GlassTheme.frosty, false) => frostyLight,
        (GlassTheme.liquid, true)  => liquidDark,
        (GlassTheme.liquid, false) => liquidLight,
      };
}
