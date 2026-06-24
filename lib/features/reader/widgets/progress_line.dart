import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_colors.dart';

/// Always-visible 2px accent progress line pinned at the very top of the
/// reader canvas (above safe-area). Track = white@22%; fill = accent.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.progress});

  /// 0.0 → 1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          // Faint track — white at 22% so it reads on the black canvas.
          Container(color: const Color(0x38FFFFFF)),
          // Accent fill — no animation during drag (matches scrubber behaviour);
          // a short ease otherwise so it feels live.
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
