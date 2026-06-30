import 'package:flutter/cupertino.dart';

/// ============================================================================
/// Comic Center — AppColors  ("LUMEN" design system)
///
/// PHILOSOPHY: A cinematic ink canvas where the cover art is the hero. Surfaces
/// are deep, near-black, layered with soft depth. Text is a warm ivory. The
/// brand "signal" is a restrained teal — but the live accent is
/// pulled dynamically from each cover (see CoverPaletteProvider); `accent` here
/// is the teal fallback used before/until a palette resolves.
///
/// TOKEN RULES:
///   • Screens MUST use context.xxxColor extensions — never raw constants.
///   • For art-driven accent, prefer the per-cover palette over `accentColor`.
/// ============================================================================
abstract final class AppColors {
  // ─────────────────────────────────────────────────────────────────────────────
  // Teal signal ramp (names kept as `coral*` for call-site compatibility)
  // ─────────────────────────────────────────────────────────────────────────────
  static const coral200 = Color(0xFFB2E8E4);
  static const coral300 = Color(0xFF7DD4CC);
  static const coral400 = Color(0xFF4DC9BF);  // dark hover / glow
  static const coral500 = Color(0xFF2BBCB3);  // DARK signal (teal)
  static const coral600 = Color(0xFF22A39B);  // dark press
  static const coral700 = Color(0xFF1A8A83);  // LIGHT signal (teal on paper)
  static const coral800 = Color(0xFF13706A);  // light press

  // Back-compat aliases
  static const cobalt300 = coral300;
  static const cobalt400 = coral400;
  static const cobalt500 = coral500;
  static const cobalt600 = coral600;
  static const cobalt700 = coral700;
  static const cobalt800 = coral800;

  // ─────────────────────────────────────────────────────────────────────────────
  // Dark mode — Ink (the primary LUMEN experience)
  // ─────────────────────────────────────────────────────────────────────────────
  static const background      = Color(0xFF0A0A0D);  // ink canvas
  static const surface         = Color(0xFF121217);  // elevated +1
  static const surfaceElevated = Color(0xFF1A1A21);  // cards, sheets
  static const surfaceBright   = Color(0xFF23232C);  // spotlight / featured
  static const surfaceSunken   = Color(0xFF050507);  // inputs, insets

  // Border ramp — ivory hairlines
  static const border        = Color(0x0DF3F0E9);  //  ~5%
  static const borderSubtle  = Color(0x14F3F0E9);  //  ~8%
  static const borderStrong  = Color(0x24F3F0E9);  // ~14%
  static const borderBright  = Color(0x33F3F0E9);  // 20%

  // Accent (teal fallback)
  static const accent        = coral500;
  static const accentHover   = coral400;
  static const accentPress   = coral600;
  static const accentSubtle  = Color(0x232BBCB3);  // teal ~14%
  static const accentLine    = Color(0x4D2BBCB3);  // teal 30%
  static const accentBorder  = Color(0x332BBCB3);  // teal 20%

  // Text — warm ivory
  static const textPrimary    = Color(0xF5F3F0E9);  // ~96%
  static const textSecondary  = Color(0x9EF3F0E9);  // ~62%
  static const textTertiary   = Color(0x5EF3F0E9);  // ~37%
  static const textQuaternary = Color(0x28F3F0E9);  // ~16%
  static const textOnAccent   = Color(0xFF0A1E1D);  // deep teal ink on accent

  // ─────────────────────────────────────────────────────────────────────────────
  // Light mode — Paper (warm, optional companion to Ink)
  // ─────────────────────────────────────────────────────────────────────────────
  static const lightBackground      = Color(0xFFF3F0E9);
  static const lightSurface         = Color(0xFFFBF9F4);
  static const lightSurfaceElevated = Color(0xFFFFFFFF);
  static const lightSurfaceSunken   = Color(0xFFE9E5DC);
  static const lightBorder          = Color(0x12151019);  //  ~7% ink
  static const lightBorderStrong    = Color(0x24151019);  // ~14% ink

  static const lightAccent       = coral700;
  static const lightAccentHover  = coral600;
  static const lightAccentPress  = coral800;
  static const lightAccentSubtle = Color(0x1A1A8A83);  // 10%
  static const lightAccentLine   = Color(0x4D1A8A83);  // 30%

  static const lightTextPrimary    = Color(0xF2151019);  // deep ink
  static const lightTextSecondary  = Color(0x99151019);  // ~60%
  static const lightTextTertiary   = Color(0x5C151019);  // ~36%
  static const lightTextQuaternary = Color(0x28151019);  // ~16%

  // ─────────────────────────────────────────────────────────────────────────────
  // Semantic status
  // ─────────────────────────────────────────────────────────────────────────────
  static const unread          = Color(0xFF2BBCB3);  // teal (matches signal)
  static const downloaded      = Color(0xFF4AD07F);
  static const warning         = Color(0xFFF5C75E);
  static const info            = Color(0xFF64D2FF);
  static const lightUnread     = Color(0xFF1A8A83);
  static const lightDownloaded = Color(0xFF1F9D58);
  static const lightWarning    = Color(0xFFC99700);
  static const lightInfo       = Color(0xFF2563EB);

  // ─────────────────────────────────────────────────────────────────────────────
  // Reader modes
  // ─────────────────────────────────────────────────────────────────────────────
  static const readerBackground = Color(0xFF000000);
  static const readerDim        = Color(0xFF0A0A0A);
  static const readerWhite      = Color(0xFFFFFFFF);
  static const readerSepia      = Color(0xFFF4ECD8);

  // ─────────────────────────────────────────────────────────────────────────────
  // Scrims — text-legibility gradients over cover art / images
  // ─────────────────────────────────────────────────────────────────────────────
  static const scrimStrong = Color(0xD9000000); // 85% black

  // ─────────────────────────────────────────────────────────────────────────────
  // Floating chrome (root nav pill) — deliberately theme-independent translucent
  // surfaces, distinct from the opaque surfaceElevated tokens above.
  // ─────────────────────────────────────────────────────────────────────────────
  static const navPillDark  = Color(0xCC15151B);
  static const navPillLight = Color(0xCCFFFFFF);

  // ─────────────────────────────────────────────────────────────────────────────
  // Ambient backdrop seeds (hero gradient backgrounds) — teal-tinted ink
  // ─────────────────────────────────────────────────────────────────────────────
  static const ambientDark  = [Color(0xFF142D2B), Color(0xFF0A0A0D)];
  static const ambientLight = [Color(0xFFE0F5F3), Color(0xFFF3F0E9)];

  static const heroGradientDark = [
    Color(0x00000000), Color(0xCC0A0A0D), background,
  ];
  static const heroGradientLight = [
    Color(0x00000000), Color(0x88F3F0E9), lightBackground,
  ];

  // ─────────────────────────────────────────────────────────────────────────────
  // Source-accent gradients (Browse feature cards, source avatars)
  // ─────────────────────────────────────────────────────────────────────────────
  static const gradEmber      = [Color(0xFFFF6A3D), Color(0xFFC0264E)];
  static const gradTealSignal = [Color(0xFF2BBCB3), Color(0xFF0E4A46)];
  static const gradAzure      = [Color(0xFF60A5FA), Color(0xFF1D4ED8)];
  static const gradTeal       = [Color(0xFF2DD4BF), Color(0xFF0E7490)];
  static const gradRose       = [Color(0xFFF472B6), Color(0xFF9D174D)];
  static const gradGold       = [Color(0xFFFBBF24), Color(0xFF92400E)];

  // Back-compat: gradViolet now points to teal signal
  static const gradViolet = gradTealSignal;

  // ─────────────────────────────────────────────────────────────────────────────
  // Back-compat aliases
  // ─────────────────────────────────────────────────────────────────────────────
  static const heroGradientColors = heroGradientDark;
  static const ambientGradient    = ambientDark;
  static const tabBarBackground   = Color(0xF2121217);
  static const lightTabBarBackground = Color(0xEBF6F4F2);
  static const surfaceSunkenLegacy = Color(0xFF050507);
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
      isDark ? AppColors.tabBarBackground : AppColors.lightTabBarBackground;
}
