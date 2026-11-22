---
phase: 261121-ovv-design-v1-1-0-on-port-462-grey-favorite-
plan: 01
subsystem: lists-and-detail-ui
tags: [favorites, rating, localization, swiftui]
requires: []
provides:
  - Secondary-coloured favorite heart in list rows and grid cells, on the page-count line in the grid
  - Stars without the user-rating colour outside the detail page's open rating row
  - Edit Rating label once the fetched detail page has the user's rating (six locales)
  - Read ring with the download ring's 2.5-pt stroke
affects: [GalleryListComponents, AppModels, ParserFeature, NetworkingFeature, DetailFeature]
key-files:
  modified:
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryFavoriteHeart.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
    - AppPackage/Sources/AppModels/Gallery/Gallery.swift
    - AppPackage/Sources/AppModels/Gallery/UserRatingTint.swift
    - AppPackage/Sources/ParserFeature/Parser+Types.swift
    - AppPackage/Sources/ParserFeature/Parser+List.swift
    - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
    - AppPackage/Sources/DetailFeature/DetailReducer.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
    - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings
    - AppPackage/Tests/AppModelsTests/GalleryStatusFieldsTests.swift
    - AppPackage/Tests/ParserFeatureTests/List/GalleryStatusParserTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DetailFavoriteStateTests.swift
  deleted:
    - AppPackage/Tests/GalleryListComponentsTests/GalleryRatingTintRenderTests.swift
decisions:
  - "Hearts are secondary everywhere in lists; the slot colour stays on the detail page's favorite button (owner item 4)"
  - "Edit Rating reads galleryDetail.userRating > 0, the site's own page value, never the row's drag value (owner item 6)"
metrics:
  completed: 2026-11-21
status: complete
actuals:
  tokens: 8900
  tasks: 4
  commits: 4
plan_head_before: 61e891376376fe4ac437e453c2cb4caa7f418cf6
plan_head_after: 93de62e7d59e84cd69fe1d2e60be2e88b995cd0a
---

# Phase 261121-ovv Plan 01: Screens v1.1.0 design on port/462 Summary

Grey favorite hearts (grid heart on the page-count line), stars without the user-rating colour outside the open rating row, an Edit Rating label once the site has the user's rating, and the Read ring's 2.5-pt stroke; the now-dead list rating colour is gone from model, parser, request and reducer.

## Commits

All four are signed (`G`) with author and committer dates at +08:00. `git rev-list --count` from the recorded base gives 4.

| Task | Hash | Message | Signature line |
| ---- | ---- | ------- | -------------- |
| 1 | 98323626f | lists: grey favorite hearts on the count line | G 2026-11-21T17:18:30+08:00 2026-11-21T17:37:42+08:00 |
| 2 | e47b3507a | lists, detail: stars in the plain colour | G 2026-11-21T18:16:44+08:00 2026-11-21T18:16:44+08:00 |
| 3 | 0088f0ea6 | detail: Edit Rating once the gallery is rated | G 2026-11-21T18:18:30+08:00 2026-11-21T18:18:30+08:00 |
| 4 | 93de62e7d | detail: the Read ring's stroke is 2.5 pt | G 2026-11-21T18:59:06+08:00 2026-11-21T18:59:06+08:00 |

Plan base is `61e891376` (the orchestrator rewrote the history below Task 1 during the run; see Deviations).

## Gates

- **Baseline** (clean tree): build succeeded; 0 warnings (`warnings-baseline.txt` empty); lint over all nine directories empty.
- **Task 1:** build succeeded, no new warning; lint (`GalleryListComponents`) empty; every count gate printed its EXPECT value; `GalleryDetailCell.swift` untouched; staged list exactly the two files.
- **Task 2:** build succeeded, no new warning; lint over the nine directories empty; every count gate printed its EXPECT value (5 source files and 2 test files still name `userRatingTint`, as listed in the plan; Subviews numstat `3 0`; detail cell numstat `16 1`; 8 and 6 `@Test`s; KEEP files unchanged); no warning or error in the three edited test files; staged list is the 14 paths.
- **Task 2 TEST** (`task2`, six `-only-testing` bundles): `** TEST SUCCEEDED **`, 1131 passed, 0 failed, 6 expected failures (1137 cases). Per bundle: AppModelsTests 142; DetailFeatureTests 213; DownloadsFeatureTests 534 (+6 expected failures); GalleryListComponentsTests 13; NetworkingFeatureTests 118; ParserFeatureTests 111.
- **Task 3:** build succeeded, no new warning; lint (`DetailFeature`) empty; catalog diff `41 0`; the JSON reload gate printed `ok` (key directly after `rate_gallery`, extraction state manual, all six values, all `translated`); all Subviews gates matched (`ratingButtonTitle` 1, ternary 1, `Text(ratingButtonTitle)` 1, `.rateGallery` 1, open-row colour 1, comment 1, `previewActionSection(` 5, `#Preview("Actions` 4, rated previews 2); the catalog still has no trailing newline.
- **Task 4:** build succeeded, no new warning; lint (`DetailFeature`) empty; stroke, inset, download-ring and `3pt thick` gates as expected; no code change besides the stroke (empty diff filter); item 7 gates (slot colour expression 1, `favoriteColor` 2) and item 9 gate (no diff in `SettingFeature` or `AppTools`) as expected.
- **Task 4 TEST** (`task4`, whole FeatureTests plan minus VisualSnapshotTests): `** TEST SUCCEEDED **`, 1984 passed, 0 failed, 9 expected failures (1993 cases), 0 compiler warnings or errors in the log. `HeaderSectionActionSpacingTests` (3) and `ReduceMotionGatingSourceTests` (5) passed unchanged. Per bundle: AnalyticsClientTests 116 (+2 expected failures); AppFeatureTests 220; AppModelsTests 142; AppToolsTests 18; CookieClientTests 20; DetailFeatureTests 213; DownloadsFeatureTests 534 (+6 expected failures); FavoritesFeatureTests 22; FileClientTests 8; GalleryListComponentsTests 13; HomeFeatureTests 81; HostedViewTests 15; ImageClientTests 9; ImageColorsTests 4; LiveCheckTests 11; LiveTextTranslationTests 77; MarkdownExtTests 11; NetworkingFeatureTests 118; ParserFeatureTests 111; ReadingFeatureTests 122; SearchFeatureTests 18; SettingFeatureTests 85 (+1 expected failure); SystemNotificationTests 4; TagTranslationFeatureTests 12. The FavoritesFeatureTests flake did not occur.
- Every touched Swift file is at most 1000 lines (largest: `DetailView+Subviews.swift`, 807). `git status --short` shows only the untracked plan directory.

## Deviations from Plan

**1. [Orchestrator-fixed rebase defect] Task 2 TEST blocked at the first attempt.** The test target did not compile: `HeaderSectionDownloadLabelTests` built `HeaderSection(...)` without `readingProgress` and `isReaderOnScreen`. Task 2 TEST was blocked by a rebase defect in `HeaderSectionDownloadLabelTests`; fixed by the orchestrator in the introducing commits (fixup and autosquash, with two test-build warning fixes in `DetailReadingProgressTests` and `DetailFavoriteStateTests`). The history below Task 1 was rewritten, so the plan base `7268c40bc` became `61e891376` and Task 1's `5994fb2a0` became `98323626f` (same content). Where the plan's gates name `7268c40bc`, I used `61e891376`. The commit ledger was updated to the new base. I made no code decision of my own.

**2. Re-run of Task 2's build gate not repeated after the rewrite.** The orchestrator reported a clean `build-for-testing`; Task 2's test run (which builds everything) then passed. Tasks 3 and 4 each had a fresh build and lint.

Otherwise: none. The plan was executed as written.

## Auth gates

None.

## Known Stubs

None added.

## Threat Flags

None. The only new surface is the catalog entry, covered by T-261121-ovv-01.

## Open for the owner

E-Hentai list pages give only the user's own rating for a gallery the user has rated. In every Favorites list fixture (`AppPackage/Sources/TestingSupport/Resources/Parser/List/Favorites*List.html`) a rated row has a single star element, `class="ir irb" style="background-position:0px -1px"` (the user's 5 stars), and no average anywhere in the row. So a rated gallery's list row and grid cell still show the user's own rating, now in the plain colour; the design's "always the average" cannot be met from the list page alone. No workaround was built (no detail fetch, no hiding); the owner decides. The detail page's facts strip does show the average (`Parser+Detail` reads `#rating_label`).

This is the planner's finding, recorded as given. My own spot check on the fixtures found `class="ir irb"` star elements in each of them (counts 3 or 6 per file), consistent with the three rated rows the parser tests assert; I did not re-derive the `background-position` value.

## Snapshots to re-record

`git grep -n -E "favoriteTagIndex|favoriteTagName|isFavorited: true|userRating|readingProgress|showsUserRating" -- AppPackage/Tests/VisualSnapshotTests EhPandaUITests AppPackage/Sources/AppFeature/UITestSupport` hits:

- `AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift:561`: `reading.readingProgress` (diagnostics read, no rendering change)
- `AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Gallery.swift:425`: `userRating: 0` in a detail fixture
- `AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Library.swift:550`: `userRating: 0` in a detail fixture
- `AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Library.swift:596-597`: `state.showsUserRating = true`, `state.userRating = 7` (scenario `gallery-detail-rating`, with the site's `userRating` at 0)

No VisualSnapshotTests scenario sets a favorite slot, a list rating colour, a site-confirmed user rating or reading progress, so none is expected to change; `gallery-detail-rating` keeps Rate Gallery and plain stars. The Appshot marketing captures `home` and `detail` run on live account data and change only if that account has a favorite in Home (grey heart on the count line), a rated gallery (Edit Rating; list stars without colour) or a read gallery (thinner Read ring). Nothing was run or re-recorded.

## Self-Check: PASSED

All four commits exist (`git log` lists them in order, each `G` with two +08:00 dates), the 17 changed paths are as planned (16 modified, one deleted file), and the plan directory is the only untracked path.

## Rebase onto develop

Before this task, `port/462` was rebased from `4d98daab0` onto develop `02373e7db` (quick 261121-neo), so the design changes there come in first. The old tip was `cc586344a`. Before the merge it was rebased again onto develop `102d1709c` (quick 261121-m6q), which conflicted only in this record's `STATE.md` lines; the New column gives the hashes after that second rebase. Conflicts: `STATE.md` (develop's role wording kept, the #462 progress note restored in that wording by this record; the port's older records were brought to the same wording at the second rebase), `HeaderSectionActionSpacingTests` (both hosts' arguments), `ReduceMotionGatingSourceTests` (both branches' header gates counted: header 2 and 5, totals 38 and 82), and the header metrics (develop's download ring inset next to the Read ring's own). Two test fixes went into the commits that need them: `HeaderSectionDownloadLabelTests` takes the Read button's new host arguments, and the `makeStore` helpers of `DetailReadingProgressTests` and `DetailFavoriteStateTests` are `@MainActor`, which develop's dependency update requires.

| Old | New | Commit |
| --- | --- | ------ |
| 712941ade | 443417d76 | docs(state): mark the age wall and analytics choice as shipped in 3.0 (owner decision) |
| 4b5a04b6c | 934dd92f7 | favorites: read the sort order from the page's select and never overwrite it with nil |
| de74c968a | 4928d97fe | cache: cap the reader byte cache at 2 GiB and the Kingfisher and SDWebImage disk caches at 1 GiB |
| b57a1ac0b | ee8aaafc0 | search: tag suggestions understand the ~tag and -tag prefixes |
| 3e0db3fc7 | b1fcf1b1c | about: credit dyphire among the code contributors |
| cbeb137b8 | 6edd33f07 | docs(quick-261113-h72): Port #462 (dyphire) part 1: favorites sort order, cache caps, tag prefixes |
| 9b5234543 | e89e9e7c9 | search: tag suggestions in the saved search editor |
| b1ceb1a29 | d999bad5f | lists, detail: favorite slot, the user's own rating and expunged galleries |
| 65937a9d0 | 3689828d1 | lists: leave rows that are not favorites structurally unchanged |
| b9175ef6c | bde36a197 | detail: the Read button shows the page the reader resumes at |
| b40c94fd8 | 6f592229d | docs(quick-261113-h72): part 2 summary and the #462 progress row |
| 30fab27a3 | ffc8f6d8c | cache: the owner's disk limits, 1 GiB reader cache, 512 MiB Kingfisher, 128 MiB SDWebImage |
| 2b0476faa | 406e4a734 | detail: the Read button shows reading progress as a ring, not a capsule |
| 0ad794440 | 3ca8208ff | docs(quick-261113-h72): the Read button's progress ring replaces the capsule |
| 0f96f02fc | 1d84158fd | test: the Reduce Motion inventory counts the Read button's ring |
| 30bcf9243 | 60e3f9288 | detail: the Read button's ring grows once the reader has closed |
| e8fe132c6 | ca6799941 | docs(quick-261113-h72): rebased hashes, the ring's timing and the CJK typing check |
| b53da3062 | 2c1eb289f | lists, detail: the user's rating in the site's own colour, set per appearance |
| cc586344a | 61e891376 | docs(quick-261113-h72): the user's rating colour per the designer |
