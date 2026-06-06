import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'features/root/root_scaffold.dart';

class ComicCenterApp extends StatelessWidget {
  const ComicCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Force light status bar text (white icons) for the dark theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return const CupertinoApp(
      title: 'Comic Center',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: AppColors.background,
        barBackgroundColor: AppColors.tabBarBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.textPrimary,
          textStyle: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: '.SF Pro Text',
            fontSize: 15,
          ),
          navTitleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: '.SF Pro Display',
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          navLargeTitleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: '.SF Pro Display',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      home: RootScaffold(),
    );
  }
}
