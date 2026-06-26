import 'package:flutter/cupertino.dart';
import 'app_colors.dart';

/// ============================================================================
/// Comic Center — AppTextStyles  ("Obsidian" design system)
///
/// THREE-TIER EDITORIAL TYPE SYSTEM:
///
///   Tier 1 — Editorial (Cormorant Garamond)
///     High-contrast optical serif. Variable font — drive weight via
///     fontVariations: [FontVariation('wght', w)]. Use for display titles,
///     hero text, chapter openers, and the wordmark. The dramatic thick/thin
///     contrast makes manga titles feel cinematic at large sizes.
///
///   Tier 2 — Interface (Sora)
///     Clean, precise grotesque. Variable font. Use for nav chrome, labels,
///     overlines, buttons, metadata, and all UI copy. Neutral enough that it
///     disappears; distinctive enough to feel designed.
///
///   Tier 3 — Reading (system Roboto / SF Pro)
///     No fontFamily set — inherits the platform body font. Used for prose,
///     captions, and synopses where native legibility is paramount.
///
/// USAGE:
///   • Reference static constants — never hard-code fonts or sizes.
///   • Override color with .copyWith(color: context.textSecondaryColor).
///   • Never bake a light-mode color into a static const — use AppColorsX.
/// ============================================================================
abstract final class AppTextStyles {
  // ── Font family tokens (LUMEN) ──────────────────────────────────────────────
  // HankenGrotesk carries display + UI (weight differentiates the tiers).
  // SpaceMono is the technical voice: chapter numbers, ratings, metadata, labels.
  static const serif   = 'HankenGrotesk';  // display titles (oversized editorial)
  static const sans    = 'HankenGrotesk';  // UI chrome, labels, buttons
  static const display = 'HankenGrotesk';
  static const mono    = 'SpaceMono';      // metadata · numbers · technical labels

  /// LUMEN metadata voice — mono, tracked, used for "CH 142 · ONGOING · 9.3★".
  static const metaMono = TextStyle(
    fontFamily: mono,
    fontSize: 11, fontWeight: FontWeight.w400,
    letterSpacing: 1.2,
    color: AppColors.textSecondary,
  );

  /// Smaller mono — counts, fine technical labels.
  static const metaMonoSm = TextStyle(
    fontFamily: mono,
    fontSize: 9, fontWeight: FontWeight.w400,
    letterSpacing: 1.0,
    color: AppColors.textTertiary,
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // TIER 1 — EDITORIAL (Cormorant Garamond)
  // ══════════════════════════════════════════════════════════════════════════════

  /// Full-bleed chapter-open / cinematic moment. 56 pt, ultra-tight tracking.
  static const displayXL = TextStyle(
    fontFamily: serif,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 56, fontWeight: FontWeight.w700,
    letterSpacing: -2.5, height: 0.92,
  );

  /// Hero section openers — title detail, featured banners. 44 pt.
  static const displayL = TextStyle(
    fontFamily: serif,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 44, fontWeight: FontWeight.w700,
    letterSpacing: -2.0, height: 0.96,
  );

  /// Medium hero — 36 pt. Use for browse section heroes.
  static const displayM = TextStyle(
    fontFamily: serif,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 36, fontWeight: FontWeight.w700,
    letterSpacing: -1.5, height: 1.0,
  );

  /// Sheet / panel / detail title — 28 pt.
  static const displayS = TextStyle(
    fontFamily: serif,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 28, fontWeight: FontWeight.w600,
    letterSpacing: -1.0, height: 1.05,
  );

  /// Shelf section header ("Continue Reading") — 22 pt serif.
  static const hero = TextStyle(
    fontFamily: serif,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 22, fontWeight: FontWeight.w700,
    letterSpacing: -0.5, height: 1.1,
  );

  // Back-compat aliases
  static const displayTitle = displayS;
  static const displayTitleAccent = TextStyle(
    fontFamily: serif,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 28, fontWeight: FontWeight.w600,
    letterSpacing: -1.0, height: 1.05,
    color: AppColors.accent,
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // TIER 2 — INTERFACE (Sora)
  // ══════════════════════════════════════════════════════════════════════════════

  /// Navigation bar title — Sora SemiBold 17.
  static const navTitle = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 17, fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// Section headings — Sora Bold 22.
  static const sectionTitle = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 22, fontWeight: FontWeight.w700,
    letterSpacing: -0.5, height: 1.15,
  );

  /// Mid-level headings — Sora SemiBold 18.
  static const titleM = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 18, fontWeight: FontWeight.w600,
    letterSpacing: -0.3, height: 1.2,
  );

  /// Prominent label — card titles, row primary text. Sora SemiBold 14.
  static const labelXL = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 14, fontWeight: FontWeight.w600,
    letterSpacing: -0.1, height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Standard metadata label — Sora Medium 13.
  static const labelMedium = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 13, fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
    color: AppColors.textSecondary,
  );

  /// Small metadata — Sora Medium 11.
  static const labelSmall = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 11, fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );

  /// Uppercase section overline — Sora SemiBold 10, tracked wide.
  static const overline = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 10, fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textTertiary,
  );

  /// Primary filled button — Sora SemiBold 14.
  static const buttonPrimary = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 14, fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Source name row — Sora SemiBold 15.
  static const sourceName = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 15, fontWeight: FontWeight.w600,
  );

  /// Source meta / secondary — Sora Regular 12.
  static const sourceMeta = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 400)],
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // TIER 3 — READING (system Roboto / SF Pro — no fontFamily set)
  // ══════════════════════════════════════════════════════════════════════════════

  /// Large body — synopses, descriptions. 16 pt, generous line height.
  static const bodyLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400,
    letterSpacing: -0.1, height: 1.65,
  );

  /// Standard body — chapter lists, metadata prose. 15 pt.
  static const bodyMedium = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
    height: 1.6,
  );

  /// Small body — secondary descriptions. 13 pt.
  static const bodySmall = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  /// Fine print — footnotes, metadata. 11 pt.
  static const caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  // ── Cards ──────────────────────────────────────────────────────────────────

  static const cardTitle    = labelXL;
  static const cardSubtitle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ── Sheet / Detail ─────────────────────────────────────────────────────────

  static const sheetTitle  = displayS;
  static const sheetAuthor = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ── Reader chrome ──────────────────────────────────────────────────────────

  static const readerChapterTitle = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const readerPagePill = TextStyle(
    fontFamily: sans,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 12, fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
