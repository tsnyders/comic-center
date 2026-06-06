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
    BrowseMode.latest => source.fetchLatestUpdates(page: args.page),
    BrowseMode.search => source.search(args.query, page: args.page),
  };
});

// ── Upsert helper ─────────────────────────────────────────────────────────

bool _isRealTitle(String? s) {
  if (s == null) return false;
  final t = s.trim();
  return t.isNotEmpty && t.toLowerCase() != 'unknown';
}

/// Gets an existing [MangaEntry] from the DB or creates one by fetching
/// full detail from [source]. If [summary] is provided, its title/cover
/// are used as a fallback when the source's detail endpoint returns
/// nothing useful. Does not fetch chapters.
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

  // Reuse existing entry only if it has real data.
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
    ..sourceKey = sourceKey
    ..sourceId = source.id
    ..sourceMangaId = mangaId
    ..sourceUrl = detail.url ?? summary?.url ?? ''
    ..title = title
    ..coverUrl = coverUrl ?? entry.coverUrl
    ..author = detail.author ?? entry.author
    ..artist = detail.artist ?? entry.artist
    ..description = detail.description ?? entry.description
    ..status = detail.status == 'unknown' ? entry.status : detail.status
    ..lastUpdated = DateTime.now();
  if (detail.genres.isNotEmpty) entry.genres = detail.genres;

  await isar.writeTxn(() => isar.mangaEntrys.put(entry));
  return entry;
}

/// Wrapper that always exposes title as a non-null String even when the
/// underlying detail call fails entirely.
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

/// Loads chapters for [mangaId] from the DB, fetching from the source if
/// the DB is empty. The result is always sorted descending (latest first).
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

  final infos = await source.fetchChapterList(manga.sourceMangaId);
  if (infos.isEmpty) return [];

  final entries = infos
      .map(
        (info) => ChapterEntry()
          ..mangaId = mangaId
          ..sourceChapterId = info.id
          ..title = info.title
          ..number = info.number
          ..volume = info.volume
          ..scanlator = info.scanlator
          ..language = info.language
          ..uploadDate = info.uploadDate,
      )
      .toList();

  await isar.writeTxn(() async {
    await isar.chapterEntrys.putAll(entries);
    final m = await isar.mangaEntrys.get(mangaId);
    if (m != null) {
      m.chapterCount = entries.length;
      m.unreadCount = entries.length;
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
