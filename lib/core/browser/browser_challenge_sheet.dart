import 'package:flutter/cupertino.dart';

import '../../shared/widgets/sumi_actions.dart';
import '../theme/yomi_theme.dart';

/// Visible shell used while a site requires a human browser check.
class BrowserChallengeSheet extends StatelessWidget {
  const BrowserChallengeSheet({
    super.key,
    required this.child,
    required this.onCancel,
  });

  static const contentKey = Key('browser-challenge-content');

  final Widget child;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.yc;
    final height = MediaQuery.sizeOf(context).height * 0.9;
    return ColoredBox(
      color: colors.fg.withValues(alpha: 0.55),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            height: height,
            constraints: const BoxConstraints(maxWidth: 720),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(top: BorderSide(color: colors.line)),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(context.radii.card),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Site check',
                              style: YomiText.ui(
                                16,
                                weight: FontWeight.w700,
                                color: colors.fg,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Complete the check below to continue.',
                              style: YomiText.ui(12, color: colors.fg2),
                            ),
                          ],
                        ),
                      ),
                      SumiTextAction(label: 'Cancel', onTap: onCancel),
                    ],
                  ),
                ),
                Container(height: 1, color: colors.line),
                Expanded(
                  key: contentKey,
                  child: ColoredBox(
                    color: CupertinoColors.white,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
