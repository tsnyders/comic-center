import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/library_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class CategoryChips extends ConsumerWidget {
  const CategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(libraryCategoriesProvider);
    final selected = ref.watch(selectedCategoryProvider);

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x4),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isActive = cat == selected;
          return _Chip(
            label: cat,
            isActive: isActive,
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = cat,
          );
        },
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        // Chip/segment select: standard curve, 140–220ms
        duration: const Duration(milliseconds: 180),
        transform: _pressed
            ? (Matrix4.identity()..scaleByDouble(0.96, 0.96, 1.0, 1.0))
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          // Selected = accent fill; unselected = surfaceElevated + hairline
          color: widget.isActive
              ? context.accentColor
              : context.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: widget.isActive
                ? context.accentColor
                : context.borderStrongColor,
            width: AppRadius.hairline,
          ),
        ),
        child: Text(
          widget.label,
          style: AppTextStyles.labelMedium.copyWith(
            color: widget.isActive
                ? CupertinoColors.white
                : context.textSecondaryColor,
            fontWeight:
                widget.isActive ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12.5,
            letterSpacing: -0.05,
          ),
        ),
      ),
    );
  }
}
