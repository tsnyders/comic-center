import 'package:flutter/cupertino.dart';

import '../../../core/extensions/source_interface.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class FeaturedSourceCard extends StatefulWidget {
  const FeaturedSourceCard({
    super.key,
    required this.source,
    required this.onTap,
    required this.gradient,
  });

  final MangaSource source;
  final VoidCallback onTap;
  final LinearGradient gradient;

  @override
  State<FeaturedSourceCard> createState() => _FeaturedSourceCardState();
}

class _FeaturedSourceCardState extends State<FeaturedSourceCard> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _onTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final shadows =
        context.isDark ? AppElevation.e2 : AppElevation.e2Light;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          width: 248,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: widget.gradient,
            boxShadow: shadows,
          ),
          child: Stack(
            children: [
              // Inner top-left white sheen overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x1AFFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),

              // Text content pinned to bottom
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      widget.source.name,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.source.language.toUpperCase()} · ${widget.source.baseUrl}',
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xB3FFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder card used when no real sources are installed yet.
class FeaturedSourcePlaceholderCard extends StatefulWidget {
  const FeaturedSourcePlaceholderCard({
    super.key,
    required this.name,
    required this.description,
    required this.gradient,
    this.onTap,
  });

  final String name;
  final String description;
  final LinearGradient gradient;
  final VoidCallback? onTap;

  @override
  State<FeaturedSourcePlaceholderCard> createState() =>
      _FeaturedSourcePlaceholderCardState();
}

class _FeaturedSourcePlaceholderCardState
    extends State<FeaturedSourcePlaceholderCard> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) setState(() => _pressed = false);
  }

  void _onTapCancel() {
    if (widget.onTap != null) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final shadows =
        context.isDark ? AppElevation.e2 : AppElevation.e2Light;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          width: 248,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: widget.gradient,
            boxShadow: shadows,
          ),
          child: Stack(
            children: [
              // Inner top-left white sheen overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x1AFFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),

              // Text content pinned to bottom
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      widget.name,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xB3FFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
