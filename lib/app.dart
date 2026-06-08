import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/settings_provider.dart';
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

    return CupertinoApp(
      title: 'Yomi',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: const Color(0xFF007AFF),
        scaffoldBackgroundColor: brightness == Brightness.dark
            ? const Color(0xFF0A0A0F)
            : const Color(0xFFF2F2F7),
        barBackgroundColor: brightness == Brightness.dark
            ? const Color(0xEB141418)
            : const Color(0xEBF9F9F9),
        textTheme: CupertinoTextThemeData(
          primaryColor: brightness == Brightness.dark
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF000000),
          textStyle: TextStyle(
            color: brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF000000),
            fontFamily: '.SF Pro Text',
            fontSize: 15,
          ),
          navTitleTextStyle: TextStyle(
            color: brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF000000),
            fontFamily: '.SF Pro Display',
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          navLargeTitleTextStyle: TextStyle(
            color: brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF000000),
            fontFamily: '.SF Pro Display',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      home: const RootScaffold(),
    );
  }
}
