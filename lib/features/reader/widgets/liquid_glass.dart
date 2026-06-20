import 'package:flutter/cupertino.dart';

import '../../../shared/widgets/app_glass.dart';

/// Backwards-compatible wrapper kept for the reader's floating next/back
/// buttons. It now delegates to [AppGlass] so these surfaces follow the
/// app-wide frosty/liquid theme toggle instead of being frosty-only.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.blur = 26,
    this.padding,
    this.tint = const Color(0x40000000),
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;

  /// Base colour mixed under the glass to keep light content legible.
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AppGlass(
      borderRadius: borderRadius,
      blur: blur,
      padding: padding,
      tint: tint,
      child: child,
    );
  }
}
