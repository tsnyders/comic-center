# Adding a Manga/Comic Source

This documents the `MangaSource` extension contract referenced from the
README's "Source plugin interface" section — what each method must return,
how errors are expected to be handled, and the steps to wire up a new source.

---

## The contract

```dart
abstract class MangaSource {
  String get id;                          // stable, e.g. "asurascans_en"
  String get name;                        // display name, e.g. "AsuraScans"
  String get baseUrl;                     // canonical site URL
  String get language;                    // BCP-47, e.g. "en", "ko", "ja"
  String get version;                     // semver of this extension build
  Uint8List get iconBytes;                // PNG icon bytes (empty Uint8List(0) if none)
  Map<String, String> get imageHeaders;   // headers injected into page image requests

  Future<List<MangaSummary>> fetchPopular({int page = 1});
  Future<List<MangaSummary>> fetchLatestUpdates({int page = 1});
  Future<List<MangaSummary>> search(String query, {int page = 1, List<SourceFilter> filters = const []});

  Future<MangaDetail> fetchMangaDetail(String mangaId);
  Future<List<ChapterInfo>> fetchChapterList(String mangaId);

  Future<List<String>> fetchPageUrls(String chapterId);

  List<SourceFilter> getFilters() => const [];
}
```

Defined in [`lib/core/extensions/source_interface.dart`](../lib/core/extensions/source_interface.dart).

**Threading note:** despite an old doc comment claiming otherwise, sources do
**not** run in a separate Isolate — `grep -r Isolate lib/core/` turns up
nothing but that comment. Every `MangaSource` method runs inline on the UI
isolate, called directly from Riverpod providers (`browse_provider.dart`,
`download_provider.dart`, `reader_provider.dart`). A slow or hanging request
inside a source method will jank the UI thread; keep network calls bounded
with `Dio`'s `connectTimeout`/`receiveTimeout` (see existing sources for the
pattern — typically 15s connect / 20–30s receive).

### `id`

Must be globally unique and stable across releases — it's persisted as
`MangaEntry.sourceId` / `SourceEntry.sourceId` in the Isar database. Changing
an `id` after release orphans every user's existing library entries for that
source. Convention: `{site}_{lang}` (e.g. `asurascans_en`), or
`{site}_{lang}_v{n}` if the site has versioned APIs (e.g. `mangadex_en_v5`).

### `fetchPopular` / `fetchLatestUpdates` / `search`

Return a page of `MangaSummary` (`id`, `title`, `coverUrl?`, `url?`). `id`
here becomes `MangaEntry.sourceMangaId` and must be stable and re-derivable —
it's what `fetchMangaDetail`/`fetchChapterList` are called with later.
`page` is 1-indexed. There is currently no pagination UI wired up in Browse
(see TODO #10), so multi-page sources should still implement paging correctly
for when that lands.

### `fetchMangaDetail(mangaId)`

Returns full `MangaDetail`. **Do not throw** if individual fields are
missing — `upsertMangaEntry` (in `browse_provider.dart`) wraps this call in
a `try/catch` and falls back to an empty detail plus the `MangaSummary` title
already known. Missing `genres`/`author`/`coverUrl` should resolve to `null`
or empty list, not an exception. Only throw for genuine fetch failures
(network error, 404, source unreachable).

### `fetchChapterList(mangaId)`

Returns `List<ChapterInfo>` (`id`, `title`, `number?`, `volume?`,
`scanlator?`, `language?`, `uploadDate?`, `url?`).

- **`id` must never be empty.** `chapterSyncProvider` and
  `refreshMangaChapters` (`browse_provider.dart`) both filter out any
  `ChapterInfo` with an empty `id` before writing to the DB — an empty ID
  can't be reliably matched against existing rows on refresh, so chapters
  with no derivable ID are silently dropped rather than corrupting state.
- `id` is opaque to the rest of the app and round-trips back to your source
  via `fetchPageUrls`. Encode whatever your source needs into it — see
  AsuraScans' `"$mangaSlug::$chapterUUID::$chapterNumber"` composite-key
  pattern in `asura_scans_source.dart` for an example of packing multiple
  lookup strategies into one ID.
- Returning an **empty list** is valid (treated as "no chapters yet"), not
  an error.

### `fetchPageUrls(chapterId)`

Returns ordered, full-resolution image URLs for the reader. As of the medium
bug-fix pass, **an empty list is now treated as an error** by
`chapterPagesProvider` (`reader_provider.dart`) — it throws so the reader
shows a retry affordance instead of a blank screen. If a chapter genuinely
has no pages (removed by the source, dead link, etc.), prefer throwing a
descriptive `Exception` yourself over returning `[]`, so the error message
is specific to what went wrong rather than the generic fallback text.

### `getFilters()`

Optional. Default `const []`. Return `SourceFilter` instances
(`TextFilter`, `SelectFilter`, `TriStateFilter` — see
`lib/core/extensions/models/filter.dart`) for any search filters the site
supports (genre, status, sort order, etc.).

---

## Error handling expectations

There's no source-level error type hierarchy — sources throw plain
`Exception`s (or let `Dio`'s `DioException` propagate) and callers catch at
the provider/UI boundary. Conventions observed across existing sources:

- **Listing/search calls** (`fetchPopular`, `fetchLatestUpdates`, `search`,
  `fetchChapterList`): let exceptions propagate. Callers surface them via
  Riverpod's `AsyncValue.error` state, which the relevant screen renders.
- **Detail calls** (`fetchMangaDetail`): catch internally and degrade
  gracefully (see above) — the caller already has a `MangaSummary` to fall
  back on, so a hard failure here is a worse UX than a partial result.
- **Page fetches** (`fetchPageUrls`): throw with a message specific enough
  to help diagnose source breakage (see AsuraScans' multi-strategy fallback
  in `fetchPageUrls`, which only throws after exhausting three lookup
  strategies, with the attempted slug/uuid/chapter values in the message).
- Exception **messages are shown directly to the user** in several places
  (reader error view, browse error view) — write them as user-facing text,
  not stack-trace-style internals.

---

## Implementation patterns in this codebase

Two flavors exist among the bundled sources:

- **JSON API** (`asura_scans_source.dart`, `mangadex_source.dart`,
  `comick_source.dart`): a `Dio` client hitting a REST/GraphQL endpoint,
  parsing `Map`/`List` responses defensively (see `_dataList`/`_dataMap`
  helpers in `asura_scans_source.dart` — they probe several common response
  envelope shapes since APIs aren't always consistent).
- **HTML scraping** (`comicextra_source.dart`, `readcomiconline_source.dart`,
  `demonicscans_source.dart`): `Dio` + `package:html` to fetch and parse
  pages with CSS selectors.

Both flavors implement the same `MangaSource` contract — pick whichever
fits the target site.

---

## Wiring up a new source

A source isn't reachable from the app just by implementing `MangaSource` —
it has to be registered in `ExtensionFactory`
(`lib/core/extensions/extension_factory.dart`):

```dart
static MangaSource? create(String sourceId) => switch (sourceId) {
  'mangadex_en_v5'     => MangaDexSource(),
  // ...
  'your_new_source_id' => YourNewSource(),   // 1. add this line
  _                    => null,
};
```

If the source should be installable from the in-app extension catalogue
(`extensions_screen.dart`, which lists the upstream keiyoushi index), also
add it to `pkgToSourceId` (mapping the keiyoushi package name to your
`sourceId`) or, if it's not in the keiyoushi index at all, to
`builtInExtensions` so it's always offered regardless of the upstream
catalogue — see `ReadComicOnline`/`ComicExtra` for the pattern.

If the source should be installed by default for new users, add it to
`ExtensionManager.seedDefaults` (`lib/core/services/extension_manager.dart`).

**Known gap:** `comick_source.dart` defines a working `ComicKSource` that is
*not* currently wired into `ExtensionFactory.create` or `pkgToSourceId` —
it exists but is unreachable from the running app. Either finish wiring it
up or remove it; don't take it as a reference for "already integrated."

### Checklist

1. Implement `MangaSource` in `lib/core/extensions/sources/your_source.dart`.
2. Register it in `ExtensionFactory.create`.
3. Add it to `pkgToSourceId` or `builtInExtensions` so it's installable.
4. (Optional) Add it to `ExtensionManager.seedDefaults` if it should ship
   pre-installed.
5. Add a test under `test/sources/` — see `comick_source_test.dart` and
   `demonicscans_source_test.dart` for the pattern (mock `Dio`'s adapter,
   assert parsed output shape).
