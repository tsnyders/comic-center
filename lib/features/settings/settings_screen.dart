import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/google_drive_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/reader_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/google_drive_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../library/category_management_screen.dart';
import 'backup_restore_screen.dart';
import 'changelog_screen.dart';
import 'drive_restore_screen.dart';

// ── Icon chip colors ──────────────────────────────────────────────────────
// Content-first redesign: the stock-iOS rainbow palette is replaced by a single
// cohesive warm-graphite chip (white glyph on top), so Settings reads as one
// considered surface rather than a row of system defaults. Semantic rows that
// want to stand out use [AppColors.accent] (coral) directly at the call site.
// Names are retained so existing call sites keep compiling.

class _IColor {
  static const _ink = Color(0xFF55545B); // warm graphite
  static const indigo  = _ink;
  static const orange  = _ink;
  static const green   = _ink;
  static const blue    = _ink;
  static const purple  = _ink;
  static const teal    = _ink;
  static const yellow  = _ink;
  static const gray    = _ink;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding    = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final dlLocation    = ref.watch(downloadLocationProvider);
    final brightness    = ref.watch(brightnessProvider);
    final direction     = ref.watch(readingDirectionProvider);
    final scale         = ref.watch(pageScaleModeProvider);
    final background    = ref.watch(readerBackgroundProvider);
    final driveAccount  = ref.watch(googleDriveProvider);

    return CupertinoPageScaffold(
      backgroundColor: context.backgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + AppSpacing.x4)),

          // ── Page title ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.x8,
              ),
              child: Text(
                'Settings',
                style: AppTextStyles.hero.copyWith(
                  fontSize: 26,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
          ),

          // ── Appearance ───────────────────────────────────────────────
          _buildSection(context, 'Appearance', [
            _SettingRow(
              icon: CupertinoIcons.moon_stars,
              iconBgColor: _IColor.indigo,
              label: 'Theme Mode',
              trailing: _SegmentedPicker<Brightness>(
                value: brightness,
                items: const [
                  (Brightness.dark, 'Dark'),
                  (Brightness.light, 'Light'),
                ],
                onChanged: (b) =>
                    ref.read(brightnessProvider.notifier).state = b,
              ),
              isLast: true,
            ),
          ]),

          // ── Library ──────────────────────────────────────────────────
          _buildSection(context, 'Library', [
            _SettingRow(
              icon: CupertinoIcons.folder,
              iconBgColor: _IColor.orange,
              label: 'Categories',
              trailing: const _Chevron(),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const CategoryManagementScreen(),
                ),
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.repeat,
              iconBgColor: _IColor.green,
              label: 'Auto-Update',
              trailing: CupertinoSwitch(
                value: true,
                activeTrackColor: context.downloadedColor,
                onChanged: (_) {},
              ),
              isLast: true,
            ),
          ]),

          // ── Reader ───────────────────────────────────────────────────
          _buildSection(context, 'Reader', [
            _SettingRow(
              icon: CupertinoIcons.book,
              iconBgColor: _IColor.blue,
              label: 'Reading Direction',
              trailing: _SegmentedPicker<ReadingDirection>(
                value: direction,
                items: const [
                  (ReadingDirection.ltr, 'L→R'),
                  (ReadingDirection.rtl, 'R→L'),
                  (ReadingDirection.vertical, 'Vert'),
                ],
                onChanged: (v) =>
                    ref.read(readingDirectionProvider.notifier).state = v,
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.resize_h,
              iconBgColor: _IColor.purple,
              label: 'Page Scale',
              trailing: _SegmentedPicker<PageScaleMode>(
                value: scale,
                items: const [
                  (PageScaleMode.fitWidth, 'Width'),
                  (PageScaleMode.fitHeight, 'Height'),
                  (PageScaleMode.original, '1:1'),
                ],
                onChanged: (v) =>
                    ref.read(pageScaleModeProvider.notifier).state = v,
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.moon,
              iconBgColor: _IColor.gray,
              label: 'Background',
              trailing: _SegmentedPicker<ReaderBackground>(
                value: background,
                items: const [
                  (ReaderBackground.black, 'Black'),
                  (ReaderBackground.white, 'White'),
                  (ReaderBackground.sepia, 'Sepia'),
                ],
                onChanged: (v) =>
                    ref.read(readerBackgroundProvider.notifier).state = v,
              ),
              isLast: true,
            ),
          ]),

          // ── Downloads ────────────────────────────────────────────────
          _buildSection(context, 'Downloads', [
            _SettingRow(
              icon: CupertinoIcons.folder_badge_plus,
              iconBgColor: _IColor.yellow,
              label: 'Storage Location',
              trailing: _SegmentedPicker<DownloadLocation>(
                value: dlLocation,
                items: const [
                  (DownloadLocation.local, 'Local'),
                  (DownloadLocation.googleDrive, 'Drive'),
                ],
                onChanged: (loc) =>
                    ref.read(downloadLocationProvider.notifier).state = loc,
              ),
              isLast: dlLocation != DownloadLocation.googleDrive,
            ),
            if (dlLocation == DownloadLocation.googleDrive)
              _SettingRow(
                icon: CupertinoIcons.cloud,
                iconBgColor: _IColor.teal,
                label: 'Google Drive Account',
                trailing: driveAccount != null
                    ? _DriveConnectedBadge(email: driveAccount.email)
                    : _DriveStatusBadge(),
                onTap: () => driveAccount != null
                    ? _signOutFromDrive(context, ref)
                    : _linkGoogleDrive(context, ref),
                isLast: true,
              ),
          ]),

          // ── Extensions ───────────────────────────────────────────────
          _buildSection(context, 'Extensions', [
            const _SettingRow(
              icon: CupertinoIcons.link,
              iconBgColor: _IColor.orange,
              label: 'Repository URL',
              trailing: _Chevron(),
              isLast: true,
            ),
          ]),

          // ── Backup & Sync ─────────────────────────────────────────────
          _buildSection(context, 'Backup & Sync', [
            _SettingRow(
              icon: CupertinoIcons.arrow_up_doc,
              iconBgColor: _IColor.teal,
              label: 'Export Backup',
              trailing: const _Chevron(),
              onTap: () => _exportBackup(context, ref),
            ),
            _SettingRow(
              icon: CupertinoIcons.arrow_down_doc,
              iconBgColor: _IColor.teal,
              label: 'Restore Backup',
              trailing: const _Chevron(),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const BackupRestoreScreen(),
                ),
              ),
              isLast: driveAccount == null,
            ),
            if (driveAccount != null) ...[
              _SettingRow(
                icon: CupertinoIcons.cloud_upload,
                iconBgColor: _IColor.teal,
                label: 'Backup to Drive',
                trailing: const _Chevron(),
                onTap: () => _backupToDrive(context, ref),
              ),
              _SettingRow(
                icon: CupertinoIcons.cloud_download,
                iconBgColor: _IColor.teal,
                label: 'Restore from Drive',
                trailing: const _Chevron(),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const DriveRestoreScreen(),
                  ),
                ),
                isLast: true,
              ),
            ],
            if (driveAccount == null)
              _SettingRow(
                icon: CupertinoIcons.cloud,
                iconBgColor: _IColor.teal,
                label: 'Connect Google Drive',
                trailing: const _Chevron(),
                onTap: () => _linkGoogleDrive(context, ref),
                isLast: true,
              ),
          ]),

          // ── About ────────────────────────────────────────────────────
          _buildSection(context, 'About', [
            _SettingRow(
              icon: CupertinoIcons.info,
              iconBgColor: _IColor.gray,
              label: 'Version',
              trailing: Text(
                '1.0.0',
                style: AppTextStyles.caption.copyWith(
                  color: context.textTertiaryColor,
                ),
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.sparkles,
              iconBgColor: _IColor.indigo,
              label: "What's New",
              trailing: const _Chevron(),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const ChangelogScreen(),
                ),
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.cloud_download,
              iconBgColor: _IColor.blue,
              label: 'Check for Updates',
              trailing: const _Chevron(),
              onTap: () => _checkForUpdates(context),
              isLast: true,
            ),
          ]),

          SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 90)),
        ],
      ),
    );
  }

  static Widget _buildSection(
      BuildContext context, String title, List<Widget> rows) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.x7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.x2,
                bottom: AppSpacing.x4,
              ),
              child: Text(
                title.toUpperCase(),
                style: AppTextStyles.overline.copyWith(
                  color: context.textTertiaryColor,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: context.surfaceElevatedColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: context.borderColor,
                  width: AppRadius.hairline,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: rows),
            ),
          ],
        ),
      ),
    );
  }

  // ── Update check ─────────────────────────────────────────────────────────

  static Future<void> _checkForUpdates(BuildContext context) async {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('Checking for Updates'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );

    try {
      final release = await UpdateService.fetchLatestRelease();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (release == null) {
        _showAlert(context, 'No Updates Available',
            'You are already on the latest version.');
        return;
      }

      showCupertinoDialog<void>(
        context: context,
        builder: (_) => _UpdateDialog(release: release),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Error', e.toString());
    }
  }

  // ── Google Drive actions ─────────────────────────────────────────────────

  static Future<void> _linkGoogleDrive(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Connect Google Drive'),
        content: const Text(
            'Linking a Google account enables cloud backup and restore of your library.\n\nSign in to proceed.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('Signing in…'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );

    try {
      final ok = await ref.read(googleDriveProvider.notifier).signIn();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!ok) return;
      final account = ref.read(googleDriveProvider);
      _showAlert(context, 'Google Drive Connected',
          'Signed in as ${account?.email ?? ''}');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
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

  static void _showDeveloperErrorDialog(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Google Drive Setup Required'),
        content: const Text(
          'Google Sign-In is not configured for this build.\n\n'
          'To fix:\n'
          '1. Register your app\'s SHA-1 fingerprint in Google Cloud Console\n'
          '2. Download the updated google-services.json and rebuild\n\n'
          'Get the debug fingerprint with:\n'
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

  static Future<void> _signOutFromDrive(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Google Drive'),
        content: Text(
            'Signed in as ${ref.read(googleDriveProvider)?.email ?? ''}.\n\nSign out?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(googleDriveProvider.notifier).signOut();
    }
  }

  static Future<void> _backupToDrive(
      BuildContext context, WidgetRef ref) async {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('Uploading to Drive…'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );
    try {
      final isar = ref.read(isarProvider);
      final categories = ref.read(libraryCategoriesProvider);
      final backup = await BackupService.export(
          isar: isar, categories: categories);
      await GoogleDriveService.uploadBackup(backup.file);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Backup Uploaded',
          'Uploaded ${backup.mangaCount ?? 0} manga to Google Drive.');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Upload Failed', e.toString());
    }
  }

  static Future<void> _exportBackup(
      BuildContext context, WidgetRef ref) async {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('Exporting Backup'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );

    try {
      final isar       = ref.read(isarProvider);
      final categories = ref.read(libraryCategoriesProvider);
      final backup     = await BackupService.export(
        isar: isar,
        categories: categories,
      );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Backup Exported',
          'Saved ${backup.mangaCount ?? 0} manga to:\n${backup.file.path}');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Export Failed', e.toString());
    }
  }

  static void _showAlert(BuildContext context, String title, String message) {
    showCupertinoDialog<void>(
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

// ── Generic segmented picker ─────────────────────────────────────────────

class _SegmentedPicker<T> extends StatelessWidget {
  const _SegmentedPicker({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.x3),
          _Pill(
            label: items[i].$2,
            selected: value == items[i].$1,
            onTap: () => onChanged(items[i].$1),
          ),
        ],
      ],
    );
  }
}

// ── Pill segment button ───────────────────────────────────────────────────

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
    final accent = context.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x5,
          vertical: AppSpacing.x2 + 1,
        ),
        decoration: BoxDecoration(
          color: selected ? accent : context.surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? accent : context.borderStrongColor,
            width: AppRadius.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textOnAccent : context.textSecondaryColor,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Google Drive status badges ────────────────────────────────────────────

class _DriveStatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final warning = context.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x5,
        vertical: AppSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: warning.withValues(alpha: 0.3),
          width: AppRadius.hairline,
        ),
      ),
      child: Text(
        'Not Connected',
        style: AppTextStyles.caption.copyWith(
          color: warning,
          fontWeight: FontWeight.w600,
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
          decoration: BoxDecoration(
            color: context.downloadedColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            email,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondaryColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Setting row ───────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.iconBgColor,
    required this.label,
    required this.trailing,
    this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconBgColor;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  /// When true the bottom divider is omitted (last row in a group).
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x6,
          vertical: AppSpacing.x5,
        ),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.borderColor,
                    width: AppRadius.hairline,
                  ),
                ),
              ),
        child: Row(
          children: [
            // Icon tile
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
            // Label
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textPrimaryColor,
                ),
              ),
            ),
            // Trailing control
            trailing,
          ],
        ),
      ),
    );
  }
}

// ── Chevron ───────────────────────────────────────────────────────────────

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: context.textTertiaryColor,
      );
}

// ── Update dialog ─────────────────────────────────────────────────────────

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.release});
  final ReleaseInfo release;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  bool _downloading = false;

  Future<void> _startDownload() async {
    final url = widget.release.apkUrl;
    if (url == null) {
      Navigator.of(context).pop();
      await UpdateService.openUrl(
          'https://github.com/tsnyders/comic-center/releases');
      return;
    }
    setState(() {
      _downloading = true;
      _progress    = 0;
    });
    try {
      await UpdateService.downloadAndInstall(
        url,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // installApk hands off to the system installer — dialog can close.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      Navigator.of(context).pop();
      showCupertinoDialog<void>(
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

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('Version ${widget.release.tag}'),
      content: _downloading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const CupertinoActivityIndicator(),
                const SizedBox(height: 8),
                Text(
                  _progress != null
                      ? '${(_progress! * 100).toStringAsFixed(0)}%'
                      : 'Starting…',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            )
          : Text(
              widget.release.body.length > 300
                  ? '${widget.release.body.substring(0, 300)}…'
                  : widget.release.body.isNotEmpty
                      ? widget.release.body
                      : 'A new version is available.',
            ),
      actions: _downloading
          ? const []
          : [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: _startDownload,
                child: Text(
                  widget.release.apkUrl != null
                      ? 'Download & Install'
                      : 'View Release',
                ),
              ),
            ],
    );
  }
}
