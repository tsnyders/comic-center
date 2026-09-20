import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/services/duplicate_scan.dart';
import '../../core/services/library_update_service.dart';
import '../../core/services/update_service.dart';
import '../../core/services/whats_new_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/sumi.dart';
import '../browse/browse_screen.dart';
import '../history/history_screen.dart';
import '../library/duplicate_resolver_sheet.dart';
import '../library/library_screen.dart';
import '../settings/changelog_screen.dart';
import '../settings/settings_screen.dart';
import '../updates/updates_screen.dart';

/// Discover · Updates · Library (yin-yang) · History · Settings. Tab index
/// lives in [rootTabProvider] so Onboarding and Settings can deep-link into a
/// tab.
class RootScaffold extends ConsumerStatefulWidget {
  const RootScaffold({super.key});

  @override
  ConsumerState<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<RootScaffold> {
  @override
  void initState() {
    super.initState();
    // The pref defaults to on, so the periodic task must exist even if the
    // toggle was never touched. Idempotent (an existing schedule is kept).
    if (ref.read(autoCheckUpdatesProvider)) {
      unawaited(LibraryUpdateService.schedule());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runStartupModals());
    });
  }

  void _onTap(int index) {
    if (ref.read(rootTabProvider) == index) return;
    HapticFeedback.selectionClick();
    ref.read(rootTabProvider.notifier).state = index;
  }

  Future<void> _runStartupModals() async {
    if (ref.read(showWhatsNewProvider)) await _showWhatsNewDialog(context);
    if (!mounted) return;
    try {
      final ignored = await loadIgnoredDuplicateKeys();
      final groups = await findDuplicateGroups(ref.read(isarProvider),
          ignoredKeys: ignored);
      if (groups.isEmpty || !mounted) return;
      final sourceNames = {
        for (final source in ref.read(sourceRegistryProvider))
          source.id: source.name,
      };
      await showDuplicateResolverSheet(context,
          isar: ref.read(isarProvider),
          groups: groups,
          sourceNames: sourceNames);
    } catch (_) {
      // Startup remains usable if local duplicate inspection cannot complete.
    }
  }

  Future<void> _showWhatsNewDialog(BuildContext context) async {
    ReleaseInfo? release;
    try {
      release = await UpdateService.fetchLatestRelease();
    } catch (_) {
      return;
    }
    if (release == null || !context.mounted) return;
    final fullChangelog = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => _WhatsNewDialog(release: release!),
    );
    if (fullChangelog == true && context.mounted) {
      await Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<void>(builder: (_) => const ChangelogScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(rootTabProvider);
    return CupertinoPageScaffold(
      backgroundColor: context.yc.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // sumiRise re-runs on every tab switch (screen entrance).
          SumiRise(
            trigger: tab,
            child: IndexedStack(
              index: tab,
              children: const [
                BrowseScreen(),
                UpdatesScreen(),
                LibraryScreen(),
                HistoryScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SumiNav(index: tab, onTap: _onTap),
          ),
        ],
      ),
    );
  }
}

// ── Nav ───────────────────────────────────────────────────────────────────────

/// Bottom navigation per look. Sumi: gradient bar, 探 新 / yin-yang / 歴 設.
/// Cinema: film-strip word bar with a 2px accent rule over the active item.
/// Pastel: floating 72px card with an accent pill behind the active item.
class SumiNav extends StatelessWidget {
  const SumiNav({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => switch (context.look.look) {
        YomiLook.sumi => _SumiBar(index: index, onTap: onTap),
        YomiLook.cinema => _CinemaBar(index: index, onTap: onTap),
        YomiLook.pastel => _PastelBar(index: index, onTap: onTap),
      };
}

class _SumiBar extends StatelessWidget {
  const _SumiBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final onLibrary = index == 2;
    final reduced = reduceMotion(context);

    return Container(
      height: 92 + bottom,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 22 + bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.bg.withValues(alpha: 0), c.bg],
          stops: const [0.0, 0.45],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _KanjiItem(
              kanji: '探',
              label: 'Discover',
              active: index == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _KanjiItem(
              kanji: '新',
              label: 'Updates',
              active: index == 1,
              onTap: () => onTap(1),
            ),
          ),
          Semantics(
            button: true,
            selected: onLibrary,
            label: 'Library',
            child: Transform.translate(
              offset: const Offset(0, -14),
              child: AnimatedRotation(
                turns: onLibrary || reduced ? 0 : 0.5,
                duration: AppMotion.epic - const Duration(milliseconds: 100),
                curve: AppMotion.spring,
                child: AnimatedOpacity(
                  opacity: onLibrary ? 1 : 0.7,
                  duration: AppMotion.epic - const Duration(milliseconds: 100),
                  curve: AppMotion.spring,
                  child: SumiPress(
                    onTap: () => onTap(2),
                    haptic: false,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 30,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const YinYang(size: 64),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _KanjiItem(
              kanji: '歴',
              label: 'History',
              active: index == 3,
              onTap: () => onTap(3),
            ),
          ),
          Expanded(
            child: _KanjiItem(
              kanji: '設',
              label: 'Settings',
              active: index == 4,
              onTap: () => onTap(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _KanjiItem extends StatelessWidget {
  const _KanjiItem({
    required this.kanji,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String kanji;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final color = active ? c.fg : c.fg2;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: SumiPress(
        onTap: onTap,
        haptic: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: AppMotion.base,
                style: YomiText.display(26, color: color).copyWith(height: 1),
                child: Text(kanji),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: AppMotion.base,
                style: YomiText.ui(10, color: color, letterSpacing: 1),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _navLabels = ['Discover', 'Updates', 'Library', 'History', 'Settings'];
const _navIcons = [
  CupertinoIcons.compass,
  CupertinoIcons.bell,
  CupertinoIcons.book,
  CupertinoIcons.clock,
  CupertinoIcons.settings,
];

/// Cinema: 84 tall, `bg`, 1px top rule, five uppercase condensed words
/// (scaled down on narrow screens).
class _CinemaBar extends StatelessWidget {
  const _CinemaBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 84 + bottom,
      padding: EdgeInsets.only(bottom: 18 + bottom),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _navLabels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: index == i,
                label: _navLabels[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: -1,
                        left: 0,
                        right: 0,
                        child: FractionallySizedBox(
                          widthFactor: 0.6,
                          child: AnimatedContainer(
                            duration: AppMotion.base,
                            curve: AppMotion.snap,
                            height: 2,
                            color: index == i ? c.ac : const Color(0x00000000),
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedDefaultTextStyle(
                            duration: AppMotion.base,
                            style: YomiText.display(13,
                                color: index == i ? c.fg : c.fg2,
                                letterSpacing: 3),
                            child: Text(_navLabels[i].toUpperCase()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastel: floating 72px `card`, radius 24, accent pill behind the active
/// icon + label.
class _PastelBar extends StatelessWidget {
  const _PastelBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottom),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26503C3C),
              blurRadius: 40,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _navLabels.length; i++)
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    selected: index == i,
                    label: _navLabels[i],
                    child: SumiPress(
                      onTap: () => onTap(i),
                      haptic: false,
                      scale: AppMotion.activeScale,
                      child: AnimatedContainer(
                        duration: AppMotion.base,
                        curve: AppMotion.snap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          color: index == i ? c.ac : const Color(0x00000000),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_navIcons[i], size: 22, color: c.fg),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_navLabels[i],
                                  style: YomiText.ui(10,
                                      weight: FontWeight.w700, color: c.fg)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── What's New dialog ─────────────────────────────────────────────────────────

class _WhatsNewDialog extends StatelessWidget {
  const _WhatsNewDialog({required this.release});
  final ReleaseInfo release;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// The release body is written for the GitHub release page: a "What's new"
  /// commit list, then a "---" divider, then install instructions. In-app,
  /// only the changelog part is relevant — cut at the divider and drop the
  /// markdown heading (the dialog already has its own title).
  static String _whatsNewSection(String releaseBody) {
    var body = releaseBody.trim();
    final divider = body.indexOf('\n---');
    if (divider > 0) body = body.substring(0, divider);
    body = body
        .replaceFirst(RegExp(r"^#+\s*what'?s new\s*", caseSensitive: false), '')
        .trim();
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final body = _whatsNewSection(release.body);
    final date = _formatDate(release.publishedAtDate);
    final c = context.yc;

    return CupertinoAlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.sparkles, size: 16, color: c.ac),
          const SizedBox(width: 6),
          Text('What\'s New in ${release.tag}'),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (date.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                date,
                style: AppTextStyles.caption.copyWith(color: c.fg2),
              ),
            ),
          if (body.isNotEmpty)
            Text(
              body.length > 300 ? '${body.substring(0, 300)}…' : body,
              style: AppTextStyles.bodySmall.copyWith(color: c.fg2),
            )
          else
            Text(
              'Bug fixes and improvements.',
              style: AppTextStyles.bodySmall.copyWith(color: c.fg2),
            ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Dismiss'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Full Changelog'),
        ),
      ],
    );
  }
}
