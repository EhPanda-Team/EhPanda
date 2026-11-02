# Consolidated tag database

Every language now comes from one repository, `EhPanda-Team/ehpanda-tag-database`. Its pipeline builds `en`, `ja`,
`ko`, `zh-Hans` and `zh-Hant` (Taiwan usage only) daily, and the app compares the digest of its own language's asset
instead of the release date. OpenCC, its fork dependency and its tests are gone from the app. Korean is wired in.

The repository is private on GitHub for now, by owner decision on 2026-11-02, and its first release is published. An
anonymous request for the latest release returns 404, so the app has nothing to download until it goes public.

## Results

- Same upstream snapshot compared with the live assets: English and Korean identical; Japanese identical except
  96 empty entries for tags no longer upstream, removed on purpose.
- Assets shrink: English 4.6 MB to 1.2 MB, Japanese 5.2 to 1.6, Korean 4.7 to 1.2, Simplified Chinese 6.0 to 5.3.
- Traditional Chinese now converts descriptions and link labels: 11,307 of 12,984 descriptions changed, and Traditional
  Chinese readers previously saw these in Simplified. Compared with the app's old conversion, 57 of 44,806 names differ
  because of the newer OpenCC dictionary, and those sampled are corrections (`託` to `托` in transliterated names).
- A purged cache now downloads again. The check compared persisted metadata before, which left an empty table until
  the next upstream release.

## Decisions taken without asking, for owner review

- Repository name `ehpanda-tag-database`, as recommended; the owner did not object. One constant in the app.
- About gains a link to the repository, because its README holds the CC BY attribution for the Japanese sources.
- A Japanese key with conflicting names now keeps its seed value instead of blocking all Japanese updates.

## Verification

- Pipeline: 46 unit tests pass, and a local build of all five datasets succeeds against live sources.
- GitHub: `Validate` and `Update databases` both succeed. The first run published `db-20261102-0130` from upstream
  `v7.29530.1` with six assets, and every API digest matches the downloaded bytes. A second run reported that every
  dataset matches the latest release and published nothing.
- Published Traditional and Simplified Chinese have the same keys, and no URL differs between them. Japanese holds all
  25,665 named entries of the seed.
- App: feature test plan, excluding `VisualSnapshotTests`, 1,397 tests: 1,387 passed and 1 failed (see below). The
  other 9 were not classified in the result summary and were not looked into. Strict lint and the test build are clean.
  A scratch copy of the app's decoding model read all five real files.
- Independent review ran; its findings are fixed except those listed under limitations.

## Limitations

- Not run: a live download in the simulator, which needs the repository to be public. The first scheduled run has not
  happened yet; both runs so far were started by hand.
- `GalleryCoverLayoutTests.richSlideshowGrowsForMetadataWithoutClipping` measures a height of 2000 at the large text
  size. It fails the same way on the commit before the app switch, so this work did not cause it; not fixed here.
- A capture fixture's `release.json` must now list `assets`. Metadata with only `published_at` no longer decodes.
- `.planning/codebase/` still names OpenCC. Those maps also list long-removed dependencies, so they were left alone.
- Found in review, predates this work and not changed: removing a custom import leaves an empty table until relaunch,
  and a fetch in flight can overwrite an import that lands first.

## Owner follow-ups

- Make the repository public, then verify a live download per language in the simulator.
- Delete `EhTagTranslation_Database_KOR`, which no release ever read. The owner is handling this, and the pipeline does
  not depend on it; Korean comes from `project-violet/tag-info`.
- After v3.0 ships: delete `EhTagTranslation_Database_EN` and `_JPN`, which v2.8.1 still reads.
- `EhPanda-Team/SwiftyOpenCC` is no longer used by the app.
