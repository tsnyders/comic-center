import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../../core/theme/app_colors.dart';

/// Cached cover art with shimmer placeholder and error fallback.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.headers,
  });

  final String? url;
  final BoxFit fit;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null || src.isEmpty) return const _Placeholder();

    // Cap the decoded bitmap width so scrolling a large catalog doesn't load
    // hundreds of full-resolution covers into the in-memory image cache.
    // 350 logical px covers every usage in this app (the widest is the
    // cinematic hero backdrop); the device pixel ratio keeps it crisp.
    final cacheWidth = (350 * MediaQuery.devicePixelRatioOf(context)).round();

    return CachedNetworkImage(
      imageUrl: src,
      httpHeaders: headers,
      fit: fit,
      memCacheWidth: cacheWidth,
      placeholder: (_, __) => const _ShimmerPlaceholder(),
      errorWidget: (_, __, ___) => const _Placeholder(),
    );
  }
}

class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder();

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              Color.lerp(AppColors.surface, AppColors.surfaceElevated, _anim.value)!,
              AppColors.surface,
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      child: const Center(
        child: Icon(
          CupertinoIcons.book_fill,
          color: AppColors.textTertiary,
          size: 28,
        ),
      ),
    );
  }
}
