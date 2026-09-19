import 'package:flutter/cupertino.dart';
import 'package:isar/isar.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';
import '../../features/reader/open_reader.dart';
import 'cover_image.dart';
import 'sumi.dart';

/// One row of the Updates / History feeds.
typedef FeedItem = ({MangaEntry manga, ChapterEntry chapter});

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Today" / "Yesterday" / "Sep 17" / "Sep 17, 2025". Case follows the look
/// when rendered through [SumiOverline].
String dayLabel(DateTime day, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(DateTime(day.year, day.month, day.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final base = '${_months[day.month - 1]} ${day.day}';
  return day.year == today.year ? base : '$base, ${day.year}';
}

/// Splits [items] (already sorted newest-first by [stamp]) into consecutive
/// same-day runs.
List<(DateTime, List<T>)> groupByDay<T>(
    Iterable<T> items, DateTime Function(T) stamp) {
  final groups = <(DateTime, List<T>)>[];
  for (final item in items) {
    final s = stamp(item);
    final day = DateTime(s.year, s.month, s.day);
    if (groups.isEmpty || groups.last.$1 != day) groups.add((day, []));
    groups.last.$2.add(item);
  }
  return groups;
}

/// Opens [item] in the reader with its siblings loaded newest-first, the way
/// the detail screen and the Continue block do.
Future<void> openFeedItem(
    BuildContext context, Isar isar, FeedItem item) async {
  final chapters = await isar.chapterEntrys
      .filter()
      .mangaIdEqualTo(item.manga.id)
      .sortByNumberDesc()
      .findAll();
  if (!context.mounted) return;
  openReader(
    context,
    manga: item.manga,
    chapters: chapters,
    index: chapters.indexWhere((c) => c.id == item.chapter.id),
  );
}

/// Day-grouped feed sliver: an overline per day, then [ChapterFeedTile] rows.
class ChapterFeedList extends StatelessWidget {
  const ChapterFeedList({
    super.key,
    required this.items,
    required this.stamp,
    required this.meta,
    required this.onTap,
    this.onLongPress,
  });

  final List<FeedItem> items;
  final DateTime Function(FeedItem) stamp;
  final String Function(FeedItem) meta;
  final ValueChanged<FeedItem> onTap;
  final ValueChanged<FeedItem>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final gutter = context.yomiGutter;
    final rows = <Widget>[];
    for (final (day, list) in groupByDay(items, stamp)) {
      rows.add(Padding(
        padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 6),
        child: SumiOverline(dayLabel(day)),
      ));
      for (final item in list) {
        rows.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: SumiStagger(
            index: rows.length,
            child: ChapterFeedTile(
              item: item,
              meta: meta(item),
              onTap: () => onTap(item),
              onLongPress:
                  onLongPress == null ? null : () => onLongPress!(item),
            ),
          ),
        ));
      }
    }
    return SliverList.list(children: rows);
  }
}

/// Cover thumb 40×56 · manga title 14/700 · chapter title 12 · meta 11 ·
/// downloaded check · unread dot. Read rows sit at 55% like ChapterListTile.
class ChapterFeedTile extends StatelessWidget {
  const ChapterFeedTile({
    super.key,
    required this.item,
    required this.meta,
    required this.onTap,
    this.onLongPress,
  });

  final FeedItem item;
  final String meta;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final look = context.look;
    final (:manga, :chapter) = item;

    return Semantics(
      button: true,
      label: '${manga.title}, ${chapter.title}, $meta',
      child: SumiPress(
        onTap: onTap,
        onLongPress: onLongPress,
        scale: AppMotion.activeScale,
        child: Opacity(
          opacity: chapter.isRead ? 0.55 : 1.0,
          child: Container(
            padding: look.isPastel
                ? const EdgeInsets.all(12)
                : const EdgeInsets.symmetric(vertical: 10),
            margin: look.isPastel ? const EdgeInsets.only(bottom: 8) : null,
            decoration: BoxDecoration(
              color: look.isPastel ? c.card : null,
              border: look.isPastel
                  ? null
                  : Border(bottom: BorderSide(color: c.line)),
              borderRadius: look.isPastel ? BorderRadius.circular(20) : null,
              boxShadow: look.cardShadow,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 56,
                  child: SumiCoverFrame(
                    radius: look.isPastel ? 10 : null,
                    child: CoverImage(url: manga.coverUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        manga.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YomiText.ui(14,
                            weight: FontWeight.w700, color: c.fg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YomiText.ui(12, color: c.fg2),
                      ),
                      const SizedBox(height: 2),
                      Text(meta, style: YomiText.ui(11, color: c.fg2)),
                    ],
                  ),
                ),
                if (chapter.isDownloaded) ...[
                  const SizedBox(width: 10),
                  Semantics(
                    label: 'Downloaded',
                    child: Icon(CupertinoIcons.checkmark_alt,
                        size: 16, color: c.fg2),
                  ),
                ],
                const SizedBox(width: 10),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(look.isCinema ? 0 : 4),
                    color: chapter.isRead
                        ? const Color(0x00000000)
                        : (look.isPastel ? context.yomi.toggleOn : c.ac),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
