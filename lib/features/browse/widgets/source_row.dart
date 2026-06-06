import 'package:flutter/cupertino.dart';

import '../../../core/extensions/source_interface.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum SourceRowAction { open, install, update }

class SourceRow extends StatelessWidget {
  const SourceRow({
    super.key,
    required this.source,
    required this.action,
    this.onTap,
    this.onAction,
    this.gradient,
  });

  final MangaSource source;
  final SourceRowAction action;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: gradient ??
                    const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
              ),
              child: Center(
                child: Text(
                  source.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.name, style: AppTextStyles.sourceName),
                  const SizedBox(height: 2),
                  Text(
                    'v${source.version} · ${source.language.toUpperCase()}',
                    style: AppTextStyles.sourceMeta,
                  ),
                ],
              ),
            ),

            // Action
            _ActionWidget(action: action, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}

class _ActionWidget extends StatelessWidget {
  const _ActionWidget({required this.action, this.onPressed});
  final SourceRowAction action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return switch (action) {
      SourceRowAction.open => const Icon(
          CupertinoIcons.chevron_right,
          size: 16,
          color: AppColors.textTertiary,
        ),
      SourceRowAction.install || SourceRowAction.update => GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.accent.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              action == SourceRowAction.install ? 'Get' : 'Update',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
    };
  }
}
