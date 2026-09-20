# AllManga fixtures

`popular.json`, `latest.json`, `search.json`, and `detail.json` are trimmed
from Dio responses captured from `https://api.allanime.day/api` on
2026-09-20. The detail chapter list is a representative subset of the live
response.

`pages.json` freezes the verified `pictureUrlHead` plus scalar `pictureUrls`
contract. It is not a successful 2026-09-20 capture: the live service and the
AllManga web client both returned `AA_CRYPTO_MISSING` for `chapterPages` that
day.
