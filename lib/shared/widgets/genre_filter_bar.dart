import 'package:flutter/cupertino.dart';

import 'sumi.dart';

/// The same genre choices are used on the shelf and in source catalogs.
class GenreFilterBar extends StatelessWidget {
  const GenreFilterBar({
    super.key,
    required this.genres,
    required this.selected,
    required this.onSelected,
    this.horizontalPadding = 16,
  });

  /// Keys are stable filter values; values are their display names.
  final Map<String, String> genres;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: const SumiOverline('GENRES'),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: [
              SumiChip(
                label: 'All genres',
                active: selected == null,
                onTap: () => onSelected(null),
              ),
              for (final genre in genres.entries) ...[
                const SizedBox(width: 8),
                SumiChip(
                  label: genre.value,
                  active: selected == genre.key,
                  onTap: () => onSelected(genre.key),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
