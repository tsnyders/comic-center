import 'package:flutter/cupertino.dart';

import '../../core/services/device_profile.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Solid surface container — replaces the previous backdrop-blur GlassContainer.
/// The [blur], [tintOpacity], [borderOpacity], and [shadowOpacity] parameters
/// are accepted but [blur] is ignored; depth is expressed via solid surfaces
/// and [AppElevation] shadows.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 28, // ignored — kept for API compatibility
    this.tintOpacity = 1.0,
    this.borderOpacity = 0.08,
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
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bg = tintColor ??
        (isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated);
    final r = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
          width: AppRadius.hairline,
        ),
        boxShadow: isDark ? AppElevation.e3 : AppElevation.e3Light,
      ),
      child: child,
    );
  }
}

/// Animated gradient card with a diagonal shimmer — used for featured source
/// cards in the Browse screen. The backdrop blur has been removed; the gradient
/// and shimmer remain intact for visual richness.
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
    );
    // The travelling sheen repaints the card every frame for as long as the
    // Browse tab is visible — skip it entirely on reduced-motion devices.
    if (!DeviceProfile.current.reducedMotion) {
      _ctrl.repeat(reverse: true);
    }
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
                color: (widget.gradient as LinearGradient)
                    .colors
                    .first
                    .withValues(alpha: 0.36),
                blurRadius: 28,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Diagonal shimmer — travels left to right
              if (!DeviceProfile.current.reducedMotion)
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (_, __) => Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment(-1 + _shimmer.value * 2, -0.5),
                          end: Alignment(0 + _shimmer.value * 2, 0.5),
                          colors: const [
                            Color(0x00FFFFFF),
                            Color(0x18FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Hairline inner border
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0x33FFFFFF),
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
    );
  }
}
