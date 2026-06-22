import 'package:flutter/cupertino.dart';

import '../../../core/extensions/source_interface.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

enum SourceRowAction { open, install, update }

class SourceRow extends StatefulWidget {
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
  State<SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<SourceRow> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) setState(() => _pressed = false);
  }

  void _onTapCancel() {
    if (widget.onTap != null) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ??
        const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    final row = GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.x4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x6,
          vertical: AppSpacing.x5,
        ),
        decoration: BoxDecoration(
          color: context.surfaceElevatedColor.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: context.borderColor,
            width: AppRadius.hairline,
          ),
        ),
        child: Row(
          children: [
            // Gradient avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                gradient: effectiveGradient,
                boxShadow: AppElevation.e1,
              ),
              alignment: Alignment.center,
              child: Text(
                widget.source.name[0].toUpperCase(),
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.x4),

            // Source info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.source.name,
                    style: AppTextStyles.sourceName.copyWith(
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _LanguageBadge(
                        language: widget.source.language.toUpperCase(),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Text(
                        'v${widget.source.version}',
                        style: AppTextStyles.sourceMeta.copyWith(
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Trailing action
            _ActionWidget(
              action: widget.action,
              onPressed: widget.onAction,
            ),
          ],
        ),
      ),
    );

    if (widget.onTap == null) return row;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: row,
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0x00000000),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: context.accentLineColor,
          width: AppRadius.hairline,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        language,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: context.accentColor,
          height: 1.0,
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
      SourceRowAction.open => Icon(
          CupertinoIcons.chevron_right,
          size: 16,
          color: context.textTertiaryColor,
        ),
      SourceRowAction.install => GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.accentSubtleColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: context.accentLineColor,
                width: AppRadius.hairline,
              ),
            ),
            child: Text(
              'Get',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.accentColor,
              ),
            ),
          ),
        ),
      SourceRowAction.update => GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.surfaceElevatedColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: context.borderStrongColor,
                width: AppRadius.hairline,
              ),
            ),
            child: Text(
              'Update',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
          ),
        ),
    };
  }
}
