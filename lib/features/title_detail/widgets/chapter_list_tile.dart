import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/chapter_entry.dart';
import '../../../core/database/models/download_entry.dart';
import '../../../core/providers/download_provider.dart';
import '../../../core/theme/yomi_theme.dart';
import '../../../shared/widgets/sumi.dart';

/// Chapter row: kanji numeral · title 14/700 · meta 11 · download · status
/// dot (8px `ac` when unread, ring when in progress). Read rows sit at 55%.
class ChapterListTile extends ConsumerWidget {
  const ChapterListTile({
    super.key,
    required this.chapter,
    required this.onTap,
    this.onDownload,
    this.onLongPress,
    this.selected,
  });

  final ChapterEntry chapter;
  final VoidCallback onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onLongPress;

  /// Non-null while the list is in selection mode; true tints the row.
  final bool? selected;

  bool get _inProgress => !chapter.isRead && chapter.lastPageRead > 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yc;
    final queueStatus =
        ref.watch(chapterDownloadStatusProvider(chapter.id)).valueOrNull;

    final meta = [
      if (chapter.uploadDate != null) _formatDate(chapter.uploadDate!),
      if (_inProgress)
        chapter.pageCount > 0
            ? 'Page ${chapter.lastPageRead + 1} of ${chapter.pageCount}'
            : 'Page ${chapter.lastPageRead + 1}'
      else
        chapter.isRead ? 'Read' : 'Unread',
    ].join(' · ');

    final number = chapter.number;
    final look = context.look;

    return Semantics(
      button: true,
      selected: selected,
      label: '${chapter.title}, $meta',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: chapter.isRead && selected != true ? 0.55 : 1.0,
          child: Container(
            padding: look.isPastel
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
                : const EdgeInsets.symmetric(vertical: 14),
            margin: look.isPastel ? const EdgeInsets.only(bottom: 8) : null,
            decoration: BoxDecoration(
              color: selected == true
                  ? c.ac.withValues(alpha: 0.14)
                  : (look.isPastel ? c.card : null),
              border: look.isPastel
                  ? null
                  : Border(bottom: BorderSide(color: c.line)),
              borderRadius: look.isPastel ? BorderRadius.circular(20) : null,
              boxShadow: look.cardShadow,
            ),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints:
                      BoxConstraints(minWidth: look.isCinema ? 40 : 28),
                  child: Text(
                    number == null ? '—' : chapterMark(number),
                    style:
                        YomiText.display(look.isCinema ? 24 : 20, color: c.fg2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (look.isCinema)
                        DisplayText(chapter.title,
                            size: 18,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            height: 1)
                      else
                        Text(
                          chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: YomiText.ui(14,
                              weight: FontWeight.w700, color: c.fg),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style:
                            YomiText.ui(11, color: _inProgress ? c.ac : c.fg2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _DownloadButton(
                  chapter: chapter,
                  queueStatus: queueStatus,
                  onDownload: onDownload,
                ),
                const SizedBox(width: 10),
                Container(
                  width: look.isSumi ? 8 : 10,
                  height: look.isSumi ? 8 : 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(look.isCinema ? 0 : 5),
                    color: !chapter.isRead && !_inProgress
                        ? (look.isPastel ? context.yomi.toggleOn : c.ac)
                        : const Color(0x00000000),
                    border: _inProgress
                        ? Border.all(color: look.isPastel ? c.fg : c.ac)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

// ── Download state glyph ──────────────────────────────────────────────────────

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.chapter,
    required this.queueStatus,
    required this.onDownload,
  });

  final ChapterEntry chapter;
  final String? queueStatus;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final done =
        chapter.isDownloaded || queueStatus == DownloadStatus.completed;

    final (IconData? icon, Color color, bool tappable) = switch (true) {
      _ when done => (CupertinoIcons.checkmark_alt, c.fg2, false),
      _ when queueStatus == DownloadStatus.pending => (
          CupertinoIcons.clock,
          c.fg2,
          false
        ),
      _ when queueStatus == DownloadStatus.downloading => (null, c.ac, false),
      _ when queueStatus == DownloadStatus.paused => (
          CupertinoIcons.pause_fill,
          c.fg2,
          true
        ),
      _ when queueStatus == DownloadStatus.failed => (
          CupertinoIcons.arrow_clockwise,
          c.ac,
          true
        ),
      _ => (CupertinoIcons.arrow_down_to_line, c.fg, true),
    };

    return Semantics(
      button: tappable,
      label: done ? 'Downloaded' : 'Download chapter',
      child: GestureDetector(
        onTap: tappable ? onDownload : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: icon == null
                ? CupertinoActivityIndicator(radius: 7, color: color)
                : Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
