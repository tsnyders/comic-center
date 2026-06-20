import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/source_interface.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/app_colors.dart';
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
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
  ),
  'demonicscans_en': const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
  ),
  'asurascans_en': const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
  ),
  'reaperscans_en': const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
  ),
};

LinearGradient _gradientFor(MangaSource source) =>
    _sourceGradients[source.id] ??
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.accent,
        AppColors.accent.withOpacity(0.5),
      ],
    );

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

          // Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse',
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _GlassSearchBar(),
                ],
              ),
            ),
          ),

          if (sources.isEmpty)
            // ── Empty state ─────────────────────────────────────────────
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
            // ── Featured carousel ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Text('Featured', style: AppTextStyles.sectionTitle),
                  ),
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: sources.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => FeaturedSourceCard(
                        source: sources[i],
                        gradient: _gradientFor(sources[i]),
                        onTap: () => _openSource(context, sources[i].id),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Installed sources list ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text('Installed', style: AppTextStyles.sectionTitle),
              ),
            ),
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

          // ── Extensions card ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text('Extensions', style: AppTextStyles.sectionTitle),
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

// ── Glass search bar ─────────────────────────────────────────────────────────

class _GlassSearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppGlass(
      borderRadius: 14,
      blur: 16,
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(
              CupertinoIcons.search,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search all sources...',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textTertiary,
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

// ── Extensions card ──────────────────────────────────────────────────────────

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
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AppGlass(
          borderRadius: 16,
          blur: 20,
          tint: AppColors.accent.withOpacity(0.08),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
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
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Install, uninstall and update extensions',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: AppColors.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
