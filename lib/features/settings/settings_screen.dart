import 'package:flutter/cupertino.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text('Settings',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  )),
            ),
          ),

          // Sections
          _buildSection('Library', [
            _SettingRow(icon: CupertinoIcons.folder, label: 'Categories', trailing: _Chevron()),
            _SettingRow(icon: CupertinoIcons.repeat, label: 'Auto-Update', trailing: CupertinoSwitch(value: true, onChanged: (_) {})),
          ]),

          _buildSection('Reader', [
            _SettingRow(icon: CupertinoIcons.book, label: 'Reading Direction', trailing: const Text('L→R', style: TextStyle(color: AppColors.textTertiary, fontSize: 14))),
            _SettingRow(icon: CupertinoIcons.resize_h, label: 'Page Scale', trailing: const Text('Fit Width', style: TextStyle(color: AppColors.textTertiary, fontSize: 14))),
            _SettingRow(icon: CupertinoIcons.moon, label: 'Background', trailing: const Text('Black', style: TextStyle(color: AppColors.textTertiary, fontSize: 14))),
          ]),

          _buildSection('Extensions', [
            _SettingRow(icon: CupertinoIcons.link, label: 'Repository URL', trailing: _Chevron()),
            _SettingRow(icon: CupertinoIcons.cloud_download, label: 'Check for Updates', trailing: _Chevron()),
          ]),

          _buildSection('Backup & Sync', [
            _SettingRow(icon: CupertinoIcons.arrow_up_doc, label: 'Export Backup', trailing: _Chevron()),
            _SettingRow(icon: CupertinoIcons.arrow_down_doc, label: 'Restore Backup', trailing: _Chevron()),
            _SettingRow(
              icon: CupertinoIcons.cloud,
              label: 'Google Drive Sync',
              trailing: CupertinoSwitch(value: false, onChanged: (_) {}),
            ),
          ]),

          _buildSection('About', [
            _SettingRow(icon: CupertinoIcons.info, label: 'Version', trailing: const Text('1.0.0', style: TextStyle(color: AppColors.textTertiary, fontSize: 14))),
            _SettingRow(icon: CupertinoIcons.star, label: 'Rate on App Store', trailing: _Chevron()),
          ]),

          SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 90)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> rows) {
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: AppColors.textTertiary,
      );
}
