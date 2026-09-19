import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/theme/yomi_theme.dart';

/// Small 12px `fg2` text action for section headers (refresh / sort / done).
class SumiTextAction extends StatelessWidget {
  const SumiTextAction({super.key, required this.label, required this.onTap});
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

/// One [CupertinoActionSheet] row: dismisses the sheet, then runs [onTap].
CupertinoActionSheetAction sheetAction(
  BuildContext sheetContext,
  String label,
  VoidCallback onTap, {
  bool destructive = false,
}) =>
    CupertinoActionSheetAction(
      isDestructiveAction: destructive,
      onPressed: () {
        Navigator.pop(sheetContext);
        onTap();
      },
      child: Text(label),
    );
