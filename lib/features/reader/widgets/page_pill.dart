import 'package:flutter/cupertino.dart';

import '../../../core/theme/yomi_theme.dart';

/// Floating "current / total" pill, shown briefly while the chrome is hidden.
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
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: YomiReader.buttonBorder),
          ),
          child: Text(
            '$current / $total',
            style: YomiText.ui(11, color: YomiReader.ink, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
