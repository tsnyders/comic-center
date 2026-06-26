import 'package:flutter/cupertino.dart';

/// ============================================================================
/// Comic Center — AppColors  ("Studio" design system)
///
/// PHILOSOPHY: Warm-white, gallery-calm surfaces in light mode (the primary
/// experience) and a clean warm-neutral dark mode. One deep EMERALD accent
/// (#0F766E) is the single pop of colour — on CTAs, active states, and unread
/// markers. Structure is expressed with hairlines + generous whitespace, never
/// glass or blur.
///
/// TOKEN RULES:
///   • Screens MUST use context.xxxColor extensions — never raw constants.
///   • Raw constants are for widget internals that cannot carry a BuildContext.
/// ============================================================================
abstract final class AppColors {
  // ─────────────────────────────────────────────────────────────────────────────
  // Emerald accent ramp (names kept as `coral*` for call-site compatibility)
  // ─────────────────────────────────────────────────────────────────────────────
  static const coral200 = Color(0xFFB9E6DC);
  static const coral300 = Color(0xFF7FCDBE);
  static const coral400 = Color(0xFF3FAF9B);  // dark hover / glow
  static const coral500 = Color(0xFF1AA088);  // DARK primary accent (bright emerald)
  static const coral600 = Color(0xFF12877A);  // dark press
  static const coral700 = Color(0xFF0F766E);  // LIGHT primary accent (deep emerald)
  static const coral800 = Color(0xFF0B5A53);  // light press

  // Back-compat aliases for call sites still using the old "cobalt" naming
  static const cobalt300 = coral300;
  static const cobalt400 = coral400;
  static const cobalt500 = coral500;
  static const cobalt600 = coral600;
  static const cobalt700 = coral700;
  static const cobalt800 = coral800;

  // ─────────────────────────────────────────────────────────────────────────────
  // Dark mode — clean warm-neutral (Studio dark)
  // ─────────────────────────────────────────────────────────────────────────────
  static const background      = Color(0xFF121214);  // canvas
  static const surface         = Color(0xFF1A1A1D);  // elevated +1
  static const surfaceElevated = Color(0xFF222227);  // cards, sheets
  static const surfaceBright   = Color(0xFF2A2A30);  // spotlight / featured
  static const surfaceSunken   = Color(0xFF0D0D0F);  // inputs, insets

  // Border ramp — hairline to rim-light
  static const border        = Color(0x0DFFFFFF);  //  ~5% hairline
  static const borderSubtle  = Color(0x14FFFFFF);  //  ~8%
  static const borderStrong  = Color(0x24FFFFFF);  // ~14%
  static const borderBright  = Color(0x33FFFFFF);  // 20%

  // Accent tokens (dark, based on bright emerald coral500)
  static const accent        = coral500;
  static const accentHover   = coral400;
  static const accentPress   = coral600;
  static const accentSubtle  = Color(0x1F1AA088);  // emerald ~12%
  static const accentLine    = Color(0x4D1AA088);  // emerald 30%
  static const accentBorder  = Color(0x331AA088);  // emerald 20%

  // Text — warm-neutral near-white
  static const textPrimary    = Color(0xFAF7F6F3);  // ~98%
  static const textSecondary  = Color(0x9AF7F6F3);  // ~60%
  static const textTertiary   = Color(0x5AF7F6F3);  // ~35%
  static const textQuaternary = Color(0x28F7F6F3);  // ~16%
  static const textOnAccent   = Color(0xFFFFFFFF);

  // ─────────────────────────────────────────────────────────────────────────────
  // Light mode — warm white (Studio, the primary experience)
  // ─────────────────────────────────────────────────────────────────────────────
  static const lightBackground      = Color(0xFFFAFAF7);
  static const lightSurface         = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFFFFFFF);
  static const lightSurfaceSunken   = Color(0xFFF2F1EA);
  static const lightBorder          = Color(0x14151510);  //  ~8% ink
  static const lightBorderStrong    = Color(0x24151510);  // ~14% ink

  static const lightAccent       = coral700;  // deep emerald on white
  static const lightAccentHover  = coral600;
  static const lightAccentPress  = coral800;
  static const lightAccentSubtle = Color(0x1A0F766E);  // 10%
  static const lightAccentLine   = Color(0x4D0F766E);  // 30%

  static const lightTextPrimary    = Color(0xF2151510);  // warm ink
  static const lightTextSecondary  = Color(0x99151510);  // ~60%
  static const lightTextTertiary   = Color(0x5C151510);  // ~36%
  static const lightTextQuaternary = Color(0x28151510);  // ~16%

  // ─────────────────────────────────────────────────────────────────────────────
  // Semantic status
  // ─────────────────────────────────────────────────────────────────────────────
  static const unread          = Color(0xFF1AA088);  // emerald (matches accent)
  static const downloaded      = Color(0xFF30D158);
  static const warning         = Color(0xFFFFD60A);
  static const info            = Color(0xFF64D2FF);
  static const lightUnread     = Color(0xFF0F766E);
  static const lightDownloaded = Color(0xFF28A745);
  static const lightWarning    = Color(0xFFB7791F);
  static const lightInfo       = Color(0xFF2563EB);

  // ─────────────────────────────────────────────────────────────────────────────
  // Reader modes
  // ─────────────────────────────────────────────────────────────────────────────
  static const readerBackground = Color(0xFF000000);
  static const readerDim        = Color(0xFF0A0A0A);
  static const readerSepia      = Color(0xFFF4ECD8);

  // ─────────────────────────────────────────────────────────────────────────────
  // Ambient backdrop seeds (hero gradient backgrounds) — faint emerald wash
  // ─────────────────────────────────────────────────────────────────────────────
  static const ambientDark  = [Color(0xFF13241F), Color(0xFF121214)];
  static const ambientLight = [Color(0xFFEAF3EF), Color(0xFFFAFAF7)];

  static const heroGradientDark = [
    Color(0x00000000), Color(0xCC121214), background,
  ];
  static const heroGradientLight = [
    Color(0x00000000), Color(0x88FAFAF7), lightBackground,
  ];

  // ─────────────────────────────────────────────────────────────────────────────
  // Source-accent gradients (Browse feature cards, source avatars)
  // ─────────────────────────────────────────────────────────────────────────────
  static const gradEmber  = [Color(0xFF1AA088), Color(0xFF0B5A53)];
  static const gradViolet = [Color(0xFF8B5CF6), Color(0xFF4C1D95)];
  static const gradAzure  = [Color(0xFF60A5FA), Color(0xFF1D4ED8)];
  static const gradTeal   = [Color(0xFF2DD4BF), Color(0xFF0E7490)];
  static const gradRose   = [Color(0xFFF472B6), Color(0xFF9D174D)];
  static const gradGold   = [Color(0xFFFBBF24), Color(0xFF92400E)];

  // ─────────────────────────────────────────────────────────────────────────────
  // Back-compat aliases — pre-redesign names still referenced in older screens
  // ─────────────────────────────────────────────────────────────────────────────
  static const heroGradientColors = heroGradientDark;
  static const ambientGradient    = ambientDark;
  static const tabBarBackground   = Color(0xF21A1A1D);
  static const surfaceSunkenLegacy = Color(0xFF0D0D0F);
}

/// Context-aware token resolvers — the ONLY API screens should call.
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
  Color get borderSubtleColor =>
      isDark ? AppColors.borderSubtle : AppColors.lightBorder;
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
  Color get infoColor =>
      isDark ? AppColors.info : AppColors.lightInfo;

  // Back-compat
  Color get tabBarColor =>
      isDark ? AppColors.tabBarBackground : const Color(0xEBFAFAF7);
}
