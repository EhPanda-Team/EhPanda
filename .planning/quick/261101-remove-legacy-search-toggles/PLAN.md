# Remove legacy search toggles — 2026-11-01

## Owner decision

After live comparisons on E-Hentai and ExHentai, the owner chose to remove the six Filters toggles
whose parameters the sites no longer honor: "移除六個開關". The proposal also covered `f_sr` and
`f_sp`, which were stated to be removed together unless the owner objected.

## Scope

- Remove the toggles for gallery name, gallery tags, gallery description, torrent filenames,
  low-power tags and downvoted tags from `FiltersView`.
- Remove their `Filter` fields, including the mutual-exclusion `didSet` pair.
- Remove `f_sname`, `f_stags`, `f_sdesc`, `f_storr`, `f_sdt1`, `f_sdt2`, `f_sr` and `f_sp` from
  `Defaults` and `URLUtil`.
- Remove the six `search_*` keys from the FiltersFeature catalog.
- Add no `SchemaV2`: synthesized decoding skips stale keys. Cover this with a test.

## Out of scope

- Reordering or renaming the remaining toggles.
- Applying or editing copy-audit proposals.
- Recapturing the Filters website screenshots.
- Testing the Favorites `sn`, `st`, `sf` parameters.

## Verification

- Strict SwiftLint on the changed Swift files.
- `AppModelsTests`, `NetworkingFeatureTests`, `HomeFeatureTests`, `AppFeatureTests` and
  `DownloadsFeatureTests`, the targets that construct `Filter`.
