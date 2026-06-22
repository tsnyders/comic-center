import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/database/models/manga_entry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/unread_badge.dart';

/// Shared hero tag for a manga cover so it animates between the library grid
/// and the title detail screen.
String mangaCoverHeroTag(int mangaId) => 'cover_$mangaId';

class MangaCard extends StatelessWidget {
  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  final MangaEntry manga;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Slightly smaller typography for denser (3-column) grids.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final elevation =
        context.isDark ? AppElevation.e2 : AppElevation.e2Light;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.cover),
        boxShadow: elevation,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.cover),
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover art (hero-animated into the detail screen)
              Hero(
                tag: mangaCoverHeroTag(manga.id),
                child: CoverImage(url: manga.coverUrl),
              ),

              // Bottom protection gradient + metadata
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomOverlay(manga: manga, compact: compact),
              ),

              // Unread badge — top-right, 8px inset, using context.unreadColor
              if (manga.unreadCount > 0)
                Positioned(
                  top: AppSpacing.x4,
                  right: AppSpacing.x4,
                  child: UnreadBadge(count: manga.unreadCount),
                ),

              // Hairline border overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.cover),
                      border: Border.all(
                        color: context.borderColor,
                        width: AppRadius.hairline,
                      ),
                    ),
                  ),
                ),
              ),

              // Single gesture detector on top — handles tap, long-press, highlight.
              Positioned.fill(
                child: _TapHighlight(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
                  onLongPress: onLongPress == null
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          onLongPress!();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomOverlay extends StatelessWidget {
  const _BottomOverlay({required this.manga, this.compact = false});
  final MangaEntry manga;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        compact ? 26 : 30,
        10,
        compact ? 8 : 10,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          // rgba(0,0,0,.85) at bottom → transparent at top (~40% height)
          stops: [0.0, 0.55, 1.0],
          colors: [
            Color(0xD9000000),
            Color(0x66000000),
            Color(0x00000000),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            manga.title,
            style: compact
                ? AppTextStyles.cardTitle.copyWith(
                    fontSize: 12,
                    color: CupertinoColors.white,
                  )
                : AppTextStyles.cardTitle.copyWith(
                    color: CupertinoColors.white,
                  ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!compact) ...[
            const SizedBox(height: 2),
            Text(
              manga.lastReadChapterId != null
                  ? 'Ch. ${manga.lastReadChapterNumber?.toStringAsFixed(0) ?? "?"}'
                  : '${manga.chapterCount} chapters',
              style: AppTextStyles.cardSubtitle.copyWith(
                color: const Color(0xA6FFFFFF), // white @ 65%
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TapHighlight extends StatefulWidget {
  const _TapHighlight({required this.onTap, this.onLongPress});
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_TapHighlight> createState() => _TapHighlightState();
}

class _TapHighlightState extends State<_TapHighlight> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        // 80ms press dim overlay per spec
        duration: const Duration(milliseconds: 80),
        color: _pressed
            ? const Color(0x2E000000) // rgba(0,0,0,.18)
            : const Color(0x00000000),
      ),
    );
  }
}
