import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/update_service.dart';
import '../../core/services/whats_new_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../browse/browse_screen.dart';
import '../downloads/downloads_screen.dart';
import '../library/library_screen.dart';
import '../settings/changelog_screen.dart';
import '../settings/settings_screen.dart';

class RootScaffold extends ConsumerStatefulWidget {
  const RootScaffold({super.key});

  @override
  ConsumerState<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<RootScaffold> {
  int _selectedIndex = 0;

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
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = context.isDark;

    return CupertinoPageScaffold(
      backgroundColor: context.backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient backdrop — subtle radial wash on the ink canvas
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.5),
                radius: 1.4,
                colors: isDark ? AppColors.ambientDark : AppColors.ambientLight,
              ),
            ),
          ),

          IndexedStack(
            index: _selectedIndex,
            children: const [
              LibraryScreen(),
              BrowseScreen(),
              DownloadsScreen(),
              SettingsScreen(),
            ],
          ),

          // Floating LUMEN nav pill — centered, compact, icon-only
          Positioned(
            bottom: bottomPadding + AppSpacing.x6,
            left: 0,
            right: 0,
            child: Center(
              child: _LumenNav(
                selectedIndex: _selectedIndex,
                onTap: _onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── LUMEN floating nav pill ─────────────────────────────────────────────────

class _LumenNav extends StatelessWidget {
  const _LumenNav({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, IconData)>[
    (CupertinoIcons.square_stack_3d_up, CupertinoIcons.square_stack_3d_up_fill),
    (CupertinoIcons.compass, CupertinoIcons.compass_fill),
    (CupertinoIcons.arrow_down_circle, CupertinoIcons.arrow_down_circle_fill),
    (CupertinoIcons.settings, CupertinoIcons.settings_solid),
  ];

  @override
  Widget build(BuildContext context) {
    // Solid translucent surface — the previous BackdropFilter blur re-sampled
    // the entire scrolling list/grid behind the floating pill on every frame,
    // which was the last live backdrop blur in the app (all others were removed
    // in the no-glass redesign). The nav-pill colours are ~80% opaque, so a
    // plain container reads the same without the per-frame GPU cost.
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.navPillDark
            : AppColors.navPillLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: context.borderSubtleColor,
          width: AppRadius.hairline,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 32,
            spreadRadius: -4,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_items.length, (i) {
          final active = i == selectedIndex;
          return _NavDot(
            icon: active ? _items[i].$2 : _items[i].$1,
            active: active,
            onTap: () => onTap(i),
          );
        }),
      ),
    );
  }
}

class _NavDot extends StatelessWidget {
  const _NavDot({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = context.textSecondaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.easeOut,
        width: 52,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? context.accentColor : const Color(0x00000000),
          shape: BoxShape.circle,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: context.accentColor.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 23,
          color: active ? AppColors.textOnAccent : inactive,
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
        .replaceFirst(
            RegExp(r"^#+\s*what'?s new\s*", caseSensitive: false), '')
        .trim();
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final body = _whatsNewSection(release.body);
    final date = _formatDate(release.publishedAtDate);

    return CupertinoAlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.sparkles, size: 16, color: AppColors.accent),
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
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          if (body.isNotEmpty)
            Text(
              body.length > 300 ? '${body.substring(0, 300)}…' : body,
              style: AppTextStyles.bodySmall,
            )
          else
            const Text(
              'Bug fixes and improvements.',
              style: AppTextStyles.bodySmall,
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
