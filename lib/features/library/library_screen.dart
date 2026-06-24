import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/manga_entry.dart';
import '../../core/providers/library_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/empty_state.dart';
import '../title_detail/title_detail_screen.dart';
import 'library_filter_sheet.dart';
import 'widgets/category_chips.dart';
import 'widgets/continue_reading_shelf.dart';
import 'widgets/manga_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late final _scrollOffset = ValueNotifier<double>(0);
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffset.value =
          _scrollController.offset.clamp(0.0, double.infinity);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final library = ref.watch(filteredLibraryProvider);

    return CupertinoPageScaffold(
      backgroundColor: context.backgroundColor,
      child: Stack(
        children: [
          // Ambient radial glow — mode-aware
          Positioned.fill(
            child: _AmbientBackground(),
          ),

          // Scrollable content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Spacer for the frosted top bar
              SliverToBoxAdapter(
                child: SizedBox(height: topPadding + 64),
              ),

              // "My / Library" display title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.x4,
                    AppSpacing.gutter,
                    AppSpacing.x6,
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'My\n',
                          style: AppTextStyles.displayTitle.copyWith(
                            color: context.textPrimaryColor,
                          ),
                        ),
                        TextSpan(
                          text: 'Library',
                          style: AppTextStyles.displayTitleAccent.copyWith(
                            color: context.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Continue reading shelf (recently read titles)
              SliverToBoxAdapter(
                child: ContinueReadingShelf(
                  onOpen: _openDetail,
                ),
              ),

              // Category filter chips
              const SliverToBoxAdapter(
                child: CategoryChips(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Manga grid
              library.when(
                loading: () => _buildShimmerGrid(),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (mangas) => mangas.isEmpty
                    ? _EmptyLibraryView()
                    : _buildGrid(mangas),
              ),

              // Bottom safe area + tab bar clearance
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 90,
                ),
              ),
            ],
          ),

          // Frosted top bar (always on top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FrostedTopBar(
              scrollOffset: _scrollOffset,
              searchActive: _searchActive,
              searchController: _searchController,
              columns: ref.watch(libraryGridColumnsProvider),
              onSearchTap: () => setState(() => _searchActive = true),
              onSearchChanged: (q) =>
                  ref.read(librarySearchProvider.notifier).state = q,
              onSearchClose: () {
                setState(() => _searchActive = false);
                _searchController.clear();
                ref.read(librarySearchProvider.notifier).state = '';
              },
              onFilterTap: () => showCupertinoModalPopup<void>(
                context: context,
                builder: (_) => const LibraryFilterSheet(),
              ),
              onToggleColumns: () {
                HapticFeedback.selectionClick();
                final current = ref.read(libraryGridColumnsProvider);
                ref.read(libraryGridColumnsProvider.notifier).state =
                    current == 2 ? 3 : 2;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<MangaEntry> mangas) {
    final columns = ref.watch(libraryGridColumnsProvider);
    return SliverPadding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: columns == 2 ? AppSpacing.gridGap : 10,
          mainAxisSpacing: columns == 2 ? AppSpacing.gridGap : 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => MangaCard(
            manga: mangas[i],
            compact: columns == 3,
            onTap: () => _openDetail(mangas[i]),
            onLongPress: () => _showQuickActions(mangas[i]),
          ),
          childCount: mangas.length,
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    final columns = ref.watch(libraryGridColumnsProvider);
    return SliverPadding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: columns == 2 ? AppSpacing.gridGap : 10,
          mainAxisSpacing: columns == 2 ? AppSpacing.gridGap : 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, __) => _ShimmerCard(),
          childCount: 6,
        ),
      ),
    );
  }

  void _openDetail(MangaEntry manga) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => TitleDetailScreen(manga: manga),
      ),
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

// ── Frosted top bar ────────────────────────────────────────────────────────

class _FrostedTopBar extends StatelessWidget {
  const _FrostedTopBar({
    required this.scrollOffset,
    required this.searchActive,
    required this.searchController,
    required this.columns,
    required this.onSearchTap,
    required this.onSearchChanged,
    required this.onSearchClose,
    required this.onFilterTap,
    required this.onToggleColumns,
  });

  final ValueNotifier<double> scrollOffset;
  final bool searchActive;
  final TextEditingController searchController;
  final int columns;
  final VoidCallback onSearchTap;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClose;
  final VoidCallback onFilterTap;
  final VoidCallback onToggleColumns;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<double>(
      valueListenable: scrollOffset,
      builder: (context, offset, _) {
        // Transparent until scrolled >8px, then ramp in blur+bg
        final blurAlpha = ((offset - 8) / 32).clamp(0.0, 1.0);

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurAlpha * 20,
              sigmaY: blurAlpha * 20,
            ),
            child: Container(
              color: context.backgroundColor.withValues(alpha: 0.72 * blurAlpha),
              padding: EdgeInsets.only(
                top: topPadding + 8,
                left: AppSpacing.gutter,
                right: AppSpacing.gutter,
                bottom: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: searchActive
                        ? CupertinoSearchTextField(
                            controller: searchController,
                            autofocus: true,
                            onChanged: onSearchChanged,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.textPrimaryColor,
                            ),
                          )
                        : GestureDetector(
                            onTap: onSearchTap,
                            child: _SearchPill(),
                          ),
                  ),
                  const SizedBox(width: 10),
                  if (searchActive)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(38, 38),
                      onPressed: onSearchClose,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else ...[
                    // Grid density toggle — 38px circular surfaceElevated button
                    _CircleIconButton(
                      icon: columns == 2
                          ? CupertinoIcons.square_grid_3x2
                          : CupertinoIcons.square_grid_2x2,
                      onTap: onToggleColumns,
                    ),
                    const SizedBox(width: 10),
                    // Filter button
                    _CircleIconButton(
                      icon: CupertinoIcons.slider_horizontal_3,
                      onTap: onFilterTap,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Search pill (h38, radius.pill, surfaceElevated@80%) ────────────────────

class _SearchPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: context.borderStrongColor,
          width: AppRadius.hairline,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            CupertinoIcons.search,
            size: 16,
            color: context.textTertiaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Search library',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textTertiaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Circular icon button (top bar, 38px, surfaceElevated tone) ─────────────

class _CircleIconButton extends StatefulWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _pressed
              ? context.surfaceElevatedColor
              : context.surfaceElevatedColor.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: context.borderStrongColor,
            width: AppRadius.hairline,
          ),
        ),
        child: Icon(
          widget.icon,
          size: 16,
          color: context.textSecondaryColor,
        ),
      ),
    );
  }
}

// ── Ambient background ─────────────────────────────────────────────────────

class _AmbientBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final seedColor = context.isDark
        ? const Color(0x24FF6A5C)
        : const Color(0x14DC4633);
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

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyLibraryView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: EmptyState(
          icon: CupertinoIcons.book,
          title: 'Your library is empty',
          message: 'Browse sources to find manga and add them here.',
        ),
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.bodySmall.copyWith(
            color: context.textSecondaryColor,
          ),
        ),
      ),
    );
  }
}

// ── Shimmer card (1200ms ease in/out per spec) ─────────────────────────────

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
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
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.cover),
          border: Border.all(
            color: context.borderColor,
            width: AppRadius.hairline,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.surfaceColor,
              Color.lerp(
                context.surfaceColor,
                context.surfaceElevatedColor,
                _anim.value,
              )!,
            ],
          ),
        ),
      ),
    );
  }
}
