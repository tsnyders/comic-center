import 'package:flutter/cupertino.dart';

/// ============================================================================
/// Comic Center — AppSpacing / AppRadius / AppElevation / AppMotion
/// ("Obsidian" design system)
///
/// SPACING: 4 pt grid. Step names mirror the Tailwind scale (x2=4, x4=8, …).
/// RADIUS: Five named tiers — from chip (xs=8) to sheet (xl=28) + pill.
/// ELEVATION: Obsidian shadow system — near-black shadows, coral bloom on float.
///   Depth is the primary way surfaces are separated now that blur is removed.
/// MOTION: Precision spring-physics vocabulary.
///   Duration names describe the FEEL, not the milliseconds:
///     instant 80ms — toggle, checkbox (syncs to tap haptic)
///     micro  120ms — icon state swap, badge pop
///     fast   180ms — button press, color change, chip select
///     base   260ms — card reveal, panel open
///     page   380ms — navigation push/pop, modal sheet
///     hero   520ms — hero entrance, cover zoom
///     epic   700ms — elaborate full-screen (use sparingly)
///   Curve names describe the feel: snap, spring, overshoot, decelerate.
/// ============================================================================

abstract final class AppSpacing {
  static const x0  = 0.0;
  static const x1  = 2.0;
  static const x2  = 4.0;
  static const x3  = 6.0;
  static const x4  = 8.0;
  static const x5  = 12.0;
  static const x6  = 16.0;
  static const x7  = 20.0;   // page horizontal margin
  static const x8  = 24.0;
  static const x9  = 32.0;
  static const x10 = 40.0;
  static const x11 = 48.0;
  static const x12 = 64.0;

  static const gutter  = x7;    // screen edge inset (20)
  static const gridGap = 14.0;  // library 2-col (10 for 3-col)
}

abstract final class AppRadius {
  static const xs    = 8.0;    // chips, tags, small inputs
  static const sm    = 10.0;   // badges, segmented controls
  static const cover = 12.0;   // manga / manhwa cover art
  static const md    = 16.0;   // cards, rows, buttons
  static const lg    = 22.0;   // nav bar, grouped lists, hero cards
  static const xl    = 28.0;   // bottom sheets, full-bleed panels
  static const pill  = 999.0;  // filter pills, nav indicator

  static const hairline = 0.75;  // standard border width
}

abstract final class AppElevation {
  // ── Dark mode (obsidian — near-black shadows + coral bloom on float) ────────

  static const e1 = [
    BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const e2 = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const e3 = [
    BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x33000000), blurRadius: 6,  offset: Offset(0, 2)),
  ];

  static const e4 = [
    BoxShadow(color: Color(0x80000000), blurRadius: 56, offset: Offset(0, 20)),
    BoxShadow(color: Color(0x4D000000), blurRadius: 14, offset: Offset(0, 4)),
  ];

  /// Floating nav bar — deep drop shadow + coral bloom + violet ambient.
  static const float = [
    BoxShadow(
      color: Color(0x7A000000), blurRadius: 48,
      spreadRadius: -4, offset: Offset(0, 16),
    ),
    BoxShadow(color: Color(0x1AFF5A4A), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D8B5CF6), blurRadius: 32, offset: Offset(0, 12)),
  ];

  // ── Light mode (ink shadows — shallower, cool) ───────────────────────────

  static const e2Light = [
    BoxShadow(color: Color(0x140D0D1A), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const e3Light = [
    BoxShadow(color: Color(0x1A0D0D1A), blurRadius: 32, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x100D0D1A), blurRadius: 6,  offset: Offset(0, 2)),
  ];

  static const floatLight = [
    BoxShadow(
      color: Color(0x240D0D1A), blurRadius: 48,
      spreadRadius: -4, offset: Offset(0, 16),
    ),
    BoxShadow(color: Color(0x10DE2E1F), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

abstract final class AppMotion {
  // ── Durations ────────────────────────────────────────────────────────────────

  static const instant = Duration(milliseconds: 80);
  static const micro   = Duration(milliseconds: 120);
  static const fast    = Duration(milliseconds: 180);
  static const base    = Duration(milliseconds: 260);
  static const page    = Duration(milliseconds: 380);
  static const hero    = Duration(milliseconds: 520);
  static const epic    = Duration(milliseconds: 700);

  // Back-compat aliases used across existing screens
  static const slow     = page;   // nav pill slide was called `slow`
  static const standard = Cubic(0.4, 0.0, 0.2, 1.0);  // kept as Curve alias

  // ── Curves ───────────────────────────────────────────────────────────────────

  /// Tight spring snap — default for most UI transitions.
  static const snap = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Material standard decelerate — accelerate then ease.
  static const ease = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Gentle settle into final position — panels, drawers.
  static const easeOut = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Bouncy spring — active icon pops, pill indicator slide.
  static const spring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Classic overshoot (Penner "back") — strong character moments.
  static const overshoot = Cubic(0.68, -0.55, 0.265, 1.55);

  /// Decelerate to rest — drag release, fling settle.
  static const decelerate = Cubic(0.0, 0.0, 0.2, 1.0);

  // ── Scale transforms ─────────────────────────────────────────────────────────

  /// Touch-press feedback scale.
  static const pressScale = 0.94;

  /// Card / button hover lift scale.
  static const hoverScale = 1.02;

  /// Active-state micro-pop scale.
  static const activeScale = 0.97;

  // ── Stagger choreography ─────────────────────────────────────────────────────

  /// Delay between successive list / grid items during entrance.
  static const staggerUnit = Duration(milliseconds: 35);

  /// Maximum items that participate in stagger — caps the tail delay.
  static const staggerMax = 6;

  /// Compute stagger delay for an item at [index].
  static Duration stagger(int index) =>
      staggerUnit * index.clamp(0, staggerMax);
}
