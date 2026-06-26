import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  List<DriveBackupFile>? _backups;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bs = await GoogleDriveService.listBackups();
      if (mounted) {
        setState(() {
          _backups = bs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backups = [];
          _loading = false;
        });
        _showError(e.toString());
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
                  alignment: Alignment.bottomRight,
                  child: CupertinoButton(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    onPressed: _load,
                    child: const Icon(
                      CupertinoIcons.refresh,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Restore from Drive',
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : (_backups == null || _backups!.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.cloud,
                              size: 48,
                              color: AppColors.textQuaternary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Drive backups found',
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Backup to Drive first from Settings.',
                              style: AppTextStyles.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            EdgeInsets.fromLTRB(20, 8, 20, bottomPadding + 20),
                        itemCount: _backups!.length,
                        itemBuilder: (_, i) => _DriveTile(
                          backup: _backups![i],
                          onRestore: () =>
                              _confirmRestore(context, _backups![i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(BuildContext context, DriveBackupFile backup) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Restore from Drive'),
        content: const Text(
            'This will merge the backup with your current library. Existing entries will be updated.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              Navigator.pop(context);
              await _doRestore(backup);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _doRestore(DriveBackupFile backup) async {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('Downloading…'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );
    try {
      final file =
          await GoogleDriveService.downloadBackup(backup.id, backup.name);
      if (!mounted) return;
      final isar = ref.read(isarProvider);
      final result = await BackupService.restore(isar: isar, file: file);
      if (!mounted) return;
      Navigator.of(context).pop();
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Restore Complete'),
          content: Text(
              'Restored ${result.mangaCount} manga and ${result.chapterCount} chapters.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showError(e.toString());
    }
  }
}

class _DriveTile extends StatelessWidget {
  const _DriveTile({required this.backup, required this.onRestore});
  final DriveBackupFile backup;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRestore,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.cloud, size: 22, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(backup.displayName, style: AppTextStyles.bodyMedium),
                  Text(
                    backup.sizeDisplay,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.arrow_counterclockwise,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
