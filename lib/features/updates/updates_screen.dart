import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/library_update_provider.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/chapter_feed_tile.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_update_action.dart';
import '../../shared/widgets/sumi.dart';

/// When a chapter "arrived": its fetch time, or the upload date for rows from
/// before [ChapterEntry.dateFetched] existed.
DateTime? updateStamp(ChapterEntry c) => c.dateFetched ?? c.uploadDate;

/// Chapters that arrived for shelf titles after they were added, newest
/// first. The "after added" cut keeps a freshly saved title's whole backlog
/// out of the feed (Tachiyomi's rule).
final updatesFeedProvider = StreamProvider.autoDispose<List<FeedItem>>((ref) {
  final isar = ref.watch(isarProvider);
  final mangas =
      ref.watch(libraryStreamProvider).valueOrNull ?? const <MangaEntry>[];
  if (mangas.isEmpty) return Stream.value(const []);
  final byId = {for (final m in mangas) m.id: m};
  return isar.chapterEntrys
      .filter()
      .anyOf(byId.keys, (q, int id) => q.mangaIdEqualTo(id))
      .watch(fireImmediately: true)
      .map((chapters) {
    final items = <FeedItem>[];
    for (final chapter in chapters) {
      final manga = byId[chapter.mangaId]!;
      final stamp = updateStamp(chapter);
      final added = manga.addedToLibrary;
      if (stamp == null || (added != null && !stamp.isAfter(added))) continue;
      items.add((manga: manga, chapter: chapter));
    }
    items.sort((a, b) {
      final byStamp =
          updateStamp(b.chapter)!.compareTo(updateStamp(a.chapter)!);
      if (byStamp != 0) return byStamp;
      return (b.chapter.number ?? 0).compareTo(a.chapter.number ?? 0);
    });
    // ponytail: every shelf chapter is loaded per change; page the query if
    // shelves pass a few thousand rows.
    return items.take(300).toList();
  });
});

/// ============================================================================
/// Updates — "New chapters"
///
/// Overline + brush title + Update library action → pull-to-refresh → feed
/// grouped by day. Long-press: Mark as read · Download.
/// ============================================================================
class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yc;
    final insets = MediaQuery.paddingOf(context);
    final gutter = context.yomiGutter;
    final feed = ref.watch(updatesFeedProvider);

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: insets.top + 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SumiOverline('UPDATES', kanji: '新'),
                        DisplayText('New chapters', size: 36),
                      ],
                    ),
                  ),
                  LibraryUpdateAction(),
                ],
              ),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () => ref.read(libraryUpdateProvider.notifier).run(),
          ),
          feed.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 64),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 48, gutter, 0),
                child: Text(e.toString(),
                    textAlign: TextAlign.center,
                    style: YomiText.ui(13, color: c.fg2)),
              ),
            ),
            data: (items) => items.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: EmptyState(
                        icon: CupertinoIcons.bell,
                        title: 'No new chapters',
                        message:
                            'Chapters that arrive for titles on your shelf show up here.',
                        actionLabel: 'Update library',
                        onAction: () =>
                            ref.read(libraryUpdateProvider.notifier).run(),
                      ),
                    ),
                  )
                : ChapterFeedList(
                    items: items,
                    stamp: (i) => updateStamp(i.chapter)!,
                    meta: _meta,
                    onTap: (i) =>
                        openFeedItem(context, ref.read(isarProvider), i),
                    onLongPress: (i) => _showActions(context, ref, i),
                  ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: insets.bottom + 120)),
        ],
      ),
    );
  }

  static String _meta(FeedItem i) {
    final ch = i.chapter;
    return [
      if (ch.number != null) 'Ch. ${chapterMark(ch.number!)}',
      ch.isRead ? 'Read' : 'Unread',
    ].join(' · ');
  }

  static void _showActions(BuildContext context, WidgetRef ref, FeedItem i) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(i.manga.title),
        message: Text(i.chapter.title),
        actions: [
          if (!i.chapter.isRead)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                ref.read(libraryNotifierProvider.notifier).markChapterRead(
                      mangaId: i.manga.id,
                      chapterId: i.chapter.id,
                      lastPage: i.chapter.lastPageRead,
                    );
              },
              child: const Text('Mark as read'),
            ),
          if (!i.chapter.isDownloaded)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                ref
                    .read(downloadManagerProvider.notifier)
                    .enqueue(manga: i.manga, chapter: i.chapter);
              },
              child: const Text('Download'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
