import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/manga_entry.dart';
import '../../../core/providers/library_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/cover_image.dart';

/// A horizontal strip of the most recently read titles, shown at the top of
/// the library so users can jump straight back into what they were reading.
class ContinueReadingShelf extends ConsumerWidget {
  const ContinueReadingShelf({super.key, required this.onOpen});

  final void Function(MangaEntry manga) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(continueReadingProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            'CONTINUE READING',
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.5),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _ShelfCard(
              manga: items[i],
              onTap: () {
                HapticFeedback.selectionClick();
                onOpen(items[i]);
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.manga, required this.onTap});
  final MangaEntry manga;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  SizedBox(
                    width: 92,
                    height: 122,
                    child: CoverImage(url: manga.coverUrl),
                  ),
                  // Play affordance
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.92),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        size: 13,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              manga.lastReadChapterNumber != null
                  ? 'Ch. ${manga.lastReadChapterNumber!.toStringAsFixed(0)}'
                  : manga.title,
              style: AppTextStyles.caption.copyWith(
                color: context.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
