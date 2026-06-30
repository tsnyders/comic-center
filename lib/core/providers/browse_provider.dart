import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/manga_entry.dart';
import '../extensions/models/manga_detail.dart';
import '../extensions/models/manga_summary.dart';
import '../extensions/source_interface.dart';
import 'database_provider.dart';
import 'source_registry_provider.dart';

// ── Browse mode ───────────────────────────────────────────────────────────

enum BrowseMode { popular, latest, search }

// ── Browse args (used as FutureProvider.family key) ───────────────────────

class BrowseArgs {
  const BrowseArgs({
    required this.sourceId,
    required this.mode,
    this.page = 1,
    this.query = '',
  });

  final String sourceId;
  final BrowseMode mode;
  final int page;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is BrowseArgs &&
      other.sourceId == sourceId &&
      other.mode == mode &&
      other.page == page &&
      other.query == query;

  @override
  int get hashCode => Object.hash(sourceId, mode, page, query);
}

// ── Per-source providers ──────────────────────────────────────────────────

final browseModeProvider =
    StateProvider.family<BrowseMode, String>((ref, _) => BrowseMode.popular);

final browseMangaProvider =
    FutureProvider.family<List<MangaSummary>, BrowseArgs>((ref, args) async {
  final source = ref.watch(sourceByIdProvider(args.sourceId));
  if (source == null) {
    throw Exception('Source "${args.sourceId}" is not installed.');
  }
  return switch (args.mode) {
    BrowseMode.popular => source.fetchPopular(page: args.page),
    BrowseMode.latest  => source.fetchLatestUpdates(page: args.page),
    BrowseMode.search  => source.search(args.query, page: args.page),
  };
});

// ── Upsert helper ─────────────────────────────────────────────────────────

bool _isRealTitle(String? s) {
  if (s == null) return false;
  final t = s.trim();
  if (t.isEmpty || t.toLowerCase() == 'unknown') return false;
  // Reject URL-slug-shaped titles (no spaces + percent encoding leftover from
  // a previous broken extraction, e.g. "Revenge-of-the-Iron%252DBlooded-...").
  if (!t.contains(' ') && t.contains('%')) return false;
  return true;
}

Future<MangaEntry> upsertMangaEntry({
  required Isar isar,
  required MangaSource source,
  required String mangaId,
  MangaSummary? summary,
}) async {
  final sourceKey = '${source.id}::$mangaId';

  final existing = await isar.mangaEntrys
      .filter()
      .sourceKeyEqualTo(sourceKey)
      .findFirst();

  if (existing != null && _isRealTitle(existing.title)) return existing;

  MangaDetailLike detail;
  try {
    detail = MangaDetailLike.fromDetail(await source.fetchMangaDetail(mangaId));
  } catch (_) {
    detail = MangaDetailLike.empty();
  }

  final title = _isRealTitle(detail.title)
      ? detail.title
      : (_isRealTitle(summary?.title) ? summary!.title : detail.title);

  final coverUrl = detail.coverUrl ?? summary?.coverUrl;

  final entry = existing ?? MangaEntry();
  entry
    ..sourceKey     = sourceKey
    ..sourceId      = source.id
    ..sourceMangaId = mangaId
    ..sourceUrl     = detail.url ?? summary?.url ?? ''
    ..title         = title
    ..coverUrl      = coverUrl ?? entry.coverUrl
    ..author        = detail.author ?? entry.author
    ..artist        = detail.artist ?? entry.artist
    ..description   = detail.description ?? entry.description
    ..status        = detail.status == 'unknown' ? entry.status : detail.status
    ..lastUpdated   = DateTime.now();
  if (detail.genres.isNotEmpty) entry.genres = detail.genres;

  await isar.writeTxn(() => isar.mangaEntrys.put(entry));
  return entry;
}

class MangaDetailLike {
  MangaDetailLike({
    required this.title,
    this.coverUrl,
    this.author,
    this.artist,
    this.description,
    this.genres = const [],
    this.status = 'unknown',
    this.url,
  });

  factory MangaDetailLike.fromDetail(MangaDetail detail) => MangaDetailLike(
        title: detail.title,
        coverUrl: detail.coverUrl,
        author: detail.author,
        artist: detail.artist,
        description: detail.description,
        genres: detail.genres,
        status: detail.status,
        url: detail.url,
      );

  factory MangaDetailLike.empty() => MangaDetailLike(title: '');

  final String title;
  final String? coverUrl;
  final String? author;
  final String? artist;
  final String? description;
  final List<String> genres;
  final String status;
  final String? url;
}

// ── Chapter sync ──────────────────────────────────────────────────────────

final chapterSyncProvider =
    FutureProvider.family<List<ChapterEntry>, int>((ref, mangaId) async {
  final isar = ref.watch(isarProvider);

  final existing = await isar.chapterEntrys
      .filter()
      .mangaIdEqualTo(mangaId)
      .sortByNumberDesc()
      .findAll();

  if (existing.isNotEmpty) return existing;

  final manga = await isar.mangaEntrys.get(mangaId);
  if (manga == null) return [];

  final source = ref.read(sourceByIdProvider(manga.sourceId));
  if (source == null) return [];

  final infos = (await source.fetchChapterList(manga.sourceMangaId))
      .where((info) => info.id.trim().isNotEmpty)
      .toList();
  if (infos.isEmpty) return [];

  final entries = infos
      .map(
        (info) => ChapterEntry()
          ..mangaId         = mangaId
          ..sourceChapterId = info.id
          ..title           = info.title
          ..number          = info.number
          ..volume          = info.volume
          ..scanlator       = info.scanlator
          ..language        = info.language
          ..uploadDate      = info.uploadDate,
      )
      .toList();

  await isar.writeTxn(() async {
    await isar.chapterEntrys.putAll(entries);
    final m = await isar.mangaEntrys.get(mangaId);
    if (m != null) {
      m.chapterCount = entries.length;
      m.unreadCount  = entries.length;
      await isar.mangaEntrys.put(m);
    }
  });

  return isar.chapterEntrys
      .filter()
      .mangaIdEqualTo(mangaId)
      .sortByNumberDesc()
      .findAll();
});

// ── Live manga entry stream ───────────────────────────────────────────────

final liveMangaProvider =
    StreamProvider.family.autoDispose<MangaEntry?, int>((ref, mangaId) {
  final isar = ref.watch(isarProvider);
  return isar.mangaEntrys.watchObject(mangaId, fireImmediately: true);
});

// ── Chapter refresh (pull-to-refresh) ────────────────────────────────────

/// Re-fetches chapters from the source and upserts them into the DB,
/// preserving existing read/download status on already-known chapters.
Future<void> refreshMangaChapters({
  required Isar isar,
  required MangaSource source,
  required int mangaId,
  required String sourceMangaId,
}) async {
  final infos = (await source.fetchChapterList(sourceMangaId))
      .where((info) => info.id.trim().isNotEmpty)
      .toList();
  if (infos.isEmpty) return;

  await isar.writeTxn(() async {
    for (final info in infos) {
      final existing = await isar.chapterEntrys
          .filter()
          .mangaIdEqualTo(mangaId)
          .and()
          .sourceChapterIdEqualTo(info.id)
          .findFirst();

      if (existing != null) {
        existing
          ..title      = info.title
          ..number     = info.number
          ..uploadDate = info.uploadDate;
        await isar.chapterEntrys.put(existing);
      } else {
        final entry = ChapterEntry()
          ..mangaId         = mangaId
          ..sourceChapterId = info.id
          ..title           = info.title
          ..number          = info.number
          ..volume          = info.volume
          ..scanlator       = info.scanlator
          ..language        = info.language
          ..uploadDate      = info.uploadDate;
        await isar.chapterEntrys.put(entry);
      }
    }

    final total = await isar.chapterEntrys.filter().mangaIdEqualTo(mangaId).count();
    final read  = await isar.chapterEntrys
        .filter()
        .mangaIdEqualTo(mangaId)
        .isReadEqualTo(true)
        .count();
    final manga = await isar.mangaEntrys.get(mangaId);
    if (manga != null) {
      manga
        ..chapterCount = total
        ..unreadCount  = (total - read).clamp(0, 9999)
        ..lastUpdated  = DateTime.now();
      await isar.mangaEntrys.put(manga);
    }
  });
}
