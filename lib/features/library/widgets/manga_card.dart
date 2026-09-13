import 'package:flutter/cupertino.dart';

import '../../../core/database/models/manga_entry.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/yomi_theme.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/sumi.dart';
import '../../../shared/widgets/unread_badge.dart';

/// Shared hero tag for a manga cover so it animates between the library grid
/// and the title detail plate. Same 4px radius and 2:3 aspect at both ends.
String mangaCoverHeroTag(int mangaId) => 'cover_$mangaId';

/// Shelf tile: 2:3 cover (`card` + 1px `line`, radius 4), kanji tag top-left
/// at 70%, unread badge top-right; name 12/700, author 11 `fg2` below.
class MangaCard extends StatelessWidget {
  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
    this.onLongPress,
  });

  final MangaEntry manga;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return SumiPress(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: AppMotion.activeScale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: mangaCoverHeroTag(manga.id),
                  child: SumiCoverFrame(child: CoverImage(url: manga.coverUrl)),
                ),
                if (context.look.kanji)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Text(
                      kanjiTag(manga.title),
                      style: YomiText.display(20,
                          color: c.fg.withValues(alpha: 0.7)),
                    ),
                  ),
                if (manga.unreadCount > 0)
                  Positioned(
                    left: context.look.isCinema ? 0 : null,
                    right: context.look.isCinema ? null : 6,
                    top: context.look.isCinema ? 0 : 6,
                    child: UnreadBadge(count: manga.unreadCount),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (context.look.isCinema)
            DisplayText(manga.title,
                size: 15,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                height: 1.1)
          else
            Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: YomiText.ui(12,
                  weight: FontWeight.w700, color: c.fg, height: 1.25),
            ),
          const SizedBox(height: 2),
          Text(
            (manga.author?.isNotEmpty ?? false)
                ? manga.author!
                : '${manga.chapterCount} chapters',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: YomiText.ui(11, color: c.fg2, height: 1.25),
          ),
        ],
      ),
    );
  }

  /// Extra height below the 2:3 cover: 8 + two 12px lines at 1.25 + 2 + one
  /// 11px line at 1.25.
  static const textBlockHeight = 8 + 30 + 2 + 14;
}
