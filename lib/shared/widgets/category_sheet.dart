import 'package:flutter/cupertino.dart';

import '../../core/theme/yomi_theme.dart';
import 'sumi.dart';

/// Category picker. Shows a "No Categories" dialog when [allCategories] is
/// empty; otherwise a chip sheet that calls [onSave] with the selection.
Future<void> showCategorySheet(
  BuildContext context, {
  required List<String> allCategories,
  required List<String> initial,
  required Future<void> Function(List<String> categories) onSave,
}) {
  if (allCategories.isEmpty) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('No Categories'),
        content: const Text('Create categories in Settings → Categories first.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => CategorySheet(
        allCategories: allCategories, initial: initial, onSave: onSave),
  );
}

class CategorySheet extends StatefulWidget {
  const CategorySheet({
    super.key,
    required this.allCategories,
    required this.initial,
    required this.onSave,
  });

  final List<String> allCategories;
  final List<String> initial;
  final Future<void> Function(List<String> categories) onSave;

  @override
  State<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<CategorySheet> {
  late final List<String> _selected = List.from(widget.initial);

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final gutter = context.yomiGutter;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: EdgeInsets.fromLTRB(
          gutter, 20, gutter, MediaQuery.paddingOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SumiOverline('CATEGORIES', kanji: '類'),
          const SizedBox(height: 6),
          const DisplayText('Add to category', size: 26),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in widget.allCategories)
                SumiChip(
                  label: cat,
                  active: _selected.contains(cat),
                  onTap: () => setState(() => _selected.contains(cat)
                      ? _selected.remove(cat)
                      : _selected.add(cat)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SumiButton(
            label: 'Save',
            height: 50,
            radius: context.look.isSumi ? 4 : null,
            onTap: () async {
              await widget.onSave(_selected);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
