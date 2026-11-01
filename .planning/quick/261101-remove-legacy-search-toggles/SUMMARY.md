# Remove legacy search toggles — 2026-11-01

## Owner request

After reviewing live comparisons on both sites, the owner chose to remove the six Filters toggles:
"移除六個開關". The owner's request to check ExHentai as well as E-Hentai was met before that decision.

## Evidence

Both sites' advanced search forms no longer have these fields. Comparing results with and without each
parameter, using gallery IDs and pagination cursors because the displayed counts are estimates:

| Parameter | Toggle | E-Hentai | ExHentai |
| --- | --- | --- | --- |
| `f_sname` | Search Gallery Name | Ignored | Ignored |
| `f_stags` | Search Gallery Tags | Ignored | Ignored |
| `f_sdesc` | Search Gallery Description | Ignored | Ignored |
| `f_storr` | Search Torrent Filenames | Ignored, one sample | Ignored, one sample |
| `f_sdt1` | Search Low-Power Tags | Ignored | Ignored |
| `f_sdt2` | Search Downvoted Tags | Almost certainly ignored | Almost certainly ignored |

Positive controls used the documented `title:`, `tag:`, `comment:`, `weak:` and `gid:` qualifiers.
`f_sdt2` has no direct control. Both sites' pagination links keep `f_sto`, `f_srdd`, `f_spf` and `f_spt`
but drop all six, plus `f_sr` and `f_sp`. E-Hentai was tested signed out with 32 requests, ExHentai signed
in with 20 requests, spaced at least 8 and 9 seconds apart. No request was refused.

## Change

- `FiltersView`: the Advanced section keeps Require Gallery Torrent and Browse Only Expunged Galleries.
- `Filter`: the six fields and the `lowPowerTags`/`downvotedTags` `didSet` pair are gone.
- `Defaults` and `URLUtil`: the six parameters, `f_sr` and `f_sp` are gone. The rating and page range
  helpers no longer take `queryItems2`.
- FiltersFeature catalog: the six `search_*` keys are gone from all six locales.
- No `SchemaV2`. Synthesized decoding skips the stale keys and keeps every other setting, and the next
  save drops them. An older build reading a new blob fails decoding and resets that filter to its
  default, the same outcome a version bump would give. The comment on `schemaVersion` records this.
- Search results do not change, because neither site honors the removed parameters.

## Verification

- New tests: `StrictDecodingTests.aFilterBlobCarryingRemovedFieldsDecodesAndKeepsItsSettings` and
  `FilterSearchURLTests.advancedFilterSendsOnlyTheSiteFormParameters` on both hosts.
- `DownloadFilterAndBadgeTests`: three page range tests no longer expect `f_sp`.
- `AppModelsTests`, `NetworkingFeatureTests`, `HomeFeatureTests`, `AppFeatureTests` and
  `DownloadsFeatureTests` on a temporary iPhone Air simulator (iOS 27.2): 1,184 cases passed and 4 failed.
  Three were the `f_sp` expectations above. `AppModelsTests` and `DownloadsFeatureTests` then passed 722
  cases with no failures. The fourth is `GalleryCoverLayoutTests.richSlideshowGrowsForMetadataWithoutClipping`,
  already recorded by earlier 2026-11-01 quick tasks and outside this change. It remains open.
- No compiler warnings in either run. Strict SwiftLint is clean on the changed Swift files.
- On a temporary iPhone Air simulator (iOS 27.2), the Filters screen in English light mode shows Require
  Gallery Torrent and Browse Only Expunged Galleries in the Advanced section, followed by the rating and
  page range rows. Other locales, dark mode and other sizes were not opened.
- Not tested: the Favorites `sn`, `st`, `sf` parameters.

## Knock-on effects

- 24 of the 192 website review screenshots show the Filters screen and now differ from the app. They were
  not changed here.
- The copy-audit task has already dropped its 18 findings on the removed keys from
  `261101-copy-audit/proposals.json`, which now has none.
