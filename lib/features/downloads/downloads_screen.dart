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
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text('Downloads',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  )),
            ),
          ),

          // Active queue
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('Queue', style: AppTextStyles.sectionTitle),
            ),
          ),
          queue.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(child: Text(e.toString())),
            data: (items) => items.isEmpty
                ? SliverToBoxAdapter(child: _EmptySection(message: 'No active downloads'))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) => _DownloadTile(entry: items[i]),
                    ),
                  ),
          ),

          // History
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Text('Completed', style: AppTextStyles.sectionTitle),
            ),
          ),
          history.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(child: Text(e.toString())),
            data: (items) => items.isEmpty
                ? SliverToBoxAdapter(child: _EmptySection(message: 'No completed downloads'))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) => _DownloadTile(entry: items[i]),
                    ),
                  ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 90)),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.entry});
  final DownloadEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.mangaTitle,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: entry.progress,
                backgroundColor: AppColors.surface,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                minHeight: 4,
              ),
            ),
          ],
        ],
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
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
