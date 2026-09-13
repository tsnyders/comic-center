import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/yomi_theme.dart';

/// Always-visible 2px line at the very top of the reader (above the safe
/// area). Track `#222`, fill `ac`; width animates 300ms on page change.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.progress});

  /// 0.0 → 1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Container(color: ReaderPalette.of(context).track),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: AppMotion.snap,
            width: constraints.maxWidth * progress.clamp(0.0, 1.0),
            color: context.yc.ac,
          ),
        ],
      ),
    );
  }
}
