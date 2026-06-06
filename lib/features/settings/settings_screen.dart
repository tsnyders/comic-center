import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/library_provider.dart';
import '../../core/providers/reader_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/update_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../library/category_management_screen.dart';
import 'backup_restore_screen.dart';

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
              label: 'Auto-Update',
              trailing: CupertinoSwitch(value: true, onChanged: (_) {}),
            ),
          ]),

          // ── Reader ───────────────────────────────────────────────────
          _buildSection(context, 'Reader', [
            _SettingRow(
              icon: CupertinoIcons.book,
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
            ),
          ]),

          // ── Downloads ────────────────────────────────────────────────
          _buildSection(context, 'Downloads', [
            _SettingRow(
              icon: CupertinoIcons.folder_badge_plus,
              label: 'Storage Location',
              trailing: _LocationPicker(
                value: dlLocation,
                onChanged: (loc) =>
                    ref.read(downloadLocationProvider.notifier).state = loc,
              ),
            ),
            if (dlLocation == DownloadLocation.googleDrive)
              _SettingRow(
                icon: CupertinoIcons.cloud,
                label: 'Google Drive',
                trailing: _DriveStatusBadge(),
              ),
          ]),

          // ── Extensions ───────────────────────────────────────────────
          _buildSection(context, 'Extensions', [
            _SettingRow(
              icon: CupertinoIcons.link,
              label: 'Repository URL',
              trailing: const _Chevron(),
            ),
            _SettingRow(
              icon: CupertinoIcons.cloud_download,
              label: 'Check for Updates',
              trailing: const _Chevron(),
              onTap: () => _checkForUpdates(context),
            ),
          ]),

          // ── Backup & Sync ─────────────────────────────────────────────
          _buildSection(context, 'Backup & Sync', [
            _SettingRow(
              icon: CupertinoIcons.arrow_up_doc,
              label: 'Export Backup',
              trailing: const _Chevron(),
              onTap: () => _exportBackup(context, ref),
            ),
            _SettingRow(
              icon: CupertinoIcons.arrow_down_doc,
              label: 'Restore Backup',
              trailing: const _Chevron(),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const BackupRestoreScreen(),
                ),
              ),
            ),
          ]),

          // ── About ────────────────────────────────────────────────────
          _buildSection(context, 'About', [
            _SettingRow(
              icon: CupertinoIcons.info,
              label: 'Version',
              trailing: const Text(
                '1.0.0',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
          ]),

          SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 90)),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> rows) {
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
        showCupertinoDialog<void>(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('No Updates Found'),
            content: const Text(
                'Could not reach the update server. Check your connection.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text('Version ${release.tag}'),
          content: Text(release.body.length > 200
              ? '${release.body.substring(0, 200)}…'
              : release.body),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            if (release.apkUrl != null)
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(context);
                  UpdateService.openUrl(release.apkUrl!);
                },
                child: const Text('Download'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Error'),
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

  static Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
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
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Backup Exported'),
          content: Text(
            'Saved ${backup.mangaCount ?? 0} manga to:\n${backup.file.path}',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Export Failed'),
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

// ── Generic segmented picker ─────────────────────────────────────────────────

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
          if (i > 0) const SizedBox(width: 4),
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
  const _Pill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderStrong,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? CupertinoColors.white : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Google Drive status badge ─────────────────────────────────────────────

class _DriveStatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        'Setup Required',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Shared row widgets ────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
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
