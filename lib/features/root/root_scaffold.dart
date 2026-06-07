import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/update_service.dart';
import '../../core/services/whats_new_service.dart';
import '../../core/theme/app_colors.dart';
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

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient gradient — gives BackdropFilter something colorful to blur.
          Builder(builder: (ctx) {
            final isDark =
                CupertinoTheme.of(ctx).brightness == Brightness.dark;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.4),
                  radius: 1.4,
                  colors: isDark
                      ? const [Color(0xFF0D1B3E), Color(0xFF0A0A0F)]
                      : [
                          const Color(0xFF3B82F6).withOpacity(0.10),
                          const Color(0xFFF2F2F7),
                        ],
                ),
              ),
            );
          }),

          // ── Tab content ───────────────────────────────────────────────
          IndexedStack(
            index: _selectedIndex,
            children: const [
              LibraryScreen(),
              BrowseScreen(),
              DownloadsScreen(),
              SettingsScreen(),
            ],
          ),

          // ── Floating glass navigation bar ─────────────────────────────
          Positioned(
            bottom: bottomPadding + 12,
            left: 20,
            right: 20,
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

// ── Glass navigation bar ──────────────────────────────────────────────────

class _GlassNavBar extends StatefulWidget {
  const _GlassNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  State<_GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<_GlassNavBar>
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
      duration: const Duration(milliseconds: 380),
    );
    _indicatorPos = Tween<double>(
      begin: widget.selectedIndex.toDouble(),
      end: widget.selectedIndex.toDouble(),
    ).animate(
      CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
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
        CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
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

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(isDark ? 0.45 : 0.15),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.accent.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: (isDark
                      ? const Color(0xFF16162A)
                      : const Color(0xFFF0F0FA))
                  .withOpacity(isDark ? 0.82 : 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: (isDark
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF000000))
                    .withOpacity(isDark ? 0.18 : 0.10),
                width: 0.75,
              ),
            ),
            child: Stack(
              children: [
                // Specular highlight on top edge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFFFFFF)
                              .withOpacity(isDark ? 0.14 : 0.50),
                          const Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),

                // Animated pill indicator
                AnimatedBuilder(
                  animation: _indicatorPos,
                  builder: (_, __) {
                    return Positioned(
                      top: 8,
                      bottom: 8,
                      left: _indicatorPos.value / _tabs.length *
                                  (MediaQuery.of(context).size.width - 40 - 16) +
                              8,
                      width: (MediaQuery.of(context).size.width - 40 - 16) /
                          _tabs.length,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.50),
                            width: 0.75,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.20),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Tab icons + labels
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
          ),
        ),
      ),
    );
  }
}

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
      duration: const Duration(milliseconds: 220),
      value: widget.isActive ? 1.0 : 0.0,
    );
    _scale = Tween<double>(begin: 0.85, end: 1.12).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutBack),
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
            child: Icon(
              widget.isActive ? widget.tab.activeIcon : widget.tab.icon,
              size: 22,
              color: widget.isActive ? AppColors.accent : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  widget.isActive ? FontWeight.w600 : FontWeight.w400,
              color: widget.isActive
                  ? AppColors.accent
                  : AppColors.textTertiary,
            ),
            child: Text(widget.tab.label),
          ),
        ],
      ),
    );
  }
}

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
            Text(
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
