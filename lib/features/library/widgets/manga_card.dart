import 'package:flutter/cupertino.dart';

import '../../../core/database/models/manga_entry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/unread_badge.dart';

class MangaCard extends StatelessWidget {
  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
  });

  final MangaEntry manga;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover art
            CoverImage(url: manga.coverUrl),

            // Bottom gradient + metadata
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomOverlay(manga: manga),
            ),

            // Unread badge
            if (manga.unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: UnreadBadge(count: manga.unreadCount),
              ),

            // Single gesture detector on top — handles both tap and highlight.
            Positioned.fill(
              child: _TapHighlight(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomOverlay extends StatelessWidget {
  const _BottomOverlay({required this.manga});
  final MangaEntry manga;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 30, 10, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.heroGradientColors,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            manga.title,
            style: AppTextStyles.cardTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            manga.lastReadChapterId != null
                ? 'Ch. ${manga.lastReadChapterNumber?.toStringAsFixed(0) ?? "?"}'
                : '${manga.chapterCount} chapters',
            style: AppTextStyles.cardSubtitle,
          ),
        ],
      ),
    );
  }
}

class _TapHighlight extends StatefulWidget {
  const _TapHighlight({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_TapHighlight> createState() => _TapHighlightState();
}

class _TapHighlightState extends State<_TapHighlight> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed ? AppColors.textQuaternary : const Color(0x00000000),
      ),
    );
  }
}
