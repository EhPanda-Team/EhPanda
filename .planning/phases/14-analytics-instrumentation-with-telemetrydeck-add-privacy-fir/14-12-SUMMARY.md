---
phase: 14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir
plan: 12
subsystem: analytics
tags: [telemetrydeck, tca, analytics, privacy, search, favorites, quicksearch, testing]

# Dependency graph
requires:
  - phase: 14-01
    provides: SearchFeatureTests / FavoritesFeatureTests targets, their analyticsClient edges, the SearchShape / Buckets / TagNamespaceCounts vocabulary, and FeatureTests.xctestplan registration
  - phase: 14-03
    provides: SearchShape + TagNamespaceCounts audited reductions and the ContentLeakProbe reflection helper
  - phase: 14-05
    provides: the AnalyticsSignal case set (searchPerformed, filterPanelOpened, quickSearchPanelOpened, quickSearchWordUsed, galleryDetailOpened)
  - phase: 14-10
    provides: the gallery-detail push payload derivation (Category + TagNamespaceCounts) matched here for the Favorites push
provides:
  - Performed-search emission at SearchReducer's fetch-completion case, carrying a reduced SearchShape and a CountBucket result count and never the keyword text
  - Filter and quick-search panel emissions naming the Search, Search-root and Favorites surfaces
  - Favorites gallery-detail push emission (galleryDetailOpened) matching the other four entry paths
  - A payload-free QuickSearchReducer.wordTapped seam and its quickSearchWordUsed emission
  - Real emission suites in the previously-empty SearchFeatureTests (9 tests) and FavoritesFeatureTests (3 tests), including the phase's keyword-never-leaks sentinel proof
affects: [14-17]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Performed-search analytics is emitted from the fetch-COMPLETION case, the only point the result count is known; the fetch-request case stays silent so a search counts exactly once"
    - "Raw-content-carrying persistence actions (history keyword) are documented as deliberately signal-free so a later reader does not add an emission for completeness"
    - "A payload-free reducer action (wordTapped) is the D-14-compliant seam for a signal whose only content is forbidden, making it TestStore-provable where a view-callback emission would not be"
    - "Feature test targets that cannot import AnalyticsClientTests reproduce the ContentLeakProbe reflection walk verbatim rather than reimplementing it"

key-files:
  created:
    - AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift
    - AppPackage/Tests/FavoritesFeatureTests/AnalyticsEmissionTests.swift
  modified:
    - AppPackage/Sources/SearchFeature/SearchReducer.swift
    - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
    - AppPackage/Sources/QuickSearchFeature/QuickSearchReducer.swift
    - AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift

key-decisions:
  - "Performed-search emits from the fetch-completion case (success → returned gallery count as CountBucket; failure → zero bucket); the fetch-request case emits nothing to avoid double-counting (T-14-13)"
  - "The quick-search wordTapped action is payload-free by construction — the word is forbidden content (D-06), so nothing about it is transmitted"
  - "The Favorites gallery-detail push reuses the exact Category + TagNamespaceCounts(tags:) derivation of the other four entry paths (D-16 keeps namespace counts exact, unbucketed)"

patterns-established:
  - "Emit at completion, not request: a metric whose value is a result count belongs on the completion action"
  - "Sentinel-based reflection over the whole recorded signal graph is the search family's primary privacy proof, asserted at the reducer boundary rather than only at the type boundary"

requirements-completed: []  # ANALYTICS-01 is intentionally left open; plan 14-17 closes it out.

coverage:
  - id: D1
    description: "A performed search emits exactly one searchPerformed signal carrying a reduced SearchShape and a CountBucket result count, never the keyword text"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift#aFailedSearchRecordsOnePerformedSignalWithAZeroBucket"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift#theRecordedPerformedSignalReflectsTheKeywordShape"
        status: pass
    human_judgment: false
  - id: D2
    description: "The recorded performed-search signal carries no part of the keyword (sentinel reflection); the history-keyword action records zero signals"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift#theRecordedPerformedSignalCarriesNoPartOfTheKeyword"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift#appendingAHistoryKeywordRecordsNoSignals"
        status: pass
    human_judgment: false
  - id: D3
    description: "Filter and quick-search panels on the Search, Search-root and Favorites screens each emit naming their own surface"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift#openingTheSearchFilterPanelRecordsOneSignalNamingSearch"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift#openingTheSearchRootQuickSearchPanelRecordsOneSignalNamingSearchRoot"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/FavoritesFeatureTests/AnalyticsEmissionTests.swift#openingTheQuickSearchPanelRecordsOneSignalNamingFavorites"
        status: pass
    human_judgment: false
  - id: D4
    description: "The Favorites gallery-detail push emits galleryDetailOpened with a Category and exact per-namespace tag counts, no title/tag text"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/FavoritesFeatureTests/AnalyticsEmissionTests.swift#pushingAGalleryDetailRecordsOneSignalMatchingTheFixture"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/FavoritesFeatureTests/AnalyticsEmissionTests.swift#pushedGalleryDetailSignalCarriesNoFixtureTitleOrTagText"
        status: pass
    human_judgment: false
  - id: D5
    description: "Selecting a quick-search word records one payload-free quickSearchWordUsed signal from a reducer action, carrying no part of the word"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift#selectingAQuickSearchWordRecordsOnePayloadFreeSignal"
        status: pass
    human_judgment: false

# Metrics
duration: 14min
completed: 2026-07-24
status: complete
---

# Phase 14 Plan 12: Search-Family Analytics Instrumentation Summary

**Seven privacy-redacted emission sites across the search family — performed searches (at fetch completion), four filter/quick-search panels, the payload-free quick-search-word seam, and the Favorites gallery-detail push — plus the two search-family test suites (9 + 3 tests) that plan 14-01 declared empty, anchored by the phase's keyword-never-leaks sentinel proof.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-07-24T06:46:56Z
- **Completed:** 2026-07-24T07:01:25Z
- **Tasks:** 3
- **Files modified:** 5 source modified, 2 test files created, 2 placeholder suites deleted

## Accomplishments
- Performed-search analytics emits once from `SearchReducer`'s fetch-completion case with a `SearchShape` reduced from `lastKeyword` and a `CountBucket` result count (returned gallery count on success, zero on failure); the fetch-request case and both history-keyword persistence cases stay deliberately silent, each carrying an explanatory comment (T-14-13, D-06).
- Filter and quick-search panels emit naming their own surface: Search (`.search` ×2), Search-root (`.searchRoot` ×2), Favorites quick-search (`.favorites` ×1). The Favorites gallery-detail push emits `galleryDetailOpened` with the same `Category` + exact `TagNamespaceCounts(tags:)` derivation the four other entry paths use.
- A new payload-free `QuickSearchReducer.wordTapped` action is the D-14-compliant seam for the quick-search-word signal; the word row sends it then runs the host search callback unchanged, leaving all five host screens untouched.
- `SearchFeatureTests` (9 tests) and `FavoritesFeatureTests` (3 tests) now execute a non-zero test count, replacing the 14-01 placeholders. The suite includes the phase's single most important assertion — a sentinel keyword proven to survive nowhere in the recorded performed-search signal's reflected value graph — plus a zero-signal proof for the raw-keyword history action.

## Task Commits

Each task was committed atomically:

1. **Task 1: Performed-search, panel and Favorites emissions** - `fc431ea4` (feat)
2. **Task 2: Payload-free wordTapped seam for quick-search word selection** - `c485534b` (feat)
3. **Task 3: Emission proofs in SearchFeatureTests and FavoritesFeatureTests** - `9f02da1f` (test)

_Task 1/2 verified with `xcodebuild build`; Task 3 with the filtered and full test plans._

## Files Created/Modified
- `AppPackage/Sources/SearchFeature/SearchReducer.swift` - `searchPerformed` emission at fetch completion; Search filter/quick-search panel emissions
- `AppPackage/Sources/SearchFeature/SearchRootReducer.swift` - Search-root panel emissions; explanatory silence on both history-keyword paths
- `AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift` - gallery-detail push `galleryDetailOpened`; Favorites quick-search panel emission
- `AppPackage/Sources/QuickSearchFeature/QuickSearchReducer.swift` - payload-free `wordTapped` action + `quickSearchWordUsed` emission
- `AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift` - row button sends `wordTapped` before the unchanged search callback
- `AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift` - created; 9 emission/privacy proofs
- `AppPackage/Tests/FavoritesFeatureTests/AnalyticsEmissionTests.swift` - created; 3 emission/privacy proofs
- Deleted: the `SearchFeatureTests.swift` and `FavoritesFeatureTests.swift` placeholder suites left by plan 14-01

## Decisions Made
- Emit performed-search at completion, not request — the result count is only known then, and a request-side emission would double-count retries.
- `wordTapped` is payload-free by construction; the reducer returns only the emission effect and mutates no state.
- Favorites gallery-detail keeps per-namespace tag counts exact (D-16), not bucketed, matching the four sibling entry paths.

## Deviations from Plan

### Reported (not fixed) — missing test-target dependency edge under the manifest freeze

**1. [Rule 4 - reported, manifest frozen] The non-zero success result-bucket assertion for `searchPerformed` could not be added**
- **Found during:** Task 3 (emission proofs)
- **Issue:** The plan's behavior block asks for a "successful search … result bucket matches the fixture gallery count" test. Exercising the success arm of `fetchGalleriesDone` requires constructing a `GalleriesResult`, which is declared in `NetworkingFeature`. `SearchFeatureTests` does not depend on `NetworkingFeature`, and this toolchain (Swift 6 / Xcode 26.6) rejects naming the type transitively (`error: cannot find type 'GalleriesResult' in scope`).
- **Decision:** Per the plan's `manifest_freeze` instruction — "If a needed dependency edge turns out to be missing … stop and report it rather than editing the manifest here" — `AppPackage/Package.swift` was left untouched. The success test was omitted; the failure arm (zero bucket) and a multi-word/tag-qualified shape-derivation test cover the reachable surface, and the `CountBucket(count:)` mapping the success arm uses is exhaustively covered in `AnalyticsClientTests/BucketTests`.
- **Follow-up for 14-17 (or a manifest-owning plan):** add `.module(.networkingFeature)` to the `searchFeatureTests` target, then add a success-arm test asserting a non-zero result bucket. This is the only coverage gap.
- **Files modified:** none (manifest deliberately not edited)
- **Verification:** filtered and full test plans green without the edge

### Note — `.searchPerformed(` appears twice in SearchReducer.swift by name

The pre-existing `SearchReducer.Delegate.searchPerformed(String)` (a search-history delegate, unrelated to analytics) is spelled `.searchPerformed(` at its send site, so a bare `grep '\.searchPerformed('` over `SearchReducer.swift` returns 2. The **analytics** emission — `.searchPerformed(shape:` in the fetch-completion case — appears exactly once and is uniquely pinned by `SearchShape(keyword:`. No behavior overlap; the delegate is history persistence, the signal is analytics.

---

**Total deviations:** 1 reported (missing test-target edge, deliberately not fixed under the manifest freeze), 1 clarifying note.
**Impact on plan:** No scope creep. All hard acceptance criteria met; the single omitted assertion is flagged for 14-17 with the exact fix.

## Issues Encountered
- The first filtered test run failed to compile on `GalleriesResult` (see Deviations). Resolved by removing the manifest-dependent success test and strengthening the reachable failure-path coverage; the manifest was never edited.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The search family is now the highest-risk module fully instrumented and, for the first time, covered by real tests rather than source inspection.
- ANALYTICS-01 remains open by design; plan **14-17** owns closing it out and should also add the `NetworkingFeature` edge + success-bucket test noted above, and correct the `Buckets.swift` / REQUIREMENTS wording for D-16's second bucketing exception.

## Self-Check: PASSED

All five source/two test files and the SUMMARY exist on disk; all three task commits (`fc431ea4`, `c485534b`, `9f02da1f`) are present in git history.

---
*Phase: 14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir*
*Completed: 2026-07-24*
