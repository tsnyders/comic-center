import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/source_interface.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/sumi.dart';
import 'extensions_screen.dart';
import 'global_search_screen.dart';
import 'source_manga_screen.dart';
import 'source_settings_screen.dart';

/// ============================================================================
/// Discover — search, a featured source plate with the sumi splatter, then
/// the installed sources as curated rows with a kanji language tag.
/// ============================================================================
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  void _openSource(BuildContext context, String sourceId) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceMangaScreen(sourceId: sourceId),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const GlobalSearchScreen()),
    );
  }

  void _openExtensions(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const ExtensionsScreen()),
    );
  }

  void _openSettings(BuildContext context, MangaSource source) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceSettingsScreen(source: source),
      ),
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
                  SumiOverline(context.look.copy.discoverKicker ?? 'DISCOVER',
                      kanji: '探'),
                  DisplayText(context.look.copy.discoverTitle, size: 36),
                ],
              ),
            ),
          ),

          // ── Search ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
              child: _SearchField(
                onTap: () => _openSearch(context),
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
                child: const SumiOverline('SOURCES', kanji: '源'),
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
                    onSettings: sources[i].preferences.isEmpty
                        ? null
                        : () => _openSettings(context, sources[i]),
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
          height: context.look.isPastel ? 48 : 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: context.look.isPastel ? c.card : null,
            border: context.look.isPastel ? null : Border.all(color: c.line),
            borderRadius: BorderRadius.circular(
                context.look.isPastel ? 18 : context.radii.cover),
            boxShadow: context.look.cardShadow,
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
    final look = context.look;
    final pastel = look.isPastel;
    final ink = pastel ? look.onAccent : c.fg;
    final ink2 = pastel ? look.onAccent.withValues(alpha: 0.75) : c.fg2;
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
            color: pastel ? look.accents[1] : c.card,
            border: pastel ? null : Border.all(color: c.line),
            borderRadius: BorderRadius.circular(context.radii.card),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (look.isSumi) const SumiSplatter(),
              if (pastel)
                Positioned(
                  right: -40,
                  bottom: -40,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: c.ac.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              if (look.kanji)
                Positioned(
                  right: 18,
                  top: 18,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text('探索',
                        style: YomiText.display(22,
                            color: c.bg, letterSpacing: 4)),
                  ),
                ),
              if (look.isCinema)
                Positioned(
                  left: 20,
                  top: 20,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: c.ac)),
                    child: Text('FEATURE',
                        style: YomiText.display(12,
                            color: c.ac, letterSpacing: 2)),
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
                    SumiOverline('FEATURED SOURCE',
                        color: pastel ? ink2 : c.ac),
                    const SizedBox(height: 6),
                    DisplayText(source.name,
                        size: look.isCinema ? 44 : 28,
                        color: ink,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      '${source.language.toUpperCase()} · ${_host(source.baseUrl)} · v${source.version}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: YomiText.ui(13, color: ink2, height: 1.4),
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
  const _SourceRow({
    required this.source,
    required this.onTap,
    this.onSettings,
  });
  final MangaSource source;
  final VoidCallback onTap;

  /// Opens the source's settings; null hides the gear.
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final look = context.look;
    return SumiPress(
      onTap: onTap,
      scale: AppMotion.activeScale,
      child: Container(
        padding: look.isPastel
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(vertical: 14),
        margin: look.isPastel ? const EdgeInsets.only(bottom: 10) : null,
        decoration: BoxDecoration(
          color: look.isPastel ? c.card : null,
          border:
              look.isPastel ? null : Border(bottom: BorderSide(color: c.line)),
          borderRadius: look.isPastel ? BorderRadius.circular(22) : null,
          boxShadow: look.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.card,
                border: look.isPastel ? null : Border.all(color: c.line),
                borderRadius: BorderRadius.circular(context.radii.small),
              ),
              child: source.iconBytes.isEmpty
                  ? Center(
                      child: Text(kanjiTag(source.name),
                          style: YomiText.display(22, color: c.fg2)))
                  : Image.memory(source.iconBytes, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (look.isCinema)
                    DisplayText(source.name,
                        size: 22, maxLines: 1, overflow: TextOverflow.ellipsis)
                  else
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
            Text(
                look.kanji
                    ? languageKanji(source.language)
                    : source.language.toUpperCase(),
                style:
                    YomiText.display(22, color: look.isPastel ? c.fg2 : c.ac)),
            if (onSettings != null)
              Semantics(
                label: '${source.name} settings',
                child: CupertinoButton(
                  padding: const EdgeInsets.only(left: 10),
                  onPressed: onSettings,
                  child: Icon(CupertinoIcons.gear, size: 20, color: c.fg2),
                ),
              ),
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
                child: context.look.kanji
                    ? Text(kanji, style: YomiText.display(26, color: c.fg))
                    : Icon(CupertinoIcons.square_grid_2x2,
                        size: 24, color: c.fg),
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
