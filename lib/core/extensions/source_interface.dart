import 'dart:typed_data';

import 'models/chapter_info.dart';
import 'models/filter.dart';
import 'models/genre_option.dart';
import 'models/manga_detail.dart';
import 'models/manga_summary.dart';
import 'models/source_preference.dart';

export 'models/genre_option.dart';
export 'models/source_preference.dart';

/// The contract every extension must implement.
///
/// Sources run in both the UI and background download isolates. Sources that
/// need the in-app browser for pages are prepared in the UI isolate first.
/// Keep network calls bounded with a connect/receive timeout.
/// See docs/SOURCES.md for the full contract, error-handling conventions,
/// and the steps to register a new source.
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

  /// Genres backed by this source's catalogue. An empty list means that the
  /// source has no verified genre browse route.
  Future<List<GenreOption>> fetchGenres() async => const [];

  /// Browse a source-native [genreId] returned by [fetchGenres].
  Future<List<MangaSummary>> fetchByGenre(
    String genreId, {
    int page = 1,
  }) =>
      throw UnsupportedError('Genre browsing is unavailable for $name.');

  // ── Detail ────────────────────────────────────────────────────────────────

  Future<MangaDetail> fetchMangaDetail(String mangaId);

  Future<List<ChapterInfo>> fetchChapterList(String mangaId);

  // ── Reader ────────────────────────────────────────────────────────────────

  /// Returns ordered list of full-resolution page URLs for [chapterId].
  Future<List<String>> fetchPageUrls(String chapterId);

  /// Page discovery requires the foreground app's in-app browser.
  bool get needsBrowserForPages => false;

  // ── Filters ───────────────────────────────────────────────────────────────

  List<SourceFilter> getFilters() => const [];

  // ── Settings ──────────────────────────────────────────────────────────────

  /// Per-source settings shown on the source settings screen. Sources read
  /// the stored values at request time through `SourcePrefs`.
  List<SourcePreference> get preferences => const [];
}
