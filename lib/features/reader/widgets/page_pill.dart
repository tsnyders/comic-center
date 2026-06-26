import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_text_styles.dart';

/// Floating pill showing "current / total" in the LUMEN mono voice. Visible
/// only when the chrome is hidden. Solid ink pill — no glass.
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xCC0A0A0D),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x1FFFFFFF), width: 0.75),
          ),
          child: Text(
            '$current / $total',
            style: AppTextStyles.metaMono.copyWith(
              color: const Color(0xFFF3F0E9),
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
