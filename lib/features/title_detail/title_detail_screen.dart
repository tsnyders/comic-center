import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/providers/browse_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/sumi.dart';
import '../library/widgets/manga_card.dart' show mangaCoverHeroTag;
import '../reader/open_reader.dart';
import 'widgets/chapter_list_tile.dart';

/// ============================================================================
/// Title detail — cover floats on a `card` plate with the title set
/// vertically at the right edge; brush title, meta, Read + download buttons,
/// synopsis, then chapters with kanji numerals.
/// ============================================================================
class TitleDetailScreen extends ConsumerStatefulWidget {
  const TitleDetailScreen({super.key, required this.manga});

  final MangaEntry manga;

  @override
  ConsumerState<TitleDetailScreen> createState() => _TitleDetailScreenState();
}

class _TitleDetailScreenState extends ConsumerState<TitleDetailScreen> {
  /// false = newest first (source order); true = oldest first.
  bool _ascending = false;
  bool _refreshing = false;
  bool _expanded = false;

  MangaEntry get manga => widget.manga;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final insets = MediaQuery.paddingOf(context);
    final gutter = context.yomiGutter;

    final live = ref.watch(liveMangaProvider(manga.id)).valueOrNull ?? manga;
    final chapterSync = ref.watch(chapterSyncProvider(manga.id));
    final liveChapters = ref.watch(liveChaptersProvider(manga.id));
    // The sync provider owns initial source loading; the live Isar stream owns
    // subsequent changes made by the reader or background download isolate.
    final chapters = (liveChapters.valueOrNull?.isEmpty ?? true)
        ? chapterSync
        : liveChapters;
    final chs = chapters.valueOrNull ?? const <ChapterEntry>[];
    final display = _ascending ? chs.reversed.toList() : chs;
    final unread = chs.where((ch) => !ch.isRead).length;
    final continueIdx = _continueIndex(chs);
    final started = chs.any((ch) => ch.isRead || ch.lastPageRead > 0);
    final readLabel = chs.isEmpty
        ? 'No chapters'
        : started
            ? 'Read · Ch. ${_num(chs[continueIdx].number)}'
            : 'Start reading';

    final meta = [
      if (live.author?.isNotEmpty ?? false) live.author!,
      '${live.chapterCount} chapters',
      _capitalise(live.status),
    ].join(' · ');

    // Entrance comes from LumenPageRoute (fade + rise) so the cover Hero
    // has a single motion to fly over.
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Plate(manga: live, topInset: insets.top)),

          CupertinoSliverRefreshControl(onRefresh: _refreshChapters),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(live.title, style: YomiText.kanji(32, color: c.fg)),
                  const SizedBox(height: 4),
                  Text(meta, style: YomiText.ui(13, color: c.fg2)),

                  // ── Buttons ───────────────────────────────────────────
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: SumiButton(
                          label: readLabel,
                          height: 50,
                          radius: 4,
                          enabled: chs.isNotEmpty,
                          onTap: () => openReader(context,
                              manga: live, chapters: chs, index: continueIdx),
                          child: chapters.isLoading
                              ? const CupertinoActivityIndicator()
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SumiSquareButton(
                        icon: CupertinoIcons.arrow_down_to_line,
                        onTap: unread == 0
                            ? null
                            : () => ref
                                .read(downloadManagerProvider.notifier)
                                .enqueueAll(
                                  manga: live,
                                  chapters:
                                      chs.where((ch) => !ch.isRead).toList(),
                                ),
                      ),
                      if (live.inLibrary) ...[
                        const SizedBox(width: 10),
                        SumiSquareButton(
                          icon: CupertinoIcons.folder,
                          onTap: () => _showCategorySheet(context, live),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Download for offline · $unread unread of ${chs.length} chapters',
                    style: YomiText.ui(11, color: c.fg2),
                  ),

                  // ── Synopsis ──────────────────────────────────────────
                  if (live.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 26),
                    const SumiOverline('ABOUT · 作'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        live.description!,
                        maxLines: _expanded ? null : 5,
                        overflow: _expanded ? null : TextOverflow.ellipsis,
                        style: YomiText.ui(13, color: c.fg2, height: 1.55),
                      ),
                    ),
                  ],

                  // ── Chapters header ───────────────────────────────────
                  const SizedBox(height: 26),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const SumiOverline('CHAPTERS · 話'),
                      const Spacer(),
                      _TextAction(
                        label: _refreshing ? 'Checking…' : 'Refresh',
                        onTap: _refreshing ? null : _refreshChapters,
                      ),
                      const SizedBox(width: 14),
                      _TextAction(
                        label: _ascending ? 'Oldest first' : 'Newest first',
                        onTap: () => setState(() => _ascending = !_ascending),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),

          // ── Chapter list ──────────────────────────────────────────────
          chapters.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 0),
                child: Text(e.toString(), style: YomiText.ui(13, color: c.fg2)),
              ),
            ),
            data: (_) => SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverList.builder(
                itemCount: display.length,
                itemBuilder: (context, i) => SumiStagger(
                  index: i,
                  child: ChapterListTile(
                    chapter: display[i],
                    onTap: () => openReader(context,
                        manga: live,
                        chapters: chs,
                        index: chs.indexOf(display[i])),
                    onDownload: display[i].isDownloaded
                        ? null
                        : () => ref
                            .read(downloadManagerProvider.notifier)
                            .enqueue(manga: live, chapter: display[i]),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: insets.bottom + 40)),
        ],
      ),
    );
  }

  /// Newest-first list: the highest chapter the user has touched, else the
  /// first chapter (last in the list).
  static int _continueIndex(List<ChapterEntry> chs) {
    if (chs.isEmpty) return 0;
    final touched = chs.indexWhere((ch) => ch.isRead || ch.lastPageRead > 0);
    return touched >= 0 ? touched : chs.length - 1;
  }

  static String _num(double? n) => n == null
      ? '?'
      : n == n.roundToDouble()
          ? n.toStringAsFixed(0)
          : n.toString();

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<void> _refreshChapters() async {
    if (_refreshing) return;
    final source = ref.read(sourceByIdProvider(manga.sourceId));
    if (source == null) {
      _showError('Source "${manga.sourceId}" is not installed.');
      return;
    }
    setState(() => _refreshing = true);
    try {
      await refreshMangaChapters(
        isar: ref.read(isarProvider),
        source: source,
        mangaId: manga.id,
        sourceMangaId: manga.sourceMangaId,
      );
      ref.invalidate(chapterSyncProvider(manga.id));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Refresh Failed'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCategorySheet(BuildContext context, MangaEntry live) {
    final allCats =
        ref.read(libraryCategoriesProvider).where((x) => x != 'All').toList();
    if (allCats.isEmpty) {
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('No Categories'),
          content:
              const Text('Create categories in Settings → Categories first.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _CategorySheet(manga: live, allCategories: allCats),
    );
  }
}

// ── Header plate ──────────────────────────────────────────────────────────────

class _Plate extends ConsumerWidget {
  const _Plate({required this.manga, required this.topInset});
  final MangaEntry manga;
  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yc;
    final inLibrary = manga.inLibrary;
    return Container(
      height: topInset + 290,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: topInset + 12,
            child: const SumiBackButton(),
          ),
          Positioned(
            right: 16,
            top: topInset + 12,
            child: Semantics(
              button: true,
              label: inLibrary ? 'Remove from library' : 'Add to library',
              child: SumiPress(
                onTap: () {
                  final n = ref.read(libraryNotifierProvider.notifier);
                  inLibrary
                      ? n.removeFromLibrary(manga.id)
                      : n.addToLibrary(manga);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: c.bg, shape: BoxShape.circle),
                  child: Icon(
                    inLibrary
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    size: 18,
                    color: inLibrary ? c.ac : c.fg,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            top: topInset + 56,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  manga.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: YomiText.kanji(20, color: c.fg2, letterSpacing: 3),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 22,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 150,
                height: 220,
                child: Hero(
                  tag: mangaCoverHeroTag(manga.id),
                  child: SumiCoverFrame(
                    shadow: true,
                    child: CoverImage(url: manga.coverUrl),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small text action (refresh / sort) ────────────────────────────────────────

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(label, style: YomiText.ui(12, color: c.fg2)),
      ),
    );
  }
}

// ── Category assignment sheet ─────────────────────────────────────────────────

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.manga, required this.allCategories});

  final MangaEntry manga;
  final List<String> allCategories;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final List<String> _selected = List.from(widget.manga.categories);

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final gutter = context.yomiGutter;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: EdgeInsets.fromLTRB(
          gutter, 20, gutter, MediaQuery.paddingOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SumiOverline('CATEGORIES · 類'),
          const SizedBox(height: 6),
          Text('Add to category', style: YomiText.kanji(26, color: c.fg)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in widget.allCategories)
                SumiChip(
                  label: cat,
                  active: _selected.contains(cat),
                  onTap: () => setState(() => _selected.contains(cat)
                      ? _selected.remove(cat)
                      : _selected.add(cat)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SumiButton(
            label: 'Save',
            height: 50,
            radius: 4,
            onTap: () async {
              await ref
                  .read(libraryNotifierProvider.notifier)
                  .updateCategories(widget.manga.id, _selected);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
