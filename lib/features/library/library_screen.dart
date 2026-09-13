import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/lumen_page_route.dart';
import '../../shared/widgets/sumi.dart';
import '../reader/open_reader.dart';
import '../title_detail/title_detail_screen.dart';
import 'widgets/manga_card.dart';

/// ============================================================================
/// Library — "Your shelf"
///
/// Overline + brush title + seal → Continue block (hand-drawn progress
/// stroke) → filter chips → cover grid (columns from Cover size).
/// ============================================================================
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yc;
    final insets = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final gutter = context.yomiGutter;
    final gap = context.yomiGridGap;
    final cols = context.yomiGridColumns;

    final library = ref.watch(filteredLibraryProvider);
    final total = ref.watch(libraryStreamProvider).valueOrNull?.length ?? 0;
    final continueItems = ref.watch(continueReadingProvider);
    final filter = ref.watch(shelfFilterProvider);
    final categories =
        ref.watch(libraryCategoriesProvider).where((x) => x != 'All');

    // Tile = 2:3 cover + text block; grid aspect ratio derived from the
    // actual column width so the text never clips.
    final tileWidth = (width - gutter * 2 - gap * (cols - 1)) / cols;
    final tileHeight = tileWidth * 1.5 + MangaCard.textBlockHeight;

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: insets.top + 12)),

          // ── Header: overline + title, seal stamp ──────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SumiOverline(
                            context.look.copy.libraryKicker ?? 'LIBRARY',
                            kanji: '庫'),
                        DisplayText(context.look.copy.libraryTitle, size: 36),
                      ],
                    ),
                  ),
                  const LookMark(),
                ],
              ),
            ),
          ),

          // ── Continue block ────────────────────────────────────────────────
          if (continueItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 0),
                child: _ContinueBlock(
                  manga: continueItems.first,
                  onTap: () => _continue(context, ref, continueItems.first),
                ),
              ),
            ),

          // ── Filter chips ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 26),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  children: [
                    for (final f in [
                      ...ShelfFilter.builtIn,
                      ...categories
                    ]) ...[
                      SumiChip(
                        label: f == ShelfFilter.all ? 'All $total' : f,
                        active: filter == f,
                        onTap: () =>
                            ref.read(shelfFilterProvider.notifier).state = f,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Cover grid ────────────────────────────────────────────────────
          library.when(
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
            data: (mangas) => mangas.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: EmptyState(
                        icon: CupertinoIcons.book,
                        title: total == 0
                            ? 'Your shelf is empty'
                            : 'Nothing here yet',
                        message: total == 0
                            ? 'Discover sources to find titles and add them here.'
                            : 'No titles match this filter.',
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 0),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                        childAspectRatio: tileWidth / tileHeight,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => SumiStagger(
                          index: i,
                          child: MangaCard(
                            manga: mangas[i],
                            onTap: () => _openDetail(context, mangas[i]),
                            onLongPress: () =>
                                _showQuickActions(context, ref, mangas[i]),
                          ),
                        ),
                        childCount: mangas.length,
                      ),
                    ),
                  ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: insets.bottom + 120)),
        ],
      ),
    );
  }

  static void _openDetail(BuildContext context, MangaEntry manga) {
    Navigator.of(context, rootNavigator: true).push(
      LumenPageRoute(builder: (_) => TitleDetailScreen(manga: manga)),
    );
  }

  /// Continue block → Reader at the last read chapter and page.
  static Future<void> _continue(
      BuildContext context, WidgetRef ref, MangaEntry manga) async {
    final isar = ref.read(isarProvider);
    final chapters = await isar.chapterEntrys
        .filter()
        .mangaIdEqualTo(manga.id)
        .sortByNumberDesc()
        .findAll();
    if (!context.mounted) return;
    if (chapters.isEmpty) return _openDetail(context, manga);
    var index = chapters.indexWhere(
        (ChapterEntry ch) => ch.sourceChapterId == manga.lastReadChapterId);
    if (index < 0) {
      index = chapters.indexWhere((ch) => ch.isRead || ch.lastPageRead > 0);
    }
    if (index < 0) index = chapters.length - 1;
    openReader(context, manga: manga, chapters: chapters, index: index);
  }

  static void _showQuickActions(
      BuildContext context, WidgetRef ref, MangaEntry manga) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(manga.title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openDetail(context, manga);
            },
            child: const Text('Open'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              HapticFeedback.selectionClick();
              ref
                  .read(libraryNotifierProvider.notifier)
                  .markAllChaptersRead(manga.id);
              Navigator.pop(sheetContext);
            },
            child: const Text('Mark all as read'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref
                  .read(libraryNotifierProvider.notifier)
                  .removeFromLibrary(manga.id);
              Navigator.pop(sheetContext);
            },
            child: const Text('Remove from library'),
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

// ── Continue block ────────────────────────────────────────────────────────────

/// Cover 96×140 · right column bottom-aligned: 続 · CONTINUE, brush title,
/// meta, hand-drawn progress stroke.
class _ContinueBlock extends StatelessWidget {
  const _ContinueBlock({required this.manga, required this.onTap});
  final MangaEntry manga;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final ch = manga.lastReadChapterNumber;
    final total = manga.chapterCount;
    final progress =
        (ch != null && total > 0) ? (ch / total).clamp(0.0, 1.0) : 0.0;
    final chLabel = ch == null ? null : _num(ch);
    final meta = chLabel == null
        ? '$total chapters'
        : total > 0
            ? 'Ch. $chLabel of $total'
            : 'Ch. $chLabel';

    final look = context.look;
    final pastel = look.isPastel;
    final ink = pastel ? look.onAccent : c.fg;
    final ink2 = pastel ? look.onAccent.withValues(alpha: 0.7) : c.fg2;

    final coverHeight = pastel ? 120.0 : 140.0;

    Widget cover = SizedBox(
      width: pastel ? 84 : 96,
      height: coverHeight,
      child: SumiCoverFrame(
        radius: pastel ? 16 : null,
        shadow: pastel,
        child: CoverImage(url: manga.coverUrl),
      ),
    );
    if (pastel && !reduceMotion(context)) {
      // Sticker tilt, −3°.
      cover = Transform.rotate(angle: -3 * 3.14159265 / 180, child: cover);
    }

    // The sliver gives this block unbounded height; `stretch` would hand every
    // child a tight infinite height (blank shelf in release, assert in debug).
    // The cover defines the block height — bound the row to it.
    Widget row = SizedBox(
      height: coverHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cover,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  pastel ? MainAxisAlignment.center : MainAxisAlignment.end,
              children: [
                SumiOverline('CONTINUE',
                    kanji: '続', color: pastel ? ink2 : c.ac),
                const SizedBox(height: 6),
                DisplayText(manga.title,
                    size: look.isCinema ? 34 : 26,
                    color: ink,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(meta, style: YomiText.ui(13, color: ink2)),
                const SizedBox(height: 14),
                LookProgress(progress: progress, onAccent: pastel),
              ],
            ),
          ),
        ],
      ),
    );
    if (pastel) {
      row = Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.ac,
          borderRadius: BorderRadius.circular(context.radii.card),
        ),
        child: row,
      );
    }

    return Semantics(
      button: true,
      label: 'Continue ${manga.title}, $meta',
      child: SumiPress(onTap: onTap, scale: AppMotion.activeScale, child: row),
    );
  }

  static String _num(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();
}
