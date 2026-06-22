import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/extension_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

// ── Tabs ──────────────────────────────────────────────────────────────────

enum _Tab { installed, available, updates }

// ── Screen ────────────────────────────────────────────────────────────────

class ExtensionsScreen extends ConsumerStatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen> {
  _Tab _tab = _Tab.installed;
  String _query = '';

  /// Source IDs currently mid-install or mid-uninstall.
  final _loading = <String>{};

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final indexAsync = ref.watch(extensionIndexProvider);
    final installedIds = ref.watch(installedSourceIdsProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),

          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x7,
                0,
                AppSpacing.x7,
                AppSpacing.x5,
              ),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '‹ Browse',
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Extensions',
                      style: AppTextStyles.hero.copyWith(
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.invalidate(extensionIndexProvider),
                    child: Icon(
                      CupertinoIcons.arrow_clockwise,
                      color: context.accentColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Search bar ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x7,
                0,
                AppSpacing.x7,
                AppSpacing.x5,
              ),
              child: _SearchBar(
                onChanged: (q) => setState(() => _query = q.toLowerCase()),
              ),
            ),
          ),

          // ── Tab selector ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x7,
                0,
                AppSpacing.x7,
                AppSpacing.x6,
              ),
              child: CupertinoSlidingSegmentedControl<_Tab>(
                groupValue: _tab,
                onValueChanged: (t) => setState(() => _tab = t!),
                children: const {
                  _Tab.installed: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Installed'),
                  ),
                  _Tab.available: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Available'),
                  ),
                  _Tab.updates: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Updates'),
                  ),
                },
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          indexAsync.when(
            loading: _buildLoading,
            error: (e, _) => _buildError(e),
            data: (index) {
              return switch (_tab) {
                _Tab.installed =>
                  _buildInstalled(context, index, installedIds),
                _Tab.available =>
                  _buildAvailable(context, index, installedIds),
                _Tab.updates =>
                  _buildUpdates(context, index, installedIds),
              };
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Tab builders ──────────────────────────────────────────────────────────

  Widget _buildLoading() => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );

  Widget _buildError(Object e) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(CupertinoIcons.wifi_slash,
                  size: 40, color: context.textTertiaryColor),
              const SizedBox(height: 12),
              Text(
                'Failed to load extension index',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Check your connection and tap ↻ to retry.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textTertiaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildInstalled(
    BuildContext context,
    List<ExtensionEntry> index,
    Set<String> installedIds,
  ) {
    final installed = index
        .where((e) =>
            e.yomiSourceId != null && installedIds.contains(e.yomiSourceId) &&
            (_query.isEmpty || e.name.toLowerCase().contains(_query)))
        .toList();

    if (installed.isEmpty) {
      return _buildEmpty(
        icon: CupertinoIcons.square_grid_2x2,
        title: 'No extensions installed',
        subtitle: 'Switch to Available to browse the extension catalogue.',
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x7),
      sliver: SliverList.builder(
        itemCount: installed.length,
        itemBuilder: (_, i) => _ExtensionTile(
          entry: installed[i],
          isInstalled: true,
          isLoading: _loading.contains(installed[i].yomiSourceId),
          action: _ExtensionAction.uninstall,
          onAction: () => _uninstall(installed[i]),
        ),
      ),
    );
  }

  Widget _buildAvailable(
    BuildContext context,
    List<ExtensionEntry> index,
    Set<String> installedIds,
  ) {
    final available = index
        .where((e) =>
            !(e.yomiSourceId != null && installedIds.contains(e.yomiSourceId)) &&
            (_query.isEmpty || e.name.toLowerCase().contains(_query)))
        .toList();

    if (available.isEmpty) {
      return _buildEmpty(
        icon: CupertinoIcons.checkmark_seal_fill,
        title: 'All extensions installed',
        subtitle: 'You have installed every available extension.',
      );
    }

    // Group: Yomi-native at top, then others
    final native =
        available.where((e) => e.isNativelySupported).toList();
    final others =
        available.where((e) => !e.isNativelySupported).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x7),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (native.isNotEmpty) ...[
            _SectionHeader(label: 'Available for Yomi (${native.length})'),
            ...native.map((e) => _ExtensionTile(
                  entry: e,
                  isInstalled: false,
                  isLoading: _loading.contains(e.yomiSourceId),
                  action: _ExtensionAction.install,
                  onAction: () => _install(e),
                )),
            const SizedBox(height: 16),
          ],
          if (others.isNotEmpty) ...[
            _SectionHeader(
              label: 'Other Tachiyomi extensions (${others.length})',
              subtitle:
                  'These extensions work on Mihon/Tachiyomi. Yomi ports are coming.',
            ),
            ...others.map((e) => _ExtensionTile(
                  entry: e,
                  isInstalled: false,
                  isLoading: false,
                  action: _ExtensionAction.unavailable,
                  onAction: null,
                )),
          ],
        ]),
      ),
    );
  }

  Widget _buildUpdates(
    BuildContext context,
    List<ExtensionEntry> index,
    Set<String> installedIds,
  ) {
    final installedSources = ref.read(sourceRegistryProvider);
    final updates = index.where((e) {
      if (e.yomiSourceId == null) return false;
      if (!installedIds.contains(e.yomiSourceId)) return false;
      final installed =
          installedSources.firstWhere((s) => s.id == e.yomiSourceId,
              orElse: () => installedSources.first);
      return installed.version != e.version;
    }).where((e) =>
        _query.isEmpty || e.name.toLowerCase().contains(_query)).toList();

    if (updates.isEmpty) {
      return _buildEmpty(
        icon: CupertinoIcons.checkmark_circle_fill,
        title: 'Everything is up to date',
        subtitle: 'All installed extensions are on the latest version.',
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x7),
      sliver: SliverList.builder(
        itemCount: updates.length,
        itemBuilder: (_, i) => _ExtensionTile(
          entry: updates[i],
          isInstalled: true,
          isLoading: _loading.contains(updates[i].yomiSourceId),
          action: _ExtensionAction.update,
          onAction: () => _update(updates[i]),
        ),
      ),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: context.textQuaternaryColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textTertiaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _install(ExtensionEntry entry) async {
    final sourceId = entry.yomiSourceId;
    if (sourceId == null) return;
    setState(() => _loading.add(sourceId));

    final isar = ref.read(isarProvider);
    final ok = await ref.read(sourceRegistryProvider.notifier).install(
          isar,
          sourceId: sourceId,
          name: entry.name,
          version: entry.version,
          language: entry.lang,
          hasNsfw: entry.isNsfw,
        );

    if (mounted) {
      setState(() => _loading.remove(sourceId));
      if (!ok && context.mounted) {
        _showError(context, 'Installation failed for ${entry.name}.');
      }
    }
  }

  Future<void> _uninstall(ExtensionEntry entry) async {
    final sourceId = entry.yomiSourceId;
    if (sourceId == null) return;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('Remove ${entry.name}?'),
        content: const Text(
            'This extension will be removed from Browse. You can reinstall it from Available at any time.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading.add(sourceId));
    final isar = ref.read(isarProvider);
    await ref.read(sourceRegistryProvider.notifier).uninstall(isar, sourceId);
    if (mounted) setState(() => _loading.remove(sourceId));
  }

  Future<void> _update(ExtensionEntry entry) async {
    final sourceId = entry.yomiSourceId;
    if (sourceId == null) return;
    setState(() => _loading.add(sourceId));

    final isar = ref.read(isarProvider);
    await ref
        .read(sourceRegistryProvider.notifier)
        .updateVersion(isar, sourceId, entry.version);

    if (mounted) {
      setState(() => _loading.remove(sourceId));
      // Switch to Installed tab after update
      setState(() => _tab = _Tab.installed);
    }
  }

  void _showError(BuildContext context, String message) {
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
}

// ── Action enum ──────────────────────────────────────────────────────────────

enum _ExtensionAction { install, uninstall, update, unavailable }

// ── Gradient letter icon ──────────────────────────────────────────────────────

/// A 44×44 gradient avatar with a white letter initial.
/// Used as both [CachedNetworkImage] placeholder and errorWidget.
class _GradientLetterIcon extends StatelessWidget {
  const _GradientLetterIcon({
    required this.name,
    required this.gradientColors,
  });

  final String name;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppElevation.e1,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Extension tile ────────────────────────────────────────────────────────────

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({
    required this.entry,
    required this.isInstalled,
    required this.isLoading,
    required this.action,
    required this.onAction,
  });

  final ExtensionEntry entry;
  final bool isInstalled;
  final bool isLoading;
  final _ExtensionAction action;
  final VoidCallback? onAction;

  /// Pick a gradient seed by hashing the first character of the extension name.
  List<Color> _gradientFor(String name) {
    final gradients = [
      AppColors.gradEmber,
      AppColors.gradViolet,
      AppColors.gradTeal,
      AppColors.gradRose,
    ];
    final index = name.isNotEmpty ? name[0].codeUnitAt(0) % 4 : 0;
    return gradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _gradientFor(entry.name);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: context.borderColor,
          width: AppRadius.hairline,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CachedNetworkImage(
              imageUrl: entry.iconUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _GradientLetterIcon(
                name: entry.name,
                gradientColors: gradientColors,
              ),
              placeholder: (_, __) => _GradientLetterIcon(
                name: entry.name,
                gradientColors: gradientColors,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: AppTextStyles.sourceName.copyWith(
                          color: context.textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isNsfw) ...[
                      const SizedBox(width: 6),
                      _Badge(label: '18+', color: context.unreadColor),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                // Meta row
                Row(
                  children: [
                    _LanguageBadge(lang: entry.lang),
                    const SizedBox(width: 6),
                    Text(
                      'v${entry.version}',
                      style: AppTextStyles.sourceMeta.copyWith(
                        color: context.textTertiaryColor,
                      ),
                    ),
                    if (!entry.isNativelySupported) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· Mihon only',
                        style: AppTextStyles.sourceMeta.copyWith(
                          color: context.textQuaternaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Action
          if (isLoading)
            const SizedBox(
              width: 60,
              child: Center(child: CupertinoActivityIndicator()),
            )
          else
            _ActionButton(action: action, onTap: onAction),
        ],
      ),
    );
  }
}

// ── Language badge ────────────────────────────────────────────────────────────

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0x00000000), // transparent
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: context.accentLineColor,
          width: AppRadius.hairline,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        lang.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: context.accentColor,
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, this.onTap});

  final _ExtensionAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return switch (action) {
      _ExtensionAction.install => _Chip(
          label: 'Get',
          onTap: onTap,
          backgroundColor: context.accentSubtleColor,
          borderColor: context.accentLineColor,
          textColor: context.accentColor,
        ),
      _ExtensionAction.uninstall => _Chip(
          label: 'Remove',
          onTap: onTap,
          backgroundColor: context.unreadColor.withValues(alpha: 0.12),
          borderColor: context.unreadColor.withValues(alpha: 0.35),
          textColor: context.unreadColor,
        ),
      _ExtensionAction.update => _Chip(
          label: 'Update',
          onTap: onTap,
          backgroundColor: context.surfaceElevatedColor,
          borderColor: context.borderStrongColor,
          textColor: context.textPrimaryColor,
        ),
      _ExtensionAction.unavailable => Text(
          'Unavailable',
          style: AppTextStyles.caption.copyWith(
            color: context.textQuaternaryColor,
          ),
        ),
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: borderColor,
            width: AppRadius.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ── NSFW badge ────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.sectionTitle.copyWith(
              color: context.textPrimaryColor,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle!,
                style: AppTextStyles.caption.copyWith(
                  color: context.textTertiaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: context.borderStrongColor,
          width: AppRadius.hairline,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            CupertinoIcons.search,
            size: 15,
            color: context.textTertiaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _ctrl,
              placeholder: 'Search extensions...',
              placeholderStyle: AppTextStyles.bodySmall.copyWith(
                color: context.textQuaternaryColor,
              ),
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textPrimaryColor,
              ),
              decoration: null,
              onChanged: (v) {
                setState(() {}); // rebuild to show/hide clear button
                widget.onChanged(v);
              },
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                setState(() {});
                widget.onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 15,
                  color: context.textTertiaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
