import 'dart:typed_data';

import 'models/chapter_info.dart';
import 'models/filter.dart';
import 'models/manga_detail.dart';
import 'models/manga_summary.dart';

/// The contract every extension must implement.
///
/// Sources run in their own Isolate so network failures are isolated
/// from the UI thread. Only this interface crosses the Isolate boundary.
abstract class MangaSource {
  /// Stable unique identifier, e.g. "mangadex_en_v5".
  String get id;

  String get name;
  String get baseUrl;

  /// BCP-47 language tag, e.g. "en", "ko", "ja".
  String get language;

  /// Semver string of this extension build.
  String get version;

  /// PNG icon bytes bundled with the extension.
  Uint8List get iconBytes;

  /// HTTP headers injected into every page image request (auth, user-agent).
  Map<String, String> get imageHeaders;

  // ── Listings ──────────────────────────────────────────────────────────────

  Future<List<MangaSummary>> fetchPopular({int page = 1});

  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1});

  Future<List<MangaSummary>> search(
    String query, {
    int page = 1,
    List<SourceFilter> filters = const [],
  });

  // ── Detail ────────────────────────────────────────────────────────────────

  Future<MangaDetail> fetchMangaDetail(String mangaId);

  Future<List<ChapterInfo>> fetchChapterList(String mangaId);

  // ── Reader ────────────────────────────────────────────────────────────────

  /// Returns ordered list of full-resolution page URLs for [chapterId].
  Future<List<String>> fetchPageUrls(String chapterId);

  // ── Filters ───────────────────────────────────────────────────────────────

  List<SourceFilter> getFilters() => const [];
}
