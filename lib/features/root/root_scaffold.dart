import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/update_service.dart';
import '../../core/services/whats_new_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_glass.dart';
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
    // Show "What's New" dialog on first launch after a version update.
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
      // Silently skip if offline — user can always tap "What's New" in Settings.
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
          // ── Ambient backdrop — gives BackdropFilter something to refract ──
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.4),
                radius: 1.4,
                colors: isDark
                    ? AppColors.ambientDark
                    : AppColors.ambientLight,
              ),
            ),
          ),

          // ── Tab content ───────────────────────────────────────────────────
          IndexedStack(
            index: _selectedIndex,
            children: const [
              LibraryScreen(),
              BrowseScreen(),
              DownloadsScreen(),
              SettingsScreen(),
            ],
          ),

          // ── Floating glass navigation bar ─────────────────────────────────
          Positioned(
            bottom: bottomPadding + AppSpacing.x5,
            left: AppSpacing.x7,
            right: AppSpacing.x7,
            child: _GlassNavBar(
              selectedIndex: _selectedIndex,
              onTap: _onTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass navigation bar ──────────────────────────────────────────────────────

class _GlassNavBar extends ConsumerStatefulWidget {
  const _GlassNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  ConsumerState<_GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends ConsumerState<_GlassNavBar>
    with TickerProviderStateMixin {
  late final AnimationController _indicatorCtrl;
  late Animation<double> _indicatorPos;
  int _prevIndex = 0;

  static const _tabs = [
    _TabItem(icon: CupertinoIcons.book, activeIcon: CupertinoIcons.book_fill, label: 'Library'),
    _TabItem(icon: CupertinoIcons.globe, activeIcon: CupertinoIcons.globe, label: 'Browse'),
    _TabItem(icon: CupertinoIcons.arrow_down_circle, activeIcon: CupertinoIcons.arrow_down_circle_fill, label: 'Downloads'),
    _TabItem(icon: CupertinoIcons.settings, activeIcon: CupertinoIcons.settings_solid, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _indicatorPos = Tween<double>(
      begin: widget.selectedIndex.toDouble(),
      end: widget.selectedIndex.toDouble(),
    ).animate(
      CurvedAnimation(parent: _indicatorCtrl, curve: AppMotion.easeOut),
    );
  }

  @override
  void didUpdateWidget(_GlassNavBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _indicatorPos = Tween<double>(
        begin: _prevIndex.toDouble(),
        end: widget.selectedIndex.toDouble(),
      ).animate(
        CurvedAnimation(parent: _indicatorCtrl, curve: AppMotion.easeOut),
      );
      _indicatorCtrl.forward(from: 0);
      _prevIndex = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  Widget _barContent(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          // ── Animated pill indicator ────────────────────────────────────
          AnimatedBuilder(
            animation: _indicatorPos,
            builder: (ctx, __) {
              final barWidth = MediaQuery.of(ctx).size.width
                  - AppSpacing.x7 * 2   // L/R inset (20 + 20)
                  - AppSpacing.x4 * 2;  // inner horizontal padding (8 + 8)
              final tabWidth = barWidth / _tabs.length;
              final pillLeft =
                  _indicatorPos.value * tabWidth + AppSpacing.x4;

              return Positioned(
                top: AppSpacing.x4,
                bottom: AppSpacing.x4,
                left: pillLeft,
                width: tabWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ctx.accentSubtleColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: ctx.accentLineColor,
                      width: AppRadius.hairline,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ctx.accentSubtleColor,
                        blurRadius: 14,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Tab icons + labels ─────────────────────────────────────────
          Row(
            children: List.generate(_tabs.length, (i) {
              final isActive = i == widget.selectedIndex;
              return Expanded(
                child: _TabButton(
                  tab: _tabs[i],
                  isActive: isActive,
                  onTap: () => widget.onTap(i),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final shadows = isDark ? AppElevation.float : AppElevation.floatLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: shadows,
      ),
      child: AppGlass(
        borderRadius: AppRadius.lg,
        child: _barContent(context),
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final _TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.base,
      value: widget.isActive ? 1.0 : 0.0,
    );
    // Active: scale 1.06; inactive: scale 1.0
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: AppMotion.spring),
    );
  }

  @override
  void didUpdateWidget(_TabButton old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) {
      if (widget.isActive) {
        _scaleCtrl.forward();
      } else {
        _scaleCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final inactiveColor = context.textTertiaryColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _scale,
            builder: (_, child) => Transform.scale(
              scale: _scale.value,
              child: child,
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.base,
              child: Icon(
                widget.isActive ? widget.tab.activeIcon : widget.tab.icon,
                key: ValueKey<bool>(widget.isActive),
                size: 21,
                color: widget.isActive ? accentColor : inactiveColor,
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: AppMotion.base,
            style: TextStyle(
              fontFamily: AppTextStyles.display,
              fontVariations: [
                FontVariation('wght', widget.isActive ? 600 : 400),
              ],
              fontSize: 10,
              fontWeight:
                  widget.isActive ? FontWeight.w600 : FontWeight.w400,
              color: widget.isActive ? accentColor : inactiveColor,
            ),
            child: Text(widget.tab.label),
          ),
        ],
      ),
    );
  }
}

// ── Tab data ──────────────────────────────────────────────────────────────────

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
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

  @override
  Widget build(BuildContext context) {
    final body = release.body.trim();
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
              // Show first 300 chars to keep dialog manageable.
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
