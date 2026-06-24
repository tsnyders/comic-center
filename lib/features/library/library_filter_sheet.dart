import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/library_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class LibraryFilterSheet extends ConsumerStatefulWidget {
  const LibraryFilterSheet({super.key});

  @override
  ConsumerState<LibraryFilterSheet> createState() =>
      _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends ConsumerState<LibraryFilterSheet> {
  static const _statuses = [
    ('All', null),
    ('Ongoing', 'ongoing'),
    ('Completed', 'completed'),
    ('Hiatus', 'hiatus'),
    ('Cancelled', 'cancelled'),
  ];

  late String? _status;
  late List<String> _genres;
  late List<String> _availableGenres;

  @override
  void initState() {
    super.initState();
    _status = ref.read(libraryStatusFilterProvider);
    _genres = List.from(ref.read(libraryGenreFilterProvider));
    _availableGenres = ref.read(libraryGenresProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: Border(
          top: BorderSide(
            color: context.borderColor,
            width: AppRadius.hairline,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.x5,
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.gutter,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.x6),
              decoration: BoxDecoration(
                color: context.borderStrongColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: context.textPrimaryColor,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _reset,
                child: Text(
                  'Reset',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x6),

          // Status section
          Text(
            'STATUS',
            style: AppTextStyles.overline.copyWith(
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Wrap(
            spacing: AppSpacing.x4,
            runSpacing: AppSpacing.x4,
            children: _statuses.map((s) {
              final isSelected = _status == s.$2;
              return _FilterChip(
                label: s.$1,
                selected: isSelected,
                onTap: () => setState(() => _status = s.$2),
              );
            }).toList(),
          ),

          if (_availableGenres.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x6),
            Text(
              'GENRES',
              style: AppTextStyles.overline.copyWith(
                color: context.textTertiaryColor,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.x4,
                  runSpacing: AppSpacing.x4,
                  children: _availableGenres.map((g) {
                    final isSelected = _genres.contains(g);
                    return _FilterChip(
                      label: g,
                      selected: isSelected,
                      onTap: () => setState(() {
                        if (isSelected) {
                          _genres.remove(g);
                        } else {
                          _genres.add(g);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.gutter),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: context.accentColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              onPressed: _apply,
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _apply() {
    ref.read(libraryStatusFilterProvider.notifier).state = _status;
    ref.read(libraryGenreFilterProvider.notifier).state =
        List.from(_genres);
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _status = null;
      _genres = [];
    });
    ref.read(libraryStatusFilterProvider.notifier).state = null;
    ref.read(libraryGenreFilterProvider.notifier).state = [];
    Navigator.of(context).pop();
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        transform: _pressed
            ? (Matrix4.identity()..scaleByDouble(0.96, 0.96, 1.0, 1.0))
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: widget.selected
              ? context.accentColor
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: widget.selected
                ? context.accentColor
                : context.borderStrongColor,
            width: AppRadius.hairline,
          ),
        ),
        child: Text(
          widget.label,
          style: AppTextStyles.bodySmall.copyWith(
            color: widget.selected
                ? AppColors.textOnAccent
                : context.textSecondaryColor,
            fontWeight:
                widget.selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
