import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// ============================================================================
/// Comic Center — AppTheme  ("Obsidian" design system)
///
/// Central factory for CupertinoThemeData and ThemeData.
/// Feed the [brightness] from [brightnessProvider] and get a fully wired theme.
///
/// Usage in app.dart:
///   theme: AppTheme.cupertino(brightness),
/// ============================================================================
abstract final class AppTheme {
  /// Full CupertinoThemeData for the app.
  static CupertinoThemeData cupertino(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: isDark ? AppColors.accent : AppColors.lightAccent,
      scaffoldBackgroundColor:
          isDark ? AppColors.background : AppColors.lightBackground,
      barBackgroundColor:
          isDark ? AppColors.tabBarBackground : AppColors.lightTabBarBackground,
      textTheme: CupertinoTextThemeData(
        primaryColor:
            isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
        // Default text style for all Cupertino widgets
        textStyle: TextStyle(
          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          fontFamily: AppTextStyles.sans,
          fontVariations: const [FontVariation('wght', 400)],
          fontSize: 15,
          height: 1.5,
        ),
        // Editorial serif for nav titles — Cormorant Garamond SemiBold
        navTitleTextStyle: TextStyle(
          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          fontFamily: AppTextStyles.serif,
          fontVariations: const [FontVariation('wght', 600)],
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        // Editorial serif for large title — Cormorant Garamond Bold
        navLargeTitleTextStyle: TextStyle(
          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          fontFamily: AppTextStyles.serif,
          fontVariations: const [FontVariation('wght', 700)],
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        actionTextStyle: TextStyle(
          color: isDark ? AppColors.accent : AppColors.lightAccent,
          fontFamily: AppTextStyles.sans,
          fontVariations: const [FontVariation('wght', 500)],
          fontSize: 16,
        ),
      ),
    );
  }

  /// Companion MaterialTheme for any Material widgets used alongside Cupertino.
  static ThemeData material(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seed = isDark ? AppColors.accent : AppColors.lightAccent;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        surface: isDark ? AppColors.surface : AppColors.lightSurface,
      ),
      fontFamily: AppTextStyles.sans,
      scaffoldBackgroundColor:
          isDark ? AppColors.background : AppColors.lightBackground,
    );
  }
}
