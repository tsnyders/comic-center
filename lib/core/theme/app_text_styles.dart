import 'package:flutter/cupertino.dart';
import 'app_colors.dart';

/// ============================================================================
/// Comic Center — AppTextStyles  ("Ink & Glass" redesign)
///
/// Renders in SF Pro (the Cupertino system face). Large text carries tight
/// negative tracking; captions open up slightly. Sizes/weights are unchanged
/// from the baseline where they already worked — the redesign adds a `hero`
/// step + `overline`, and standardises tracking.
///
/// Most styles bake a sensible DARK-mode default color so legacy call sites
/// keep their look; redesigned screens override per-mode with
/// `.copyWith(color: context.textSecondaryColor)` (and friends from
/// `AppColorsX`). The few always-accent styles bake the accent.
/// ============================================================================
abstract final class AppTextStyles {
  // ── Display ──────────────────────────────────────────────────────────
  static const displayTitle = TextStyle(
    fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.0,
  );
  static const displayTitleAccent = TextStyle(
    fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.0,
    color: AppColors.accent,
  );

  /// A mid-weight hero step for shelf headers ("Continue Reading").
  static const hero = TextStyle(
    fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.05,
  );

  // ── Navigation / sections ────────────────────────────────────────────
  static const navTitle = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2,
  );
  static const sectionTitle = TextStyle(
    fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3,
  );

  // ── Body ─────────────────────────────────────────────────────────────
  static const bodyLarge = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.1,
  );
  static const bodyMedium = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
  );
  static const bodySmall = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, height: 1.45,
    color: AppColors.textSecondary,
  );

  // ── Labels / captions ────────────────────────────────────────────────
  static const labelMedium = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static const labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2,
    color: AppColors.textTertiary,
  );
  static const caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
  /// Uppercase section overline ("184 CHAPTERS", "APPEARANCE").
  static const overline = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5,
    color: AppColors.textTertiary,
  );

  // ── Cards ────────────────────────────────────────────────────────────
  static const cardTitle = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3,
    color: AppColors.textPrimary,
  );
  static const cardSubtitle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ── Buttons ──────────────────────────────────────────────────────────
  static const buttonPrimary = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1,
  );

  // ── Detail sheet ─────────────────────────────────────────────────────
  static const sheetTitle = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5,
  );
  static const sheetAuthor = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ── Reader ───────────────────────────────────────────────────────────
  static const readerChapterTitle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const readerPagePill = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // ── Source rows ──────────────────────────────────────────────────────
  static const sourceName = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600,
  );
  static const sourceMeta = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
}
