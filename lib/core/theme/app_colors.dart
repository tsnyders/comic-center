import 'package:flutter/cupertino.dart';

import 'yomi_theme.dart';

/// ============================================================================
/// Comic Center — AppColors  (Sumi defaults)
///
/// The live palette is [YomiTheme] (see yomi_theme.dart): six semantic roles
/// driven by the user's mode + accent. The `context.xxxColor` extension below
/// resolves through it, so every existing call site follows the runtime theme.
///
/// The static constants here are the Sumi *dark defaults* — kept for the few
/// const contexts that cannot read a BuildContext (static text styles, reader
/// overlays). Prefer the context extension or `context.yc` in widgets.
/// ============================================================================
abstract final class AppColors {
  // ─────────────────────────────────────────────────────────────────────────────
  // Accent ramp (Sumi vermilion). Names kept for call-site compatibility.
  // ─────────────────────────────────────────────────────────────────────────────
  static const coral200 = Color(0xFFE9A6A9);
  static const coral300 = Color(0xFFD9767B);
  static const coral400 = Color(0xFFC9484F);
  static const coral500 = Color(0xFFB7282E);
  static const coral600 = Color(0xFF9E2027);
  static const coral700 = Color(0xFFB7282E);
  static const coral800 = Color(0xFF7F1A20);

  static const cobalt300 = coral300;
  static const cobalt400 = coral400;
  static const cobalt500 = coral500;
  static const cobalt600 = coral600;
  static const cobalt700 = coral700;
  static const cobalt800 = coral800;

  // ─────────────────────────────────────────────────────────────────────────────
  // Dark mode — Sumi ink
  // ─────────────────────────────────────────────────────────────────────────────
  static const background      = Color(0xFF0B0B0A);
  static const surface         = Color(0xFF1A1917);
  static const surfaceElevated = Color(0xFF1A1917);
  static const surfaceBright   = Color(0xFF2A2825);
  static const surfaceSunken   = Color(0xFF000000);

  static const border        = Color(0xFF2A2825);
  static const borderSubtle  = Color(0xFF2A2825);
  static const borderStrong  = Color(0xFF2A2825);
  static const borderBright  = Color(0xFF3A3733);

  static const accent        = coral500;
  static const accentHover   = coral400;
  static const accentPress   = coral600;
  static const accentSubtle  = Color(0x23B7282E);
  static const accentLine    = Color(0x4DB7282E);
  static const accentBorder  = Color(0x33B7282E);

  static const textPrimary    = Color(0xFFF2EDE3);
  static const textSecondary  = Color(0xFFA9A399);
  static const textTertiary   = Color(0xB3A9A399);
  static const textQuaternary = Color(0x66A9A399);
  static const textOnAccent   = Color(0xFFFFFFFF);

  // ─────────────────────────────────────────────────────────────────────────────
  // Light mode — Paper
  // ─────────────────────────────────────────────────────────────────────────────
  static const lightBackground      = Color(0xFFF2EDE3);
  static const lightSurface         = Color(0xFFE7E1D5);
  static const lightSurfaceElevated = Color(0xFFE7E1D5);
  static const lightSurfaceSunken   = Color(0xFFD8D2C6);
  static const lightBorder          = Color(0xFFD8D2C6);
  static const lightBorderStrong    = Color(0xFFD8D2C6);

  static const lightAccent       = coral500;
  static const lightAccentHover  = coral400;
  static const lightAccentPress  = coral600;
  static const lightAccentSubtle = Color(0x1AB7282E);
  static const lightAccentLine   = Color(0x4DB7282E);

  static const lightTextPrimary    = Color(0xFF0B0B0A);
  static const lightTextSecondary  = Color(0xFF6B665C);
  static const lightTextTertiary   = Color(0xB36B665C);
  static const lightTextQuaternary = Color(0x666B665C);

  // ─────────────────────────────────────────────────────────────────────────────
  // Semantic status
  // ─────────────────────────────────────────────────────────────────────────────
  static const unread          = coral500;
  static const downloaded      = Color(0xFF3F7A5E);
  static const warning         = Color(0xFFB8892E);
  static const info            = Color(0xFF2B4A7A);
  static const lightUnread     = coral500;
  static const lightDownloaded = Color(0xFF3F7A5E);
  static const lightWarning    = Color(0xFFB8892E);
  static const lightInfo       = Color(0xFF2B4A7A);

  // ─────────────────────────────────────────────────────────────────────────────
  // Reader modes
  // ─────────────────────────────────────────────────────────────────────────────
  static const readerBackground = Color(0xFF000000);
  static const readerDim        = Color(0xFF0A0A0A);
  static const readerWhite      = Color(0xFFFFFFFF);
  static const readerSepia      = Color(0xFFF4EFE4);

  // ─────────────────────────────────────────────────────────────────────────────
  // Scrims
  // ─────────────────────────────────────────────────────────────────────────────
  static const scrimStrong = Color(0xD9000000); // 85% black

  static const navPillDark  = Color(0xCC0B0B0A);
  static const navPillLight = Color(0xCCF2EDE3);

  static const ambientDark  = [Color(0xFF1A1917), Color(0xFF0B0B0A)];
  static const ambientLight = [Color(0xFFE7E1D5), Color(0xFFF2EDE3)];

  static const heroGradientDark = [
    Color(0x00000000), Color(0xCC0B0B0A), background,
  ];
  static const heroGradientLight = [
    Color(0x00000000), Color(0x88F2EDE3), lightBackground,
  ];

  // Source-accent gradients (Browse feature cards, source avatars)
  static const gradEmber      = [Color(0xFFB7282E), Color(0xFF7F1A20)];
  static const gradTealSignal = [Color(0xFF3F7A5E), Color(0xFF1F3D2F)];
  static const gradAzure      = [Color(0xFF2B4A7A), Color(0xFF16253D)];
  static const gradTeal       = gradTealSignal;
  static const gradRose       = gradEmber;
  static const gradGold       = [Color(0xFFB8892E), Color(0xFF5C4517)];
  static const gradViolet     = gradAzure;

  static const heroGradientColors = heroGradientDark;
  static const ambientGradient    = ambientDark;
  static const tabBarBackground   = Color(0xF20B0B0A);
  static const lightTabBarBackground = Color(0xEBF2EDE3);
  static const surfaceSunkenLegacy = Color(0xFF000000);
}

/// Context-aware token resolvers — the ONLY API screens should call.
/// All of these resolve through the live [YomiTheme].
extension AppColorsX on BuildContext {
  bool get isDark => yomi.isDark;

  Color get backgroundColor => yc.bg;
  Color get surfaceColor => yc.card;
  Color get surfaceElevatedColor => yc.card;
  Color get surfaceSunkenColor => yc.bg;

  Color get borderColor => yc.line;
  Color get borderSubtleColor => yc.line;
  Color get borderStrongColor => yc.line;

  Color get accentColor => yc.ac;
  Color get accentSubtleColor => yc.ac.withValues(alpha: 0.14);
  Color get accentLineColor => yc.ac.withValues(alpha: 0.30);

  Color get textPrimaryColor => yc.fg;
  Color get textSecondaryColor => yc.fg2;
  Color get textTertiaryColor => yc.fg2.withValues(alpha: 0.70);
  Color get textQuaternaryColor => yc.fg2.withValues(alpha: 0.40);

  Color get unreadColor => yc.ac;
  Color get downloadedColor =>
      isDark ? AppColors.downloaded : AppColors.lightDownloaded;
  Color get warningColor =>
      isDark ? AppColors.warning : AppColors.lightWarning;
  Color get infoColor =>
      isDark ? AppColors.info : AppColors.lightInfo;

  Color get tabBarColor => yc.bg;
}
