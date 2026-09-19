import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/models/chapter_entry.dart';
import '../../core/database/models/manga_entry.dart';
import '../../core/providers/browse_provider.dart';
import '../../core/providers/chapter_prefs_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/source_registry_provider.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/category_sheet.dart';
import '../../shared/widgets/cover_image.dart';
import '../../shared/widgets/sumi.dart';
import '../../shared/widgets/sumi_actions.dart';
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
  /// Chapter ids picked in selection mode; null when not selecting.
  Set<int>? _selected;
  bool _refreshing = false;
  bool _expanded = false;

  MangaEntry get manga => widget.manga;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final insets = MediaQuery.paddingOf(context);
    final gutter = context.yomiGutter;

    final live = ref.watch(liveMangaProvider(manga.id)).valueOrNull ?? manga;
    final genres = <String, String>{};
    for (final rawGenre in live.genres) {
      final genre = rawGenre.trim();
      if (genre.isNotEmpty) {
        genres.putIfAbsent(genre.toLowerCase(), () => genre);
      }
    }
    if (genres.isEmpty) {
      ref.watch(mangaMetadataProvider(manga.id));
    }
    final chapterSync = ref.watch(chapterSyncProvider(manga.id));
    final liveChapters = ref.watch(liveChaptersProvider(manga.id));
    // The sync provider owns initial source loading; the live Isar stream owns
    // subsequent changes made by the reader or background download isolate.
    final chapters = (liveChapters.valueOrNull?.isEmpty ?? true)
        ? chapterSync
        : liveChapters;
    final chs = chapters.valueOrNull ?? const <ChapterEntry>[];
    final sort = ref.watch(chapterSortProvider(manga.id));
    final filter = ref.watch(chapterFilterProvider(manga.id));
    final display = applyChapterView(chs, sort: sort, filter: filter);
    final selected = _selected;
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
                  DisplayText(live.title,
                      size: context.look.isCinema ? 44 : 32),
                  const SizedBox(height: 4),
                  Text(meta, style: YomiText.ui(13, color: c.fg2)),

                  if (genres.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const SumiOverline('GENRES'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final genre in genres.values)
                          SumiChip(label: genre, active: false),
                      ],
                    ),
                  ],

                  // ── Buttons ───────────────────────────────────────────
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: SumiButton(
                          label: readLabel,
                          height: 50,
                          radius: context.look.isSumi ? 4 : null,
                          enabled: chs.isNotEmpty,
                          onTap: () => openReader(context,
                              manga: live, chapters: chs, index: continueIdx),
                          child: chapters.isLoading
                              ? const CupertinoActivityIndicator()
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onLongPress: unread == 0
                            ? null
                            : () => _showDownloadSheet(live, chs),
                        child: SumiSquareButton(
                          icon: CupertinoIcons.arrow_down_to_line,
                          onTap: unread == 0
                              ? null
                              : () => _downloadUnread(live, chs),
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
                    const SumiOverline('ABOUT', kanji: '作'),
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
                      if (selected != null) ...[
                        SumiOverline('${selected.length} SELECTED',
                            kanji: '選'),
                        const Spacer(),
                        SumiTextAction(
                          label: 'Actions',
                          onTap: selected.isEmpty
                              ? null
                              : () => _showSelectionSheet(live, chs),
                        ),
                        const SizedBox(width: 14),
                        SumiTextAction(
                          label: 'Done',
                          onTap: () => setState(() => _selected = null),
                        ),
                      ] else ...[
                        const SumiOverline('CHAPTERS', kanji: '話'),
                        const Spacer(),
                        SumiTextAction(
                          label: _refreshing ? 'Checking…' : 'Refresh',
                          onTap: _refreshing ? null : _refreshChapters,
                        ),
                        const SizedBox(width: 14),
                        SumiTextAction(
                          label: filter == ChapterFilter.all
                              ? 'Filter'
                              : filter.label.replaceAll(' only', ''),
                          onTap: () => _showFilterSheet(filter),
                        ),
                        const SizedBox(width: 14),
                        SumiTextAction(
                          label: sort.label,
                          onTap: () => _showSortSheet(sort),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (display.isEmpty && chs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No chapters match this filter.',
                          style: YomiText.ui(13, color: c.fg2)),
                    ),
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
                    selected: selected?.contains(display[i].id),
                    onTap: selected != null
                        ? () => _toggle(display[i].id)
                        : () => openReader(context,
                            manga: live,
                            chapters: chs,
                            index: chs.indexOf(display[i])),
                    onLongPress: selected != null
                        ? () => _toggle(display[i].id)
                        : () => _showChapterSheet(live, display[i]),
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
    showCategorySheet(
      context,
      allCategories:
          ref.read(libraryCategoriesProvider).where((x) => x != 'All').toList(),
      initial: live.categories,
      onSave: (cats) => ref
          .read(libraryNotifierProvider.notifier)
          .updateCategories(live.id, cats),
    );
  }

  void _toggle(int chapterId) => setState(() {
        final s = _selected!;
        s.contains(chapterId) ? s.remove(chapterId) : s.add(chapterId);
      });

  /// Unread, not-yet-downloaded chapters, oldest first. [limit] caps the
  /// batch ("next N unread").
  void _downloadUnread(MangaEntry live, List<ChapterEntry> chs, {int? limit}) {
    final next = chs.reversed.where((ch) => !ch.isRead && !ch.isDownloaded);
    ref.read(downloadManagerProvider.notifier).enqueueAll(
        manga: live,
        chapters: (limit == null ? next : next.take(limit)).toList());
  }

  void _showDownloadSheet(MangaEntry live, List<ChapterEntry> chs) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: const Text('Download'),
        actions: [
          for (final n in const [5, 10])
            sheetAction(sheet, 'Next $n unread',
                () => _downloadUnread(live, chs, limit: n)),
          sheetAction(sheet, 'All unread', () => _downloadUnread(live, chs)),
        ],
        cancelButton: sheetAction(sheet, 'Cancel', () {}),
      ),
    );
  }

  void _showChapterSheet(MangaEntry live, ChapterEntry ch) {
    HapticFeedback.mediumImpact();
    final lib = ref.read(libraryNotifierProvider.notifier);
    final dl = ref.read(downloadManagerProvider.notifier);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text(ch.title),
        actions: [
          sheetAction(
              sheet,
              ch.isRead ? 'Mark as unread' : 'Mark as read',
              () => lib.setChaptersRead(live.id, [ch.id], read: !ch.isRead)),
          sheetAction(sheet, 'Mark previous as read',
              () => lib.markPreviousChaptersRead(live.id, ch.id)),
          sheetAction(sheet, 'Mark all as read',
              () => lib.markAllChaptersRead(live.id)),
          if (ch.isDownloaded)
            sheetAction(sheet, 'Delete download',
                () => dl.deleteChapterDownload(ch.id),
                destructive: true)
          else
            sheetAction(
                sheet, 'Download', () => dl.enqueue(manga: live, chapter: ch)),
          sheetAction(
              sheet, 'Select', () => setState(() => _selected = {ch.id})),
        ],
        cancelButton: sheetAction(sheet, 'Cancel', () {}),
      ),
    );
  }

  void _showSelectionSheet(MangaEntry live, List<ChapterEntry> chs) {
    final picked = chs.where((ch) => _selected!.contains(ch.id)).toList();
    final ids = picked.map((ch) => ch.id).toList();
    final lib = ref.read(libraryNotifierProvider.notifier);
    final dl = ref.read(downloadManagerProvider.notifier);
    void done() => setState(() => _selected = null);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text('${ids.length} chapters'),
        actions: [
          sheetAction(sheet, 'Mark read', () {
            lib.setChaptersRead(live.id, ids, read: true);
            done();
          }),
          sheetAction(sheet, 'Mark unread', () {
            lib.setChaptersRead(live.id, ids, read: false);
            done();
          }),
          sheetAction(sheet, 'Download', () {
            dl.enqueueAll(
                manga: live,
                chapters: picked.where((ch) => !ch.isDownloaded).toList());
            done();
          }),
          sheetAction(sheet, 'Delete downloads', () {
            for (final ch in picked.where((ch) => ch.isDownloaded)) {
              dl.deleteChapterDownload(ch.id);
            }
            done();
          }, destructive: true),
        ],
        cancelButton: sheetAction(sheet, 'Cancel', () {}),
      ),
    );
  }

  void _showFilterSheet(ChapterFilter current) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: const Text('Filter chapters'),
        actions: [
          for (final f in ChapterFilter.values)
            sheetAction(
                sheet,
                f == current ? '${f.label} ✓' : f.label,
                () => ref.read(chapterFilterProvider(manga.id).notifier).state =
                    f),
        ],
        cancelButton: sheetAction(sheet, 'Cancel', () {}),
      ),
    );
  }

  void _showSortSheet(ChapterSort current) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: const Text('Sort chapters'),
        actions: [
          for (final s in ChapterSort.values)
            sheetAction(
                sheet,
                s == current ? '${s.label} ✓' : s.label,
                () =>
                    ref.read(chapterSortProvider(manga.id).notifier).state = s),
        ],
        cancelButton: sheetAction(sheet, 'Cancel', () {}),
      ),
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
    final look = context.look;
    final inLibrary = manga.inLibrary;
    Widget cover = SumiCoverFrame(
      shadow: true,
      radius: look.isPastel ? 20 : null,
      child: CoverImage(url: manga.coverUrl),
    );
    if (look.isPastel && !reduceMotion(context)) {
      cover = Transform.rotate(angle: -3 * 3.14159265 / 180, child: cover);
    }
    return Container(
      height: topInset + 290,
      decoration: BoxDecoration(
        color: look.isPastel ? c.ac : c.card,
        border:
            look.isPastel ? null : Border(bottom: BorderSide(color: c.line)),
        borderRadius: look.isPastel
            ? const BorderRadius.vertical(bottom: Radius.circular(40))
            : null,
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
                  width: look.isSumi ? 36 : 40,
                  height: look.isSumi ? 36 : 40,
                  decoration: BoxDecoration(
                    color: look.isCinema
                        ? const Color(0x66000000)
                        : (look.isPastel ? c.card : c.bg),
                    borderRadius: BorderRadius.circular(
                        look.isSumi ? 18 : (look.isPastel ? 14 : 0)),
                    boxShadow: look.cardShadow,
                  ),
                  child: Icon(
                    inLibrary
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    size: 18,
                    color: inLibrary
                        ? (look.isPastel ? c.fg : c.ac)
                        : (look.isCinema ? const Color(0xFFF1EBE2) : c.fg),
                  ),
                ),
              ),
            ),
          ),
          if (look.kanji)
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
                    style: YomiText.display(20, color: c.fg2, letterSpacing: 3),
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
                  child: cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
