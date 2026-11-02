# Consolidated tag database

Every language now comes from one repository, `EhPanda-Team/ehpanda-tag-database`. Its pipeline builds `en`, `ja`,
`ko`, `zh-Hans` and `zh-Hant` (Taiwan usage only) daily, and the app compares the digest of its own language's asset
instead of the release date. OpenCC, its fork dependency and its tests are gone from the app. Korean is wired in.

The repository went public on 2026-11-02 at the owner's request, and the app on this branch downloads from it.
Anonymous requests for the latest release and its six assets succeed, and every asset matches its API digest.

## Results

- Same upstream snapshot compared with the live assets: English and Korean identical; Japanese identical except
  96 empty entries for tags no longer upstream, removed on purpose.
- Assets shrink: English 4.6 MB to 1.2 MB, Japanese 5.2 to 1.6, Korean 4.7 to 1.2, Simplified Chinese 6.0 to 5.3.
- Traditional Chinese now converts descriptions and link labels: 11,307 of 12,984 descriptions changed, and Traditional
  Chinese readers previously saw these in Simplified. Compared with the app's old conversion, 57 of 44,806 names differ
  because of the newer OpenCC dictionary, and those sampled are corrections (`託` to `托` in transliterated names).
- A purged cache now downloads again. The check compared persisted metadata before, which left an empty table until
  the next upstream release.
- The Japanese seed dropped 18 entries by owner decision on 2026-11-02. Against the release before that, 17 tags lost
  their Japanese name and 1 tag left the index. English, Korean and both Chinese assets stayed byte-identical.

## Release tags

Owner decision on 2026-11-02: tags follow the upstream release, as the old English and Japanese repositories did. A
later release on the same upstream takes a number, as in `v7.29530.1-2`; that path is covered by unit tests only, since
no such release has happened yet. The first `db-` release was deleted, and before going public the owner had the
repository recreated with one first commit, now `170aa05`, which holds everything from before going public. Each later
release adds a bot commit on top, by owner decision, because `state/latest.json` is the audit trail and keeps the
schedule enabled.

## Old repositories

The owner also had `EhTagTranslation_Database_EN` and `_JPN` recreated on 2026-11-02 under the same names, so v2.8.1
reads them from the same URLs. Each holds one commit with its README, license text and source manifest, plus
`sources/e-hentaidb.html` for Japanese, and has no workflows or data files in git. `v7.29530.1` is their only release,
with the same `db.raw.json` as before; `v7.29522.1` and `v7.29510.1` are gone. Anonymous requests for the latest
release and its asset both succeed and match the earlier bytes. The new `published_at` may make v2.8.1 download them
once more. The owner then archived both, and both still serve the release. `EhTagTranslation_Database_KOR` is already
deleted.

## Dependency updates

Dependabot checks `github-actions` and `pip` weekly. It cannot update Python itself, so `update-python.yml` does: it
takes the newest minor that `setup-python` offers and `opencc` has a hash-pinned wheel for. `.python-version` is the
one place that names the version. `opencc` 1.4.2 has wheels up to Python 3.14, so 3.15 is skipped until OpenCC ships
one.

By owner decision on 2026-11-02, updates land on their own once they pass their check. For Python and OpenCC,
`update-python.yml` and the new `land-dependabot.yml` build every dataset before and after the update from the same
sources and run the tests. Identical output goes to `main` as a bot push, and changed output waits in a pull request
for a person. OpenCC 1.3.0 and 1.4.1 both convert differently from 1.4.2, so real OpenCC updates will often wait.
Dependabot's GitHub Actions pull requests land once `Validate` passes on the new versions.

Temporary private repositories exercised each path with real Dependabot pull requests:

- On the branch tip, a fast-forward kept Dependabot's commit and GitHub marked the pull request as merged.
- Behind the tip, a rebase landed a bot-committed copy and the workflow closed the pull request.
- An OpenCC update that changed `zh-Hant.json` stayed open, and the landing job was skipped.
- A GitHub Actions update and an OpenCC update landed in one run. When the OpenCC check failed, the GitHub Actions
  update still landed, the OpenCC pull request stayed open and the run ended as failed.
- A GitHub Actions update whose `Validate` run failed stayed open.
- Python landed directly when the data matched and opened a pull request when it did not. `Validate` shows
  `action_required` on that bot pull request, which is why the testing happens first.

`GITHUB_TOKEN` pushed changes to workflow files there, both as a fast-forward and as a new rebased commit. On the public
repository both landing workflows have run once and found nothing to do, so no update has landed there yet.

## Decisions taken without asking, for owner review

- Repository name `ehpanda-tag-database`, as recommended; the owner did not object. One constant in the app.
- About gains a link to the repository, because its README holds the CC BY attribution for the Japanese sources.
- A Japanese key with conflicting names now keeps its seed value instead of blocking all Japanese updates.

## Verification

- Pipeline: 89 unit tests pass, and a local build of all five datasets succeeds against live sources.
- GitHub: on the recreated repository, `Validate` and `Update databases` both succeed, on CPython 3.14.9. The current
  release `v7.29536.1` has six assets, and every API digest matches the downloaded bytes. The latest run reported that
  every dataset matches that release and published nothing. `Update Python` and `Land Dependabot updates` also ran
  there and found nothing to do. Those three workflows ran again after the repository went public, with the same
  results.
- Live download: a Debug build of `ccc2ea626` on an iPhone Air simulator (iOS 27.2) with Enhanced Tags on, launched once
  per language. `en`, `ja`, `ko`, `zh-Hans` and `zh-Hant` each downloaded from `v7.29536.1`. Each cached file has its
  asset's size and digest, and the stored metadata names that language and digest, which the app writes only after a
  successful decode. Relaunching in Traditional Chinese did not rewrite the cached file.
- Search suggestions showed names from the downloaded tables: `language:japanese` as 日語 in Traditional Chinese and 日本語
  in Japanese, and `character:agumon` as 아구몬 in Korean. Simplified Chinese was not checked in the interface, and English
  has no names to show.
- Published Traditional and Simplified Chinese have the same keys, and no URL differs between them. Japanese reports
  25,647 named tags, the same count as the entries in its seed.
- App: feature test plan, excluding `VisualSnapshotTests`, 1,397 tests: 1,387 passed and 1 failed (see below). The
  other 9 were not classified in the result summary and were not looked into. Strict lint and the test build are clean.
  A scratch copy of the app's decoding model read all five real files.
- Independent review ran; its findings are fixed except those listed under limitations.

## Limitations

- No scheduled run has happened yet; every run so far was started by hand.
- `GalleryCoverLayoutTests.richSlideshowGrowsForMetadataWithoutClipping` measures a height of 2000 at the large text
  size. It fails the same way on the commit before the app switch, so this work did not cause it; not fixed here.
- A capture fixture's `release.json` must now list `assets`. Metadata with only `published_at` no longer decodes.
- `.planning/codebase/` still names OpenCC. Those maps also list long-removed dependencies, so they were left alone.
- Found in review, predates this work and not changed: removing a custom import leaves an empty table until relaunch,
  and a fetch in flight can overwrite an import that lands first.

## Owner follow-ups

- After v3.0 ships: delete `EhTagTranslation_Database_EN` and `_JPN`, which v2.8.1 still reads.
- `EhPanda-Team/SwiftyOpenCC` is no longer used by the app.
