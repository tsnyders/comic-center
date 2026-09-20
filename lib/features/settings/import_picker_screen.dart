import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/sumi.dart';
import '../../shared/widgets/sumi_actions.dart';

/// Returns selected payload entries in backup order, or null when cancelled.
class ImportPickerScreen extends ConsumerStatefulWidget {
  const ImportPickerScreen({
    super.key,
    required this.manga,
    this.connectedSources = const {},
    this.unavailableSources = const [],
    this.existingSourceKeys = const {},
  });

  final List<Map<String, Object?>> manga;
  final Map<String, String> connectedSources;
  final List<String> unavailableSources;
  final Set<String> existingSourceKeys;

  @override
  ConsumerState<ImportPickerScreen> createState() => _ImportPickerScreenState();
}

class _ImportPickerScreenState extends ConsumerState<ImportPickerScreen> {
  late final _installed = {
    for (final source in ref.read(sourceRegistryProvider)) source.id: source,
  };
  // Search keys and chapter counts are computed once, never while scrolling.
  late final _entries = widget.manga.map((manga) {
    final chapters =
        (manga['chapters'] as List? ?? const []).cast<Map<String, Object?>>();
    final read = chapters.where((chapter) => chapter['isRead'] == true).length;
    return (
      manga: manga,
      search: '${manga['title'] ?? ''}\n${manga['author'] ?? ''}'.toLowerCase(),
      source: manga['sourceId'] as String? ?? '',
      categories: (manga['categories'] as List? ?? const []).cast<String>(),
      chapters: chapters.length,
      read: read,
      started: read > 0 || manga['lastReadAt'] != null,
    );
  }).toList();
  late final _sources = {
    for (final entry in _entries) entry.source: _sourceName(entry.manga),
  };
  late final _categories =
      _entries.expand((entry) => entry.categories).toSet().toList();
  late final _selected = _entries.asMap().keys.toSet();
  late List<int> _visible = _entries.asMap().keys.toList();
  String _query = '';
  String? _source;
  String? _category;
  bool _startedOnly = false;

  String _sourceName(Map<String, Object?> manga) {
    final id = manga['sourceId'] as String? ?? '';
    return _installed[id]?.name ??
        widget.connectedSources[id] ??
        manga['sourceName'] as String? ??
        (id.startsWith('tachiyomi:') && widget.unavailableSources.length == 1
            ? widget.unavailableSources.single
            : id);
  }

  void _filter() {
    _visible = [
      for (final (index, entry) in _entries.indexed)
        if (entry.search.contains(_query) &&
            (_source == null || entry.source == _source) &&
            (_category == null || entry.categories.contains(_category)) &&
            (!_startedOnly || entry.started))
          index,
    ];
  }

  String _sourceWarnings() {
    final unavailable = <String>{};
    final disabled = <String>{};
    for (final index in _selected) {
      final entry = _entries[index];
      if (entry.source.startsWith('tachiyomi:')) {
        unavailable.add(_sourceName(entry.manga));
      } else if (!_installed.containsKey(entry.source)) {
        disabled.add(_sourceName(entry.manga));
      }
    }
    return [
      if (unavailable.isNotEmpty)
        'Yomi cannot connect these sources yet: ${unavailable.join(', ')}. '
            'Their titles and progress will be saved, but their chapters cannot be read online.',
      if (disabled.isNotEmpty)
        'Enable these sources in Browse to read online: ${disabled.join(', ')}.',
    ].join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final warnings = _sourceWarnings();
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.yomiGutter),
          child: LayoutBuilder(
              builder: (context, constraints) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ponytail: scroll the header above half-height on short screens.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight / 2),
                        child: SingleChildScrollView(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Row(children: [
                              const Expanded(
                                  child:
                                      DisplayText('Import backup', size: 30)),
                              SumiTextAction(
                                  label: 'Cancel',
                                  onTap: () => Navigator.pop(context)),
                            ]),
                            const SizedBox(height: 12),
                            Text(
                                '${_selected.length} of ${_entries.length} selected',
                                style: YomiText.ui(14, color: c.fg)),
                            Wrap(spacing: 14, children: [
                              SumiTextAction(
                                  label: 'Select all',
                                  onTap: () => setState(
                                      () => _selected.addAll(_visible))),
                              SumiTextAction(
                                  label: 'Select none',
                                  onTap: () => setState(
                                      () => _selected.removeAll(_visible))),
                            ]),
                            CupertinoSearchTextField(
                              placeholder: 'Search title or author',
                              backgroundColor: c.card,
                              itemColor: c.fg2,
                              style: YomiText.ui(15, color: c.fg),
                              onChanged: (value) => setState(() {
                                _query = value.trim().toLowerCase();
                                _filter();
                              }),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: [
                                SumiChip(
                                    label: 'Started only',
                                    active: _startedOnly,
                                    onTap: () => setState(() {
                                          _startedOnly = !_startedOnly;
                                          _filter();
                                        })),
                                for (final source in _sources.entries)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: SumiChip(
                                      key: ValueKey('source:${source.key}'),
                                      label: source.value,
                                      active: _source == source.key,
                                      onTap: () => setState(() {
                                        _source = _source == source.key
                                            ? null
                                            : source.key;
                                        _filter();
                                      }),
                                    ),
                                  ),
                              ]),
                            ),
                            if (_categories.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  for (final category in _categories)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: SumiChip(
                                        key: ValueKey('category:$category'),
                                        label: category,
                                        active: _category == category,
                                        onTap: () => setState(() {
                                          _category = _category == category
                                              ? null
                                              : category;
                                          _filter();
                                        }),
                                      ),
                                    ),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        )),
                      ),
                      Expanded(
                          child: _visible.isEmpty
                              ? const Center(
                                  child: SingleChildScrollView(
                                      child: EmptyState(
                                  icon: CupertinoIcons.search,
                                  title: 'No matching titles',
                                  message:
                                      'Try another search or change your filters.',
                                )))
                              : ListView.builder(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  itemCount: _visible.length,
                                  itemBuilder: (context, index) =>
                                      _row(_visible[index]),
                                )),
                      const SizedBox(height: 8),
                      Semantics(
                        button: true,
                        enabled: _selected.isNotEmpty,
                        child: SumiButton(
                          label: 'Import ${_selected.length} titles',
                          enabled: _selected.isNotEmpty,
                          onTap: () => Navigator.pop(context, [
                            for (final (index, entry) in _entries.indexed)
                              if (_selected.contains(index)) entry.manga,
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ponytail: long source warnings scroll within a fifth of the page.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight / 5),
                        child: SingleChildScrollView(
                            child: Text(
                          'Your library, categories and reading progress will be merged. '
                          'Existing progress is kept. Downloaded chapters are not imported.'
                          '${warnings.isEmpty ? '' : '\n\n$warnings'}',
                          style: YomiText.ui(12, color: c.fg2),
                        )),
                      ),
                      const SizedBox(height: 12),
                    ],
                  )),
        ),
      ),
    );
  }

  Widget _row(int index) {
    final c = context.yc;
    final entry = _entries[index];
    final manga = entry.manga;
    final selected = _selected.contains(index);
    void toggle() => setState(() {
          if (!_selected.remove(index)) _selected.add(index);
        });
    return Semantics(
      key: ValueKey('title:$index'),
      checked: selected,
      child: SumiPress(
        onTap: toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(children: [
            CupertinoCheckbox(
                value: selected, activeColor: c.ac, onChanged: (_) => toggle()),
            ClipRRect(
              borderRadius: BorderRadius.circular(context.radii.cover),
              child: SizedBox(
                  width: 48,
                  height: 68,
                  child: CoverImage(
                    url: manga['coverUrl'] as String?,
                    headers: _installed[entry.source]?.imageHeaders,
                  )),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(manga['title'] as String? ?? 'Untitled comic',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        YomiText.ui(15, color: c.fg, weight: FontWeight.w600)),
                Text(
                    entry.source.startsWith('tachiyomi:')
                        ? 'Not available in Yomi'
                        : _sources[entry.source]!,
                    style: YomiText.ui(12, color: c.fg2)),
                Text('${entry.chapters} chapters · ${entry.read} read',
                    style: YomiText.ui(12, color: c.fg2)),
                if (widget.existingSourceKeys.contains(manga['sourceKey']))
                  const SumiOverline('In library'),
                if (entry.categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final category in entry.categories)
                        SumiChip(label: category, active: false),
                    ]),
                  ),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}
