import 'dart:ui';

import 'package:flutter/cupertino.dart';

/// Reusable frosted-glass panel — BackdropFilter + semi-transparent fill.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 24,
    this.tintOpacity = 0.10,
    this.borderOpacity = 0.18,
    this.shadowOpacity = 0.18,
    this.tintColor,
  });

  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double tintOpacity;
  final double borderOpacity;
  final double shadowOpacity;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final fill = (tintColor ?? const Color(0xFFFFFFFF)).withOpacity(tintOpacity);
    final border = const Color(0xFFFFFFFF).withOpacity(borderOpacity);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(shadowOpacity),
            blurRadius: 30,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: width,
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: border, width: 0.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A glass panel with a subtle animated shimmer — used for featured cards.
class AnimatedGlassCard extends StatefulWidget {
  const AnimatedGlassCard({
    super.key,
    required this.child,
    required this.gradient,
    this.width = 260,
    this.height = 150,
    this.onTap,
  });

  final Widget child;
  final Gradient gradient;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: widget.gradient,
            boxShadow: [
              BoxShadow(
                color: (widget.gradient as LinearGradient).colors.first
                    .withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Animated shimmer overlay
              AnimatedBuilder(
                animation: _shimmer,
                builder: (_, __) => Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1 + _shimmer.value * 2, -0.5),
                          end: Alignment(0 + _shimmer.value * 2, 0.5),
                          colors: [
                            const Color(0x00FFFFFF),
                            const Color(0x18FFFFFF),
                            const Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Glass inner border
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0x30FFFFFF),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}
