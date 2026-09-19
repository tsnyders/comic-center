import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/category_sheet.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/genre_filter_bar.dart';
import '../../shared/widgets/library_update_action.dart';
import '../../shared/widgets/lumen_page_route.dart';
import '../../shared/widgets/sumi.dart';
import '../../shared/widgets/sumi_actions.dart';
import '../../shared/widgets/unread_badge.dart';
import '../reader/open_reader.dart';
import '../title_detail/title_detail_screen.dart';
import 'widgets/manga_card.dart';

/// Manga ids picked in shelf selection mode; null when not selecting.
final _selectionProvider = StateProvider<Set<int>?>((_) => null);

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
    final genre = ref.watch(libraryGenreProvider);
    final genres = ref.watch(libraryGenresProvider);
    final categories =
        ref.watch(libraryCategoriesProvider).where((x) => x != 'All');
    final sort = ref.watch(librarySortProvider);
    final ascending = ref.watch(librarySortAscendingProvider);
    final displayMode = ref.watch(libraryDisplayProvider);
    final selected = ref.watch(_selectionProvider);
    final downloaded =
        ref.watch(downloadedMangaIdsProvider).valueOrNull ?? const <int>{};

    // Tile = 2:3 cover + text block; grid aspect ratio derived from the
    // actual column width so the text never clips.
    final tileWidth = (width - gutter * 2 - gap * (cols - 1)) / cols;
    final tileHeight = tileWidth * 1.5 + MangaCard.textBlockHeight;

    void toggle(int id) {
      final s = {...?selected};
      s.contains(id) ? s.remove(id) : s.add(id);
      ref.read(_selectionProvider.notifier).state = s;
    }

    Widget tile(MangaEntry m, int i) {
      final onTap = selected != null
          ? () => toggle(m.id)
          : () => _openDetail(context, m);
      final onLongPress = selected != null
          ? () => toggle(m.id)
          : () => _showQuickActions(context, ref, m);
      return SumiStagger(
        index: i,
        child: displayMode == LibraryDisplay.grid
            ? MangaCard(
                manga: m,
                downloaded: downloaded.contains(m.id),
                selected: selected?.contains(m.id),
                onTap: onTap,
                onLongPress: onLongPress,
              )
            : _MangaListRow(
                manga: m,
                downloaded: downloaded.contains(m.id),
                selected: selected?.contains(m.id),
                onTap: onTap,
                onLongPress: onLongPress,
              ),
      );
    }

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
                  const LibraryUpdateAction(),
                  const SizedBox(width: 14),
                  const LookMark(),
                ],
              ),
            ),
          ),

          // ── Sort / display row (selection actions while selecting) ───────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
              child: Row(
                children: selected != null
                    ? [
                        Text('${selected.length} selected',
                            style: YomiText.ui(12, color: c.fg2)),
                        const Spacer(),
                        SumiTextAction(
                          label: 'Actions',
                          onTap: selected.isEmpty
                              ? null
                              : () => _showBulkActions(context, ref,
                                  library.valueOrNull ?? const [], selected),
                        ),
                        const SizedBox(width: 14),
                        SumiTextAction(
                          label: 'Done',
                          onTap: () =>
                              ref.read(_selectionProvider.notifier).state = null,
                        ),
                      ]
                    : [
                        SumiTextAction(
                          label: '${sort.label} ${ascending ? '↑' : '↓'}',
                          onTap: () => _showSortSheet(context, ref),
                        ),
                        const Spacer(),
                        SumiTextAction(
                          label: displayMode == LibraryDisplay.grid
                              ? 'List'
                              : 'Grid',
                          onTap: () => ref
                                  .read(libraryDisplayProvider.notifier)
                                  .state =
                              displayMode == LibraryDisplay.grid
                                  ? LibraryDisplay.list
                                  : LibraryDisplay.grid,
                        ),
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
          if (genres.isNotEmpty || genre != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: GenreFilterBar(
                  genres: {for (final value in genres) value: value},
                  selected: genre,
                  horizontalPadding: gutter,
                  onSelected: (value) =>
                      ref.read(libraryGenreProvider.notifier).state = value,
                ),
              ),
            ),

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
                    sliver: displayMode == LibraryDisplay.grid
                        ? SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: gap,
                              mainAxisSpacing: gap,
                              childAspectRatio: tileWidth / tileHeight,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => tile(mangas[i], i),
                              childCount: mangas.length,
                            ),
                          )
                        : SliverList.builder(
                            itemCount: mangas.length,
                            itemBuilder: (context, i) => tile(mangas[i], i),
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
            onPressed: () {
              ref.read(_selectionProvider.notifier).state = {manga.id};
              Navigator.pop(sheetContext);
            },
            child: const Text('Select'),
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

  static void _showSortSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(librarySortProvider);
    final ascending = ref.read(librarySortAscendingProvider);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: const Text('Sort library'),
        actions: [
          for (final s in LibrarySort.values)
            sheetAction(
              sheet,
              s == current ? '${s.label} ${ascending ? '↑' : '↓'}' : s.label,
              () {
                // Re-picking the active sort flips its direction.
                ref.read(librarySortAscendingProvider.notifier).state =
                    s == current ? !ascending : s.defaultAscending;
                ref.read(librarySortProvider.notifier).state = s;
              },
            ),
        ],
        cancelButton: sheetAction(sheet, 'Cancel', () {}),
      ),
    );
  }

  static void _showBulkActions(BuildContext context, WidgetRef ref,
      List<MangaEntry> shelf, Set<int> ids) {
    final picked = shelf.where((m) => ids.contains(m.id)).toList();
    final lib = ref.read(libraryNotifierProvider.notifier);
    void done() => ref.read(_selectionProvider.notifier).state = null;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text('${picked.length} titles'),
        actions: [
          sheetAction(sheet, 'Set categories', () {
            showCategorySheet(
              context,
              allCategories: ref
                  .read(libraryCategoriesProvider)
                  .where((x) => x != 'All')
                  .toList(),
              initial: const [],
              onSave: (cats) async {
                for (final m in picked) {
                  await lib.updateCategories(m.id, cats);
                }
                done();
              },
            );
          }),
          sheetAction(sheet, 'Mark all read', () {
            for (final m in picked) {
              lib.markAllChaptersRead(m.id);
            }
            done();
          }),
          sheetAction(sheet, 'Download unread', () async {
            final isar = ref.read(isarProvider);
            final dl = ref.read(downloadManagerProvider.notifier);
            for (final m in picked) {
              final chs = await isar.chapterEntrys
                  .filter()
                  .mangaIdEqualTo(m.id)
                  .isReadEqualTo(false)
                  .isDownloadedEqualTo(false)
                  .findAll();
              await dl.enqueueAll(manga: m, chapters: chs);
            }
            done();
          }),
          sheetAction(sheet, 'Remove from library', () {
            for (final m in picked) {
              lib.removeFromLibrary(m.id);
            }
            done();
          }, destructive: true),
        ],
        cancelButton: sheetAction(sheet, 'Cancel', () {}),
      ),
    );
  }
}

// ── List row ──────────────────────────────────────────────────────────────────

/// Shelf row for list display: 48×72 cover, title 14/700, meta 11 `fg2`,
/// download mark and unread badge trailing.
class _MangaListRow extends StatelessWidget {
  const _MangaListRow({
    required this.manga,
    required this.downloaded,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final MangaEntry manga;
  final bool downloaded;
  final bool? selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final meta = (manga.author?.isNotEmpty ?? false)
        ? manga.author!
        : '${manga.chapterCount} chapters';
    return Semantics(
      button: true,
      selected: selected,
      label: '${manga.title}, $meta',
      child: SumiPress(
        onTap: onTap,
        onLongPress: onLongPress,
        scale: AppMotion.activeScale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected == true ? c.ac.withValues(alpha: 0.14) : null,
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 72,
                child: Hero(
                  tag: mangaCoverHeroTag(manga.id),
                  child: SumiCoverFrame(child: CoverImage(url: manga.coverUrl)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: YomiText.ui(14,
                          weight: FontWeight.w700, color: c.fg, height: 1.25),
                    ),
                    const SizedBox(height: 2),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: YomiText.ui(11, color: c.fg2)),
                  ],
                ),
              ),
              if (downloaded) ...[
                const SizedBox(width: 8),
                Icon(CupertinoIcons.arrow_down_to_line, size: 14, color: c.fg2),
              ],
              const SizedBox(width: 8),
              UnreadBadge(count: manga.unreadCount),
            ],
          ),
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
