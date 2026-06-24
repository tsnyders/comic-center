import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../core/theme/app_colors.dart';

/// A [BackdropFilter] blur container styled for the Immersive Dark theme.
class FrostedContainer extends StatelessWidget {
  const FrostedContainer({
    super.key,
    required this.child,
    this.blurStrength = 20.0,
    this.backgroundColor = const Color(0x70151417),
    this.borderRadius,
    this.border,
    this.padding,
  });

  final Widget child;
  final double blurStrength;
  final Color backgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border: border ??
                Border.all(color: AppColors.border, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
