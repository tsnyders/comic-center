import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/manga_entry.dart';
import '../../core/extensions/models/manga_summary.dart';
import '../../core/providers/chapter_prefs_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/reader_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/services/source_migration.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/sumi.dart';
import '../../shared/widgets/sumi_actions.dart';
import '../browse/global_search_screen.dart';

final migrationTitlesProvider = Provider<AsyncValue<List<MangaEntry>>>((ref) {
  final installed = ref.watch(sourceRegistryProvider).map((s) => s.id).toSet();
  return ref.watch(libraryStreamProvider).whenData((titles) =>
      titles.where((m) => !installed.contains(m.sourceId)).toList());
});

/// With [manga], opens its picker directly, including installed source titles.
/// With [titleIds], lists the bulk selection; otherwise lists missing sources.
class MigrateScreen extends ConsumerStatefulWidget {
  const MigrateScreen({super.key, this.manga, this.titleIds});
  final MangaEntry? manga;
  final Set<int>? titleIds;

  @override
  ConsumerState<MigrateScreen> createState() => _MigrateScreenState();
}

class _MigrateScreenState extends ConsumerState<MigrateScreen> {
  late final _search = TextEditingController(text: widget.manga?.title ?? '');
  Timer? _debounce;
  int _searchVersion = 0;
  bool _searching = false;
  bool _busy = false;
  bool _keepDownloads = true;
  String? _status;
  List<MigrationCandidate> _candidates = [];

  @override
  void initState() {
    super.initState();
    if (widget.manga != null) _find();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    _debounce?.cancel();
    final version = ++_searchVersion;
    final query = _search.text.trim();
    setState(() {
      _searching = query.isNotEmpty;
      _candidates = [];
    });
    if (query.isEmpty) return;
    final manga = MangaEntry()
      ..title = query
      ..sourceKey = widget.manga!.sourceKey;
    final results =
        await findCandidates(manga, ref.read(sourceRegistryProvider));
    if (!mounted || version != _searchVersion) return;
    setState(() {
      _searching = false;
      _candidates = results;
    });
  }

  Future<bool> _confirm(String message, {bool bulk = false}) async =>
      await showCupertinoModalPopup<bool>(
        context: context,
        builder: (sheet) => CupertinoActionSheet(
          title: Text(bulk ? 'Migrate all best matches?' : 'Migrate source?'),
          message: Text(
              '$message\n\nOnly matching chapter numbers carry reading '
              'progress. ${_keepDownloads ? 'Keep downloaded chapters.' : 'Delete old downloads.'}'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheet, true),
              child: const Text('Migrate'),
            )
          ],
          cancelButton: sheetAction(sheet, 'Cancel', () {}),
        ),
      ) ??
      false;

  Future<MangaEntry> _move(
      MangaEntry manga, MigrationCandidate candidate) async {
    final moved = await migrate(ref.read(isarProvider),
        from: manga,
        to: candidate.source,
        target: candidate.summary,
        keepDownloads: _keepDownloads);
    if (mounted) {
      ref.invalidate(chapterSortProvider(moved.id));
      ref.invalidate(chapterFilterProvider(moved.id));
      ref.invalidate(mangaReadingDirectionProvider(moved.id));
      ref.invalidate(mangaReaderModeProvider(moved.id));
    }
    return moved;
  }

  Future<void> _pick(MigrationCandidate candidate) async {
    if (_busy ||
        !await _confirm(
            '${widget.manga!.title} → ${candidate.summary.title} on ${candidate.source.name}.') ||
        !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Moving chapters and reading progress…';
    });
    try {
      final moved = await _move(widget.manga!, candidate);
      if (mounted) Navigator.pop(context, moved);
    } catch (error) {
      if (mounted) setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _all(List<MangaEntry> titles) async {
    if (_busy ||
        !await _confirm(
            'Search ${titles.length} titles and move matches scoring at least 85%. '
            'Other titles stay here for manual choice.',
            bulk: true) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    var moved = 0;
    var failed = 0;
    final sources = ref.read(sourceRegistryProvider);
    try {
      // ponytail: migrate one title at a time; each search uses four workers.
      for (final (index, manga) in titles.indexed) {
        if (!mounted) return;
        setState(
            () => _status = '${index + 1}/${titles.length} · ${manga.title}');
        try {
          final candidates = await findCandidates(manga, sources);
          if (!mounted) return;
          if (candidates.isNotEmpty && candidates.first.score >= 0.85) {
            await _move(manga, candidates.first);
            moved++;
          }
        } catch (_) {
          failed++;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status =
              '$moved migrated · ${titles.length - moved} left for manual choice'
              '${failed == 0 ? '' : ' ($failed could not migrate)'}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final manga = widget.manga;
    final sources = ref.watch(sourceRegistryProvider);
    final titles = manga != null
        ? const AsyncData<List<MangaEntry>>([])
        : widget.titleIds == null
            ? ref.watch(migrationTitlesProvider)
            : ref.watch(libraryStreamProvider).whenData((titles) =>
                titles.where((m) => widget.titleIds!.contains(m.id)).toList());
    return PopScope(
      canPop: !_busy,
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.yomiGutter),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              Row(children: [
                SumiBackButton(
                    onTap: _busy ? () {} : () => Navigator.maybePop(context)),
                const SizedBox(width: 14),
                const Expanded(child: DisplayText('Migrate source', size: 30)),
              ]),
              const SizedBox(height: 16),
              if (manga != null) ...[
                Text(manga.title,
                    style:
                        YomiText.ui(16, color: c.fg, weight: FontWeight.w600)),
                const SizedBox(height: 12),
                const SumiOverline('Search manually'),
                const SizedBox(height: 8),
                CupertinoSearchTextField(
                  controller: _search,
                  enabled: !_busy,
                  placeholder: 'Search manually',
                  backgroundColor: c.card,
                  itemColor: c.fg2,
                  style: YomiText.ui(15, color: c.fg),
                  onSubmitted: (_) => _find(),
                  onChanged: (_) {
                    _debounce?.cancel();
                    // Invalidate old results immediately, including requests
                    // finishing during the debounce window.
                    setState(() {
                      _searchVersion++;
                      _candidates = [];
                      _searching = true;
                    });
                    _debounce = Timer(const Duration(milliseconds: 300), _find);
                  },
                ),
              ] else
                SumiButton(
                  label: 'Migrate all best matches',
                  enabled: !_busy &&
                      sources.isNotEmpty &&
                      (titles.valueOrNull?.isNotEmpty ?? false),
                  onTap: () => _all(titles.valueOrNull ?? []),
                ),
              Row(children: [
                Expanded(
                    child: Text('Keep downloads',
                        style: YomiText.ui(14, color: c.fg))),
                CupertinoSwitch(
                    value: _keepDownloads,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _keepDownloads = value)),
              ]),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_status!, style: YomiText.ui(13, color: c.fg2)),
                ),
              if (_busy || _searching)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: CupertinoActivityIndicator()),
              Expanded(
                  child: manga != null
                      ? _picker(sources.isEmpty)
                      : titles.when(
                          loading: () =>
                              const Center(child: CupertinoActivityIndicator()),
                          error: (error, _) =>
                              Center(child: Text(error.toString())),
                          data: (items) => items.isEmpty
                              ? const Center(
                                  child: EmptyState(
                                      icon: CupertinoIcons.check_mark,
                                      title: 'All set',
                                      message: 'No titles need a source.'))
                              : ListView(children: [
                                  for (final title in items)
                                    SearchResultRow(
                                      item: MangaSummary(
                                          id: title.sourceMangaId,
                                          title: title.title,
                                          coverUrl: title.coverUrl),
                                      headers: ref
                                              .watch(sourceByIdProvider(
                                                  title.sourceId))
                                              ?.imageHeaders ??
                                          const {},
                                      subtitle: ref
                                              .watch(sourceByIdProvider(
                                                  title.sourceId))
                                              ?.name ??
                                          '${title.sourceId} · Unavailable',
                                      onTap: _busy
                                          ? null
                                          : () => Navigator.push<MangaEntry>(
                                              context,
                                              CupertinoPageRoute(
                                                  builder: (_) => MigrateScreen(
                                                      manga: title))),
                                    ),
                                ]),
                        )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _picker(bool noSources) {
    if (_candidates.isEmpty && !_searching) {
      return Center(
          child: EmptyState(
              icon: CupertinoIcons.search,
              title: noSources ? 'No sources installed' : 'No matches found',
              message: noSources
                  ? 'Install a source in Browse first.'
                  : 'Try another title or spelling. Unavailable sources are skipped.'));
    }
    return ListView(children: [
      for (final candidate in _candidates)
        SearchResultRow(
          item: candidate.summary,
          headers: candidate.source.imageHeaders,
          subtitle:
              '${candidate.source.name} · ${(candidate.score * 100).round()}% match',
          onTap: _busy ? null : () => _pick(candidate),
        ),
    ]);
  }
}
