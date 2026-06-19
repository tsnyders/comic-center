import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/manga_entry.dart';
import '../../core/providers/library_provider.dart';
import '../../core/theme/app_colors.dart';
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
      _scrollOffset.value = _scrollController.offset.clamp(0.0, double.infinity);
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
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Ambient radial glow
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

              // "My Library" display title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(text: 'My\n', style: AppTextStyles.displayTitle),
                        TextSpan(
                          text: 'Library',
                          style: AppTextStyles.displayTitleAccent,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: columns == 2 ? 14 : 10,
          mainAxisSpacing: columns == 2 ? 14 : 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: columns == 2 ? 14 : 10,
          mainAxisSpacing: columns == 2 ? 14 : 10,
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
        final blurAlpha = (offset / 40).clamp(0.0, 1.0);

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurAlpha * 24,
              sigmaY: blurAlpha * 24,
            ),
            child: Container(
              color: context.backgroundColor.withOpacity(0.7 * blurAlpha),
              padding: EdgeInsets.only(
                top: topPadding + 8,
                left: 20,
                right: 20,
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
                              color: AppColors.textPrimary,
                            ),
                          )
                        : GestureDetector(
                            onTap: onSearchTap,
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: context.surfaceElevatedColor.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: context.borderStrongColor,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  const Icon(
                                    CupertinoIcons.search,
                                    size: 16,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Search library',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  if (searchActive)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 38,
                      onPressed: onSearchClose,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else ...[
                    // Grid density toggle
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

// ── Circular icon button (top bar) ─────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.surfaceElevatedColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: context.borderStrongColor, width: 0.5),
        ),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

// ── Ambient background ─────────────────────────────────────────────────────

class _AmbientBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.4, -0.8),
          radius: 1.2,
          colors: [Color(0x26667EEA), AppColors.background],
          stops: [0.0, 0.6],
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
        child: Text(message, style: AppTextStyles.bodySmall),
      ),
    );
  }
}

// ── Shimmer card ───────────────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.surfaceColor,
              Color.lerp(
                context.surfaceColor,
                context.surfaceElevatedColor,
                _ctrl.value,
              )!,
            ],
          ),
        ),
      ),
    );
  }
}
