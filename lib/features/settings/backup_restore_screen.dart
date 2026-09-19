import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/google_drive_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/services/backup_file_picker.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/tachiyomi_backup.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'drive_restore_screen.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});
  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  List<BackupFile> _backups = [];
  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final backups = await BackupService.listBackups();
      if (mounted) setState(() => _backups = backups);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Could not list backups saved in Yomi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        navigationBar:
            const CupertinoNavigationBar(middle: Text('Restore Backup')),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                  'Restore your library and reading progress. Downloaded '
                  'chapters are not included.',
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
              _RestoreChoice(
                  icon: CupertinoIcons.cloud,
                  title: 'Google Drive',
                  subtitle: 'Choose a Yomi backup from your Google account.',
                  onTap: _busy ? null : _openDrive),
              _RestoreChoice(
                  icon: CupertinoIcons.folder,
                  title: 'System storage',
                  subtitle: 'Choose a Yomi backup file on your device.',
                  onTap:
                      _busy ? null : () => _pickAndRestore(tachiyomi: false)),
              _RestoreChoice(
                  icon: CupertinoIcons.book,
                  title: 'Import from Tachiyomi',
                  subtitle:
                      'Choose a .tachibk or .proto.gz backup in your Tachiyomi '
                      'folder. If it opens elsewhere, browse to your backup.',
                  onTap: _busy ? null : () => _pickAndRestore(tachiyomi: true)),
              if (_busy)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: CupertinoActivityIndicator()),
              const SizedBox(height: 20),
              Row(children: [
                const Expanded(
                    child: Text('Saved in Yomi',
                        style: AppTextStyles.sectionTitle)),
                CupertinoButton(
                    onPressed: _busy || _loading ? null : _load,
                    child: const Icon(CupertinoIcons.refresh,
                        semanticLabel: 'Refresh saved backups')),
              ]),
              if (_loading)
                const CupertinoActivityIndicator()
              else if (_loadError != null)
                Text(_loadError!, style: AppTextStyles.bodySmall)
              else if (_backups.isEmpty)
                const Text('No backups saved in Yomi yet.',
                    style: AppTextStyles.bodySmall)
              else
                for (final backup in _backups)
                  _RestoreChoice(
                      icon: CupertinoIcons.doc_text,
                      title: backup.displayName,
                      subtitle: 'Restore library and reading progress',
                      onTap: _busy ? null : () => _restoreLocal(backup.file)),
            ],
          ),
        ),
      );

  Future<void> _openDrive() async {
    setState(() => _busy = true);
    try {
      if (ref.read(googleDriveProvider) == null) {
        final signedIn = await ref.read(googleDriveProvider.notifier).signIn();
        if (!signedIn) return;
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
          CupertinoPageRoute(builder: (_) => const DriveRestoreScreen()));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndRestore({required bool tachiyomi}) async {
    if (_busy) return;
    setState(() => _busy = true);
    File? file;
    try {
      file = await BackupFilePicker.pick(tachiyomi: tachiyomi);
      if (file == null || !mounted) return;
      TachiyomiBackup? imported;
      if (tachiyomi) {
        if (await file.length() > TachiyomiBackup.maxFileBytes) {
          throw const FormatException('The backup exceeds 32 MB.');
        }
        imported =
            await compute(TachiyomiBackup.decode, await file.readAsBytes());
      }
      if (!mounted) return;
      final confirmed = await _confirm(imported);
      if (confirmed && mounted) await _doRestore(file, imported: imported);
    } catch (error) {
      _showError(error);
    } finally {
      // This is the picker-created cache copy, never the user's original.
      if (file != null) {
        try {
          await file.delete();
        } on FileSystemException {/* already removed */}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreLocal(File file) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (await _confirm(null) && mounted) await _doRestore(file);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(TachiyomiBackup? imported) async {
    final warnings = imported == null ? '' : _sourceWarnings(imported);
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: Text(imported == null ? 'Restore backup' : 'Import backup'),
            content: Text([
              if (imported != null)
                '${imported.mangaCount} titles and ${imported.chapterCount} chapter records.',
              'Your library, categories and reading progress will be merged. '
                  'Existing progress is kept. Downloaded chapters are not imported.',
              if (warnings.isNotEmpty) warnings,
            ].join('\n\n')),
            actions: [
              CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(imported == null ? 'Restore' : 'Import')),
            ],
          ),
        ) ??
        false;
  }

  String _sourceWarnings(TachiyomiBackup imported) {
    final installed = ref.read(sourceRegistryProvider).map((s) => s.id).toSet();
    final disabled = imported.connectedSources.entries
        .where((source) => !installed.contains(source.key))
        .map((source) => source.value)
        .toSet();
    return [
      if (imported.unavailableSources.isNotEmpty)
        'Yomi cannot connect these sources yet: ${imported.unavailableSources.join(', ')}. '
            'Their titles and progress will be saved, but their chapters cannot be read online.',
      if (disabled.isNotEmpty)
        'Enable these sources in Browse to read online: ${disabled.join(', ')}.',
    ].join('\n\n');
  }

  Future<void> _doRestore(File file, {TachiyomiBackup? imported}) async {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: CupertinoAlertDialog(
            title: Text('Restoring library'),
            content: Padding(
                padding: EdgeInsets.only(top: 12),
                child: CupertinoActivityIndicator())),
      ),
    );
    try {
      final isar = ref.read(isarProvider);
      final categories = ref.read(categoryNotifierProvider.notifier);
      final result = imported == null
          ? await BackupService.restore(isar: isar, file: file)
          : await BackupService.restorePayload(
              isar: isar, json: imported.payload);
      await categories.merge(result.categories);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _alert(
          'Restore complete',
          'Restored ${result.mangaCount} titles and ${result.chapterCount} chapter records. '
              'No downloaded chapters were imported.');
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    _alert(
        'Could not restore',
        switch (error) {
          MissingPluginException() =>
            'File selection is currently available on Android. '
                'You can also restore a backup saved in Yomi or from Google Drive.',
          FormatException(:final message) =>
            '$message\n\nFor Tachiyomi, create a backup '
                'in its Backup settings and select the .tachibk or .proto.gz file.',
          PlatformException(:final message) =>
            message ?? 'Could not open the file picker.',
          _ => error.toString(),
        });
  }

  void _alert(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'))
          ]),
    );
  }
}

class _RestoreChoice extends StatelessWidget {
  const _RestoreChoice(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CupertinoButton(
          padding: const EdgeInsets.all(14),
          color: AppColors.surfaceElevated,
          onPressed: onTap,
          child: Row(children: [
            Icon(icon, size: 22, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ])),
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: AppColors.textSecondary),
          ]),
        ),
      );
}
