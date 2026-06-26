import 'package:flutter/cupertino.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Solid elevated surface — replaces the previous glass/blur implementation.
///
/// The API is intentionally identical to the old AppGlass so existing call
/// sites compile without modification. The [blur] and [sheen] parameters are
/// accepted but silently ignored — depth is now expressed through color steps
/// and [AppElevation] shadows, not backdrop blur.
///
/// Behaviour:
///   • [tint] overrides the background color. Pass a semi-transparent dark
///     color (e.g. `Color(0xB3000000)`) for reader overlays that float over
///     the comic canvas.
///   • [borderRadius] defaults to [AppRadius.md] (16). Pass 0 for full-bleed
///     bars (reader chrome), or [AppRadius.pill] for pills.
///   • A hairline border is drawn when borderRadius > 0, using [AppColors.borderSubtle].
class AppGlass extends StatelessWidget {
  const AppGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur,    // ignored — kept for API compatibility
    this.padding,
    this.tint,
    this.sheen,   // ignored — kept for API compatibility
  });

  final Widget child;
  final double? borderRadius;
  final double? blur;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool? sheen;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final r = borderRadius ?? AppRadius.md;
    final bg = tint ?? (isDark ? AppColors.surface : AppColors.lightSurface);
    final showBorder = r > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: showBorder ? BorderRadius.circular(r) : null,
        border: showBorder
            ? Border.all(
                color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
                width: AppRadius.hairline,
              )
            : null,
        boxShadow: isDark ? AppElevation.e2 : AppElevation.e2Light,
      ),
      child: padding != null
          ? Padding(padding: padding!, child: child)
          : child,
    );
  }
}
