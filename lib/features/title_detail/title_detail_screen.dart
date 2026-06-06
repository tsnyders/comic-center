import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DraggableScrollableSheet;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/providers/browse_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/cover_image.dart';
import '../reader/reader_screen.dart';
import 'widgets/chapter_list_tile.dart';

// ── Screen ─────────────────────────────────────────────────────────────────

class TitleDetailScreen extends ConsumerWidget {
  const TitleDetailScreen({super.key, required this.manga});

  final MangaEntry manga;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Stack(
        children: [
          // Full-bleed hero
          _DetailHero(manga: manga),

          // Back + add-to-library overlay
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      '‹ Back',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _AddToLibraryButton(manga: manga),
                ],
              ),
            ),
          ),

          // Draggable detail sheet
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.42,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.55, 0.95],
            builder: (context, scrollController) {
              return _DetailSheet(
                manga: manga,
                scrollController: scrollController,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.manga});
  final MangaEntry manga;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred cover
          CoverImage(url: manga.coverUrl),
          // Dark overlay + fade to background at bottom
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0xCC0A0A0F),
                  AppColors.background,
                ],
                stops: [0.0, 0.55, 0.85],
              ),
            ),
          ),
          // Blur layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: const SizedBox.expand(),
          ),
          // Vivid cover (top-right corner)
          Positioned(
            top: 80,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100,
                height: 150,
                child: CoverImage(url: manga.coverUrl),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav / action buttons ───────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x80000000),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderStrong, width: 0.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AddToLibraryButton extends ConsumerWidget {
  const _AddToLibraryButton({required this.manga});
  final MangaEntry manga;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch live state so the button reacts immediately after add/remove.
    final live = ref.watch(liveMangaProvider(manga.id)).valueOrNull ?? manga;
    final inLibrary = live.inLibrary;
    return _NavButton(
      onTap: () {
        if (inLibrary) {
          ref.read(libraryNotifierProvider.notifier).removeFromLibrary(manga.id);
        } else {
          ref.read(libraryNotifierProvider.notifier).addToLibrary(live);
        }
      },
      child: Icon(
        inLibrary ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
        color: inLibrary ? AppColors.accent : AppColors.textPrimary,
        size: 18,
      ),
    );
  }
}

// ── Bottom sheet ───────────────────────────────────────────────────────────

class _DetailSheet extends ConsumerWidget {
  const _DetailSheet({
    required this.manga,
    required this.scrollController,
  });

  final MangaEntry manga;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use live manga so chapter count updates after sync.
    final liveManga =
        ref.watch(liveMangaProvider(manga.id)).valueOrNull ?? manga;
    final chapters = ref.watch(chapterSyncProvider(manga.id));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(
              top: BorderSide(color: AppColors.borderStrong, width: 0.5),
            ),
          ),
          child: CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Drag handle
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Title + author
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(liveManga.title, style: AppTextStyles.sheetTitle),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (liveManga.author != null) liveManga.author!,
                          '·',
                          _capitalise(liveManga.status),
                          '·',
                          '${liveManga.chapterCount} ch',
                        ].join(' '),
                        style: AppTextStyles.sheetAuthor,
                      ),
                    ],
                  ),
                ),
              ),

              // Genre chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: liveManga.genres
                        .map((g) => _GenreChip(label: g))
                        .toList(),
                  ),
                ),
              ),

              // Action buttons
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _ActionRow(manga: manga, chapters: chapters),
                ),
              ),

              // Description
              if (liveManga.description != null &&
                  liveManga.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(
                      liveManga.description!,
                      style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Chapters heading
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    '${liveManga.chapterCount} Chapters'.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Chapter list
              chapters.when(
                loading: () => SliverToBoxAdapter(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CupertinoActivityIndicator(),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Text(e.toString(), style: AppTextStyles.bodySmall),
                ),
                data: (chs) => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: chs.length,
                    itemBuilder: (context, i) => ChapterListTile(
                      chapter: chs[i],
                      onTap: () => _openReader(context, chs[i]),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReader(BuildContext context, ChapterEntry chapter) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReaderScreen(
          mangaId: manga.id,
          chapterId: chapter.id,
          sourceId: manga.sourceId,
          sourceChapterId: chapter.sourceChapterId,
          chapterTitle: chapter.title,
        ),
      ),
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({
    required this.manga,
    required this.chapters,
  });

  final MangaEntry manga;
  final AsyncValue<List<ChapterEntry>> chapters;

  void _continueReading(BuildContext context, List<ChapterEntry> chs) {
    if (chs.isEmpty) return;
    // Chapters are sorted descending (latest first).
    // Reading order is ascending, so reversed = ascending.
    final ascending = chs.reversed.toList();
    final target = ascending.firstWhere(
      (c) => !c.isRead,
      orElse: () => ascending.last,
    );
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReaderScreen(
          mangaId: manga.id,
          chapterId: target.id,
          sourceId: manga.sourceId,
          sourceChapterId: target.sourceChapterId,
          chapterTitle: target.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chs = chapters.valueOrNull ?? [];
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 13),
            color: chs.isEmpty ? AppColors.surfaceElevated : AppColors.accent,
            borderRadius: BorderRadius.circular(14),
            onPressed: chs.isEmpty ? null : () => _continueReading(context, chs),
            child: chapters.isLoading
                ? const CupertinoActivityIndicator()
                : Text(
                    '▶  Continue Reading',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: chs.isEmpty
                          ? AppColors.textTertiary
                          : CupertinoColors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderStrong, width: 0.5),
          ),
          child: const Center(
            child: Icon(
              CupertinoIcons.arrow_down_circle,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
