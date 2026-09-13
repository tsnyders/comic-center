import 'package:flutter/cupertino.dart';

import '../../core/theme/yomi_theme.dart';

/// Unread count — circle min 18px, `ac` fill, white 10/700. The only solid
/// accent fill on the shelf.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final c = context.yc;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.ac,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 999 ? '999+' : count.toString(),
        style: YomiText.ui(10, weight: FontWeight.w700, color: c.onAccent)
            .copyWith(height: 1),
      ),
    );
  }
}
