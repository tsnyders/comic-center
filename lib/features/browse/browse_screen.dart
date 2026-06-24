import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/source_interface.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_glass.dart';
import '../../shared/widgets/empty_state.dart';
import 'extensions_screen.dart';
import 'source_manga_screen.dart';
import 'widgets/featured_source_card.dart';
import 'widgets/source_row.dart';

// Accent gradients per source ID.
final _sourceGradients = <String, LinearGradient>{
  'mangadex_en_v5': const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.gradViolet,
  ),
  'demonicscans_en': const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.gradEmber,
  ),
  'asurascans_en': const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.gradTeal,
  ),
  'reaperscans_en': const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.gradRose,
  ),
  'readcomiconline_en': const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.gradEmber,
  ),
  'comicextra_en': const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.gradTeal,
  ),
};

LinearGradient _gradientFor(MangaSource source) {
  final known = _sourceGradients[source.id];
  if (known != null) return known;
  final seeds = [
    AppColors.gradEmber,
    AppColors.gradViolet,
    AppColors.gradTeal,
    AppColors.gradRose,
  ];
  final colors = seeds[source.id.hashCode.abs() % 4];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );
}

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  void _openSource(BuildContext context, String sourceId) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceMangaScreen(sourceId: sourceId),
      ),
    );
  }

  void _openExtensions(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ExtensionsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceRegistryProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),

          // ── Title + search pill ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse',
                    style: AppTextStyles.hero.copyWith(
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _GlassSearchBar(),
                ],
              ),
            ),
          ),

          if (sources.isEmpty)
            // ── Empty state ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
                child: EmptyState(
                  icon: CupertinoIcons.square_grid_2x2,
                  title: 'No extensions installed',
                  message: 'Install an extension to start browsing manga.',
                  actionLabel: 'Browse Extensions',
                  onAction: () => _openExtensions(context),
                ),
              ),
            )
          else ...[
            // ── Featured carousel ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Row(
                      children: [
                        Text(
                          'Featured',
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: sources.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(
                        width: 248,
                        child: FeaturedSourceCard(
                          source: sources[i],
                          gradient: _gradientFor(sources[i]),
                          onTap: () => _openSource(context, sources[i].id),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Installed sources header ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Text(
                      'Installed',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _openExtensions(context),
                      child: Text(
                        'Manage',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: context.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Installed sources list ─────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: sources.length,
                itemBuilder: (context, i) => SourceRow(
                  source: sources[i],
                  action: SourceRowAction.open,
                  gradient: _gradientFor(sources[i]),
                  onTap: () => _openSource(context, sources[i].id),
                ),
              ),
            ),
          ],

          // ── Extensions card ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'Extensions',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: context.textPrimaryColor,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ExtensionsCard(onTap: () => _openExtensions(context)),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 90)),
        ],
      ),
    );
  }
}

// ── Glass search bar ──────────────────────────────────────────────────────────

class _GlassSearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppGlass(
      borderRadius: AppRadius.pill,
      blur: 16,
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              CupertinoIcons.search,
              size: 16,
              color: context.textTertiaryColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search all sources…',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: context.textTertiaryColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Extensions card ───────────────────────────────────────────────────────────

class _ExtensionsCard extends StatefulWidget {
  const _ExtensionsCard({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ExtensionsCard> createState() => _ExtensionsCardState();
}

class _ExtensionsCardState extends State<_ExtensionsCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? AppMotion.pressScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        child: AppGlass(
          borderRadius: AppRadius.lg,
          blur: 20,
          tint: context.accentSubtleColor,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.accentSubtleColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  CupertinoIcons.square_grid_2x2,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extension Catalogue',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Install, uninstall and update extensions',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textTertiaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: context.textTertiaryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
