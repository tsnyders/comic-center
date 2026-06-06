import 'package:flutter/cupertino.dart';

abstract final class AppColors {
  // Backgrounds
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF141418);
  static const surfaceElevated = Color(0xFF1C1C24);

  // Borders
  static const border = Color(0x14FFFFFF); // 8% white
  static const borderStrong = Color(0x26FFFFFF); // 15% white

  // Accent — iOS dark-mode blue
  static const accent = Color(0xFF0A84FF);
  static const accentSubtle = Color(0x330A84FF); // 20% accent

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF); // 60%
  static const textTertiary = Color(0x4DFFFFFF); // 30%
  static const textQuaternary = Color(0x26FFFFFF); // 15%

  // Semantic
  static const unread = Color(0xFFFF453A); // iOS dark-mode red
  static const downloaded = Color(0xFF30D158); // iOS dark-mode green
  static const warning = Color(0xFFFFD60A); // iOS dark-mode yellow

  // Tab bar
  static const tabBarBackground = Color(0xEB141418); // 92% opacity

  // Reader
  static const readerBackground = Color(0xFF000000);

  // Gradients
  static const ambientGradient = [
    Color(0xFF0A0A0F),
    Color(0xFF0D0D18),
  ];

  static const heroGradientColors = [
    Colors.transparent,
    Color(0xD90A0A0F),
  ];
}

// ignore: avoid_classes_as_namespaces
abstract final class Colors {
  static const transparent = Color(0x00000000);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
}
