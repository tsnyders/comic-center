import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/download_entry.dart';
import '../../core/providers/download_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(downloadQueueProvider);
    final history = ref.watch(downloadHistoryProvider);
    final downloaded = ref.watch(downloadedTitlesProvider);
    final manager = ref.read(downloadManagerProvider.notifier);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final queued = queue.valueOrNull ?? const <DownloadEntry>[];
    final hasFailed = queued.any((e) => e.status == DownloadStatus.failed);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MANAGE',
                      style: AppTextStyles.metaMono.copyWith(
                        color: context.accentColor,
                        letterSpacing: 2.5,
                      )),
                  const SizedBox(height: 6),
                  Text('Downloads',
                      style: AppTextStyles.displayM.copyWith(
                        color: context.textPrimaryColor,
                      )),
                ],
              ),
            ),
          ),

          // Active queue
          _SectionLabel(
            'QUEUE',
            trailing: queued.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasFailed) ...[
                        _ActionChip(
                          icon: CupertinoIcons.arrow_clockwise,
                          label: 'Retry failed',
                          onTap: manager.retryAllFailed,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _ActionChip(
                        icon: CupertinoIcons.xmark,
                        label: 'Cancel all',
                        destructive: true,
                        onTap: () => _confirm(
                          context,
                          title: 'Cancel all downloads?',
                          action: 'Cancel all',
                          onConfirm: manager.cancelAll,
                        ),
                      ),
                    ],
                  ),
          ),
          _entries(queue, empty: 'No active downloads'),

          // History
          const _SectionLabel('COMPLETED', top: 24),
          _entries(history, empty: 'No completed downloads'),

          // On-disk chapters per title
          const _SectionLabel('DOWNLOADED', top: 24),
          downloaded.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(child: Text(e.toString())),
            data: (titles) => titles.isEmpty
                ? const SliverToBoxAdapter(
                    child: _EmptySection(message: 'No downloaded chapters'))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: titles.length,
                      itemBuilder: (_, i) =>
                          _DownloadedTitleTile(title: titles[i]),
                    ),
                  ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 90)),
        ],
      ),
    );
  }

  Widget _entries(
    AsyncValue<List<DownloadEntry>> entries, {
    required String empty,
  }) =>
      entries.when(
        loading: () => const SliverToBoxAdapter(
          child: Center(child: CupertinoActivityIndicator()),
        ),
        error: (e, _) => SliverToBoxAdapter(child: Text(e.toString())),
        data: (items) => items.isEmpty
            ? SliverToBoxAdapter(child: _EmptySection(message: empty))
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => _DownloadTile(entry: items[i]),
                ),
              ),
      );
}

/// Destructive confirmation sheet; runs [onConfirm] only on the red action.
Future<void> _confirm(
  BuildContext context, {
  required String title,
  required String action,
  required VoidCallback onConfirm,
}) async {
  final ok = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (ok == true) onConfirm();
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.trailing, this.top = 0});

  final String label;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, top, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTextStyles.metaMono.copyWith(
                    color: context.textTertiaryColor,
                    letterSpacing: 2.0,
                  )),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.entry});
  final DownloadEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(downloadManagerProvider.notifier);
    final isActive = entry.status == DownloadStatus.downloading ||
        entry.status == DownloadStatus.pending;
    final isPaused = entry.status == DownloadStatus.paused;
    final isFailed = entry.status == DownloadStatus.failed;

    return GestureDetector(
      onLongPress: entry.status == DownloadStatus.pending
          ? () => _showQueuedSheet(context, manager)
          : null,
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.mangaTitle,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                _StatusBadge(status: entry.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('Chapter ${entry.chapterNumber.toStringAsFixed(0)}',
                style: AppTextStyles.bodySmall),
            if (entry.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: entry.progress,
                backgroundColor: context.surfaceColor,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                minHeight: 4,
              ),
              const SizedBox(height: 2),
              Text(
                '${entry.downloadedPages} / ${entry.totalPages} pages',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            if ((isFailed || entry.status == DownloadStatus.pending) &&
                entry.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                entry.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color:
                      isFailed ? AppColors.warning : context.textTertiaryColor,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (isActive)
                  _ActionChip(
                    icon: CupertinoIcons.pause_fill,
                    label: 'Pause',
                    onTap: () => manager.pause(entry.id),
                  ),
                if (isPaused || isFailed)
                  _ActionChip(
                    icon: CupertinoIcons.play_fill,
                    label: isFailed ? 'Retry' : 'Resume',
                    onTap: () => manager.resume(entry.id),
                  ),
                if (entry.status != DownloadStatus.completed) ...[
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: CupertinoIcons.xmark,
                    label: 'Cancel',
                    destructive: true,
                    onTap: () => manager.cancel(entry.id),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: CupertinoIcons.trash,
                    label: 'Delete',
                    destructive: true,
                    onTap: () => manager.deleteDownload(entry.id),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQueuedSheet(BuildContext context, DownloadManager manager) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(entry.mangaTitle),
        message: Text('Chapter ${entry.chapterNumber.toStringAsFixed(0)}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              manager.moveToTop(entry.id);
            },
            child: const Text('Move to top'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              manager.cancel(entry.id);
            },
            child: const Text('Remove from queue'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class _DownloadedTitleTile extends ConsumerWidget {
  const _DownloadedTitleTile({required this.title});
  final DownloadedTitle title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(downloadManagerProvider.notifier);
    final chapters =
        '${title.chapterCount} chapter${title.chapterCount == 1 ? '' : 's'}';

    return _Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('$chapters · ${_formatBytes(title.bytes)}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ActionChip(
            icon: CupertinoIcons.trash,
            label: 'Delete all',
            destructive: true,
            onTap: () => _confirm(
              context,
              title: 'Delete all downloads for ${title.title}?',
              action: 'Delete $chapters',
              onConfirm: () => manager.deleteAllForManga(title.mangaId),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) => bytes < 1 << 20
    ? '${(bytes / 1024).round()} KB'
    : '${(bytes / (1 << 20)).toStringAsFixed(bytes < 100 << 20 ? 1 : 0)} MB';

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: child,
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.unread : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      DownloadStatus.completed => (AppColors.downloaded, 'Done'),
      DownloadStatus.downloading => (AppColors.accent, 'Downloading'),
      DownloadStatus.failed => (AppColors.unread, 'Failed'),
      DownloadStatus.paused => (AppColors.warning, 'Paused'),
      _ => (AppColors.textTertiary, 'Queued'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(message, style: AppTextStyles.bodySmall),
    );
  }
}

// Pull in LinearProgressIndicator from Material (pure widget, no visual style)
class LinearProgressIndicator extends StatelessWidget {
  const LinearProgressIndicator({
    super.key,
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
    this.minHeight = 4.0,
  });

  final double value;
  final Color backgroundColor;
  final AlwaysStoppedAnimation<Color> valueColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) => Stack(
        children: [
          Container(height: minHeight, color: backgroundColor),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: minHeight,
            width: constraints.maxWidth * value.clamp(0.0, 1.0),
            color: valueColor.value,
          ),
        ],
      ),
    );
  }
}
