import 'package:flutter/cupertino.dart';

/// ============================================================================
/// Comic Center — AppSpacing / AppRadius / AppElevation / AppMotion
/// New scales introduced by the "Ink & Glass" redesign. Radii are smaller and
/// more intentional than the old 14/22/28 set; spacing follows a 4pt rhythm;
/// elevation is a restrained soft+tight shadow pair, mode-tuned.
/// ============================================================================

abstract final class AppSpacing {
  static const x0  = 0.0;
  static const x1  = 2.0;
  static const x2  = 4.0;
  static const x3  = 6.0;
  static const x4  = 8.0;
  static const x5  = 12.0;
  static const x6  = 16.0;   // default inset
  static const x7  = 20.0;   // page horizontal margin
  static const x8  = 24.0;
  static const x9  = 32.0;
  static const x10 = 40.0;
  static const x11 = 48.0;
  static const x12 = 64.0;

  static const gutter  = x7;   // 20 — screen edge inset
  static const gridGap = 14.0; // library 2-col (10 when 3-col)
}

abstract final class AppRadius {
  static const xs    = 6.0;    // chips, small inputs
  static const sm    = 8.0;    // badges, segmented bg
  static const cover = 10.0;   // manga cover art
  static const md    = 12.0;   // cards, source rows, buttons
  static const lg    = 16.0;   // glass nav bar, grouped lists
  static const xl    = 20.0;   // bottom sheets
  static const pill  = 999.0;  // filter pills, indicator

  static const hairline = 0.75; // border width
}

abstract final class AppElevation {
  // Dark
  static const e1 = [BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1))];
  static const e2 = [BoxShadow(color: Color(0x38000000), blurRadius: 14, offset: Offset(0, 4))];
  static const e3 = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 30, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x2E000000), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const e4 = [
    BoxShadow(color: Color(0x66000000), blurRadius: 48, offset: Offset(0, 20)),
    BoxShadow(color: Color(0x3D000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  /// Floating nav bar — soft dark drop + faint Coral bloom.
  static const float = [
    BoxShadow(color: Color(0x6B000000), blurRadius: 40, spreadRadius: -4, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x1AFF6A5C), blurRadius: 18, offset: Offset(0, 6)),
  ];

  // Light — shallower & cooler
  static const e2Light = [BoxShadow(color: Color(0x14141828), blurRadius: 14, offset: Offset(0, 4))];
  static const e3Light = [
    BoxShadow(color: Color(0x1A141828), blurRadius: 30, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x10141828), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const floatLight = [
    BoxShadow(color: Color(0x24141828), blurRadius: 40, spreadRadius: -4, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x14DC4633), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 380); // nav pill slide

  static const standard = Cubic(0.4, 0.0, 0.2, 1.0);
  static const easeOut   = Cubic(0.22, 1.0, 0.36, 1.0);  // pill / sheet settle
  static const spring    = Cubic(0.34, 1.56, 0.64, 1.0); // active icon pop

  static const pressScale = 0.96;
}
