import 'package:flutter/cupertino.dart';

import '../../core/theme/yomi_theme.dart';

/// Unread count. Sumi: 18px accent circle (the only solid accent fill on the
/// shelf). Cinema: accent tag "3 NEW". Pastel: `fg` pill in the display face.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final c = context.yc;
    final look = context.look;
    final text = count > 999 ? '999+' : count.toString();
    return switch (look.look) {
      YomiLook.sumi => Container(
          constraints: const BoxConstraints(minWidth: 18),
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.ac,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            text,
            style: YomiText.ui(10, weight: FontWeight.w700, color: c.onAccent)
                .copyWith(height: 1),
          ),
        ),
      YomiLook.cinema => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          color: c.ac,
          child: Text(
            '$text NEW',
            style: YomiText.display(11, color: c.onAccent, letterSpacing: 1)
                .copyWith(height: 1.1),
          ),
        ),
      YomiLook.pastel => Container(
          constraints: const BoxConstraints(minWidth: 24),
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.fg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: YomiText.display(13, color: c.bg).copyWith(height: 1),
          ),
        ),
    };
  }
}
