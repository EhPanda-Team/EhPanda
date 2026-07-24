---
phase: 14-analytics-instrumentation
plan: 11
subsystem: analytics
tags: [telemetrydeck, tca, reducer, analytics, privacy, testing, home]

# Dependency graph
requires:
  - phase: 14-06
    provides: the AnalyticsClient with its start/send closures and the .noop/.unimplemented test doubles
  - phase: 14-09
    provides: the HomeFeatureTests hardening that adds a .noop analyticsClient override to every existing store
provides:
  - homeSectionViewed emission from both Home entry actions, covering all five sections through one exhaustive mapping
  - galleryDetailOpened emission from the Home gallery-detail push case only (not the device-branching tap)
  - filterPanelOpened emission from the Frontpage, Popular and Watched filter panels, each naming its own surface
  - quickSearchPanelOpened emission from the Watched quick-search panel
  - exact-sequence TestStore proofs sweeping both Home source enums' allCases, plus a sentinel leak proof
affects: [14-17]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One private mapping helper folds two source enums onto a closed vocabulary enum with no default: arm, so a new destination is a compile error"
    - "Parameterized allCases sweep (@Test(arguments:)) so a new source case fails the suite rather than shipping unmeasured"
    - "skipInFlightEffects(strict:) records a merged fire-and-forget emission while leaving the buffered presentation action unprocessed, avoiding a sub-screen's session-less network fetch"

key-files:
  created:
    - AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift
  modified:
    - AppPackage/Sources/HomeFeature/HomeReducer.swift
    - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
    - AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift

key-decisions:
  - "Both Home entry actions (section-tap and misc-tap) emit through one private helper with two exhaustive switches, no default: arm"
  - "galleryDetailOpened emits on the push case only; the device-branching tap would double-count against the iPad modal counted by plan 14-10 (T-14-13)"
  - "Gallery-detail payload derived from TagNamespaceCounts(tags:) + Category only — no gid, token, title, URL or tag value (D-06, D-09)"
  - "Panel signals record opened, not applied: applying a filter mutates a persisted shared value with no D-14-compliant reducer seam"
  - "analyticsClient declared internal (not private) on HomeReducer because its body lives in a separate file, matching deviceClient/libraryClient"

patterns-established:
  - "Analytics emission site: @Dependency(\\.analyticsClient) at reducer scope + .run(operation:) merged into the case's existing effects"
  - "Test expected-mapping mirrors the production mapping with its own exhaustive switch, so a new source case breaks both production and test"
  - "Reflection-based leak proof reused from plan 14-03 (Mirror.leafRenderings) over the recorded signal graph"

requirements-completed: []

coverage:
  - id: D1
    description: "All five Home sections emit homeSectionViewed through one exhaustive mapping across the two entry actions"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift#tappingASectionDestinationRecordsOneHomeSectionSignal (allCases sweep)"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift#tappingAMiscDestinationRecordsOneHomeSectionSignal (allCases sweep)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The Home gallery-detail push emits one galleryDetailOpened matching a fixture, carrying no gid/token/title/URL/tag text"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift#pushingAGalleryDetailRecordsOneSignalMatchingTheFixture"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift#pushedGalleryDetailSignalCarriesNoFixtureTitleOrTagText"
        status: pass
    human_judgment: false
  - id: D3
    description: "Each Home sub-screen filter panel emits filterPanelOpened naming its own surface; the Watched quick-search panel emits quickSearchPanelOpened"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift#openingTheFrontpageFilterPanelRecordsOneSignalNamingFrontpage"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift#openingThePopularFilterPanelRecordsOneSignalNamingPopular"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift#openingTheWatchedFilterPanelRecordsOneSignalNamingWatched"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift#openingTheWatchedQuickSearchPanelRecordsOneQuickSearchSignal"
        status: pass
    human_judgment: false

# Metrics
duration: 18min
completed: 2026-07-24
status: complete
---

# Phase 14 Plan 11: HomeFeature Analytics Instrumentation Summary

**Seven HomeFeature emission sites wired through the closed signal vocabulary — all five sections via two entry actions and one exhaustive mapping, the gallery-detail push, and every sub-screen filter/quick-search panel — each pinned by an exact-sequence TestStore proof.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-07-24T06:13:00Z
- **Completed:** 2026-07-24T06:31:00Z
- **Tasks:** 3 completed
- **Files modified:** 5 (1 created, 4 modified)

## Accomplishments

- **All five Home sections emit through two actions and one mapping.** `.sectionTapped` (frontpage, toplists) and `.miscTapped` (popular, watched, history) each emit `homeSectionViewed`, both routed through a single private helper holding two exhaustive `switch` statements with no `default:` arm. A sixth destination is a compile error at the mapping, not a silently unmeasured screen (T-14-14).
- **The Home gallery-detail push emits the shared payload shape.** `.pushGalleryDetail` emits `galleryDetailOpened` derived from `TagNamespaceCounts(tags:)` + `Category` — identical to the four other entry paths. The device-branching `.galleryTapped` case emits nothing and carries a one-line comment explaining it would double-count against the iPad modal counted by plan 14-10 (T-14-13).
- **Every Home sub-screen panel opening emits, naming its own surface.** Frontpage, Popular and Watched filter panels emit `filterPanelOpened(.frontpage/.popular/.watched)`; the Watched quick-search panel emits `quickSearchPanelOpened(.watched)`. Each is merged with the case's existing effect; no case's return was replaced.
- **Exact-sequence proofs sweep both source enums' `allCases`.** The two destination sweeps are parameterized over `HomeSectionType.allCases` and `HomeMiscGridType.allCases`, so a new destination fails the suite. A sentinel-based reflection assertion proves the fixture's title and tag text survive nowhere in the recorded gallery-detail signal (T-14-01). `-only-testing:HomeFeatureTests` and the full default test plan both exit TEST SUCCEEDED.

## Verified inventory (per plan's verify-by-search instruction)

Searched the three sub-screen reducers for the actual filter-panel and quick-search cases rather than trusting the recitation:

| Reducer | Filter-panel case | Quick-search case |
|---------|-------------------|-------------------|
| FrontpageReducer | `.filtersButtonTapped` | none |
| PopularReducer | `.filtersButtonTapped` | none |
| WatchedReducer | `.filtersButtonTapped` | `.quickSearchButtonTapped` |

Confirms the plan's expected counts exactly: `filterPanelOpened` ×3 (one per sub-screen), `quickSearchPanelOpened` ×1 (Watched only). No correction needed.

## Panel-signal limitation (recorded per plan)

The panel signals record that a filter/quick-search panel was **opened**, not that a filter was **applied**. Applying a filter mutates a persisted shared value with no distinct reducer action, so there is no D-14-compliant seam to instrument for it; the D-11 default parameters already carry the settings that matter. No action was invented for the apply path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] `analyticsClient` declared internal, not `private`, on HomeReducer**
- **Found during:** Task 1
- **Issue:** The plan specified `@Dependency(\.analyticsClient) private var analyticsClient`. `HomeReducer`'s body lives in a separate file (`HomeReducer+Body.swift`), and `private` restricts to file scope — the build failed with "'analyticsClient' is inaccessible due to 'private' protection level" at every emission site.
- **Fix:** Declared it as file-crossing `internal` (no `private`), matching the reducer's existing `deviceClient` and `libraryClient` dependencies, and added a one-line comment explaining why. The `private` spelling remains correct for the three sub-screen reducers (Task 2), whose bodies are same-file — those were left `private` as the plan specified.
- **Files modified:** AppPackage/Sources/HomeFeature/HomeReducer.swift
- **Commit:** 96f5cb03

## Notes on acceptance greps

The literal `grep -c "onAppear\|\.task("` over `HomeReducer+Body.swift` returns 2, not 0 — but both matches are pre-existing explanatory comments ("former view `onAppear`") that predate this plan, plus my new mapping-helper doc comment references a `default:` arm in prose. No view-lifecycle callback exists in code anywhere in `HomeFeature`, and the mapping helper has two `switch` statements with no `default:` arm. The verification intent ("no view-lifecycle callback was added") is satisfied.

## Requirements

- **ANALYTICS-01** intentionally left open (`- [ ]`). It spans the whole phase; plan 14-17 closes it out. ROADMAP plan progress updated for 14-11 only.

## Self-Check: PASSED

- FOUND: AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift
- FOUND: commits 96f5cb03 (feat task 1), 6ec9a520 (feat task 2), c28f1ef8 (test task 3)
