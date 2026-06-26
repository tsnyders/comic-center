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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
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
              SliverToBoxAdapter(child: SizedBox(height: topPadding + 12)),

              // Greeting header
              SliverToBoxAdapter(child: _GreetingHeader(greeting: _greeting)),

              // Search field
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, 4, AppSpacing.gutter, AppSpacing.x6,
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

              // Continue-reading hero (top in-progress title)
              if (continueItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.x7,
                    ),
                    child: _ContinueHero(
                      manga: continueItems.first,
                      onTap: () => _openDetail(continueItems.first),
                    ),
                  ),
                ),

              // "Jump back in" horizontal shelf (the rest of the recents)
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
                    AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.x5,
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
                data: (mangas) => mangas.isEmpty
                    ? _EmptyLibraryView()
                    : _buildList(mangas),
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
      CupertinoPageRoute(builder: (_) => TitleDetailScreen(manga: manga)),
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

// ── Greeting header ─────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.greeting});
  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.x5,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.accentSubtleColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.accentLineColor,
                width: AppRadius.hairline,
              ),
            ),
            child: Icon(
              CupertinoIcons.book_fill,
              color: context.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.x5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.textTertiaryColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Your Library',
                  style: AppTextStyles.hero.copyWith(
                    color: context.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
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

// ── Continue-reading hero card ──────────────────────────────────────────────

class _ContinueHero extends StatefulWidget {
  const _ContinueHero({required this.manga, required this.onTap});
  final MangaEntry manga;
  final VoidCallback onTap;

  @override
  State<_ContinueHero> createState() => _ContinueHeroState();
}

class _ContinueHeroState extends State<_ContinueHero> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final manga = widget.manga;
    final chapter = manga.lastReadChapterNumber?.toStringAsFixed(0);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.accentColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: context.accentColor.withValues(alpha: 0.34),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.cover),
                child: Hero(
                  tag: mangaCoverHeroTag(manga.id),
                  child: SizedBox(
                    width: 60,
                    height: 84,
                    child: CoverImage(url: manga.coverUrl),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONTINUE READING',
                      style: TextStyle(
                        fontFamily: AppTextStyles.display,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: Color(0xCCFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      manga.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 17,
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chapter != null ? 'Chapter $chapter' : 'Tap to start',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xCCFFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x4),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: CupertinoColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.play_arrow_solid,
                    color: context.accentColor, size: 20),
              ),
            ],
          ),
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
    final meta = chapter != null
        ? 'Chapter $chapter'
        : '${manga.chapterCount} chapters';
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
    final seedColor = context.isDark
        ? const Color(0x1AFF6F61)
        : const Color(0x10E04A3C);
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
