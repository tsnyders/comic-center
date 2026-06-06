import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_colors.dart';

/// A 2pt accent line. Place it inside a `Positioned` in the reader Stack.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.progress});

  /// 0.0 → 1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Container(color: AppColors.surfaceElevated),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: constraints.maxWidth * progress.clamp(0.0, 1.0),
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}
