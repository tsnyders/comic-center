import 'package:flutter/cupertino.dart';

/// ============================================================================
/// Comic Center — AppColors  ("Ink & Glass" redesign)
///
/// A near-monochrome surface system with ONE confident accent (Cobalt) and
/// crisp hairlines. Every surface/text/border token is defined for both modes;
/// glass tints additionally vary by theme (see [AppGlassSpec]).
///
/// Accent rationale: the old #0A84FF iOS blue leans cyan and reads "default".
/// Cobalt is a deeper, faintly indigo-leaning blue — more characterful, still
/// unmistakably "blue/link", and tuned per mode so accent-as-text passes
/// WCAG AA in both (the bright 500 on dark, the deeper 700 on white).
/// ============================================================================
abstract final class AppColors {
  // ── Cobalt accent ramp ────────────────────────────────────────────────
  static const cobalt300 = Color(0xFF8AA6FF);
  static const cobalt400 = Color(0xFF6E8FFF); // dark hover
  static const cobalt500 = Color(0xFF4E7BFF); // DARK accent
  static const cobalt600 = Color(0xFF3A63F0); // dark press / light hover
  static const cobalt700 = Color(0xFF2E5BE6); // LIGHT accent (AA on white)
  static const cobalt800 = Color(0xFF2348C4); // light press

  // ── Dark mode ─────────────────────────────────────────────────────────
  static const background       = Color(0xFF0A0A0F);
  static const surface          = Color(0xFF131318);
  static const surfaceElevated  = Color(0xFF1C1C24);
  static const surfaceSunken    = Color(0xFF08080C);

  static const border        = Color(0x14FFFFFF); // 8%
  static const borderStrong  = Color(0x29FFFFFF); // 16%

  static const accent        = cobalt500;
  static const accentHover   = cobalt400;
  static const accentPress   = cobalt600;
  static const accentSubtle  = Color(0x294E7BFF); // 16%
  static const accentLine    = Color(0x734E7BFF); // 45%

  static const textPrimary    = Color(0xFAFFFFFF); // 98%
  static const textSecondary  = Color(0x9EFFFFFF); // 62%
  static const textTertiary   = Color(0x5CFFFFFF); // 36%
  static const textQuaternary = Color(0x29FFFFFF); // 16%
  static const textOnAccent   = Color(0xFFFFFFFF);

  // ── Light mode ────────────────────────────────────────────────────────
  static const lightBackground      = Color(0xFFF4F4F8);
  static const lightSurface         = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFECECF1);
  static const lightSurfaceSunken   = Color(0xFFE6E6EC);

  static const lightBorder       = Color(0x14000000); // 8%
  static const lightBorderStrong = Color(0x24000000); // 14%

  static const lightAccent       = cobalt700;
  static const lightAccentHover  = cobalt600;
  static const lightAccentPress  = cobalt800;
  static const lightAccentSubtle = Color(0x1F2E5BE6); // 12%
  static const lightAccentLine   = Color(0x522E5BE6); // 32%

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
  static const ambientDark  = [Color(0xFF0D1322), Color(0xFF0A0A0F)];
  static const ambientLight = [Color(0xFFEAEEFB), Color(0xFFF4F4F8)];

  // ── Hero protection gradient (cover → background) ─────────────────────
  static const heroGradientDark = [
    Color(0x33000000), Color(0xCC0A0A0F), background,
  ];
  static const heroGradientLight = [
    Color(0x22000000), Color(0x88F4F4F8), lightBackground,
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
  static const tabBarBackground = Color(0xEB131318);
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
      isDark ? AppColors.tabBarBackground : const Color(0xEBF9F9F9);
}
