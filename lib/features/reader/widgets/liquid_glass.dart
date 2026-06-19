import 'dart:ui';

import 'package:flutter/cupertino.dart';

/// A translucent "liquid glass" surface: a light, glossy pane that lets the
/// content behind it bleed through, with a specular top-light sheen and a
/// hairline rim highlight. Replaces the old heavy frosted-black panels.
///
/// Unlike a flat frosted panel, the fill is a diagonal gradient that fades
/// from a bright highlight in the top-left to a faint tint in the
/// bottom-right, which reads as a curved glass surface catching light.
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
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CupertinoColors.white.withOpacity(0.22),
                CupertinoColors.white.withOpacity(0.06),
                tint,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: CupertinoColors.white.withOpacity(0.28),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x33000000),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // Specular top-edge highlight sitting above the gradient fill.
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: borderRadius,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(borderRadius),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CupertinoColors.white.withOpacity(0.30),
                        CupertinoColors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
