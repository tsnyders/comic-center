import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/models/manga_summary.dart';
import '../../core/extensions/source_interface.dart';
import '../../core/providers/browse_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/sumi.dart';
import '../title_detail/title_detail_screen.dart';

/// Searches every installed source and keeps each catalogue's results separate.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = query);
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
  }

  Future<void> _openManga(MangaSource source, MangaSummary summary) async {
    final isar = ref.read(isarProvider);
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
      Navigator.of(context).pop();
      Navigator.of(context).push(CupertinoPageRoute<void>(
        builder: (_) => TitleDetailScreen(manga: entry),
      ));
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Unable to open title'),
          content: Text(error.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final gutter = context.yomiGutter;
    final sources = ref.watch(sourceRegistryProvider);

    // Start every source request now. ListView builds offscreen sections lazily,
    // so watching only inside _SourceResults would delay those searches.
    if (_query.isNotEmpty) {
      for (final source in sources) {
        ref.watch(browseMangaProvider(BrowseArgs(
          sourceId: source.id,
          mode: BrowseMode.search,
          query: _query,
        )));
      }
    }

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
              child: const Row(
                children: [
                  SumiBackButton(),
                  SizedBox(width: 14),
                  Expanded(child: DisplayText('Search', size: 30)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 12),
              child: CupertinoSearchTextField(
                controller: _controller,
                autofocus: true,
                placeholder: 'Search all sources',
                backgroundColor: c.card,
                itemColor: c.fg2,
                style: YomiText.ui(15, color: c.fg),
                placeholderStyle: YomiText.ui(15, color: c.fg2),
                onChanged: _onChanged,
                onSubmitted: _submit,
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? Center(
                      child: Text(
                        sources.isEmpty
                            ? 'Install a source to search for titles.'
                            : 'Search titles across ${sources.length} sources.',
                        style: YomiText.ui(14, color: c.fg2),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 40),
                      itemCount: sources.length,
                      itemBuilder: (context, index) {
                        final source = sources[index];
                        return _SourceResults(
                          key: ValueKey('${source.id}::$_query'),
                          source: source,
                          query: _query,
                          onOpen: (summary) => _openManga(source, summary),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceResults extends ConsumerStatefulWidget {
  const _SourceResults({
    super.key,
    required this.source,
    required this.query,
    required this.onOpen,
  });

  final MangaSource source;
  final String query;
  final ValueChanged<MangaSummary> onOpen;

  @override
  ConsumerState<_SourceResults> createState() => _SourceResultsState();
}

class _SourceResultsState extends ConsumerState<_SourceResults> {
  int _pages = 1;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final results = <MangaSummary>[];
    final seen = <String>{};
    Object? failure;
    int? failedPage;
    var loading = false;
    var lastPageIsEmpty = false;

    for (var page = 1; page <= _pages; page++) {
      final args = BrowseArgs(
        sourceId: widget.source.id,
        mode: BrowseMode.search,
        page: page,
        query: widget.query,
      );
      final response = ref.watch(browseMangaProvider(args));
      if (response.isLoading) loading = true;
      if (response.hasError) {
        failure = response.error;
        failedPage = page;
      }
      final items = response.valueOrNull;
      if (items == null) continue;
      if (page == _pages) lastPageIsEmpty = items.isEmpty;
      for (final item in items) {
        if (seen.add(item.id)) results.add(item);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.source.name} results',
              style: YomiText.overline(c.fg2)),
          const SizedBox(height: 10),
          if (results.isEmpty && !loading && failure == null)
            Text('No results', style: YomiText.ui(13, color: c.fg2)),
          for (final item in results)
            _ResultRow(
              item: item,
              headers: widget.source.imageHeaders,
              onTap: () => widget.onOpen(item),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CupertinoActivityIndicator(),
            ),
          if (failure != null) ...[
            Text(failure.toString(), style: YomiText.ui(13, color: c.fg2)),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => ref.invalidate(browseMangaProvider(BrowseArgs(
                sourceId: widget.source.id,
                mode: BrowseMode.search,
                page: failedPage!,
                query: widget.query,
              ))),
              child: Text('Retry ${widget.source.name}'),
            ),
          ],
          if (results.isNotEmpty &&
              !loading &&
              failure == null &&
              !lastPageIsEmpty)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _pages++),
              child: Text('Load more ${widget.source.name}'),
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.item,
    required this.headers,
    required this.onTap,
  });

  final MangaSummary item;
  final Map<String, String> headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return SumiPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(context.radii.cover),
              child: SizedBox(
                width: 48,
                height: 68,
                child: CoverImage(url: item.coverUrl, headers: headers),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: YomiText.ui(15, color: c.fg, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right, size: 16, color: c.fg2),
          ],
        ),
      ),
    );
  }
}
