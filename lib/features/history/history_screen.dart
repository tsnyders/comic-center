import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/providers/database_provider.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/chapter_feed_tile.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/sumi.dart';
import '../../shared/widgets/sumi_actions.dart';

/// Chapters with a read timestamp, newest first, joined to their title.
final historyFeedProvider = StreamProvider.autoDispose<List<FeedItem>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.chapterEntrys
      .filter()
      .readAtIsNotNull()
      .sortByReadAtDesc()
      .limit(300)
      .watch(fireImmediately: true)
      .asyncMap((chapters) async {
    final mangas = await isar.mangaEntrys
        .getAll(chapters.map((c) => c.mangaId).toSet().toList());
    final byId = {for (final m in mangas) if (m != null) m.id: m};
    return [
      for (final c in chapters)
        if (byId[c.mangaId] case final m?) (manga: m, chapter: c),
    ];
  });
});

/// ============================================================================
/// History — "Recently read"
///
/// Overline + brush title + Clear history (confirmed) → feed grouped by day.
/// Tap resumes in the reader; long-press: Remove from history.
/// ============================================================================
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yc;
    final insets = MediaQuery.paddingOf(context);
    final gutter = context.yomiGutter;
    final feed = ref.watch(historyFeedProvider);
    final hasHistory = feed.valueOrNull?.isNotEmpty ?? false;

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: insets.top + 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SumiOverline('HISTORY', kanji: '歴'),
                        DisplayText('Recently read', size: 36),
                      ],
                    ),
                  ),
                  SumiTextAction(
                    label: 'Clear history',
                    onTap:
                        hasHistory ? () => _confirmClear(context, ref) : null,
                  ),
                ],
              ),
            ),
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
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: EmptyState(
                        icon: CupertinoIcons.clock,
                        title: 'Nothing read yet',
                        message: 'Chapters you finish show up here.',
                      ),
                    ),
                  )
                : ChapterFeedList(
                    items: items,
                    stamp: (i) => i.chapter.readAt!,
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
    final at = ch.readAt!;
    return [
      if (ch.number != null) 'Ch. ${chapterMark(ch.number!)}',
      ch.isRead ? 'Read' : 'Page ${ch.lastPageRead + 1}',
      '${at.hour}:${at.minute.toString().padLeft(2, '0')}',
    ].join(' · ');
  }

  /// Clears [readAt] on one chapter, or on every chapter when [chapterId] is
  /// null. Read status and page progress are untouched.
  static Future<void> _forget(Isar isar, {int? chapterId}) =>
      isar.writeTxn(() async {
        final chapters = chapterId == null
            ? await isar.chapterEntrys.filter().readAtIsNotNull().findAll()
            : await isar.chapterEntrys.filter().idEqualTo(chapterId).findAll();
        for (final c in chapters) {
          c.readAt = null;
        }
        await isar.chapterEntrys.putAll(chapters);
      });

  static Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
            'Read timestamps are removed. Read status and progress stay.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _forget(ref.read(isarProvider));
  }

  static void _showActions(BuildContext context, WidgetRef ref, FeedItem i) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(i.manga.title),
        message: Text(i.chapter.title),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(sheetContext);
              _forget(ref.read(isarProvider), chapterId: i.chapter.id);
            },
            child: const Text('Remove from history'),
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
