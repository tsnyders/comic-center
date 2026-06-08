import 'package:flutter/cupertino.dart';

abstract final class AppColors {
  // Backgrounds (dark theme)
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF141418);
  static const surfaceElevated = Color(0xFF1C1C24);

  // Borders (dark theme)
  static const border = Color(0x14FFFFFF);
  static const borderStrong = Color(0x26FFFFFF);

  // Accent
  static const accent = Color(0xFF0A84FF);
  static const accentSubtle = Color(0x330A84FF);

  // Text (dark theme)
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const textTertiary = Color(0x4DFFFFFF);
  static const textQuaternary = Color(0x26FFFFFF);

  // Light theme equivalents
  static const lightBackground = Color(0xFFF2F2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceElevated = Color(0xFFECECF0);
  static const lightBorder = Color(0x14000000);
  static const lightBorderStrong = Color(0x26000000);
  static const lightTextSecondary = Color(0x99000000);
  static const lightTextTertiary = Color(0x4D000000);
  static const lightTextQuaternary = Color(0x26000000);

  // Semantic
  static const unread = Color(0xFFFF453A);
  static const downloaded = Color(0xFF30D158);
  static const warning = Color(0xFFFFD60A);

  // Tab bar
  static const tabBarBackground = Color(0xEB141418);

  // Reader
  static const readerBackground = Color(0xFF000000);

  // Gradients
  static const ambientGradient = [
    Color(0xFF0A0A0F),
    Color(0xFF0D0D18),
  ];

  static const heroGradientColors = [
    Color(0x00000000),
    Color(0xD90A0A0F),
  ];
}

/// Context-aware color helpers. Use these in place of raw AppColors constants
/// when you need the correct color in both dark and light mode.
extension AppColorsX on BuildContext {
  bool get isDark {
    final brightness = CupertinoTheme.brightnessOf(this);
    return brightness == Brightness.dark;
  }

  Color get backgroundColor =>
      isDark ? AppColors.background : AppColors.lightBackground;

  Color get surfaceColor =>
      isDark ? AppColors.surface : AppColors.lightSurface;

  Color get surfaceElevatedColor =>
      isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated;

  Color get borderColor =>
      isDark ? AppColors.border : AppColors.lightBorder;

  Color get borderStrongColor =>
      isDark ? AppColors.borderStrong : AppColors.lightBorderStrong;

  Color get textSecondaryColor =>
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

  Color get textTertiaryColor =>
      isDark ? AppColors.textTertiary : AppColors.lightTextTertiary;

  Color get textQuaternaryColor =>
      isDark ? AppColors.textQuaternary : AppColors.lightTextQuaternary;

  Color get tabBarColor =>
      isDark ? AppColors.tabBarBackground : const Color(0xEBF9F9F9);
}
