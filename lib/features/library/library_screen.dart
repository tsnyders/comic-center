import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/manga_entry.dart';
import '../../core/providers/library_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/lumen_page_route.dart';
import '../../shared/widgets/unread_badge.dart';
import '../title_detail/title_detail_screen.dart';
import 'library_filter_sheet.dart';
import 'widgets/category_chips.dart';
import 'widgets/continue_reading_shelf.dart';
import 'widgets/manga_card.dart' show mangaCoverHeroTag;

/// ============================================================================
/// Library — "Discovery Feed" structure
///
/// Greeting header + search → a wide Continue-reading hero card → a horizontal
/// "Jump back in" shelf → category chips → the library as a vertical list of
/// rich rows (cover · title · author · chapter · unread). Replaces the old
/// big-title + uniform-grid layout.
/// ============================================================================
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final library = ref.watch(filteredLibraryProvider);
    final continueItems = ref.watch(continueReadingProvider);

    return CupertinoPageScaffold(
      backgroundColor: context.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(child: _AmbientBackground()),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Cinematic full-bleed hero — cover bleeds behind the status bar
              if (continueItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CinematicHero(
                    manga: continueItems.first,
                    topInset: topPadding,
                    onTap: () => _openDetail(continueItems.first),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.gutter,
                        topPadding + 32, AppSpacing.gutter, AppSpacing.x4),
                    child: Text('Your Library',
                        style: AppTextStyles.displayM
                            .copyWith(color: context.textPrimaryColor)),
                  ),
                ),

              // Search
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.x6,
                    AppSpacing.gutter,
                    AppSpacing.x6,
                  ),
                  child: _SearchField(
                    controller: _searchController,
                    onChanged: (q) =>
                        ref.read(librarySearchProvider.notifier).state = q,
                    onFilterTap: () => showCupertinoModalPopup<void>(
                      context: context,
                      builder: (_) => const LibraryFilterSheet(),
                    ),
                  ),
                ),
              ),

              // "Your shelf" — horizontal recents
              if (continueItems.length > 1)
                SliverToBoxAdapter(
                  child: ContinueReadingShelf(onOpen: _openDetail),
                ),

              // Category chips
              const SliverToBoxAdapter(child: CategoryChips()),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x6)),

              // Section header for the list
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.x5,
                  ),
                  child: Text(
                    'Your collection',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: context.textPrimaryColor,
                    ),
                  ),
                ),
              ),

              // Library as a list of rows
              library.when(
                loading: () => _buildShimmer(),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (mangas) =>
                    mangas.isEmpty ? _EmptyLibraryView() : _buildList(mangas),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 96,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<MangaEntry> mangas) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      sliver: SliverList.separated(
        itemCount: mangas.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x5),
        itemBuilder: (context, i) => _FadeSlideIn(
          index: i,
          child: _ComicRow(
            manga: mangas[i],
            onTap: () => _openDetail(mangas[i]),
            onLongPress: () => _showQuickActions(mangas[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      sliver: SliverList.separated(
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x5),
        itemBuilder: (_, __) => const _RowShimmer(),
      ),
    );
  }

  void _openDetail(MangaEntry manga) {
    Navigator.of(context, rootNavigator: true).push(
      LumenPageRoute(builder: (_) => TitleDetailScreen(manga: manga)),
    );
  }

  void _showQuickActions(MangaEntry manga) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(manga.title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openDetail(manga);
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

// ── Search field + filter ───────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.surfaceElevatedColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: context.borderColor,
                width: AppRadius.hairline,
              ),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.search,
                    size: 18, color: context.textTertiaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: CupertinoTextField(
                    controller: controller,
                    onChanged: onChanged,
                    placeholder: 'Search your library',
                    placeholderStyle: AppTextStyles.bodyMedium.copyWith(
                      color: context.textTertiaryColor,
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.textPrimaryColor,
                    ),
                    decoration: const BoxDecoration(),
                    padding: EdgeInsets.zero,
                    cursorColor: context.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x5),
        GestureDetector(
          onTap: onFilterTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.accentColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: context.accentColor.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.slider_horizontal_3,
                size: 20, color: CupertinoColors.white),
          ),
        ),
      ],
    );
  }
}

// ── Cinematic full-bleed continue hero ──────────────────────────────────────

class _CinematicHero extends StatelessWidget {
  const _CinematicHero({
    required this.manga,
    required this.topInset,
    required this.onTap,
  });

  final MangaEntry manga;
  final double topInset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ch = manga.lastReadChapterNumber;
    final total = manga.chapterCount;
    final progress =
        (ch != null && total > 0) ? (ch / total).clamp(0.0, 1.0) : 0.0;
    final chStr = ch?.toStringAsFixed(0);
    final ink = context.backgroundColor;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: topInset + 312,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover art bleeds to every edge
            Hero(
              tag: 'cover_hero_${manga.id}',
              child: CoverImage(url: manga.coverUrl),
            ),
            // Scrim — darken top (for chrome) and bottom (for text); art shows mid
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ink.withValues(alpha: 0.55),
                    const Color(0x00000000),
                    ink.withValues(alpha: 0.65),
                    ink,
                  ],
                  stops: const [0.0, 0.30, 0.74, 1.0],
                ),
              ),
            ),
            // Top wordmark
            Positioned(
              top: topInset + 10,
              left: AppSpacing.gutter,
              right: AppSpacing.gutter,
              child: Text(
                'YOMI',
                style: AppTextStyles.metaMono.copyWith(
                  color: context.textPrimaryColor,
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Bottom: mono label · title · iris progress
            Positioned(
              left: AppSpacing.gutter,
              right: AppSpacing.gutter,
              bottom: AppSpacing.x5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chStr != null ? 'CONTINUE · CH $chStr' : 'CONTINUE',
                    style: AppTextStyles.metaMono.copyWith(
                      color: context.accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    manga.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.displayM.copyWith(
                      color: context.textPrimaryColor,
                      height: 1.0,
                    ),
                  ),
                  if (progress > 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.textQuaternaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.accentColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(progress * 100).round()}%',
                          style: AppTextStyles.metaMonoSm.copyWith(
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comic list row ──────────────────────────────────────────────────────────

class _ComicRow extends StatefulWidget {
  const _ComicRow({
    required this.manga,
    required this.onTap,
    required this.onLongPress,
  });
  final MangaEntry manga;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_ComicRow> createState() => _ComicRowState();
}

class _ComicRowState extends State<_ComicRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final manga = widget.manga;
    final chapter = manga.lastReadChapterNumber?.toStringAsFixed(0);
    final meta =
        chapter != null ? 'Chapter $chapter' : '${manga.chapterCount} chapters';
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: context.borderColor,
              width: AppRadius.hairline,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.cover),
                child: Hero(
                  tag: mangaCoverHeroTag(manga.id),
                  child: SizedBox(
                    width: 52,
                    height: 72,
                    child: CoverImage(url: manga.coverUrl),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (manga.author != null && manga.author!.isNotEmpty) ...[
                      Text(
                        manga.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Icon(CupertinoIcons.book,
                            size: 12, color: context.textTertiaryColor),
                        const SizedBox(width: 5),
                        Text(
                          meta,
                          style: AppTextStyles.caption.copyWith(
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x4),
              if (manga.unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: UnreadBadge(count: manga.unreadCount),
                )
              else
                Icon(CupertinoIcons.chevron_right,
                    size: 16, color: context.textQuaternaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Row shimmer ─────────────────────────────────────────────────────────────

class _RowShimmer extends StatefulWidget {
  const _RowShimmer();
  @override
  State<_RowShimmer> createState() => _RowShimmerState();
}

class _RowShimmerState extends State<_RowShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = Color.lerp(
            context.surfaceColor, context.surfaceElevatedColor, _anim.value)!;
        return Container(
          height: 92,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: context.borderColor, width: AppRadius.hairline),
          ),
        );
      },
    );
  }
}

// ── Staggered entrance animation ────────────────────────────────────────────

class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clamped = index < 12 ? index : 11;
    const total = 760.0;
    final start = (clamped * 40) / total;
    final end = (start + 320 / total).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 760),
      curve: Interval(start, end, curve: AppMotion.easeOut),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ── Ambient background ──────────────────────────────────────────────────────

class _AmbientBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final seedColor =
        context.isDark ? const Color(0x1AFF6F61) : const Color(0x10E04A3C);
    final baseColor = context.backgroundColor;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.8),
          radius: 1.2,
          colors: [seedColor, baseColor],
          stops: const [0.0, 0.6],
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyLibraryView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: EmptyState(
            icon: CupertinoIcons.book,
            title: 'Your library is empty',
            message: 'Browse sources to find manga and add them here.',
          ),
        ),
      ),
    );
  }
}

// ── Error view ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textSecondaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
