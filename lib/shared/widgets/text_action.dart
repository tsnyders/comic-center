import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/theme/yomi_theme.dart';

/// Small 12px `fg2` text action for section headers ("Refresh", "Newest
/// first", "Update library"). Disabled when [onTap] is null.
class TextAction extends StatelessWidget {
  const TextAction({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(label, style: YomiText.ui(12, color: c.fg2)),
      ),
    );
  }
}
