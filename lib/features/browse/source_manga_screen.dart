import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/models/filter.dart';
import '../../core/extensions/models/manga_summary.dart';
import '../../core/extensions/source_interface.dart';
import '../../core/providers/browse_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/genre_filter_bar.dart';
import '../../shared/widgets/sumi.dart';
import '../title_detail/title_detail_screen.dart';

class SourceMangaScreen extends ConsumerStatefulWidget {
  const SourceMangaScreen({
    super.key,
    required this.sourceId,
    this.initialSearch = false,
  });

  final String sourceId;

  /// Open with the search bar already active (Discover's search field).
  final bool initialSearch;

  @override
  ConsumerState<SourceMangaScreen> createState() => _SourceMangaScreenState();
}

class _SourceMangaScreenState extends ConsumerState<SourceMangaScreen> {
  final _searchController = TextEditingController();
  late bool _searchActive = widget.initialSearch;

  /// Filters applied from the sheet; empty until the user taps Apply.
  List<SourceFilter> _filters = const [];

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
        filters: _filters,
      );
    }
    return BrowseArgs(
      sourceId: widget.sourceId,
      mode: mode,
      genreId: mode == BrowseMode.genre
          ? ref.watch(browseGenreProvider(widget.sourceId))
          : null,
    );
  }

  void _selectMode(BrowseMode mode) {
    ref.read(browseGenreProvider(widget.sourceId).notifier).state = null;
    ref.read(browseModeProvider(widget.sourceId).notifier).state = mode;
  }

  void _selectGenre(String? genreId) {
    _searchController.clear();
    ref.read(browseGenreProvider(widget.sourceId).notifier).state = genreId;
    ref.read(browseModeProvider(widget.sourceId).notifier).state =
        genreId == null ? BrowseMode.popular : BrowseMode.genre;
    setState(() => _searchActive = false);
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
    _filters = const [];
    _selectMode(BrowseMode.popular);
    setState(() => _searchActive = false);
  }

  void _submitSearch() {
    if (_searchController.text.trim().isEmpty && _filters.isEmpty) return;
    _selectMode(BrowseMode.search);
    setState(() {});
  }

  Future<void> _showFilterSheet(MangaSource source) async {
    final applied = await showCupertinoModalPopup<List<SourceFilter>>(
      context: context,
      builder: (_) => _FilterSheet(
        filters: _filters.isEmpty ? source.getFilters() : _filters,
        defaults: source.getFilters,
      ),
    );
    if (applied == null || !mounted) return;
    setState(() {
      _filters = applied;
      _searchActive = true;
    });
    _selectMode(BrowseMode.search);
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
              _selectMode(BrowseMode.popular);
              Navigator.pop(context);
            },
            child: const Text('Popular'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: current == BrowseMode.latest,
            onPressed: () {
              _selectMode(BrowseMode.latest);
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
    final selectedGenre = ref.watch(browseGenreProvider(widget.sourceId));
    final genresAsync = ref.watch(sourceGenresProvider(widget.sourceId));
    final mangasAsync = ref.watch(browseMangaProvider(_args(mode)));
    final hasFilters = source.getFilters().isNotEmpty;
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
                  if (hasFilters)
                    Semantics(
                      label: 'Filters',
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        onPressed: () => _showFilterSheet(source),
                        child: Icon(
                          CupertinoIcons.line_horizontal_3_decrease,
                          color: context.accentColor,
                          size: 20,
                        ),
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
                    _selectMode(_searchController.text.trim().isEmpty &&
                            _filters.isEmpty
                        ? BrowseMode.popular
                        : BrowseMode.search);
                    setState(() {});
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
                    SumiChip(
                      label: 'Popular',
                      active: mode == BrowseMode.popular,
                      onTap: () => _selectMode(BrowseMode.popular),
                    ),
                    const SizedBox(width: 8),
                    SumiChip(
                      label: 'Latest',
                      active: mode == BrowseMode.latest,
                      onTap: () => _selectMode(BrowseMode.latest),
                    ),
                  ],
                ),
              ),
            ),

          if (!_searchActive)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: genresAsync.when(
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                  error: (_, __) => CupertinoButton(
                    onPressed: () =>
                        ref.invalidate(sourceGenresProvider(widget.sourceId)),
                    child: const Text('Retry loading genres'),
                  ),
                  data: (genres) => genres.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Genre browsing is unavailable for this source.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.textSecondaryColor,
                            ),
                          ),
                        )
                      : GenreFilterBar(
                          genres: {
                            for (final genre in genres) genre.id: genre.name,
                          },
                          selected: selectedGenre,
                          onSelected: _selectGenre,
                        ),
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

// ── Filter sheet ──────────────────────────────────────────────────────────

/// Edits a draft copy of the source's filters and pops with it on Apply.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filters, required this.defaults});

  final List<SourceFilter> filters;
  final List<SourceFilter> Function() defaults;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late List<SourceFilter> _draft = widget.filters;

  void _set(int index, SourceFilter filter) =>
      setState(() => _draft = [..._draft]..[index] = filter);

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: c.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          DisplayText(YomiText.label('Filters', '絞'), size: 26),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _draft.length; i++) ...[
                    _row(i, _draft[i]),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: () =>
                      setState(() => _draft = widget.defaults()),
                  child: Text('Reset',
                      style: YomiText.ui(15,
                          weight: FontWeight.w600, color: c.fg)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SumiButton(
                  label: 'Apply',
                  height: 48,
                  onTap: () => Navigator.pop(context, _draft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(int i, SourceFilter f) => switch (f) {
        TextFilter() => _section(
            f.name,
            CupertinoTextField(
              placeholder: f.name,
              onChanged: (v) => _set(i, f.withValue(v)),
            ),
          ),
        SelectFilter() => _section(
            f.name,
            _chips([
              for (var j = 0; j < f.options.length; j++)
                SumiChip(
                  label: f.options[j],
                  active: j == f.selectedIndex,
                  onTap: () => _set(i, f.withIndex(j)),
                ),
            ]),
          ),
        SortFilter() => _section(
            f.name,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chips([
                  for (var j = 0; j < f.options.length; j++)
                    SumiChip(
                      label: f.options[j],
                      active: j == f.selectedIndex,
                      onTap: () => _set(i, f.withIndex(j)),
                    ),
                ]),
                if (f.directional) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Ascending',
                            style: YomiText.ui(14, color: context.yc.fg)),
                      ),
                      SumiToggle(
                        label: 'Ascending',
                        value: f.ascending,
                        onChanged: (v) => _set(i, f.withAscending(v)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        TriStateFilter() => _tri(f, true, (item) => _set(i, item)),
        GroupFilter() => _section(
            f.name,
            _chips([
              for (var j = 0; j < f.items.length; j++)
                _tri(f.items[j], f.excludable,
                    (item) => _set(i, f.withItem(j, item))),
            ]),
          ),
      };

  /// Cycles ignore → include → exclude (→ ignore); non-excludable groups
  /// skip the exclude state.
  Widget _tri(
    TriStateFilter item,
    bool excludable,
    ValueChanged<TriStateFilter> onChanged,
  ) =>
      SumiChip(
        label: item.state == TriState.exclude ? '− ${item.name}' : item.name,
        active: item.state != TriState.ignore,
        onTap: () => onChanged(item.withState(switch (item.state) {
          TriState.ignore => TriState.include,
          TriState.include =>
            excludable ? TriState.exclude : TriState.ignore,
          TriState.exclude => TriState.ignore,
        })),
      );

  Widget _section(String title, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SumiOverline(title.toUpperCase()),
          const SizedBox(height: 8),
          child,
        ],
      );

  Widget _chips(List<Widget> chips) =>
      Wrap(spacing: 8, runSpacing: 8, children: chips);
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
