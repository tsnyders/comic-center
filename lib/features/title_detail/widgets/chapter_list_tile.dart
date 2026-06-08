import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/chapter_entry.dart';
import '../../../core/database/models/download_entry.dart';
import '../../../core/providers/download_provider.dart';
import '../../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueStatus = ref
        .watch(chapterDownloadStatusProvider(chapter.id))
        .valueOrNull;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Read status indicator
            SizedBox(
              width: 22,
              child: _ReadIndicator(chapter: chapter),
            ),

            // Chapter number
            SizedBox(
              width: 36,
              child: Text(
                chapter.number?.toStringAsFixed(0) ?? '?',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: chapter.isRead ? AppColors.textTertiary : null,
                ),
              ),
            ),

            // Title + date + progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.title,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: chapter.isRead
                          ? AppColors.textTertiary
                          : context.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chapter.uploadDate != null || _isInProgress) ...[
                    const SizedBox(height: 2),
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
                            'pg ${chapter.lastPageRead + 1} / ${chapter.pageCount}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Download status
            _DownloadIndicator(
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

// ── Read status indicator ──────────────────────────────────────────────────

class _ReadIndicator extends StatelessWidget {
  const _ReadIndicator({required this.chapter});
  final ChapterEntry chapter;

  @override
  Widget build(BuildContext context) {
    if (chapter.isRead) {
      return const Icon(
        CupertinoIcons.checkmark_circle_fill,
        size: 14,
        color: AppColors.downloaded,
      );
    }
    if (chapter.lastPageRead > 0) {
      return const Icon(
        CupertinoIcons.circle_lefthalf_fill,
        size: 14,
        color: AppColors.warning,
      );
    }
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 3.5),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── Download indicator ─────────────────────────────────────────────────────

class _DownloadIndicator extends StatelessWidget {
  const _DownloadIndicator({
    required this.chapter,
    required this.queueStatus,
    required this.onDownload,
  });

  final ChapterEntry chapter;
  final String? queueStatus;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    if (chapter.isDownloaded || queueStatus == DownloadStatus.completed) {
      return const Icon(
        CupertinoIcons.checkmark_circle_fill,
        size: 16,
        color: AppColors.downloaded,
      );
    }

    return switch (queueStatus) {
      DownloadStatus.pending => const Icon(
          CupertinoIcons.clock,
          size: 16,
          color: AppColors.warning,
        ),
      DownloadStatus.downloading => const SizedBox(
          width: 16,
          height: 16,
          child: CupertinoActivityIndicator(radius: 7),
        ),
      DownloadStatus.paused => const Icon(
          CupertinoIcons.pause_circle,
          size: 16,
          color: AppColors.warning,
        ),
      DownloadStatus.failed => GestureDetector(
          onTap: onDownload,
          child: const Icon(
            CupertinoIcons.xmark_circle,
            size: 16,
            color: AppColors.unread,
          ),
        ),
      _ => GestureDetector(
          onTap: onDownload,
          child: const Icon(
            CupertinoIcons.arrow_down_circle,
            size: 16,
            color: AppColors.textTertiary,
          ),
        ),
    };
  }
}
