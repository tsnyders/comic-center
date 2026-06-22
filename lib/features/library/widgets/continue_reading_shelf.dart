import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/manga_entry.dart';
import '../../../core/providers/library_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/manga_card.dart';

/// A horizontal strip of the most recently read titles, shown at the top of
/// the library so users can jump straight back into what they were reading.
class ContinueReadingShelf extends ConsumerWidget {
  const ContinueReadingShelf({super.key, required this.onOpen});

  final void Function(MangaEntry manga) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(continueReadingProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    // 84px wide compact cards with 2:3 aspect = 126px tall
    const cardWidth = 84.0;
    const cardHeight = cardWidth * 3 / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.x4,
          ),
          child: Text(
            'CONTINUE READING',
            style: AppTextStyles.overline.copyWith(
              color: context.textTertiaryColor,
            ),
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.x5),
            itemBuilder: (context, i) => SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: MangaCard(
                manga: items[i],
                compact: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onOpen(items[i]);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x5 + AppSpacing.x3), // 18
      ],
    );
  }
}
