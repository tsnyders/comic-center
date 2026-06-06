import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_colors.dart';

/// A 2pt accent line always pinned at the very top of the reader screen.
/// Intentionally non-intrusive — visible even when chrome is hidden.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.progress});

  /// 0.0 → 1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding,
      left: 0,
      right: 0,
      height: 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Track
              Container(color: AppColors.surfaceElevated),
              // Fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                color: AppColors.accent,
              ),
            ],
          );
        },
      ),
    );
  }
}
