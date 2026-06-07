import 'package:flutter/cupertino.dart';

import '../../../core/database/models/chapter_entry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ChapterListTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                  color: chapter.isRead
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
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
                          : AppColors.textPrimary,
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
                            style: AppTextStyles.caption,
                          ),
                        if (chapter.uploadDate != null && _isInProgress)
                          Text(
                            '  ·  ',
                            style: AppTextStyles.caption,
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
            _DownloadButton(chapter: chapter, onDownload: onDownload),
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
        color: AppColors.downloaded, // iOS green
      );
    }
    if (!chapter.isRead && chapter.lastPageRead > 0) {
      // In progress — orange half-filled circle approximation
      return const Icon(
        CupertinoIcons.circle_lefthalf_fill,
        size: 14,
        color: AppColors.warning,
      );
    }
    // Unread — solid accent dot
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

// ── Download button ────────────────────────────────────────────────────────

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.chapter, this.onDownload});
  final ChapterEntry chapter;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    if (chapter.isDownloaded) {
      return const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Icon(
          CupertinoIcons.checkmark_circle_fill,
          size: 16,
          color: AppColors.downloaded,
        ),
      );
    }
    return GestureDetector(
      onTap: onDownload,
      child: const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Icon(
          CupertinoIcons.arrow_down_circle,
          size: 16,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
