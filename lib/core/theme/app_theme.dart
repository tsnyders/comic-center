import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'yomi_theme.dart';

/// ============================================================================
/// Comic Center — AppTheme (Sumi)
///
/// Central factory for CupertinoThemeData / ThemeData, fed by the live
/// [YomiTheme] and its (possibly mid-crossfade) [YomiColors].
/// ============================================================================
abstract final class AppTheme {
  static CupertinoThemeData cupertino(YomiTheme theme, YomiColors c) {
    return CupertinoThemeData(
      brightness: theme.mode,
      primaryColor: c.ac,
      scaffoldBackgroundColor: c.bg,
      barBackgroundColor: c.bg,
      textTheme: CupertinoTextThemeData(
        primaryColor: c.fg,
        textStyle: YomiText.ui(15, color: c.fg, height: 1.5),
        navTitleTextStyle: YomiText.display(19, color: c.fg),
        navLargeTitleTextStyle: YomiText.display(34, color: c.fg),
        actionTextStyle: YomiText.ui(16, weight: FontWeight.w500, color: c.ac),
      ),
    );
  }

  /// Companion MaterialTheme for any Material widgets used alongside Cupertino.
  static ThemeData material(YomiTheme theme, YomiColors c) {
    return ThemeData(
      useMaterial3: true,
      brightness: theme.mode,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.ac,
        brightness: theme.mode,
        surface: c.card,
      ),
      fontFamily: theme.spec.bodyFont,
      scaffoldBackgroundColor: c.bg,
    );
  }
}
