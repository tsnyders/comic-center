import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DraggableScrollableSheet;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/providers/browse_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_glass.dart';
import '../../shared/widgets/cover_image.dart';
import '../library/widgets/manga_card.dart' show mangaCoverHeroTag;
import '../reader/reader_screen.dart';
import 'widgets/chapter_list_tile.dart';

// ── Webtoon detection ──────────────────────────────────────────────────────

/// Returns true when the manga should use the continuous vertical scroll
/// reader (webtoon mode) rather than the page-by-page manga reader.
///
/// Triggers on DemonicScans (all manhwa) and on any title whose genre list
/// contains "manhwa", "webtoon", or "manhua".
bool _isWebtoon(MangaEntry manga) {
  if (manga.sourceId == 'demonicscans_en') return true;
  return manga.genres.any((g) {
    final lower = g.toLowerCase();
    return lower == 'manhwa' || lower == 'webtoon' || lower == 'manhua';
  });
}

// ── Screen ─────────────────────────────────────────────────────────────────

class TitleDetailScreen extends ConsumerWidget {
  const TitleDetailScreen({super.key, required this.manga});

  final MangaEntry manga;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Full-bleed hero
          _DetailHero(manga: manga),

          // Back + add-to-library overlay
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      '‹ Back',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _AddToLibraryButton(manga: manga),
                ],
              ),
            ),
          ),

          // Draggable detail sheet
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.42,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.55, 0.95],
            builder: (context, scrollController) {
              return _DetailSheet(
                manga: manga,
                scrollController: scrollController,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.manga});
  final MangaEntry manga;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred cover
          CoverImage(url: manga.coverUrl),
          // Dark overlay + fade to background at bottom
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0xCC0A0A0F),
                  AppColors.background,
                ],
                stops: [0.0, 0.55, 0.85],
              ),
            ),
          ),
          // Blur layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: const SizedBox.expand(),
          ),
          // Vivid cover (top-right corner)
          Positioned(
            top: 80,
            right: 20,
            child: Hero(
              tag: mangaCoverHeroTag(manga.id),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 100,
                  height: 150,
                  child: CoverImage(url: manga.coverUrl),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav / action buttons ───────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppGlass(
        borderRadius: 16,
        blur: 10,
        tint: const Color(0x66000000),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: child,
      ),
    );
  }
}

class _AddToLibraryButton extends ConsumerWidget {
  const _AddToLibraryButton({required this.manga});
  final MangaEntry manga;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch live state so the button reacts immediately after add/remove.
    final live = ref.watch(liveMangaProvider(manga.id)).valueOrNull ?? manga;
    final inLibrary = live.inLibrary;
    return _NavButton(
      onTap: () {
        if (inLibrary) {
          ref.read(libraryNotifierProvider.notifier).removeFromLibrary(manga.id);
        } else {
          ref.read(libraryNotifierProvider.notifier).addToLibrary(live);
        }
      },
      child: Icon(
        inLibrary ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
        color: inLibrary ? AppColors.accent : AppColors.textPrimary,
        size: 18,
      ),
    );
  }
}

// ── Bottom sheet ───────────────────────────────────────────────────────────

enum _ChapterFilter { all, unread, downloaded }

class _DetailSheet extends ConsumerStatefulWidget {
  const _DetailSheet({
    required this.manga,
    required this.scrollController,
  });

  final MangaEntry manga;
  final ScrollController scrollController;

  @override
  ConsumerState<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends ConsumerState<_DetailSheet> {
  _ChapterFilter _filter = _ChapterFilter.all;

  /// false = newest first (default, matches source order); true = oldest first.
  bool _ascending = false;

  MangaEntry get manga => widget.manga;
  ScrollController get scrollController => widget.scrollController;

  List<ChapterEntry> _applyFilterSort(List<ChapterEntry> chs) {
    var result = switch (_filter) {
      _ChapterFilter.all => chs,
      _ChapterFilter.unread => chs.where((c) => !c.isRead).toList(),
      _ChapterFilter.downloaded => chs.where((c) => c.isDownloaded).toList(),
    };
    if (_ascending) result = result.reversed.toList();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Use live manga so chapter count updates after sync.
    final liveManga =
        ref.watch(liveMangaProvider(manga.id)).valueOrNull ?? manga;
    final chapters = ref.watch(chapterSyncProvider(manga.id));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(
              top: BorderSide(color: AppColors.borderStrong, width: 0.5),
            ),
          ),
          child: CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Drag handle
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Pull-to-refresh
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  final isar   = ref.read(isarProvider);
                  final source = ref.read(sourceByIdProvider(manga.sourceId));
                  if (source == null) return;
                  await refreshMangaChapters(
                    isar: isar,
                    source: source,
                    mangaId: manga.id,
                    sourceMangaId: manga.sourceMangaId,
                  );
                  ref.invalidate(chapterSyncProvider(manga.id));
                },
              ),

              // Title + author
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(liveManga.title, style: AppTextStyles.sheetTitle),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (liveManga.author != null) liveManga.author!,
                          '·',
                          _capitalise(liveManga.status),
                          '·',
                          '${liveManga.chapterCount} ch',
                        ].join(' '),
                        style: AppTextStyles.sheetAuthor,
                      ),
                    ],
                  ),
                ),
              ),

              // Genre chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: liveManga.genres
                        .map((g) => _GenreChip(label: g))
                        .toList(),
                  ),
                ),
              ),

              // Action buttons
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _ActionRow(
                    manga: manga,
                    chapters: chapters,
                    onShowDownloadSheet: () => _showDownloadSheet(
                      context: context,
                      ref: ref,
                      title: 'Download All Chapters',
                      onConfirm: () {
                        final chs = chapters.valueOrNull ?? [];
                        ref.read(downloadManagerProvider.notifier).enqueueAll(
                              manga: manga,
                              chapters: chs,
                            );
                      },
                    ),
                    onManageCategories: () =>
                        _showCategorySheet(context, ref, manga),
                  ),
                ),
              ),

              // Description
              if (liveManga.description != null &&
                  liveManga.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(
                      liveManga.description!,
                      style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Chapters heading + filter / sort bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${liveManga.chapterCount} Chapters'.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      _SortButton(
                        ascending: _ascending,
                        onTap: () => setState(() => _ascending = !_ascending),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter pills
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'All',
                        selected: _filter == _ChapterFilter.all,
                        onTap: () =>
                            setState(() => _filter = _ChapterFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Unread',
                        selected: _filter == _ChapterFilter.unread,
                        onTap: () =>
                            setState(() => _filter = _ChapterFilter.unread),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Downloaded',
                        selected: _filter == _ChapterFilter.downloaded,
                        onTap: () => setState(
                            () => _filter = _ChapterFilter.downloaded),
                      ),
                    ],
                  ),
                ),
              ),

              // Chapter list
              chapters.when(
                loading: () => SliverToBoxAdapter(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CupertinoActivityIndicator(),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Text(e.toString(), style: AppTextStyles.bodySmall),
                ),
                data: (chs) {
                  final display = _applyFilterSort(chs);
                  if (display.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No chapters match this filter.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: display.length,
                      itemBuilder: (context, i) => ChapterListTile(
                        chapter: display[i],
                        onTap: () => _openReader(context, chs, display[i]),
                        onDownload: display[i].isDownloaded
                            ? null
                            : () => _downloadChapter(context, ref, display[i]),
                      ),
                    ),
                  );
                },
              ),

              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showCategorySheet(
    BuildContext context,
    WidgetRef ref,
    MangaEntry manga,
  ) {
    final allCats = ref.read(libraryCategoriesProvider).where((c) => c != 'All').toList();
    if (allCats.isEmpty) {
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('No Categories'),
          content: const Text(
              'Create categories in Settings → Categories first.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _CategorySheet(manga: manga, allCategories: allCats),
    );
  }

  void _openReader(
      BuildContext context, List<ChapterEntry> chs, ChapterEntry chapter) {
    // Index into the original (descending) list so next-chapter navigation
    // stays correct regardless of the current display filter / sort order.
    final index = chs.indexWhere((c) => c.id == chapter.id);
    if (index < 0) return;
    HapticFeedback.selectionClick();
    final isWebtoon = _isWebtoon(manga);
    final summaries = chs
        .map((c) => ReaderChapterSummary(
              id: c.id,
              sourceChapterId: c.sourceChapterId,
              title: c.title,
            ))
        .toList();
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ReaderScreen(
          mangaId: manga.id,
          chapterId: chapter.id,
          sourceId: manga.sourceId,
          sourceChapterId: chapter.sourceChapterId,
          chapterTitle: chapter.title,
          isWebtoon: isWebtoon,
          chapters: summaries,
          chapterIndex: index,
        ),
      ),
    );
  }

  void _downloadChapter(
    BuildContext context,
    WidgetRef ref,
    ChapterEntry chapter,
  ) {
    _showDownloadSheet(
      context: context,
      ref: ref,
      title: 'Download Chapter ${chapter.number?.toStringAsFixed(0) ?? '?'}',
      onConfirm: () {
        ref.read(downloadManagerProvider.notifier).enqueue(
              manga: manga,
              chapter: chapter,
            );
      },
    );
  }

  static void _showDownloadSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required VoidCallback onConfirm,
  }) {
    final location = ref.read(downloadLocationProvider);
    final locationLabel =
        location == DownloadLocation.local ? 'Local Storage' : 'Google Drive';

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(title),
        message: Text('Save to: $locationLabel\n'
            'Change storage location in Settings → Downloads.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Download'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.ascending, required this.onTap});
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ascending
                ? CupertinoIcons.arrow_up
                : CupertinoIcons.arrow_down,
            size: 13,
            color: AppColors.accent,
          ),
          const SizedBox(width: 4),
          Text(
            ascending ? 'Oldest' : 'Newest',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.accent,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderStrong,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color:
                selected ? CupertinoColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({
    required this.manga,
    required this.chapters,
    required this.onShowDownloadSheet,
    required this.onManageCategories,
  });

  final MangaEntry manga;
  final AsyncValue<List<ChapterEntry>> chapters;
  final VoidCallback onShowDownloadSheet;
  final VoidCallback onManageCategories;

  void _continueReading(BuildContext context, List<ChapterEntry> chs) {
    if (chs.isEmpty) return;
    HapticFeedback.selectionClick();
    // chs is sorted descending (latest first). Reading order is ascending.
    // Find the first unread chapter in ascending order (i.e., last unread from
    // the end of chs).
    final targetIdx = chs.lastIndexWhere((c) => !c.isRead);
    final index = targetIdx >= 0 ? targetIdx : 0;
    final target = chs[index];
    final summaries = chs
        .map((c) => ReaderChapterSummary(
              id: c.id,
              sourceChapterId: c.sourceChapterId,
              title: c.title,
            ))
        .toList();
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ReaderScreen(
          mangaId: manga.id,
          chapterId: target.id,
          sourceId: manga.sourceId,
          sourceChapterId: target.sourceChapterId,
          chapterTitle: target.title,
          isWebtoon: _isWebtoon(manga),
          chapters: summaries,
          chapterIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chs = chapters.valueOrNull ?? [];
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 13),
            color: chs.isEmpty ? AppColors.surfaceElevated : AppColors.accent,
            borderRadius: BorderRadius.circular(14),
            onPressed: chs.isEmpty ? null : () => _continueReading(context, chs),
            child: chapters.isLoading
                ? const CupertinoActivityIndicator()
                : Text(
                    '▶  Continue Reading',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: chs.isEmpty
                          ? AppColors.textTertiary
                          : CupertinoColors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: chs.isEmpty ? null : onShowDownloadSheet,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderStrong, width: 0.5),
            ),
            child: Center(
              child: Icon(
                CupertinoIcons.arrow_down_circle,
                color: chs.isEmpty
                    ? AppColors.textQuaternary
                    : AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onManageCategories,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderStrong, width: 0.5),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.folder_badge_plus,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Category assignment sheet ──────────────────────────────────────────────

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({
    required this.manga,
    required this.allCategories,
  });

  final MangaEntry manga;
  final List<String> allCategories;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.manga.categories);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Add to Category', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.allCategories.map((cat) {
              final isSelected = _selected.contains(cat);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selected.remove(cat);
                  } else {
                    _selected.add(cat);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.borderStrong,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected
                          ? CupertinoColors.white
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
              onPressed: () async {
                await ref
                    .read(libraryNotifierProvider.notifier)
                    .updateCategories(widget.manga.id, _selected);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
