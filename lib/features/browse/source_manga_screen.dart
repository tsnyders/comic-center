import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/models/manga_summary.dart';
import '../../core/providers/browse_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/cover_image.dart';
import '../title_detail/title_detail_screen.dart';

class SourceMangaScreen extends ConsumerStatefulWidget {
  const SourceMangaScreen({super.key, required this.sourceId});

  final String sourceId;

  @override
  ConsumerState<SourceMangaScreen> createState() => _SourceMangaScreenState();
}

class _SourceMangaScreenState extends ConsumerState<SourceMangaScreen> {
  final _searchController = TextEditingController();
  bool _searchActive = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  BrowseArgs _args(BrowseMode mode) {
    if (mode == BrowseMode.search) {
      return BrowseArgs(
        sourceId: widget.sourceId,
        mode: BrowseMode.search,
        query: _searchController.text.trim(),
      );
    }
    return BrowseArgs(sourceId: widget.sourceId, mode: mode);
  }

  Future<void> _openManga(MangaSummary summary) async {
    final source = ref.read(sourceByIdProvider(widget.sourceId));
    if (source == null) return;
    final isar = ref.read(isarProvider);

    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );

    try {
      final entry = await upsertMangaEntry(
        isar: isar,
        source: source,
        mangaId: summary.id,
        summary: summary,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loader
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => TitleDetailScreen(manga: entry),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  void _activateSearch() {
    setState(() => _searchActive = true);
  }

  void _dismissSearch() {
    _searchController.clear();
    ref.read(browseModeProvider(widget.sourceId).notifier).state =
        BrowseMode.popular;
    setState(() => _searchActive = false);
  }

  void _submitSearch() {
    if (_searchController.text.trim().isEmpty) return;
    ref.read(browseModeProvider(widget.sourceId).notifier).state =
        BrowseMode.search;
    setState(() {});
  }

  void _showSortSheet(BuildContext context) {
    final current = ref.read(browseModeProvider(widget.sourceId));
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Sort By'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: current == BrowseMode.popular,
            onPressed: () {
              ref.read(browseModeProvider(widget.sourceId).notifier).state =
                  BrowseMode.popular;
              Navigator.pop(context);
            },
            child: const Text('Popular'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: current == BrowseMode.latest,
            onPressed: () {
              ref.read(browseModeProvider(widget.sourceId).notifier).state =
                  BrowseMode.latest;
              Navigator.pop(context);
            },
            child: const Text('Latest'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(sourceByIdProvider(widget.sourceId));
    if (source == null) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Text(
            'Source not found',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textPrimaryColor,
            ),
          ),
        ),
      );
    }

    final mode = ref.watch(browseModeProvider(widget.sourceId));
    final mangasAsync = ref.watch(browseMangaProvider(_args(mode)));
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding)),

          // ── Header ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '‹ Browse',
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      source.name,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: context.textPrimaryColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    onPressed: _searchActive ? _dismissSearch : _activateSearch,
                    child: Icon(
                      _searchActive
                          ? CupertinoIcons.xmark_circle_fill
                          : CupertinoIcons.search,
                      color: context.accentColor,
                      size: 20,
                    ),
                  ),
                  if (!_searchActive)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      onPressed: () => _showSortSheet(context),
                      child: Icon(
                        CupertinoIcons.slider_horizontal_3,
                        color: context.accentColor,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Search bar ────────────────────────────────────────────────
          if (_searchActive)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (_) {
                    if (_searchController.text.trim().isNotEmpty) {
                      ref
                          .read(browseModeProvider(widget.sourceId).notifier)
                          .state = BrowseMode.search;
                      setState(() {});
                    }
                  },
                  onSubmitted: (_) => _submitSearch(),
                ),
              ),
            ),

          // ── Mode tabs ─────────────────────────────────────────────────
          if (!_searchActive)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _ModeTab(
                      label: 'Popular',
                      selected: mode == BrowseMode.popular,
                      onTap: () => ref
                          .read(browseModeProvider(widget.sourceId).notifier)
                          .state = BrowseMode.popular,
                    ),
                    const SizedBox(width: 8),
                    _ModeTab(
                      label: 'Latest',
                      selected: mode == BrowseMode.latest,
                      onTap: () => ref
                          .read(browseModeProvider(widget.sourceId).notifier)
                          .state = BrowseMode.latest,
                    ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Manga grid ────────────────────────────────────────────────
          mangasAsync.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load: $e',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            data: (mangas) => mangas.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No results',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.58,
                      ),
                      itemCount: mangas.length,
                      itemBuilder: (context, i) => _MangaCard(
                        title: mangas[i].title,
                        coverUrl: mangas[i].coverUrl,
                        onTap: () => _openManga(mangas[i]),
                      ),
                    ),
                  ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(height: bottomPadding + 90),
          ),
        ],
      ),
    );
  }
}

// ── Mode tab pill ─────────────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  const _ModeTab({
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
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? context.accentColor
              : context.surfaceElevatedColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: selected
              ? null
              : Border.all(
                  color: context.borderColor,
                  width: AppRadius.hairline,
                ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected
                ? AppColors.textOnAccent
                : context.textSecondaryColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Manga card in grid ────────────────────────────────────────────────────

class _MangaCard extends StatelessWidget {
  const _MangaCard({
    required this.title,
    required this.coverUrl,
    required this.onTap,
  });

  final String title;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.cover),
              child: SizedBox.expand(
                child: CoverImage(url: coverUrl),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
              color: context.textPrimaryColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
