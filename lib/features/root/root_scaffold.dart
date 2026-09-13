import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/services/update_service.dart';
import '../../core/services/whats_new_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/sumi.dart';
import '../browse/browse_screen.dart';
import '../library/library_screen.dart';
import '../settings/changelog_screen.dart';
import '../settings/settings_screen.dart';

/// Discover · Library (yin-yang) · Settings. Tab index lives in
/// [rootTabProvider] so Onboarding and Settings can deep-link into a tab.
class RootScaffold extends ConsumerStatefulWidget {
  const RootScaffold({super.key});

  @override
  ConsumerState<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<RootScaffold> {
  @override
  void initState() {
    super.initState();
    if (ref.read(showWhatsNewProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showWhatsNewDialog(context);
      });
    }
  }

  void _onTap(int index) {
    if (ref.read(rootTabProvider) == index) return;
    HapticFeedback.selectionClick();
    ref.read(rootTabProvider.notifier).state = index;
  }

  Future<void> _showWhatsNewDialog(BuildContext context) async {
    ReleaseInfo? release;
    try {
      release = await UpdateService.fetchLatestRelease();
    } catch (_) {
      return;
    }
    if (release == null || !context.mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => _WhatsNewDialog(release: release!),
    );
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
                LibraryScreen(),
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

/// Bottom bar 92 tall, gradient transparent → `bg` from 45%. 探 Discover,
/// yin-yang Library (raised 14px, rotates 180° when leaving Library), 設
/// Settings.
class SumiNav extends StatelessWidget {
  const SumiNav({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final onLibrary = index == 1;
    final reduced = reduceMotion(context);

    return Container(
      height: 92 + bottom,
      padding: EdgeInsets.fromLTRB(40, 0, 40, 22 + bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.bg.withValues(alpha: 0), c.bg],
          stops: const [0.0, 0.45],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(
            kanji: '探',
            label: 'Discover',
            active: index == 0,
            onTap: () => onTap(0),
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
                    onTap: () => onTap(1),
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
          _NavItem(
            kanji: '設',
            label: 'Settings',
            active: index == 2,
            onTap: () => onTap(2),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
                style: YomiText.kanji(26, color: color).copyWith(height: 1),
                child: Text(kanji),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: AppMotion.base,
                style: YomiText.ui(10, color: color, letterSpacing: 1),
                child: Text(label),
              ),
            ],
          ),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Dismiss'),
        ),
        CupertinoDialogAction(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context, rootNavigator: true).push(
              CupertinoPageRoute<void>(
                builder: (_) => const ChangelogScreen(),
              ),
            );
          },
          child: const Text('Full Changelog'),
        ),
      ],
    );
  }
}
