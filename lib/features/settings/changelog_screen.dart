import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _changelogProvider = FutureProvider<List<ReleaseInfo>>((ref) {
  return UpdateService.fetchReleases();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ChangelogScreen extends ConsumerWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final releasesAsync = ref.watch(_changelogProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),

          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                      'What\'s New',
                      style: AppTextStyles.sectionTitle.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.invalidate(_changelogProvider),
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

          // Body
          releasesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorView(
                message: e is UpdateCheckException
                    ? e.message
                    : e.toString(),
                onRetry: () => ref.invalidate(_changelogProvider),
              ),
            ),
            data: (releases) {
              if (releases.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.tag,
                          size: 48,
                          color: AppColors.textQuaternary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No releases yet',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back after the first release.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 90),
                sliver: SliverList.separated(
                  itemCount: releases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => _ReleaseCard(release: releases[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Release card ──────────────────────────────────────────────────────────────

class _ReleaseCard extends StatefulWidget {
  const _ReleaseCard({required this.release});
  final ReleaseInfo release;

  @override
  State<_ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<_ReleaseCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand the first (latest) release — determined by parent index 0.
    // We expand all cards by default; collapse is opt-in.
    _expanded = true;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final date = _formatDate(release.publishedAtDate);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Version badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.35),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      release.tag,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (release.isPrerelease) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Pre-release',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      release.name.isNotEmpty &&
                              release.name != release.tag
                          ? release.name
                          : '',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (date.isNotEmpty)
                    Text(
                      date,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      CupertinoIcons.chevron_down,
                      size: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible body
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 0.5,
                  color: context.borderColor,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: release.body.trim().isEmpty
                      ? Text(
                          'No release notes provided.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textTertiary),
                        )
                      : _ReleaseBody(body: release.body),
                ),
                if (release.apkUrl != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GestureDetector(
                      onTap: () => UpdateService.openUrl(release.apkUrl!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.arrow_down_to_line,
                              size: 14,
                              color: CupertinoColors.white,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Download APK',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

// ── Release body renderer ─────────────────────────────────────────────────────
//
// Renders GitHub Markdown release notes with basic formatting:
//   ## Heading  →  bold section header
//   - item      →  bullet point
//   **text**    →  bold inline
//   other       →  regular body text

class _ReleaseBody extends StatelessWidget {
  const _ReleaseBody({required this.body});
  final String body;

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    final widgets = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // H2/H3 heading
      if (line.startsWith('### ')) {
        widgets.add(_styledLine(
          line.substring(4),
          fontSize: 12,
          weight: FontWeight.w700,
          color: AppColors.textSecondary,
          topPad: 10,
        ));
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(_styledLine(
          line.substring(3),
          fontSize: 13,
          weight: FontWeight.w800,
          color: AppColors.accent,
          topPad: 12,
        ));
        continue;
      }
      if (line.startsWith('# ')) {
        widgets.add(_styledLine(
          line.substring(2),
          fontSize: 14,
          weight: FontWeight.w800,
          color: AppColors.accent,
          topPad: 12,
        ));
        continue;
      }

      // Horizontal rule
      if (RegExp(r'^[-*_]{3,}$').hasMatch(line)) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(height: 0.5, color: context.borderColor),
        ));
        continue;
      }

      // Bullet point
      if (line.startsWith('- ') || line.startsWith('* ')) {
        final text = line.substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(child: _inlineText(text)),
            ],
          ),
        ));
        continue;
      }

      // Regular paragraph line
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: _inlineText(line),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _styledLine(
    String text, {
    required double fontSize,
    required FontWeight weight,
    required Color color,
    double topPad = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPad, bottom: 4),
      child: Text(
        _stripInlineMarkdown(text),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
        ),
      ),
    );
  }

  // Renders a line with **bold** support via RichText.
  Widget _inlineText(String line) {
    final spans = _parseInline(line);
    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodySmall,
        children: spans,
      ),
    );
  }

  List<TextSpan> _parseInline(String text) {
    final spans = <TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    int cursor = 0;

    for (final match in boldRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(
            fontFamily: 'Courier',
            fontSize: 11,
            color: AppColors.accent,
          ),
        ));
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }

  String _stripInlineMarkdown(String text) =>
      text.replaceAll(RegExp(r'\*\*|__|\*|_|`'), '');
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.wifi_slash,
              size: 44,
              color: AppColors.textQuaternary,
            ),
            const SizedBox(height: 14),
            Text(
              'Failed to load changelog',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.35),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'Retry',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
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
