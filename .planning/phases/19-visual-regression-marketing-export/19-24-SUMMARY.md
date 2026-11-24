---
phase: 19-visual-regression-marketing-export
plan: "24"
subsystem: ui
tags: [home-slideshow, stat-labels, front-page-fixture, confirmation-dialog, ipad-popover, hosted-tests]

requires:
  - phase: 19-23
    provides: "the C9 and C6 decisions (the owner's words are binding) and the C7 handover"
provides:
  - "C9: the Front Page shelf of `home-populated` receives the 8 public fixtures (4 columns); the compact slideshow card puts its stats below the cover at the card's full width, one stat per line, when the two-column grid does not fit beside it; the regular card falls back to the same lines when its two equal columns do not fit; `SlideshowInformationLayoutTests`, `HomeFrontPageFixtureTests`"
  - "C7: the Delete Folder and Delete Saved Search confirmations are attached to the row whose Delete was tapped, through a key path into the one `@Presents` dialog, so the iPad popover points at that row; `RowConfirmationAnchorTests`, `FolderManagerDeleteConfirmationTests`, `SavedSearchDeleteConfirmationTests`"
  - "C6: no change, as the owner decided (the system `Picker` stays; the clipped `ko` accessibility5 portrait rows are a recorded known limitation)"
affects: [19-25, 19-26]

actuals:
  tokens: 13800
  tasks: 2
  commits: 2

plan_head_before: 785464b7e24d91e8223aa16dfecc66bf7b788a18
plan_head_after: c9ab0eefecf3983f25a4f5a45550af7f912f90fe

key-files:
  created:
    - AppPackage/Sources/HomeFeature/HomeCompactSlideshowLayout.swift
    - AppPackage/Tests/HostedViewTests/SlideshowInformationLayoutTests.swift
    - AppPackage/Tests/HostedViewTests/RowConfirmationAnchorTests.swift
    - AppPackage/Tests/DetailFeatureTests/FolderManagerDeleteConfirmationTests.swift
    - AppPackage/Tests/SearchFeatureTests/SavedSearchDeleteConfirmationTests.swift
  modified:
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
    - AppPackage/Sources/HomeFeature/HomeCompactSlideshowContent.swift
    - AppPackage/Sources/HomeFeature/HomeCompactSlideshowInformation.swift
    - AppPackage/Sources/HomeFeature/HomeGalleryInformation.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/TracerSnapshotTests.swift
    - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerReducer.swift
    - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerView.swift
    - AppPackage/Sources/QuickSearchFeature/QuickSearchReducer.swift
    - AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift

key-decisions:
  - "The compact card's choice between 'stats beside the cover' and 'stats below the cover' is made by the card, as a `ViewThatFits` over one `HomeCompactSlideshowLayout` per arrangement, because a stat view cannot place itself below its sibling cover. The layout reports the cover, its spacing and the narrowest the stats get as the beside arrangement's ideal width, so the title's one-line width never decides it."
  - "The delete dialog stays one `@Presents` value with a `pendingDeletion` target and a read-only `subscript(deleteConfirmationFor:)`; each row scopes `$store.scope(state: \\.[deleteConfirmationFor: id], action: \\.confirmationDialog)`. TCA's binding scope accepted the subscript key path, so no closure `Binding` and no per-row reducer was needed."

requirements-completed: [VIS-18-01]
status: complete
---

# Phase 19 Plan 24: C9 stat labels and Front Page fixture, C7 row-anchored delete confirmations Summary

**The Front Page shelf shows 8 galleries in 4 columns, the compact slideshow card moves its stats under the cover (one "label value" line each) before any label can break mid-word, the regular card falls back to the same lines, and the Delete Folder and Delete Saved Search popovers on the iPad point at the row whose Delete was tapped; each fix is one signed commit with tests that failed before it and pass after it.**

All local runs of this plan ran on the iOS 27.2 simulator runtime (owner decision 2026-11-24); every measured value below is an iOS 27.2 value, and the earlier baseline2 evidence the record quotes was iOS 27.0. Strict SwiftLint ran from the standalone binary 0.65.1 (the SPM artifact the build plugin uses), from each module's own directory. Evidence is in `$W` (`$ROOT/.capture/agent-work/phase19-24`, ignored).

## Accomplishments

- **Task 1, C9** (`237f59ebe`):
  - **Fixture.** `TracerScenarios.homeState()` (new, `home()` builds its store from it) gives the Front Page `galleries + carouselNeighbors()`, the 8 public fixtures, all cached by `cacheHomeArtwork`; the fixture export is unchanged.
  - **Compact card.** `HomeCompactSlideshowContent` is now the whole compact card: `ViewThatFits(in: .horizontal) { card(.beside); card(.below) }` over `HomeCompactSlideshowLayout` (cover, title, stats, optional tags, in VoiceOver order). Beside the cover the stats are the existing 3-column then 2-column grid; when the 2-column grid does not fit the text column, the stats go below the cover at the card's full width as `HomeSlideshowStatLines` (rating, pages, category, one per line). The tags are still dropped when they do not fit under the title and the stats in the cover's height (`HomeCompactSlideshowTags`, a `ViewThatFits(in: .vertical)` that shows nothing in a proposal that is too short).
  - **Regular card.** `HomeSlideshowInformation` shows Pages and Category in two equal columns (`HomeEqualColumnsLayout`, private to `HomeGalleryInformation.swift`; ideal width twice the wider column plus the spacing), capped at 360 pt as before, and falls back to the same `HomeSlideshowStatLines` (pages, category) when they do not fit.
  - **Identifiers** (`home_slideshow_information`, `home_slideshow_title_<id>`, `home_slideshow_cover_<id>`) are unchanged; `GalleryCardCell` lost its `compactCoverSize` property, as the layout takes the cover's own size.
- **Task 2, C7** (`c9ab0eefe`): in `FolderManagerReducer` and `QuickSearchReducer`, `pendingDeletion` (`String?`, `SavedSearch.ID?`) is set with the dialog and cleared on `.presented(.confirmDelete)` and `.dismiss`; a read-only `subscript(deleteConfirmationFor:)` returns the dialog only for the target. The list-level `.confirmationDialog` is gone from both views; the folder row (after its swipe actions) and the saved search's row button each carry `.confirmationDialog($store.scope(state: \.[deleteConfirmationFor: id], action: \.confirmationDialog))`. Swipe and context actions are unchanged. No `Binding(get:set:)`, no hoisting, no lint suppression.

## RED and GREEN evidence (iOS 27.2)

| Task | RED (before the fix) | GREEN (after) |
| --- | --- | --- |
| C9 fixture | `Failed 4 3` (the run `c9-red2`, iPhone Air): `HomeFrontPageFixtureTests` failed `("2") is not equal to ("8")` and the gid list `["VH2", "VH3"]` against the 8 fixtures | `Passed 4 0` (`c9-green1`) |
| C9 compact card, six locales at `.accessibility5` | failed for all six: `en` "Rating" and "Pages" 102.3 pt tall against one line 51.3 pt, "Category" not drawn (dropped by the squeeze); `de` "Bewertung" 153.3 pt (three lines), "Seiten" 102.3, "Kategorie" not drawn; `ja`, `zh-Hans`, `zh-Hant` labels 102.3 pt, `ko` "페이지" 102.3 pt; every stat label also started at the title's x (beside the cover) instead of left of it | `Passed` (same run) |
| C9 regular card, `en` and `de` | failed: `en` "Category" 102.3 pt and "Doujinshi" 116.7 pt, `de` "Kategorie" 102.3 pt and "Doujinshi" 116.7 pt (one line is 51.3 pt for a label, 58.3 pt for the value) | `Passed` |
| C9 guard at `.large`, `en` | passed on the old code too (the stats are beside the cover there; the test keeps the new fallback from firing when it should not) | `Passed` |
| C9 verify block as written | | `** TEST SUCCEEDED **`, `Passed 386 0` (`HostedViewTests/SlideshowInformationLayoutTests`, all of `VisualSnapshotTests` and `HomeFeatureTests`; `c9.xcresult`) |
| C7 hosted, iPad | `Failed 2 2` (`c7-red-ipad`): the folder popover points at (417.0, 635.5), outside its row (20.0, 181.5, 794.0, 60.5); the saved-search popover points at (417.0, 661.5), outside its row (20.0, 277.0, 794.0, 87.0) | `** TEST SUCCEEDED **`, `Passed 27 0` |
| C7 hosted, iPhone | no RED: at compact width the dialog is an action sheet and the test only requires one to be presented, which the old code also did | `** TEST SUCCEEDED **`, `Passed 27 0` |
| C7 reducer tests | no runtime RED: `pendingDeletion` and the subscript did not exist, so `FolderManagerDeleteConfirmationTests` and `SavedSearchDeleteConfirmationTests` could not compile before the fix (the 19-22 precedent) | in the two `Passed 27 0` runs (the verify block's `DetailFeatureTests/FolderManagerDeleteConfirmationTests` and all of `SearchFeatureTests`) |

The C7 verify block ran as written on both phase simulators (`c7-<udid>.xcresult` in `$W`).

Acceptance (C7): `grep -cF 'scope(\.$confirmationDialog'` over the two views sums to 0; `grep -c 'deleteConfirmationFor'` over them sums to 2. Strict lint of `Sources/HomeFeature`, `Sources/DetailFeature`, `Sources/QuickSearchFeature`, `Tests/DetailFeatureTests`, `Tests/SearchFeatureTests`, `Tests/HostedViewTests` and `Tests/VisualSnapshotTests`, each from its own directory, prints nothing.

## Picture checks (by eye with the Read tool)

C9, `HomeSnapshotTests/testHomePopulated`, candidate mode (`$W/c9-capture-phone`, `$W/c9-capture-pad`). The runs report `error` for the expected `page-height` coordinates only (the home page needs 1755 pt at `en-large` and 4373 pt at `de-accessibility5` against 912 pt committed; the full height is 19-26's), and every picture is recorded.

- **iPhone, `de-accessibility5`, portrait** (`$W/c9-capture-phone/actual/iphone/de/accessibility5/home-populated/portrait-light.png`): the Start card shows the cover and the title beside it, and under the cover "Bewertung 4,5", "Seiten 24", then "Kategorie" with "Doujinshi" under it. No label is hyphenated or broken, the card is not clipped and the carousel is not cut, and the Front Page heading follows below. The title is cut with an ellipsis as before (the cover's height is its budget).
- **iPhone, `en-large`, portrait** (`.../en/large/home-populated/portrait-light.png`): the card is the old beside-the-cover layout (Rating, Pages, Category as a grid), unchanged; the Front Page shows the first three of its four columns, each with two covers.
- **iPhone, `de-accessibility5`, landscape** (`.../landscape-light.png`): the two-column grid (Bewertung, Seiten) beside the cover, as before the fix; nothing is cut.
- **iPad, `de-accessibility5`, portrait** (`$W/c9-capture-pad/actual/ipad/de/accessibility5/home-populated/portrait-light.png`): the regular card shows the star rating, "Seiten 24", then "Kategorie" with "Doujinshi" under it; no label is hyphenated ("Kate-gorie" and "Dou-jinshi" are gone). The Front Page shows four columns.
- **iPad, `en-large`, portrait** (`.../en/large/home-populated/portrait-light.png`): the regular card keeps its two columns (Pages, Category); the Front Page shows 4 columns of two rows, the 8 fixtures.

C7, `QuickSearchSnapshotTests/testDeleteConfirmation` and `DetailPagesMoreSnapshotTests/testFolderDeleteConfirmation`, `en-large`, light pictures (`$W/c7-capture-pad-portrait`, `$W/c7-capture-pad-landscape`, `$W/c7-capture-phone`). The runs report `error` for the expected `page-height` coordinates only (iPhone portrait Quick Search 944 against 912, landscape 709 / 656 against 420; iPad Quick Search 1242 against 1210 portrait and 866 against 834 landscape). The iPad scenarios delete the first row of each list.

- **iPad portrait, Folder Manager** (`$W/c7-capture-pad-portrait/ipad/en/large/detail-pages-folder-delete-confirmation/portrait-light.png`): the popover's arrow points down at the first folder row (Visual Folder A, under the popover), not at the sheet's top.
- **iPad portrait, Quick Search** (`$W/c7-capture-pad-portrait/actual/ipad/en/large/quick-search-delete-confirmation/portrait-light.png`): the arrow points at the first saved-search row ("visual fixture one").
- **iPad landscape, Folder Manager** (`$W/c7-capture-pad-landscape/ipad/en/large/detail-pages-folder-delete-confirmation/landscape-light.png`) and **Quick Search** (`.../actual/ipad/en/large/quick-search-delete-confirmation/landscape-light.png`): the same, the arrow on the first row of each list.
- The iPhone pictures (`$W/c7-capture-phone`) were captured and not examined further, as an action sheet has no anchor.

## Re-measures handed to C7 (`--measure-heights`, `en-large`, iOS 27.2; `$W/c7-measure-phone/heights.jsonl`, `$W/c7-measure-pad/heights.jsonl`)

No line is `error` or `cannot-cover:popover`, so no stop condition applied; no `heights:` value was changed. Both runs ended `TEST FAILED` only because the script fails a run that holds a `did-not-converge` line (phone `measured=4 did-not-converge=4`, pad `measured=2 did-not-converge=2`).

| key | status | need (pt) | steps | reason |
| --- | --- | --- | --- | --- |
| `detail-pages-folder-delete-confirmation__en__large__portrait__iphone__light` | measured | 912 | 0 | none (screen 912) |
| `detail-pages-folder-delete-confirmation__en__large__portrait__iphone__dark` | measured | 912 | 0 | none (screen 912) |
| `detail-pages-folder-delete-confirmation__en__large__landscape__iphone__light` | measured | 656 | 1 | none (screen 420) |
| `detail-pages-folder-delete-confirmation__en__large__landscape__iphone__dark` | measured | 656 | 1 | none (screen 420) |
| `quick-search-delete-confirmation__en__large__portrait__iphone__light` | did-not-converge | 1328 | 12 | none (screen 912) |
| `quick-search-delete-confirmation__en__large__portrait__iphone__dark` | did-not-converge | 1328 | 12 | none (screen 912) |
| `quick-search-delete-confirmation__en__large__landscape__iphone__light` | did-not-converge | 1093 | 12 | none (screen 420) |
| `quick-search-delete-confirmation__en__large__landscape__iphone__dark` | did-not-converge | 1093 | 12 | none (screen 420) |
| `detail-pages-folder-delete-confirmation__en__large__portrait__ipad__light` | measured | 1210 | 0 | none (screen 1210) |
| `detail-pages-folder-delete-confirmation__en__large__portrait__ipad__dark` | measured | 1210 | 0 | none (screen 1210) |
| `quick-search-delete-confirmation__en__large__portrait__ipad__light` | did-not-converge | 1626 | 12 | none (screen 1210) |
| `quick-search-delete-confirmation__en__large__portrait__ipad__dark` | did-not-converge | 1626 | 12 | none (screen 1210) |

Findings for 19-26:
- The Folder Manager delete confirmation converges on both devices (the iPhone landscape needs 656 pt in one step; the portrait iPhone and iPad fit their screens).
- The Quick Search delete confirmation still does not converge: 1328 / 1093 pt on the iPhone and 1626 pt on the iPad portrait, the same needs as 19-30's pre-fix values and 19-21's iPad value, after 12 steps with the need not holding still. On the iPhone it is a change from 19-21's `cannot-cover:popover` (1008 / 741 pt): with the dialog on a row the measurer no longer meets a popover source outside the scene, and the growth shows instead. The C7 anchoring fix does not change this need; it stays 19-26's.

## Deviations from Plan

### Orchestrator-approved (2026-11-25, on this plan's own pause report)

1. **Files beyond the plan's Task 1 list.** The record's "last option of `HomeCompactSlideshowInformation`'s `ViewThatFits`" was the orchestrator's description of how the owner's arrangement would be built, not the owner's decision, and a child view cannot place itself below its sibling cover (the text column is 176 pt wide on the iPhone, narrower than "Bewertung" at 200.3 pt). The orchestrator therefore approved a card-level layout and these files in addition to the plan's list: `GalleryCardCell.swift`, `HomeCompactSlideshowContent.swift` and the new `HomeCompactSlideshowLayout.swift`. The owner's chosen arrangement is unchanged: stats below the cover, at the card's full width, one stat per line as "label value".
2. **Test details the orchestrator asked for beyond the plan:** a guard case at `.large` in `en` asserting that the stats stay beside the cover, and a reading-order assertion (the title is read before the stats).

### Mine, to be reviewed

3. **A stat that does not fit on one line moves its value under its label.** In the fallback each stat is a `ViewThatFits` of "label value" on one line, then label above value. It triggers in `de` at `.accessibility5`: "Kategorie" (175.0 pt) and "Doujinshi" (about 170 pt at caption) do not fit the iPhone card's 338 pt width side by side (the picture shows "Kategorie" with "Doujinshi" under it), and on the iPad "Kategorie" and the subheadline "Doujinshi" (193.7 pt) do not fit the 360 pt cap. The alternative, one line with the value broken mid-word ("Doujin-shi"), is what the owner's decision exists to prevent. Every label stays whole; only that one value sits under its label. **Open for the owner:** on the iPad the card's text column is 482 pt wide, so lifting the 360 pt cap for the fallback lines would keep "Kategorie Doujinshi" on one line there; I kept the cap because the 360 pt block width is the existing design and the equal-columns decision needs it.
4. **The fixture test needed a seam.** `TracerScenarios.home()` was split into `homeState()` (the state) and `home()` (the view), so a test can read `frontPageGalleries`. `HomeFrontPageFixtureTests` is not named `Tracer…` because the hosted gate skips classes with that prefix.
5. **The equal-columns layout is private to `HomeGalleryInformation.swift`.** The record's "when its two columns do not fit" needs the columns' ideal width to be twice the wider column, which an `HStack` of `maxWidth: .infinity` frames does not report (it reports their sum, 333.7 pt for `en`, which fits the 360 pt cap, while the equal columns need 415.4 pt). A 25-line `Layout` gives `ViewThatFits` that width; it adds no file.

### Process notes (not plan deviations)

- Three runs failed to compile because of my own test code, and are not counted: the first C9 RED (`c9-red`, `category.value` is a `LocalizedStringResource`, not a `String`), and the first C7 verify (a missing `import AnalyticsClient` in `FolderManagerDeleteConfirmationTests`, found with the logged `c7-diag`). One C7 case then failed on `skipInFlightEffects()` ("no in-flight effects to skip"), which the test now replaces with `receive(\.deleteFolderDone)` (`c7-diag2`, `Failed 27 1`).
- Several runs waited an hour or more behind another project's `xcodebuild` on the host.
- No first-boot accessibility error (kAXError -25218) occurred at the iPad turn step in any of the five iPad runs of this plan.

## Auth gates

None.

## Known Stubs

None.

## Threat Flags

None. T-19-52 (a per-row dialog confirming a delete for the wrong row) is mitigated: the dialog's action still carries its own target, and `FolderManagerDeleteConfirmationTests` and `SavedSearchDeleteConfirmationTests` prove that confirming deletes only the targeted folder or saved search, that the dialog is exposed for that target only, and that dismissing clears both the dialog and the target.

## Self-Check: PASSED

Commits `237f59ebe` (C9) and `c9ab0eefe` (C7) are in the branch history, signed, with +08:00 dates. The created files named in `key-files` are in the tree; no file was deleted.
