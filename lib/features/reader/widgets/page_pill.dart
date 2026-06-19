import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_text_styles.dart';
import 'liquid_glass.dart';

/// Floating pill showing "current / total". Place inside a `Positioned`
/// in the reader Stack (bottom-center, above the tab bar clearance).
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
        child: LiquidGlass(
          borderRadius: 16,
          blur: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(
            '$current / $total',
            style: AppTextStyles.readerPagePill,
          ),
        ),
      ),
    );
  }
}
