import 'package:flutter/cupertino.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.unread.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.textQuaternary, width: 0.5),
      ),
      child: Text(
        count > 999 ? '999+' : count.toString(),
        style: AppTextStyles.caption.copyWith(
          color: CupertinoColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
