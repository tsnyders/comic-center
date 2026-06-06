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
            // Chapter number
            SizedBox(
              width: 40,
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

            // Title + date
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
                  if (chapter.uploadDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(chapter.uploadDate!),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),

            // Trailing indicators
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!chapter.isRead)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (chapter.isDownloaded)
                  const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 16,
                    color: AppColors.downloaded,
                  )
                else
                  GestureDetector(
                    onTap: onDownload,
                    child: const Icon(
                      CupertinoIcons.arrow_down_circle,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
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
