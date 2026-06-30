import 'dart:ui';

import 'package:flutter/cupertino.dart';
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
import '../../core/providers/cover_palette_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_glass.dart';
import '../../shared/widgets/cover_image.dart';
import '../library/widgets/manga_card.dart' show mangaCoverHeroTag;
import '../reader/reader_screen.dart';
import 'widgets/chapter_list_tile.dart';

// ── Webtoon detection ──────────────────────────────────────────────────────

/// Sources that publish exclusively long-strip webtoons / manhwa / manhua.
/// Titles from these always use the continuous vertical-scroll reader so the
/// tall strip images are never cut off by the page-by-page manga reader.
const _webtoonSources = <String>{
  'demonicscans_en',
  'asurascans_en',
  'reaperscans_en',
  'flamescans_en',
};

/// Returns true when the manga should use the continuous vertical scroll
/// reader (webtoon mode) rather than the page-by-page manga reader.
///
/// Triggers on any known webtoon-only source, and on any title whose genre
/// list contains "manhwa", "webtoon", or "manhua".
bool _isWebtoon(MangaEntry manga) {
  if (_webtoonSources.contains(manga.sourceId)) return true;
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
      backgroundColor: context.backgroundColor,
      child: Stack(
        children: [
          // Full-bleed hero
          _DetailHero(manga: manga),

          // Back + add-to-library overlay
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.x4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      '‹ Back',
                      style: TextStyle(
                        color: context.accentColor,
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

class _DetailHero extends ConsumerWidget {
  const _DetailHero({required this.manga});
  final MangaEntry manga;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    final heroGradient = dark
        ? AppColors.heroGradientDark
        : AppColors.heroGradientLight;
    // LUMEN: ambient colour pulled from this cover's own palette.
    final artColor =
        ref.watch(coverPaletteProvider(manga.coverUrl ?? '')).valueOrNull
            ?? context.accentColor;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred, scaled cover fills the hero area
          Transform.scale(
            scale: 1.3,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
              child: CoverImage(url: manga.coverUrl),
            ),
          ),

          // Art ambient wash — top glow tinted by the cover's dominant colour
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 550),
            child: DecoratedBox(
              key: ValueKey(artColor),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    artColor.withValues(alpha: 0.50),
                    artColor.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.62],
                ),
              ),
            ),
          ),

          // Gradient fade to background — brightness-aware
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: heroGradient,
                stops: const [0.0, 0.55, 0.86],
              ),
            ),
          ),

          // Sharp cover chip — 104×156, top-right, e3 shadow
          Positioned(
            top: 80,
            right: AppSpacing.gutter,
            child: Hero(
              tag: mangaCoverHeroTag(manga.id),
              child: Container(
                width: 104,
                height: 156,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: dark ? AppElevation.e3 : AppElevation.e3Light,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
        borderRadius: 14,
        blur: 12,
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
        color: inLibrary ? context.accentColor : context.textPrimaryColor,
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

  bool _refreshingChapters = false;

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
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          border: Border(
            top: BorderSide(
              color: context.borderStrongColor,
              width: AppRadius.hairline,
            ),
          ),
        ),
        child: CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Drag handle — 36×4
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(
                      top: AppSpacing.x5,
                      bottom: AppSpacing.x6,
                    ),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderStrongColor,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveManga.title,
                        style: AppTextStyles.displayM.copyWith(
                          color: context.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      Text(
                        [
                          if (liveManga.author != null &&
                              liveManga.author!.isNotEmpty)
                            liveManga.author!,
                          _capitalise(liveManga.status),
                          '${liveManga.chapterCount} CH',
                        ].join('   ·   '),
                        style: AppTextStyles.metaMono.copyWith(
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Genre chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.x5, AppSpacing.gutter, 0,
                  ),
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.x6, AppSpacing.gutter, 0,
                  ),
                  child: _ActionRow(
                    manga: manga,
                    chapters: chapters,
                    onShowDownloadSheet: () => _showDownloadSheet(
                      context: context,
                      ref: ref,
                      title: 'Download Unread Chapters',
                      onConfirm: () {
                        final chs = (chapters.valueOrNull ?? [])
                            .where((c) => !c.isRead)
                            .toList();
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter, AppSpacing.x6, AppSpacing.gutter, 0,
                    ),
                    child: Text(
                      liveManga.description!,
                      style: AppTextStyles.bodySmall.copyWith(
                        height: 1.5,
                        color: context.textSecondaryColor,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Chapters heading + filter / sort bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.x7, AppSpacing.gutter, AppSpacing.x4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${liveManga.chapterCount} Chapters'.toUpperCase(),
                          style: AppTextStyles.overline.copyWith(
                            color: context.textTertiaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      _RefreshButton(
                        refreshing: _refreshingChapters,
                        onTap: _refreshChapters,
                      ),
                      const SizedBox(width: AppSpacing.x5),
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.x4,
                  ),
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'All',
                        selected: _filter == _ChapterFilter.all,
                        onTap: () =>
                            setState(() => _filter = _ChapterFilter.all),
                      ),
                      const SizedBox(width: AppSpacing.x4),
                      _FilterPill(
                        label: 'Unread',
                        selected: _filter == _ChapterFilter.unread,
                        onTap: () =>
                            setState(() => _filter = _ChapterFilter.unread),
                      ),
                      const SizedBox(width: AppSpacing.x4),
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
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CupertinoActivityIndicator(),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Text(
                    e.toString(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
                data: (chs) {
                  final display = _applyFilterSort(chs);
                  if (display.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No chapters match this filter.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
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
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 32,
                ),
              ),
            ],
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
              downloadPath: c.downloadPath,
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
          downloadPath: chapter.downloadPath,
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

  Future<void> _refreshChapters() async {
    if (_refreshingChapters) return;
    final source = ref.read(sourceByIdProvider(manga.sourceId));
    if (source == null) {
      _showRefreshError('Source "${manga.sourceId}" is not installed.');
      return;
    }
    setState(() => _refreshingChapters = true);
    try {
      await refreshMangaChapters(
        isar: ref.read(isarProvider),
        source: source,
        mangaId: manga.id,
        sourceMangaId: manga.sourceMangaId,
      );
      ref.invalidate(chapterSyncProvider(manga.id));
    } catch (e) {
      _showRefreshError(e.toString());
    } finally {
      if (mounted) setState(() => _refreshingChapters = false);
    }
  }

  void _showRefreshError(String message) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Refresh Failed'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Sort button ────────────────────────────────────────────────────────────

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
            color: context.accentColor,
          ),
          const SizedBox(width: 4),
          Text(
            ascending ? 'Oldest' : 'Newest',
            style: AppTextStyles.overline.copyWith(
              color: context.accentColor,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Refresh (check for updates) button ─────────────────────────────────────

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.refreshing, required this.onTap});
  final bool refreshing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: refreshing
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (refreshing)
            SizedBox(
              width: 13,
              height: 13,
              child: CupertinoActivityIndicator(
                radius: 6.5,
                color: context.accentColor,
              ),
            )
          else
            Icon(
              CupertinoIcons.arrow_2_circlepath,
              size: 13,
              color: context.accentColor,
            ),
          const SizedBox(width: 4),
          Text(
            refreshing ? 'Checking…' : 'Check Updates',
            style: AppTextStyles.overline.copyWith(
              color: context.accentColor,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter pill ────────────────────────────────────────────────────────────

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
          color: selected ? context.accentColor : context.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? context.accentColor
                : context.borderStrongColor,
            width: AppRadius.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.textOnAccent
                : context.textSecondaryColor,
          ),
        ),
      ),
    );
  }
}

// ── Genre chip ─────────────────────────────────────────────────────────────

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: context.borderStrongColor,
          width: AppRadius.hairline,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.metaMonoSm.copyWith(
          color: context.textSecondaryColor,
        ),
      ),
    );
  }
}

// ── Action row ─────────────────────────────────────────────────────────────

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

  bool _hasStarted(List<ChapterEntry> chs) =>
      chs.any((c) => c.isRead || c.lastPageRead > 0);

  void _continueReading(BuildContext context, List<ChapterEntry> chs) {
    if (chs.isEmpty) return;
    HapticFeedback.selectionClick();
    // chs is sorted descending (latest/highest chapter first).
    // "Continue": open the highest-numbered chapter the user has touched.
    // "Start":    open the first chapter (lowest number = last in desc list).
    final started = _hasStarted(chs);
    final rawIdx =
        started ? chs.indexWhere((c) => c.isRead || c.lastPageRead > 0) : -1;
    final index = rawIdx >= 0 ? rawIdx : chs.length - 1;
    final target = chs[index];
    final summaries = chs
        .map((c) => ReaderChapterSummary(
              id: c.id,
              sourceChapterId: c.sourceChapterId,
              title: c.title,
              downloadPath: c.downloadPath,
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
          downloadPath: target.downloadPath,
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
    final started = _hasStarted(chs);
    final dark = context.isDark;
    // Primary CTA is tinted by the cover's own palette ("let art decide").
    final art = ref.watch(coverPaletteProvider(manga.coverUrl ?? ''))
            .valueOrNull ??
        context.accentColor;
    return Row(
      children: [
        // Primary CTA — full-width accent button
        Expanded(
          child: GestureDetector(
            onTap: chs.isEmpty ? null : () => _continueReading(context, chs),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: chs.isEmpty ? context.surfaceElevatedColor : art,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: chs.isEmpty
                    ? null
                    : [
                        BoxShadow(
                          color: art.withValues(alpha: 0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: chapters.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.play_arrow_solid,
                          size: 15,
                          color: chs.isEmpty
                              ? context.textTertiaryColor
                              : CupertinoColors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          started ? 'Continue Reading' : 'Start Reading',
                          style: AppTextStyles.buttonPrimary.copyWith(
                            color: chs.isEmpty
                                ? context.textTertiaryColor
                                : CupertinoColors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x5),
        // Download icon button — 48px rounded
        GestureDetector(
          onTap: chs.isEmpty ? null : onShowDownloadSheet,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.surfaceElevatedColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: context.borderStrongColor,
                width: AppRadius.hairline,
              ),
              boxShadow: dark ? AppElevation.e1 : AppElevation.e2Light,
            ),
            child: Center(
              child: Icon(
                CupertinoIcons.arrow_down_circle,
                color: chs.isEmpty
                    ? context.textQuaternaryColor
                    : context.textSecondaryColor,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x5),
        // Categories icon button — 48px rounded
        GestureDetector(
          onTap: onManageCategories,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.surfaceElevatedColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: context.borderStrongColor,
                width: AppRadius.hairline,
              ),
              boxShadow: dark ? AppElevation.e1 : AppElevation.e2Light,
            ),
            child: Center(
              child: Icon(
                CupertinoIcons.folder_badge_plus,
                color: context.textSecondaryColor,
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
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: Border(
          top: BorderSide(
            color: context.borderStrongColor,
            width: AppRadius.hairline,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.x5,
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.gutter,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.x6),
              decoration: BoxDecoration(
                color: context.borderStrongColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Add to Category',
            style: AppTextStyles.sectionTitle.copyWith(
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          Wrap(
            spacing: AppSpacing.x4,
            runSpacing: AppSpacing.x4,
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
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor
                        : context.surfaceElevatedColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isSelected
                          ? context.accentColor
                          : context.borderStrongColor,
                      width: AppRadius.hairline,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected
                          ? AppColors.textOnAccent
                          : context.textSecondaryColor,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.gutter),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: context.accentColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              onPressed: () async {
                await ref
                    .read(libraryNotifierProvider.notifier)
                    .updateCategories(widget.manga.id, _selected);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(
                'Save',
                style: AppTextStyles.buttonPrimary.copyWith(
                  color: AppColors.textOnAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
