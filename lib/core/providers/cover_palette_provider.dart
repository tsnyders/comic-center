import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../theme/app_colors.dart';

/// LUMEN "let art decide" — extracts a vivid accent colour from a cover image,
/// used to tint the detail hero ambient and drive per-title accents. Falls back
/// to the iris signal when extraction fails or the URL is empty. Riverpod caches
/// the result per cover URL so it only runs once per title.
final coverPaletteProvider =
    FutureProvider.family<Color, String>((ref, url) async {
  if (url.isEmpty) return AppColors.accent;
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(url),
      size: const Size(120, 180),
      maximumColorCount: 12,
    );
    final c = palette.vibrantColor?.color ??
        palette.lightVibrantColor?.color ??
        palette.dominantColor?.color;
    if (c == null) return AppColors.accent;
    return _readableOnInk(c);
  } catch (_) {
    return AppColors.accent;
  }
});

/// Nudge a dark or washed-out extracted colour toward something that reads as
/// an accent on the ink canvas — raise saturation and clamp lightness.
Color _readableOnInk(Color c) {
  final hsl = HSLColor.fromColor(c);
  final s = hsl.saturation < 0.35 ? 0.5 : hsl.saturation;
  final l = hsl.lightness.clamp(0.46, 0.72).toDouble();
  return hsl.withSaturation(s).withLightness(l).toColor();
}
