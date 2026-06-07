import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/google_drive_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/google_drive_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'drive_restore_screen.dart';

// ── Icon background colors (iOS Settings palette) ─────────────────────────

class _IColor {
  static const indigo = Color(0xFF5E5CE6);
  static const orange = Color(0xFFFF9F0A);
  static const green = Color(0xFF30D158);
  static const blue = Color(0xFF0A84FF);
  static const purple = Color(0xFFBF5AF2);
  static const teal = Color(0xFF32ADE6);
  static const yellow = Color(0xFFFFD60A);
  static const gray = Color(0xFF636366);
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final dlLocation = ref.watch(downloadLocationProvider);
    final brightness = ref.watch(brightnessProvider);
    final driveAccount = ref.watch(googleDriveProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(
                'Settings',
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // ── Appearance ───────────────────────────────────────────────
          _buildSection(context, 'Appearance', [
            _SettingRow(
              icon: CupertinoIcons.moon_stars,
              iconBgColor: _IColor.indigo,
              label: 'Theme',
              trailing: _ThemePicker(
                brightness: brightness,
                onChanged: (b) =>
                    ref.read(brightnessProvider.notifier).state = b,
              ),
            ),
          ]),

          // ── Library ──────────────────────────────────────────────────
          _buildSection(context, 'Library', [
            _SettingRow(
              icon: CupertinoIcons.folder,
              iconBgColor: _IColor.orange,
              label: 'Categories',
              trailing: const _Chevron(),
            ),
            _SettingRow(
              icon: CupertinoIcons.repeat,
              iconBgColor: _IColor.green,
              label: 'Auto-Update',
              trailing: CupertinoSwitch(value: true, onChanged: (_) {}),
            ),
          ]),

          // ── Reader ───────────────────────────────────────────────────
          _buildSection(context, 'Reader', [
            _SettingRow(
              icon: CupertinoIcons.book,
              iconBgColor: _IColor.blue,
              label: 'Reading Direction',
              trailing: const Text(
                'L→R',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.resize_h,
              iconBgColor: _IColor.purple,
              label: 'Page Scale',
              trailing: const Text(
                'Fit Width',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.moon,
              iconBgColor: _IColor.gray,
              label: 'Background',
              trailing: const Text(
                'Black',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
          ]),

          // ── Downloads ────────────────────────────────────────────────
          _buildSection(context, 'Downloads', [
            _SettingRow(
              icon: CupertinoIcons.folder_badge_plus,
              iconBgColor: _IColor.yellow,
              label: 'Storage Location',
              trailing: _LocationPicker(
                value: dlLocation,
                onChanged: (loc) =>
                    ref.read(downloadLocationProvider.notifier).state = loc,
              ),
            ),
          ]),

          // ── Backup & Sync ─────────────────────────────────────────────
          _buildSection(context, 'Backup & Sync', [
            // Google Drive link/unlink row
            _SettingRow(
              icon: CupertinoIcons.cloud,
              iconBgColor: _IColor.teal,
              label: 'Google Drive',
              trailing: driveAccount == null
                  ? _LinkDriveButton(
                      onTap: () => _linkGoogleDrive(context, ref),
                    )
                  : _DriveConnectedBadge(email: driveAccount.email),
              onTap: driveAccount != null
                  ? () => _signOutFromDrive(context, ref)
                  : null,
            ),
            _SettingRow(
              icon: CupertinoIcons.arrow_up_doc,
              iconBgColor: _IColor.teal,
              label: 'Export Backup',
              trailing: const _Chevron(),
              onTap: () => _exportBackup(context, ref, driveAccount?.email),
            ),
            if (driveAccount != null)
              _SettingRow(
                icon: CupertinoIcons.arrow_down_doc,
                iconBgColor: _IColor.teal,
                label: 'Restore from Drive',
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  CupertinoPageRoute(
                    builder: (_) => const DriveRestoreScreen(),
                  ),
                ),
              ),
          ]),

          // ── Extensions ───────────────────────────────────────────────
          _buildSection(context, 'Extensions', [
            _SettingRow(
              icon: CupertinoIcons.link,
              iconBgColor: _IColor.orange,
              label: 'Repository URL',
              trailing: const _Chevron(),
            ),
            _SettingRow(
              icon: CupertinoIcons.cloud_download,
              iconBgColor: _IColor.blue,
              label: 'Check for Updates',
              trailing: const _Chevron(),
            ),
          ]),

          // ── About ────────────────────────────────────────────────────
          _buildSection(context, 'About', [
            _SettingRow(
              icon: CupertinoIcons.info,
              iconBgColor: _IColor.gray,
              label: 'Version',
              trailing: const Text(
                '1.0.0',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.arrow_down_to_line,
              iconBgColor: _IColor.blue,
              label: 'Check for App Updates',
              trailing: const _Chevron(),
              onTap: () => _checkForAppUpdate(context),
            ),
          ]),

          SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 90)),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> rows,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.5),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(children: rows),
            ),
          ],
        ),
      ),
    );
  }

  // ── Google Drive actions ─────────────────────────────────────────────────

  Future<void> _linkGoogleDrive(BuildContext context, WidgetRef ref) async {
    try {
      final ok = await ref.read(googleDriveProvider.notifier).signIn();
      if (!ok && context.mounted) {
        _showAlert(context, 'Sign-In Cancelled', 'Google sign-in was cancelled.');
      }
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString();
      if (msg.contains('ApiException: 10') ||
          msg.contains('DEVELOPER_ERROR') ||
          msg.contains(': 10:')) {
        _showDeveloperErrorDialog(context);
      } else {
        _showAlert(context, 'Sign-In Failed', msg);
      }
    }
  }

  Future<void> _signOutFromDrive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Sign Out of Drive?'),
        content: const Text(
          'Your backups will remain in Google Drive.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(googleDriveProvider.notifier).signOut();
    }
  }

  Future<void> _exportBackup(
    BuildContext context,
    WidgetRef ref,
    String? driveEmail,
  ) async {
    final isar = ref.read(isarProvider);
    try {
      final file = await BackupService.export(isar);
      if (driveEmail != null) {
        final ts = DateTime.now();
        final name =
            'yomi_backup_${ts.year}${_pad(ts.month)}${_pad(ts.day)}_${_pad(ts.hour)}${_pad(ts.minute)}.json.gz';
        await GoogleDriveService.uploadBackup(file, name);
        if (context.mounted) {
          _showAlert(
            context,
            'Backup Complete',
            'Saved to Google Drive as $name',
          );
        }
      } else {
        if (context.mounted) {
          _showAlert(
            context,
            'Backup Exported',
            'Saved locally at:\n${file.path}',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showAlert(context, 'Backup Failed', e.toString());
      }
    }
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  // ── App update ────────────────────────────────────────────────────────────

  Future<void> _checkForAppUpdate(BuildContext context) async {
    _showAlert(
      context,
      'Checking…',
      'Looking for updates on GitHub.',
    );
    const currentVersion = '1.0.0';
    final info = await UpdateService.checkForUpdate(currentVersion);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // close the "Checking" dialog

    if (info == null) {
      _showAlert(context, 'Up to Date', 'You\'re running the latest version.');
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (_) => _UpdateDialog(info: info),
    );
  }

  // ── Developer error dialog ────────────────────────────────────────────────

  void _showDeveloperErrorDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Google Drive Setup Required'),
        content: const Text(
          'Google Sign-In is not configured for this build.\n\n'
          'To fix:\n'
          '1. Register your app\'s SHA-1 fingerprint in Google Cloud Console\n'
          '2. Download the updated google-services.json\n'
          '3. Rebuild the app\n\n'
          'Run in terminal:\n'
          'keytool -list -v -keystore ~/.android/debug.keystore '
          '-alias androiddebugkey -storepass android -keypass android',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAlert(BuildContext context, String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
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
}

// ── Update dialog ─────────────────────────────────────────────────────────

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  bool _downloading = false;

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _progress = 0; });
    try {
      await UpdateService.downloadAndInstall(
        widget.info.downloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        Navigator.of(context).pop();
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Update Failed'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('Update Available — v${widget.info.version}'),
      content: _downloading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                CupertinoActivityIndicator(),
                const SizedBox(height: 8),
                Text(
                  _progress != null
                      ? '${(_progress! * 100).toStringAsFixed(0)}%'
                      : 'Starting…',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            )
          : Text(widget.info.releaseNotes.isEmpty
              ? 'A new version is available. Update now?'
              : widget.info.releaseNotes),
      actions: _downloading
          ? []
          : [
              CupertinoDialogAction(
                onPressed: _startDownload,
                child: const Text('Download & Install'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: false,
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
            ],
    );
  }
}

// ── Theme / brightness picker ─────────────────────────────────────────────

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.brightness, required this.onChanged});
  final Brightness brightness;
  final ValueChanged<Brightness> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          label: 'Dark',
          selected: brightness == Brightness.dark,
          onTap: () => onChanged(Brightness.dark),
        ),
        const SizedBox(width: 6),
        _Pill(
          label: 'Light',
          selected: brightness == Brightness.light,
          onTap: () => onChanged(Brightness.light),
        ),
      ],
    );
  }
}

// ── Storage location picker ───────────────────────────────────────────────

class _LocationPicker extends StatelessWidget {
  const _LocationPicker({required this.value, required this.onChanged});
  final DownloadLocation value;
  final ValueChanged<DownloadLocation> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          label: 'Local',
          selected: value == DownloadLocation.local,
          onTap: () => onChanged(DownloadLocation.local),
        ),
        const SizedBox(width: 6),
        _Pill(
          label: 'Drive',
          selected: value == DownloadLocation.googleDrive,
          onTap: () => onChanged(DownloadLocation.googleDrive),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderStrong,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? CupertinoColors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Google Drive badges ───────────────────────────────────────────────────

class _LinkDriveButton extends StatelessWidget {
  const _LinkDriveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.accent.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: const Text(
          'Link',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DriveConnectedBadge extends StatelessWidget {
  const _DriveConnectedBadge({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.downloaded,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            email,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Shared row widgets ────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.iconBgColor,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Colored icon badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 16, color: CupertinoColors.white),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => const Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: AppColors.textTertiary,
      );
}
