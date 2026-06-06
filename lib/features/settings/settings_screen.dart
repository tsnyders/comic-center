import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final dlLocation = ref.watch(downloadLocationProvider);
    final brightness = ref.watch(brightnessProvider);

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
              trailing: const Text(
                'L→R',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.resize_h,
              label: 'Page Scale',
              trailing: const Text(
                'Fit Width',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
            _SettingRow(
              icon: CupertinoIcons.moon,
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
            ),
          ]),

          // ── Backup & Sync ─────────────────────────────────────────────
          _buildSection(context, 'Backup & Sync', [
            _SettingRow(
              icon: CupertinoIcons.arrow_up_doc,
              label: 'Export Backup',
              trailing: const _Chevron(),
            ),
            _SettingRow(
              icon: CupertinoIcons.arrow_down_doc,
              label: 'Restore Backup',
              trailing: const _Chevron(),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : AppColors.borderStrong,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
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
