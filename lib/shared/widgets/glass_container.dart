import 'dart:ui';

import 'package:flutter/cupertino.dart';

/// Reusable liquid-glass panel — BackdropFilter blur + specular highlight +
/// semi-transparent fill, mirroring Apple's glass material aesthetic.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 28,
    this.tintOpacity = 0.18,
    this.borderOpacity = 0.22,
    this.shadowOpacity = 0.22,
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
    final r = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(shadowOpacity),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: width,
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: r,
              border: Border.all(color: border, width: 0.5),
            ),
            child: Stack(
              children: [
                // Specular highlight — white shimmer on the top edge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: borderRadius,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(borderRadius),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFFFFFF).withOpacity(0.12),
                          const Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
                if (child != null) child!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass card with shimmer animation and press-scale — used for featured
/// source cards.
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
                    .withOpacity(0.40),
                blurRadius: 28,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Animated diagonal shimmer
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (_, __) => Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1 + _shimmer.value * 2, -0.5),
                          end: Alignment(0 + _shimmer.value * 2, 0.5),
                          colors: const [
                            Color(0x00FFFFFF),
                            Color(0x22FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Specular highlight — top-edge glow
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFFFFFF).withOpacity(0.28),
                          const Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
                // Inner border
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0x40FFFFFF),
                        width: 0.75,
                      ),
                    ),
                  ),
                ),
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
