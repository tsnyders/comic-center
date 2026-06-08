import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/extension_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/app_colors.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.chevron_back,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Extensions',
                      style: AppTextStyles.sectionTitle.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.invalidate(extensionIndexProvider),
                    child: const Icon(
                      CupertinoIcons.arrow_clockwise,
                      color: AppColors.accent,
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _SearchBar(
                onChanged: (q) => setState(() => _query = q.toLowerCase()),
              ),
            ),
          ),

          // ── Tab selector ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
              const Icon(CupertinoIcons.wifi_slash,
                  size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Failed to load extension index',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 6),
              Text('Check your connection and tap ↻ to retry.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
              Icon(icon, size: 48, color: AppColors.textQuaternary),
              const SizedBox(height: 16),
              Text(title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          // Icon
          _ExtensionIcon(iconUrl: entry.iconUrl, name: entry.name),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isNsfw) ...[
                      const SizedBox(width: 6),
                      _Badge(label: '18+', color: AppColors.unread),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _Badge(
                      label: entry.lang.toUpperCase(),
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'v${entry.version}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                    if (!entry.isNativelySupported) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· Mihon only',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textQuaternary),
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

class _ExtensionIcon extends StatelessWidget {
  const _ExtensionIcon({required this.iconUrl, required this.name});

  final String iconUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 46,
        height: 46,
        child: CachedNetworkImage(
          imageUrl: iconUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _LetterIcon(name: name),
          placeholder: (_, __) => _LetterIcon(name: name),
        ),
      ),
    );
  }
}

class _LetterIcon extends StatelessWidget {
  const _LetterIcon({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accent.withOpacity(0.18),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, this.onTap});

  final _ExtensionAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return switch (action) {
      _ExtensionAction.install => _Chip(
          label: 'Get',
          color: AppColors.accent,
          onTap: onTap,
        ),
      _ExtensionAction.uninstall => _Chip(
          label: 'Remove',
          color: AppColors.unread,
          onTap: onTap,
        ),
      _ExtensionAction.update => _Chip(
          label: 'Update',
          color: AppColors.warning,
          onTap: onTap,
        ),
      _ExtensionAction.unavailable => Text(
          'Unavailable',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textQuaternary),
        ),
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35), width: 0.5),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
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
          Text(label, style: AppTextStyles.sectionTitle),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle!,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

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
        color: context.surfaceElevatedColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderStrongColor, width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(CupertinoIcons.search, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _ctrl,
              placeholder: 'Search extensions...',
              placeholderStyle: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textQuaternary),
              style: AppTextStyles.bodySmall,
              decoration: null,
              onChanged: widget.onChanged,
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                widget.onChanged('');
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(CupertinoIcons.xmark_circle_fill,
                    size: 15, color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}
