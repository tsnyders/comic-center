import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/settings_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'features/root/root_scaffold.dart';

class YomiApp extends ConsumerWidget {
  const YomiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessProvider);

    // Adapt status bar icon style to match the current brightness mode
    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );

    final isDark = brightness == Brightness.dark;

    return CupertinoApp(
      title: 'Yomi',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: brightness,
        // Coral accent drives default Cupertino tints (buttons, switches,
        // sliders, selection handles) — no more stock-iOS system blue.
        primaryColor: isDark ? AppColors.accent : AppColors.lightAccent,
        scaffoldBackgroundColor:
            isDark ? AppColors.background : AppColors.lightBackground,
        barBackgroundColor: isDark
            ? AppColors.tabBarBackground
            : const Color(0xEBF6F4F2),
        textTheme: CupertinoTextThemeData(
          primaryColor: isDark
              ? AppColors.textPrimary
              : AppColors.lightTextPrimary,
          textStyle: TextStyle(
            color: isDark
                ? AppColors.textPrimary
                : AppColors.lightTextPrimary,
            fontFamily: '.SF Pro Text',
            fontSize: 15,
          ),
          // Native nav bars adopt the Sora display face for brand consistency.
          navTitleTextStyle: TextStyle(
            color: isDark
                ? AppColors.textPrimary
                : AppColors.lightTextPrimary,
            fontFamily: AppTextStyles.display,
            fontVariations: const [FontVariation('wght', 600)],
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          navLargeTitleTextStyle: TextStyle(
            color: isDark
                ? AppColors.textPrimary
                : AppColors.lightTextPrimary,
            fontFamily: AppTextStyles.display,
            fontVariations: const [FontVariation('wght', 700)],
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
      ),
      home: const RootScaffold(),
    );
  }
}
