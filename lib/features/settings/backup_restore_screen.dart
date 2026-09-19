import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/google_drive_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/reader_provider.dart';
import '../../core/providers/settings_provider.dart';
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
      if (!tachiyomi) {
        await _restoreYomi(file);
        return;
      }
      if (await file.length() > TachiyomiBackup.maxFileBytes) {
        throw const FormatException('The backup exceeds 32 MB.');
      }
      final imported =
          await compute(TachiyomiBackup.decode, await file.readAsBytes());
      if (!mounted) return;
      if (await _confirmTachiyomi(imported) && mounted) {
        await _importTachiyomi(imported);
      }
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
      await _restoreYomi(file);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreYomi(File file) async {
    final result = await restoreYomiBackup(context, ref, file);
    if (result != null && mounted) {
      _alert('Restore complete', restoreSummary(result));
    }
  }

  Future<bool> _confirmTachiyomi(TachiyomiBackup imported) async {
    final warnings = _sourceWarnings(imported);
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Import backup'),
            content: Text([
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
                  child: const Text('Import')),
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

  Future<void> _importTachiyomi(TachiyomiBackup imported) async {
    _showProgress(context);
    try {
      final isar = ref.read(isarProvider);
      final categories = ref.read(categoryNotifierProvider.notifier);
      final result =
          await BackupService.restorePayload(isar: isar, json: imported.payload);
      await categories.merge(result.categories);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _alert('Restore complete', restoreSummary(result));
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

// ── Yomi restore flow (shared with DriveRestoreScreen) ────────────────────────

/// Restores a Yomi backup file: asks for the passphrase only when the file
/// needs one, previews counts with a "Restore settings too" toggle, then
/// merges. Returns null when the user cancels; throws on failure.
Future<RestoreResult?> restoreYomiBackup(
    BuildContext context, WidgetRef ref, File file) async {
  String? passphrase;
  if (await BackupService.needsPassphrase(file)) {
    if (!context.mounted) return null;
    passphrase = await promptBackupPassphrase(context,
        title: 'Backup passphrase',
        message: 'This backup is encrypted. Enter the passphrase it was '
            'created with.',
        action: 'Unlock');
    if (passphrase == null) return null;
  }
  final json = await BackupService.decode(file, passphrase: passphrase);
  final counts = BackupService.summarize(json);
  if (!context.mounted) return null;
  final restoreSettings = await _confirmYomiRestore(context, counts);
  if (restoreSettings == null || !context.mounted) return null;
  _showProgress(context);
  try {
    final result = await BackupService.restorePayload(
        isar: ref.read(isarProvider),
        json: json,
        restoreSettings: restoreSettings);
    await ref.read(categoryNotifierProvider.notifier).merge(result.categories);
    if (result.settingsCount > 0) _reloadSettings(ref);
    return result;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

String restoreSummary(RestoreResult result) =>
    'Restored ${result.mangaCount} titles, ${result.chapterCount} chapter '
    'records and ${result.settingsCount} settings. No downloaded chapters '
    'were imported.';

/// Returns the entered passphrase, or null when cancelled or left empty.
Future<String?> promptBackupPassphrase(BuildContext context,
    {required String title,
    required String message,
    required String action}) async {
  final controller = TextEditingController();
  final entered = await showCupertinoDialog<String>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Passphrase',
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
        ),
      ]),
      actions: [
        CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(action)),
      ],
    ),
  );
  controller.dispose();
  return entered == null || entered.isEmpty ? null : entered;
}

Future<bool?> _confirmYomiRestore(BuildContext context,
    ({int titles, int chapters, int categories, int settings}) counts) {
  var restoreSettings = true;
  return showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setState) => CupertinoAlertDialog(
        title: const Text('Restore backup'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${counts.titles} titles, ${counts.chapters} chapter records, '
              '${counts.categories} categories and ${counts.settings} '
              'settings.\n\nYour library, categories and reading progress '
              'will be merged. Existing progress is kept. Downloaded chapters '
              'are not imported.'),
          if (counts.settings > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                const Expanded(child: Text('Restore settings too')),
                CupertinoSwitch(
                    value: restoreSettings,
                    onChanged: (value) =>
                        setState(() => restoreSettings = value)),
              ]),
            ),
        ]),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, restoreSettings),
              child: const Text('Restore')),
        ],
      ),
    ),
  );
}

void _showProgress(BuildContext context) {
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
}

/// Settings providers read SharedPreferences once when created, so restored
/// values only show up after they are rebuilt.
void _reloadSettings(WidgetRef ref) {
  for (final provider in <ProviderOrFamily>[
    readingDirectionProvider,
    mangaReadingDirectionProvider,
    pageScaleModeProvider,
    readerBackgroundProvider,
    defaultReaderModeProvider,
    mangaReaderModeProvider,
    brightnessProvider,
    autoCheckUpdatesProvider,
    accentIndexProvider,
    coverSizeProvider,
    densityProvider,
    lookProvider,
    onboardingDoneProvider,
    selectedGenresProvider,
    hapticsProvider,
    wifiOnlyProvider,
  ]) {
    ref.invalidate(provider);
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
