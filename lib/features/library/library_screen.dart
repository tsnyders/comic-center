import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/manga_entry.dart';
import '../../core/providers/library_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../title_detail/title_detail_screen.dart';
import 'widgets/category_chips.dart';
import 'widgets/manga_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _scrollController = ScrollController();
  late final _scrollOffset = ValueNotifier<double>(0);

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
            child: _FrostedTopBar(scrollOffset: _scrollOffset),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<MangaEntry> mangas) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => MangaCard(
            manga: mangas[i],
            onTap: () => _openDetail(mangas[i]),
          ),
          childCount: mangas.length,
        ),
      ),
    );
  }

  SliverGrid _buildShimmerGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, __) => _ShimmerCard(),
        childCount: 6,
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
}

// ── Frosted top bar ────────────────────────────────────────────────────────

class _FrostedTopBar extends StatelessWidget {
  const _FrostedTopBar({required this.scrollOffset});
  final ValueNotifier<double> scrollOffset;

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
              color: AppColors.background.withOpacity(0.7 * blurAlpha),
              padding: EdgeInsets.only(
                top: topPadding + 8,
                left: 20,
                right: 20,
                bottom: 10,
              ),
              child: Row(
                children: [
                  // Search pill
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: AppColors.borderStrong,
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
                  const SizedBox(width: 12),
                  // Avatar / profile button
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'M',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.book,
              size: 56,
              color: AppColors.textQuaternary,
            ),
            const SizedBox(height: 16),
            Text(
              'Your library is empty',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse sources to find manga and add them here.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
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
              AppColors.surface,
              Color.lerp(
                AppColors.surface,
                AppColors.surfaceElevated,
                _ctrl.value,
              )!,
            ],
          ),
        ),
      ),
    );
  }
}
