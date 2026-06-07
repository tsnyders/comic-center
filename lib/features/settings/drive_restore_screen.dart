import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/providers/database_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/google_drive_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class DriveRestoreScreen extends ConsumerStatefulWidget {
  const DriveRestoreScreen({super.key});

  @override
  ConsumerState<DriveRestoreScreen> createState() => _DriveRestoreScreenState();
}

class _DriveRestoreScreenState extends ConsumerState<DriveRestoreScreen> {
  bool _loading = true;
  List<DriveBackupFile> _backups = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final backups = await GoogleDriveService.listBackups();
      if (mounted) setState(() { _backups = backups; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _restore(DriveBackupFile backup) async {
    final confirmed = await _confirm(backup.displayName);
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);
    try {
      final dir = await getTemporaryDirectory();
      final localPath = '${dir.path}/${backup.name}';
      final file = await GoogleDriveService.downloadBackup(backup.id, localPath);
      final isar = ref.read(isarProvider);
      await BackupService.restore(isar, File(file.path));
      if (mounted) {
        Navigator.of(context).pop();
        _showSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError(e.toString());
      }
    }
  }

  Future<bool> _confirm(String name) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Restore Backup?'),
        content: Text(
          'Restoring "$name" will overwrite your current library. This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccess() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Restored'),
        content: const Text('Your library has been restored from Drive.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Restore Failed'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.chevron_left,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Restore from Drive',
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_circle,
                        size: 40,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_backups.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No backups found in Drive.',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: _backups.length,
                itemBuilder: (context, i) {
                  final b = _backups[i];
                  return GestureDetector(
                    onTap: () => _restore(b),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF32ADE6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              CupertinoIcons.cloud_download,
                              size: 18,
                              color: Color(0xFF32ADE6),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.displayName,
                                  style: AppTextStyles.bodyMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b.sizeDisplay,
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
