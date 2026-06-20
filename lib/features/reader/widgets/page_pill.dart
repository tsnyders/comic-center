import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_glass.dart';

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
        child: AppGlass(
          borderRadius: 14,
          blur: 20,
          tint: const Color(0xB3000000),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            '$current / $total',
            style: AppTextStyles.readerPagePill,
          ),
        ),
      ),
    );
  }
}
