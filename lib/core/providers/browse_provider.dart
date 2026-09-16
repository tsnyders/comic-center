import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../database/models/chapter_entry.dart';
import '../database/models/manga_entry.dart';
import '../extensions/models/manga_detail.dart';
import '../extensions/models/manga_summary.dart';
import '../extensions/source_interface.dart';
import 'database_provider.dart';
import 'provider_cache.dart';
import 'source_registry_provider.dart';

// ── Browse mode ───────────────────────────────────────────────────────────

enum BrowseMode { popular, latest, search, genre }

// ── Browse args (used as FutureProvider.family key) ───────────────────────

class BrowseArgs {
  const BrowseArgs({
    required this.sourceId,
    required this.mode,
    this.page = 1,
    this.query = '',
    this.genreId,
  });

  final String sourceId;
  final BrowseMode mode;
  final int page;
  final String query;
  final String? genreId;

  @override
  bool operator ==(Object other) =>
      other is BrowseArgs &&
      other.sourceId == sourceId &&
      other.mode == mode &&
      other.page == page &&
      other.query == query &&
      other.genreId == genreId;

  @override
  int get hashCode => Object.hash(sourceId, mode, page, query, genreId);
}

// ── Per-source providers ──────────────────────────────────────────────────

final browseModeProvider =
    StateProvider.family<BrowseMode, String>((ref, _) => BrowseMode.popular);

final browseGenreProvider = StateProvider.family<String?, String>((ref, _) => null);

final sourceGenresProvider = FutureProvider.autoDispose
    .family<List<GenreOption>, String>((ref, sourceId) async {
  ref.cacheFor(const Duration(minutes: 15));
  final source = ref.watch(sourceByIdProvider(sourceId));
  if (source == null) {
    throw Exception('Source "$sourceId" is not installed.');
  }
  return source.fetchGenres();
});

// autoDispose: BrowseArgs includes the search query and page number, so every
// query ever typed and every page ever browsed used to stay cached for the
// app's lifetime — an unbounded leak. cacheFor keeps each result warm for a
// bounded window so backing out of a title and returning to the catalog
// doesn't refetch, then lets it age out.
final browseMangaProvider = FutureProvider.autoDispose
    .family<List<MangaSummary>, BrowseArgs>((ref, args) async {
  ref.cacheFor(const Duration(minutes: 15));
  final source = ref.watch(sourceByIdProvider(args.sourceId));
  if (source == null) {
    throw Exception('Source "${args.sourceId}" is not installed.');
  }
  final genreId = args.genreId?.trim();
  if (args.mode == BrowseMode.genre &&
      (genreId == null || genreId.isEmpty)) {
    throw ArgumentError.value(args.genreId, 'genreId', 'A genre is required.');
  }
  return switch (args.mode) {
    BrowseMode.popular => source.fetchPopular(page: args.page),
    BrowseMode.latest => source.fetchLatestUpdates(page: args.page),
    BrowseMode.search => source.search(args.query, page: args.page),
    BrowseMode.genre => source.fetchByGenre(genreId!, page: args.page),
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

// Avoid fetching detail on every open when a source has no genre metadata.
// A later visit can retry, and the cache resets when the app restarts.
final _missingGenreRetryAfter = <String, DateTime>{};

List<String> _cleanGenres(Iterable<String> genres) {
  final byName = <String, String>{};
  for (final genre in genres) {
    final name = genre.trim();
    if (name.isNotEmpty) byName.putIfAbsent(name.toLowerCase(), () => name);
  }
  return byName.values.toList();
}

Future<MangaEntry> upsertMangaEntry({
  required Isar isar,
  required MangaSource source,
  required String mangaId,
  MangaSummary? summary,
}) async {
  final sourceKey = '${source.id}::$mangaId';

  final existing =
      await isar.mangaEntrys.filter().sourceKeyEqualTo(sourceKey).findFirst();

  final hasTitle = existing != null && _isRealTitle(existing.title);
  if (existing != null && hasTitle) {
    if (existing.genres.any((genre) => genre.trim().isNotEmpty)) {
      return existing;
    }
    final retryAfter = _missingGenreRetryAfter[sourceKey];
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
      return existing;
    }
  }

  MangaDetailLike detail;
  try {
    detail = MangaDetailLike.fromDetail(await source.fetchMangaDetail(mangaId));
  } catch (_) {
    detail = MangaDetailLike.empty();
  }

  final genres = _cleanGenres(detail.genres);
  if (hasTitle && genres.isEmpty) {
    _missingGenreRetryAfter[sourceKey] =
        DateTime.now().add(const Duration(minutes: 15));
    return existing!;
  }
  _missingGenreRetryAfter.remove(sourceKey);

  final title = _isRealTitle(detail.title)
      ? detail.title
      : (_isRealTitle(summary?.title)
          ? summary!.title
          : (existing?.title ?? detail.title));

  final coverUrl = detail.coverUrl ?? summary?.coverUrl;

  return isar.writeTxn(() async {
    // Re-read after the network request so a bookmark, category, or reading
    // progress changed while detail loaded is not overwritten by a stale row.
    final current =
        await isar.mangaEntrys.filter().sourceKeyEqualTo(sourceKey).findFirst();
    if (current != null &&
        _isRealTitle(current.title) &&
        current.genres.any((genre) => genre.trim().isNotEmpty)) {
      return current;
    }
    final entry = current ?? MangaEntry();
    entry
      ..sourceKey = sourceKey
      ..sourceId = source.id
      ..sourceMangaId = mangaId
      ..sourceUrl = detail.url ?? summary?.url ?? current?.sourceUrl ?? ''
      ..title = title
      ..coverUrl = coverUrl ?? entry.coverUrl
      ..author = detail.author ?? entry.author
      ..artist = detail.artist ?? entry.artist
      ..description = detail.description ?? entry.description
      ..status = detail.status == 'unknown' ? entry.status : detail.status
      ..lastUpdated = DateTime.now();
    if (genres.isNotEmpty) entry.genres = genres;
    await isar.mangaEntrys.put(entry);
    return entry;
  });
}

/// Hydrates one saved title when its stored genres are missing. The detail
/// screen watches this only for that title, so opening the library never
/// starts a catalogue-wide metadata fetch.
final mangaMetadataProvider = FutureProvider.autoDispose
    .family<MangaEntry?, int>((ref, mangaId) async {
  ref.cacheFor(const Duration(minutes: 15));
  final isar = ref.watch(isarProvider);
  final sources = ref.watch(sourceRegistryProvider);
  final manga = await isar.mangaEntrys.get(mangaId);
  if (manga == null || manga.genres.any((genre) => genre.trim().isNotEmpty)) {
    return manga;
  }
  MangaSource? source;
  for (final candidate in sources) {
    if (candidate.id == manga.sourceId) {
      source = candidate;
      break;
    }
  }
  if (source == null) return manga;
  return upsertMangaEntry(
    isar: isar,
    source: source,
    mangaId: manga.sourceMangaId,
  );
});

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

// autoDispose: keyed per manga id — grew without bound as titles were visited.
// Short TTL: the data is DB-backed so a refetch is cheap; the cache mainly
// smooths the detail-screen → reader → detail-screen round trip.
final chapterSyncProvider = FutureProvider.autoDispose
    .family<List<ChapterEntry>, int>((ref, mangaId) async {
  ref.cacheFor(const Duration(minutes: 5));
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

/// Live chapter state for UI fields that can change outside the detail screen,
/// including background-download completion and reader progress.
final liveChaptersProvider =
    StreamProvider.family.autoDispose<List<ChapterEntry>, int>((ref, mangaId) {
  final isar = ref.watch(isarProvider);
  return isar.chapterEntrys
      .filter()
      .mangaIdEqualTo(mangaId)
      .sortByNumberDesc()
      .watch(fireImmediately: true);
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
          ..title = info.title
          ..number = info.number
          ..uploadDate = info.uploadDate;
        await isar.chapterEntrys.put(existing);
      } else {
        final entry = ChapterEntry()
          ..mangaId = mangaId
          ..sourceChapterId = info.id
          ..title = info.title
          ..number = info.number
          ..volume = info.volume
          ..scanlator = info.scanlator
          ..language = info.language
          ..uploadDate = info.uploadDate;
        await isar.chapterEntrys.put(entry);
      }
    }

    final total =
        await isar.chapterEntrys.filter().mangaIdEqualTo(mangaId).count();
    final read = await isar.chapterEntrys
        .filter()
        .mangaIdEqualTo(mangaId)
        .isReadEqualTo(true)
        .count();
    final manga = await isar.mangaEntrys.get(mangaId);
    if (manga != null) {
      manga
        ..chapterCount = total
        ..unreadCount = (total - read).clamp(0, 9999)
        ..lastUpdated = DateTime.now();
      await isar.mangaEntrys.put(manga);
    }
  });
}
