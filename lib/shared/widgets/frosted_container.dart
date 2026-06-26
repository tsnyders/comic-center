import 'package:flutter/cupertino.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Solid elevated surface container — replaces the previous BackdropFilter
/// frosted-glass implementation. The API is unchanged so call sites compile
/// without modification. [blurStrength] is accepted but ignored.
class FrostedContainer extends StatelessWidget {
  const FrostedContainer({
    super.key,
    required this.child,
    this.blurStrength = 20.0,  // ignored — kept for API compatibility
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.padding,
  });

  final Widget child;
  final double blurStrength;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bg = backgroundColor ??
        (isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        border: border ??
            Border.all(
              color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
              width: AppRadius.hairline,
            ),
        boxShadow: isDark ? AppElevation.e2 : AppElevation.e2Light,
      ),
      child: child,
    );
  }
}
