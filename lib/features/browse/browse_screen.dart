import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/source_interface.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/sumi.dart';
import 'extensions_screen.dart';
import 'source_manga_screen.dart';

/// ============================================================================
/// Discover — search, a featured source plate with the sumi splatter, then
/// the installed sources as curated rows with a kanji language tag.
/// ============================================================================
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  void _openSource(BuildContext context, String sourceId,
      {bool search = false}) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            SourceMangaScreen(sourceId: sourceId, initialSearch: search),
      ),
    );
  }

  void _openExtensions(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const ExtensionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yc;
    final sources = ref.watch(sourceRegistryProvider);
    final insets = MediaQuery.paddingOf(context);
    final gutter = context.yomiGutter;

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: insets.top + 12)),

          // ── Header ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SumiOverline('DISCOVER · 探'),
                  Text('Explore', style: YomiText.kanji(36, color: c.fg)),
                ],
              ),
            ),
          ),

          // ── Search ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
              child: _SearchField(
                onTap: () => sources.isEmpty
                    ? _openExtensions(context)
                    : _openSource(context, sources.first.id, search: true),
              ),
            ),
          ),

          if (sources.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 48, 0, 32),
                child: EmptyState(
                  icon: CupertinoIcons.square_grid_2x2,
                  title: 'No sources installed',
                  message: 'Install an extension to start exploring.',
                  actionLabel: 'Browse extensions',
                  onAction: () => _openExtensions(context),
                ),
              ),
            )
          else ...[
            // ── Featured plate ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 0),
                child: _FeaturedPlate(
                  source: sources.first,
                  onTap: () => _openSource(context, sources.first.id),
                ),
              ),
            ),

            // ── Curated rows ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 26, gutter, 10),
                child: const SumiOverline('SOURCES · 源'),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverList.builder(
                itemCount: sources.length,
                itemBuilder: (context, i) => SumiStagger(
                  index: i,
                  child: _SourceRow(
                    source: sources[i],
                    onTap: () => _openSource(context, sources[i].id),
                  ),
                ),
              ),
            ),
          ],

          // ── Extensions ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _PlainRow(
                kanji: '拡',
                title: 'Extensions',
                subtitle: 'Install, update and remove sources',
                onTap: () => _openExtensions(context),
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: insets.bottom + 120)),
        ],
      ),
    );
  }
}

// ── Search field (44 tall, 1px line, radius 4) ────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return Semantics(
      button: true,
      label: 'Search titles, authors',
      child: SumiPress(
        onTap: onTap,
        scale: AppMotion.activeScale,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.search, size: 18, color: c.fg2),
              const SizedBox(width: 10),
              Text('Search titles, authors',
                  style: YomiText.ui(14, color: c.fg2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Featured plate (300 tall, splatter, vertical kanji) ───────────────────────

class _FeaturedPlate extends StatelessWidget {
  const _FeaturedPlate({required this.source, required this.onTap});
  final MangaSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return Semantics(
      button: true,
      label: 'Featured source ${source.name}',
      child: SumiPress(
        onTap: onTap,
        scale: AppMotion.activeScale,
        child: Container(
          height: 300,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const SumiSplatter(),
              Positioned(
                right: 18,
                top: 18,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Text('探索',
                      style: YomiText.kanji(22, color: c.bg, letterSpacing: 4)),
                ),
              ),
              Positioned(
                left: 18,
                right: 120,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SumiOverline('FEATURED SOURCE', color: c.ac),
                    const SizedBox(height: 6),
                    Text(source.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: YomiText.kanji(28, color: c.fg)),
                    const SizedBox(height: 6),
                    Text(
                      '${source.language.toUpperCase()} · ${_host(source.baseUrl)} · v${source.version}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: YomiText.ui(13, color: c.fg2, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _host(String url) {
  final u = Uri.tryParse(url);
  return (u?.host.isNotEmpty ?? false) ? u!.host : url;
}

// ── Source row: 56px icon, name 15/700, meta 12, kanji tag ────────────────────

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.onTap});
  final MangaSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return SumiPress(
      onTap: onTap,
      scale: AppMotion.activeScale,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.card,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(3),
              ),
              child: source.iconBytes.isEmpty
                  ? Center(
                      child: Text(kanjiTag(source.name),
                          style: YomiText.kanji(22, color: c.fg2)))
                  : Image.memory(source.iconBytes, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YomiText.ui(15,
                          weight: FontWeight.w700, color: c.fg)),
                  const SizedBox(height: 2),
                  Text(_host(source.baseUrl),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YomiText.ui(12, color: c.fg2)),
                  const SizedBox(height: 8),
                  Text('Popular · Latest · Search · v${source.version}',
                      style: YomiText.ui(12, color: c.fg2, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text(languageKanji(source.language),
                style: YomiText.kanji(22, color: c.ac)),
          ],
        ),
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({
    required this.kanji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String kanji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return SumiPress(
      onTap: onTap,
      scale: AppMotion.activeScale,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Center(
                child: Text(kanji, style: YomiText.kanji(26, color: c.fg)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: YomiText.ui(15,
                          weight: FontWeight.w700, color: c.fg)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: YomiText.ui(12, color: c.fg2)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 16, color: c.fg2),
          ],
        ),
      ),
    );
  }
}
