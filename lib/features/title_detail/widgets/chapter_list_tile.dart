import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/chapter_entry.dart';
import '../../../core/database/models/download_entry.dart';
import '../../../core/providers/download_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class ChapterListTile extends ConsumerWidget {
  const ChapterListTile({
    super.key,
    required this.chapter,
    required this.onTap,
    this.onDownload,
  });

  final ChapterEntry chapter;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  bool get _isInProgress =>
      !chapter.isRead && chapter.lastPageRead > 0 && chapter.pageCount > 0;

  double get _progress => chapter.pageCount > 0
      ? ((chapter.lastPageRead + 1) / chapter.pageCount).clamp(0.0, 1.0)
      : 0.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueStatus =
        ref.watch(chapterDownloadStatusProvider(chapter.id)).valueOrNull;

    final titleColor = chapter.isRead
        ? context.textTertiaryColor
        : context.textPrimaryColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.borderColor,
              width: AppRadius.hairline,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Read / unread status dot — 10px wide column ──────────────
            SizedBox(
              width: 10,
              child: _StatusDot(chapter: chapter),
            ),

            const SizedBox(width: AppSpacing.x5),

            // ── Title + meta + progress ───────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: titleColor,
                      fontWeight:
                          chapter.isRead ? FontWeight.w500 : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chapter.uploadDate != null || _isInProgress) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (chapter.uploadDate != null)
                          Text(
                            _formatDate(chapter.uploadDate!),
                            style: AppTextStyles.caption.copyWith(
                              color: context.textTertiaryColor,
                            ),
                          ),
                        if (chapter.uploadDate != null && _isInProgress)
                          Text(
                            '  ·  ',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textTertiaryColor,
                            ),
                          ),
                        if (_isInProgress)
                          Text(
                            'Page ${chapter.lastPageRead + 1} of ${chapter.pageCount}',
                            style: AppTextStyles.caption.copyWith(
                              color: context.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                  // Continuous progress bar for partially-read chapters.
                  if (_isInProgress) ...[
                    const SizedBox(height: 7),
                    _ProgressBar(value: _progress),
                  ],
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.x5),

            // ── Download button ───────────────────────────────────────────
            _DownloadButton(
              chapter: chapter,
              queueStatus: queueStatus,
              onDownload: onDownload,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

// ── Read / unread status dot ────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.chapter});
  final ChapterEntry chapter;

  @override
  Widget build(BuildContext context) {
    // Read chapters carry no dot — the dimmed title conveys read state.
    if (chapter.isRead) return const SizedBox.shrink();

    final inProgress = chapter.lastPageRead > 0;
    // Unread = filled accent dot; in-progress = accent ring (2px).
    return Center(
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: inProgress ? null : context.accentColor,
          shape: BoxShape.circle,
          border: inProgress
              ? Border.all(color: context.accentColor, width: 2)
              : null,
        ),
      ),
    );
  }
}

// ── Progress bar ────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(
          children: [
            // Track
            Positioned.fill(
              child: ColoredBox(color: context.borderStrongColor),
            ),
            // Fill
            FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(color: context.accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Download button — 40px circle, color@12% bg, hairline@32% border ────────

class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({
    required this.chapter,
    required this.queueStatus,
    required this.onDownload,
  });

  final ChapterEntry chapter;
  final String? queueStatus;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done =
        chapter.isDownloaded || queueStatus == DownloadStatus.completed;

    // Resolve icon / colour / tap behaviour from the current state.
    final (IconData? icon, Color color, bool tappable, Widget? custom) =
        switch (true) {
      _ when done => (
          CupertinoIcons.checkmark_alt,
          context.downloadedColor,
          false,
          null,
        ),
      _ when queueStatus == DownloadStatus.pending => (
          CupertinoIcons.clock,
          context.warningColor,
          false,
          null,
        ),
      _ when queueStatus == DownloadStatus.downloading => (
          null,
          context.accentColor,
          false,
          const CupertinoActivityIndicator(radius: 9),
        ),
      _ when queueStatus == DownloadStatus.paused => (
          CupertinoIcons.pause_fill,
          context.warningColor,
          true,
          null,
        ),
      _ when queueStatus == DownloadStatus.failed => (
          CupertinoIcons.arrow_clockwise,
          context.unreadColor,
          true,
          null,
        ),
      _ => (
          CupertinoIcons.arrow_down,
          context.accentColor,
          true,
          null,
        ),
    };

    return GestureDetector(
      onTap: tappable ? onDownload : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.32),
            width: AppRadius.hairline,
          ),
        ),
        child: Center(
          child: custom ?? Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
