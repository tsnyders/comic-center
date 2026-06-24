import 'package:flutter/cupertino.dart';

/// ============================================================================
/// Comic Center — AppColors  ("Content-First" redesign)
///
/// A monochrome ink surface system with ONE warm accent (Coral). The chrome
/// stays neutral on purpose — colour comes from the cover art itself — and a
/// single coral accent marks intent (continue, active, follow, unread).
/// Every surface/text/border token is defined for both modes; glass tints
/// additionally vary by theme (see [AppGlassSpec]).
///
/// Accent rationale: Coral (#FF6A5C) is warm, distinctive, and unmistakably
/// "act here" without competing with the colourful covers it sits beside. It
/// pairs with a DARK warm foreground on fills (white-on-coral fails contrast,
/// ink-on-coral clears ~7:1); light mode steps the accent deeper for legibility.
/// ============================================================================
abstract final class AppColors {
  // ── Coral accent ramp ─────────────────────────────────────────────────
  static const coral300 = Color(0xFFFFA99E);
  static const coral400 = Color(0xFFFF8B7C); // dark hover
  static const coral500 = Color(0xFFFF6A5C); // DARK accent
  static const coral600 = Color(0xFFF0533F); // dark press / light hover
  static const coral700 = Color(0xFFDC4633); // LIGHT accent
  static const coral800 = Color(0xFFBE3A29); // light press

  // ── Back-compat aliases (call sites still referencing the old ramp) ────
  static const cobalt300 = coral300;
  static const cobalt400 = coral400;
  static const cobalt500 = coral500;
  static const cobalt600 = coral600;
  static const cobalt700 = coral700;
  static const cobalt800 = coral800;

  // ── Dark mode (neutral-warm ink) ──────────────────────────────────────
  static const background       = Color(0xFF0B0B0D);
  static const surface          = Color(0xFF151417);
  static const surfaceElevated  = Color(0xFF1F1E22);
  static const surfaceSunken    = Color(0xFF08080A);

  static const border        = Color(0x14FFFFFF); // 8%
  static const borderStrong  = Color(0x29FFFFFF); // 16%

  static const accent        = coral500;
  static const accentHover   = coral400;
  static const accentPress   = coral600;
  static const accentSubtle  = Color(0x29FF6A5C); // 16%
  static const accentLine    = Color(0x73FF6A5C); // 45%

  static const textPrimary    = Color(0xFAFFFFFF); // 98%
  static const textSecondary  = Color(0x9EFFFFFF); // 62%
  static const textTertiary   = Color(0x5CFFFFFF); // 36%
  static const textQuaternary = Color(0x29FFFFFF); // 16%
  /// Foreground on coral fills — a deep warm ink (ink-on-coral ≈ 7:1).
  static const textOnAccent   = Color(0xFF2A0B07);

  // ── Light mode (warm paper) ───────────────────────────────────────────
  static const lightBackground      = Color(0xFFF6F4F2);
  static const lightSurface         = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFEEEBE7);
  static const lightSurfaceSunken   = Color(0xFFE9E5E1);

  static const lightBorder       = Color(0x14000000); // 8%
  static const lightBorderStrong = Color(0x24000000); // 14%

  static const lightAccent       = coral700;
  static const lightAccentHover  = coral600;
  static const lightAccentPress  = coral800;
  static const lightAccentSubtle = Color(0x1FDC4633); // 12%
  static const lightAccentLine   = Color(0x52DC4633); // 32%

  static const lightTextPrimary    = Color(0xEB000000); // 92%
  static const lightTextSecondary  = Color(0x8F000000); // 56%
  static const lightTextTertiary   = Color(0x57000000); // 34%
  static const lightTextQuaternary = Color(0x24000000); // 14%

  // ── Semantic status (mode-tuned for contrast) ─────────────────────────
  static const unread          = Color(0xFFFF453A);
  static const downloaded      = Color(0xFF2FBF71);
  static const warning         = Color(0xFFF5C518);
  static const lightUnread     = Color(0xFFE5392E);
  static const lightDownloaded = Color(0xFF1F9D58);
  static const lightWarning    = Color(0xFFC99700);

  // ── Reader ────────────────────────────────────────────────────────────
  static const readerBackground = Color(0xFF000000);
  static const readerSepia      = Color(0xFFF4ECD8);

  // ── Ambient backdrop seeds (give the blur something to chew on) ───────
  static const ambientDark  = [Color(0xFF18100F), Color(0xFF0B0B0D)];
  static const ambientLight = [Color(0xFFFBF0EE), Color(0xFFF6F4F2)];

  // ── Hero protection gradient (cover → background) ─────────────────────
  static const heroGradientDark = [
    Color(0x33000000), Color(0xCC0B0B0D), background,
  ];
  static const heroGradientLight = [
    Color(0x22000000), Color(0x88F6F4F2), lightBackground,
  ];

  // ── Source-accent gradient seeds (Browse featured cards / avatars) ────
  static const gradEmber  = [Color(0xFFFF6A3D), Color(0xFFC0264E)];
  static const gradViolet = [Color(0xFF6E62F0), Color(0xFF3B2FA6)];
  static const gradTeal   = [Color(0xFF18B6C9), Color(0xFF0E6E8C)];
  static const gradRose   = [Color(0xFFFF5C8A), Color(0xFFB0265E)];

  // ── Back-compat aliases (pre-redesign call sites) ─────────────────────
  // Retained so existing screens keep compiling during/after the migration.
  static const heroGradientColors = heroGradientDark;
  static const ambientGradient = ambientDark;
  static const tabBarBackground = Color(0xEB151417);
}

/// Context-aware resolvers — return the correct value for the active mode.
extension AppColorsX on BuildContext {
  bool get isDark =>
      CupertinoTheme.brightnessOf(this) == Brightness.dark;

  Color get backgroundColor =>
      isDark ? AppColors.background : AppColors.lightBackground;
  Color get surfaceColor =>
      isDark ? AppColors.surface : AppColors.lightSurface;
  Color get surfaceElevatedColor =>
      isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated;
  Color get surfaceSunkenColor =>
      isDark ? AppColors.surfaceSunken : AppColors.lightSurfaceSunken;

  Color get borderColor =>
      isDark ? AppColors.border : AppColors.lightBorder;
  Color get borderStrongColor =>
      isDark ? AppColors.borderStrong : AppColors.lightBorderStrong;

  Color get accentColor =>
      isDark ? AppColors.accent : AppColors.lightAccent;
  Color get accentSubtleColor =>
      isDark ? AppColors.accentSubtle : AppColors.lightAccentSubtle;
  Color get accentLineColor =>
      isDark ? AppColors.accentLine : AppColors.lightAccentLine;

  Color get textPrimaryColor =>
      isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get textSecondaryColor =>
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get textTertiaryColor =>
      isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;
  Color get textQuaternaryColor =>
      isDark ? AppColors.textQuaternary : AppColors.lightTextQuaternary;

  Color get unreadColor =>
      isDark ? AppColors.unread : AppColors.lightUnread;
  Color get downloadedColor =>
      isDark ? AppColors.downloaded : AppColors.lightDownloaded;
  Color get warningColor =>
      isDark ? AppColors.warning : AppColors.lightWarning;

  // Back-compat: floating tab bar tint.
  Color get tabBarColor =>
      isDark ? AppColors.tabBarBackground : const Color(0xEBF6F4F2);
}
