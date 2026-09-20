import 'package:flutter/cupertino.dart';
import 'package:isar/isar.dart';

import '../../core/database/models/manga_entry.dart';
import '../../core/services/duplicate_scan.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/sumi.dart';
import '../../shared/widgets/sumi_actions.dart';

typedef DuplicateResolveCallback = Future<void> Function(
    DuplicateGroup group, MangaEntry keep, bool deleteDownloads);
typedef DuplicateIgnoreCallback = Future<void> Function(String ignoreKey);

Future<void> showDuplicateResolverSheet(
  BuildContext context, {
  required Isar isar,
  required List<DuplicateGroup> groups,
  required Map<String, String> sourceNames,
}) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => DuplicateResolverSheet(
        isar: isar,
        groups: groups,
        sourceNames: sourceNames,
      ),
    );

MangaEntry defaultDuplicateKeep(DuplicateGroup group) {
  final ranked = [...group.entries]..sort((a, b) {
      final downloaded = b.downloadedCount.compareTo(a.downloadedCount);
      if (downloaded != 0) return downloaded;
      final read = b.readCount.compareTo(a.readCount);
      if (read != 0) return read;
      final left = a.addedToLibrary;
      final right = b.addedToLibrary;
      if (left != null || right != null) {
        if (left == null) return 1;
        if (right == null) return -1;
        final added = left.compareTo(right);
        if (added != 0) return added;
      }
      return a.entry.sourceKey.compareTo(b.entry.sourceKey);
    });
  return ranked.first.entry;
}

class DuplicateResolverSheet extends StatefulWidget {
  const DuplicateResolverSheet({
    super.key,
    required this.isar,
    required this.groups,
    required this.sourceNames,
    this.onResolve,
    this.onIgnore,
  });

  final Isar isar;
  final List<DuplicateGroup> groups;
  final Map<String, String> sourceNames;
  final DuplicateResolveCallback? onResolve;
  final DuplicateIgnoreCallback? onIgnore;

  @override
  State<DuplicateResolverSheet> createState() => _DuplicateResolverSheetState();
}

class _DuplicateResolverSheetState extends State<DuplicateResolverSheet> {
  late final List<DuplicateGroup> _groups = [...widget.groups];
  late final Map<String, int> _keepIds = {
    for (final group in _groups)
      group.ignoreKey: defaultDuplicateKeep(group).id,
  };
  bool _busy = false;

  Future<void> _keepBoth(DuplicateGroup group) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onIgnore != null) {
        await widget.onIgnore!(group.ignoreKey);
      } else {
        await ignoreDuplicateKey(group.ignoreKey);
      }
      if (!mounted) return;
      setState(() {
        _groups.remove(group);
        _keepIds.remove(group.ignoreKey);
        _busy = false;
      });
      if (_groups.isEmpty) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _showError(error);
    }
  }

  Future<void> _apply() async {
    if (_busy || _groups.isEmpty) return;
    final downloaded = _groups.fold<int>(0, (count, group) {
      final keepId = _keepIds[group.ignoreKey];
      return count +
          group.entries
              .where((stats) => stats.entry.id != keepId)
              .fold<int>(0, (sum, stats) => sum + stats.downloadedCount);
    });
    if (downloaded > 0) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text('Delete $downloaded downloaded chapters?'),
          content: const Text(
              'Downloads that cannot be moved to the title you keep will be deleted.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete & Apply'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      for (final group in [..._groups]) {
        final keepId = _keepIds[group.ignoreKey];
        final keep =
            group.entries.firstWhere((stats) => stats.entry.id == keepId).entry;
        final hasDiscardedDownloads = group.entries.any(
            (stats) => stats.entry.id != keep.id && stats.downloadedCount > 0);
        if (widget.onResolve != null) {
          await widget.onResolve!(group, keep, hasDiscardedDownloads);
        } else {
          await resolveGroup(widget.isar,
              group: group, keep: keep, deleteDownloads: hasDiscardedDownloads);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _showError(error);
    }
  }

  Future<void> _showError(Object error) => showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Could not resolve duplicates'),
          content: Text(error.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return CupertinoAlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.square_stack_3d_up, size: 16, color: c.ac),
          const SizedBox(width: 6),
          const Flexible(
              child: Text('Duplicate titles', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.56),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  child: Text(
                    'Choose the library copy to keep. Reading progress and categories will be merged.',
                    style: AppTextStyles.bodySmall.copyWith(color: c.fg2),
                  ),
                ),
                for (final group in _groups) _group(context, group),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: CupertinoActivityIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Decide later'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _busy ? null : _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, DuplicateGroup group) {
    final c = context.yc;
    final selected = _keepIds[group.ignoreKey];
    return Container(
      key: ValueKey('duplicate-group:${group.ignoreKey}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(context.radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DisplayText(group.title, size: 18, maxLines: 2),
          const SizedBox(height: 6),
          for (final stats in group.entries)
            _entry(context, group, stats, selected == stats.entry.id),
          Align(
            alignment: Alignment.centerRight,
            child: SumiTextAction(
              label: 'Keep both',
              onTap: _busy ? null : () => _keepBoth(group),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, DuplicateGroup group,
      DuplicateEntryStats stats, bool selected) {
    final c = context.yc;
    final entry = stats.entry;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Keep ${widget.sourceNames[entry.sourceId] ?? 'Not available'}',
      child: SumiPress(
        key: ValueKey('keep:${entry.id}'),
        onTap: _busy
            ? null
            : () => setState(() => _keepIds[group.ignoreKey] = entry.id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 2, right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.ac : null,
                  border: Border.all(color: selected ? c.ac : c.fg2, width: 2),
                ),
                child: selected
                    ? Icon(CupertinoIcons.check_mark,
                        size: 12, color: c.onAccent)
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.sourceNames[entry.sourceId] ?? 'Not available',
                        style: YomiText.ui(13,
                            color: c.fg, weight: FontWeight.w600)),
                    Text(
                      '${stats.chapterCount} chapters · ${stats.readCount} read',
                      style: YomiText.ui(11, color: c.fg2),
                    ),
                    Text(_addedLabel(stats.addedToLibrary),
                        style: YomiText.ui(11, color: c.fg2)),
                    if (stats.downloadedCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SumiChip(
                          label: '${stats.downloadedCount} downloaded',
                          active: true,
                        ),
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

  String _addedLabel(DateTime? date) {
    if (date == null) return 'Date added unavailable';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Added ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
