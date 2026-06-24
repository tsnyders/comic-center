import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/library_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          SizedBox(
            height: topPadding + 56,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: CupertinoButton(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '‹ Back',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Categories', style: AppTextStyles.sectionTitle),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _addController,
                    placeholder: 'New category name',
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.border, width: 0.5),
                    ),
                    style: AppTextStyles.bodyMedium,
                    onSubmitted: (_) => _addCategory(),
                  ),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _addCategory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        color: AppColors.textOnAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: categoriesAsync.when(
              loading: () =>
                  const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (cats) => cats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.folder_badge_plus,
                            size: 48,
                            color: AppColors.textQuaternary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No categories yet',
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add one above to organise your library.',
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                          20, 0, 20, bottomPadding + 20),
                      itemCount: cats.length,
                      itemBuilder: (context, i) => _CategoryTile(
                        name: cats[i],
                        onRename: () =>
                            _showRenameDialog(context, cats[i]),
                        onDelete: () =>
                            _confirmDelete(context, cats[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    await ref.read(categoryNotifierProvider.notifier).add(name);
    _addController.clear();
  }

  void _showRenameDialog(BuildContext context, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Rename Category'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              Navigator.pop(context);
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                await ref
                    .read(categoryNotifierProvider.notifier)
                    .rename(oldName, newName);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String name) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Delete "$name"? Manga assigned to this category won\'t be deleted.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(categoryNotifierProvider.notifier)
                  .remove(name);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.onRename,
    required this.onDelete,
  });

  final String name;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.folder,
              size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: AppTextStyles.bodyMedium),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minSize: 36,
            onPressed: onRename,
            child: const Icon(
              CupertinoIcons.pencil,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minSize: 36,
            onPressed: onDelete,
            child: const Icon(
              CupertinoIcons.trash,
              size: 18,
              color: AppColors.unread,
            ),
          ),
        ],
      ),
    );
  }
}
