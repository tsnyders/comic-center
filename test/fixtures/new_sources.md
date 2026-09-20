# Additional source fixtures

Captured 2026-09-20 with curl and Dio, using a Chrome browser user agent.
HTML files are small excerpts retaining source markup. Menus, ads, comments,
unrelated scripts, redundant records and all but a few reader images were
removed. Next JSON keeps its original envelope and representative records.
No image binary content is stored.

| Folder | Captured listing/detail | Captured chapters/reader |
| --- | --- | --- |
| thunderscans | `/comics/?order=popular`; `/comics/0086250808-i-got-the-weakest-class-dragon-tamer/` | Embedded chapter rows; `/1482765166-i-got-the-weakest-class-dragon-tamer-1/` (`ts_reader.run`) |
| rizzfables | `/series`; POST `/Index/filter_series` (`OrderValue=popular`, `StatusValue=all`, `TypeValue=all`); `/series/r2311170-a-bad-person` | Embedded chapter rows; `/chapter/r2311170-a-bad-person-chapter-1` (`#readerarea`) |
| manhwatop | `/manga/?m_orderby=views`; `/manga/martial-peak-series/` | Both chapter POSTs and reader returned 403; `*.synthetic.html` files are contract examples, **not live proof** |
| manhuaplus | `/manga/?m_orderby=views`; `/manga/martial-peak/` | Embedded chapter rows; `/manga/martial-peak/chapter-3860/` (`.reading-content`) |
| toonily | `/serie/?m_orderby=views`; `/serie/the-beginning-after-the-end-54f5cb7c/` | Embedded chapter rows; `/serie/the-beginning-after-the-end-54f5cb7c/chapter-1/` (`.reading-content`) |
| weebcentral | `/search/data?sort=Popularity&order=Descending&limit=32&offset=0&display_mode=Full%20Display`; `/series/01J76XY7E4JCPK14V53BVQWD9Y/Bleach` | `/series/01J76XY7E4JCPK14V53BVQWD9Y/full-chapter-list`; `/chapters/01J76XYY6FR49PR82YQB2FR3MK/images?is_prev=False&reading_style=long_strip` |
| flamecomics | `/browse`, `/`, `/series/2` (`__NEXT_DATA__`) | Chapter props; `/series/2/0c9db8012fbd1257` page props |
| webtoons | `/en/ranking/popular`; `/en/drama/the-price-is-your-everything/list?title_no=6054` | `m.webtoons.com/api/v1/webtoon/6054/episodes?pageSize=99999`; `/en/drama/the-price-is-your-everything/ep-1-murder-of-the-crown-princess/viewer?title_no=6054&episode_no=1` |
| mangakakalot | `/` cards only; catalogue/detail returned 403 | `/api/manga/rise-of-the-limitless-necromancer/chapters?limit=-1`; reader returned 403 |
| natomanga | `/` cards only; catalogue/detail returned 403 | `/api/manga/rise-of-the-limitless-necromancer/chapters?limit=-1`; reader returned 403 |
| allmanga | POST `https://api.allanime.day/api` catalogue/detail | POST chapter list; `pages.json` is the browser-capture payload contract, not a live WebView capture |

Base URLs are in `docs/SOURCES.md`. `genres.html` captures each theme's
catalogue genre controls. Rizz's description script is retained because
its text is rendered client-side from a JSON string.

Mangakakalot/NatoManga detail and reader fixtures explicitly use
`*.synthetic.html` filenames and placeholder content. Their captured
homepage cards exercise the shared card parser, not the blocked popular
route. Madara's two AJAX strategies are exercised with synthetic ManhwaTop
responses, including successful fallback and propagated HTTP failures.

Later Dio probes received 403 from ManhwaTop and Toonily and intermittent
500/520 from ManhuaPlus (its complete Dio chain succeeded on recheck).
A successful curl snapshot does not establish
reliable Dart/Android access. The Madara and Mangakakalot-family requests now
use `BrowserFetch.instance.userAgent`, matching the browser that supplies
clearance cookies through the separately implemented interceptor. Their
existing fixture-backed parsers need no further markup changes. Cloudflare
and device acceptance remain open until that interceptor is integrated and
verified on Android.
