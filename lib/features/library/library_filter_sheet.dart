import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/library_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class LibraryFilterSheet extends ConsumerStatefulWidget {
  const LibraryFilterSheet({super.key});

  @override
  ConsumerState<LibraryFilterSheet> createState() => _LibraryFilterSheetState();
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
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter', style: AppTextStyles.sectionTitle),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _reset,
                child: Text(
                  'Reset',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status section
          Text('STATUS', style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
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
            const SizedBox(height: 16),
            Text('GENRES', style: AppTextStyles.labelSmall),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8, runSpacing: 8,
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

          const SizedBox(height: 20),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
              onPressed: _apply,
              child: const Text('Apply Filters',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _apply() {
    ref.read(libraryStatusFilterProvider.notifier).state = _status;
    ref.read(libraryGenreFilterProvider.notifier).state  = List.from(_genres);
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _status = null;
      _genres = [];
    });
    ref.read(libraryStatusFilterProvider.notifier).state = null;
    ref.read(libraryGenreFilterProvider.notifier).state  = [];
    Navigator.of(context).pop();
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool   selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderStrong,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? CupertinoColors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
