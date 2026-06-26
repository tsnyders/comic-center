import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Solid dark surface — replaces the previous liquid-glass floating button
/// container in the reader. The blur/tint parameters are accepted for API
/// compatibility but blur is ignored. The solid dark surface keeps reader
/// button clusters legible against any comic page background.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.blur = 26,       // ignored — kept for API compatibility
    this.padding,
    this.tint = const Color(0xB3000000),
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: AppRadius.hairline,
        ),
        boxShadow: AppElevation.e3,
      ),
      child: padding != null
          ? Padding(padding: padding!, child: child)
          : child,
    );
  }
}
