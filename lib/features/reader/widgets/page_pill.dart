import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Floating pill showing "current / total" that fades in during swipes.
class PagePill extends StatelessWidget {
  const PagePill({
    super.key,
    required this.current,
    required this.total,
    required this.visible,
  });

  final int current;
  final int total;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding + 90,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderStrong, width: 0.5),
                ),
                child: Text(
                  '$current / $total',
                  style: AppTextStyles.readerPagePill,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
