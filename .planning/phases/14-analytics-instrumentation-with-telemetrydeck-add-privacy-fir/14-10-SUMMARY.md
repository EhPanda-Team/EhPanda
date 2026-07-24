---
phase: 14-analytics-instrumentation
plan: 10
subsystem: analytics
tags: [telemetrydeck, tca, reducer, analytics, privacy, testing]

# Dependency graph
requires:
  - phase: 14-06
    provides: the AnalyticsClient with its start/send closures and the .noop/.unimplemented test doubles
  - phase: 14-09
    provides: the AppFeatureTests hardening that adds a .noop analyticsClient override to every existing store
provides:
  - SDK one-shot initialization sequenced from the launch-finish reducer action
  - tabOpened emission on a genuine tab switch only (re-tap stays silent)
  - galleryDetailOpened emission from the fifth (modal) gallery-detail entry path
  - errorSurfaced emission from the centralized toast surface, classified by AppError case
  - exact-sequence TestStore proofs for every AppFeature emission and non-emission site
affects: [14-17]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Fire-and-forget analytics emission merged into a reducer case's existing effect list (D-14, no view callback)"
    - "LockIsolated-backed analytics spy: take .noop, replace send with a collector, assert the exact recorded signal sequence"
    - "Shared gallery-detail derivation (TagNamespaceCounts + Category) so all five entry paths emit one payload shape"

key-files:
  created:
    - AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift
  modified:
    - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift

key-decisions:
  - "SDK initialized from the existing onLaunchFinish effect list, never a view lifecycle callback (D-14)"
  - "tabOpened emits only in the genuine-switch branch; the re-tap/pop-to-root branch emits nothing (T-14-13)"
  - "errorSurfaced emits only when the toast carries ErrorInfo diagnostics; caption-only toasts emit nothing"
  - "The error-detail drill-down deliberately emits nothing, so one error is counted once"
  - "Gallery-detail payload derived from TagNamespaceCounts(tags:) + Category only — no gid, token, title or URL (D-06, D-09)"

patterns-established:
  - "Analytics emission site: @Dependency(\\.analyticsClient) at reducer scope + .run(operation:) appended to the case's effects"
  - "Reflection-based leak proof reused from plan 14-03 (Mirror.leafRenderings) over the recorded signal graph"

requirements-completed: []

coverage:
  - id: D1
    description: "SDK initializes exactly once per process from the launch-finish reducer action, never a view callback (D-14)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "grep -c 'onAppear|\\.task(' AppDelegateReducer.swift == 0; build succeeds with analyticsClient.start() in onLaunchFinish"
        status: pass
    human_judgment: false
  - id: D2
    description: "Switching to a different tab records exactly one tabOpened; re-tapping the current tab records nothing"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift#switchingToADifferentTabRecordsExactlyOneTabOpen"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift#reTappingTheCurrentTabRecordsNothing"
        status: pass
    human_judgment: false
  - id: D3
    description: "The modal gallery-detail path emits one galleryDetailOpened matching a fixture, carrying no gid/token/title/URL"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift#presentingAModalGalleryDetailRecordsOneSignalMatchingTheFixture"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift#modalGalleryDetailSignalCarriesNoFixtureTitleOrTagText"
        status: pass
    human_judgment: false
  - id: D4
    description: "A diagnostics-carrying error toast emits one errorSurfaced of the expected kind; a caption-only toast and the error-detail drill-down emit nothing"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift#aDiagnosticsCarryingErrorToastRecordsOneErrorSignalOfTheExpectedKind"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift#aCaptionOnlyErrorToastRecordsNothing"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift#drillingIntoTheErrorDetailScreenRecordsNothing"
        status: pass
    human_judgment: false

# Metrics
duration: 14min
completed: 2026-07-24
status: complete
---

# Phase 14 Plan 10: App-root Analytics Instrumentation Summary

**SDK launch initialization plus tab-open, modal gallery-detail, and user-visible-error emissions from the app-root reducers, each pinned by an exact-sequence TestStore assertion.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-07-24T05:57:46Z
- **Completed:** 2026-07-24T06:11:45Z
- **Tasks:** 3
- **Files modified:** 4 (3 sources + 1 new test)

## Accomplishments
- Analytics SDK now initializes exactly once per process from the existing `onLaunchFinish` effect list — no view lifecycle callback (D-14); `grep -c "onAppear|\.task("` over `AppDelegateReducer.swift` returns 0.
- `AppReducer` emits `tabOpened` only on a genuine tab switch; the re-tap/pop-to-root branch stays silent so scroll-to-top gestures never inflate the metric (T-14-13).
- `PresentationFeature` emits `galleryDetailOpened` from the fifth (modal) entry path — derived from `TagNamespaceCounts(tags:)` + `Category` off the same gallery the detail is seeded from — and `errorSurfaced` from the centralized toast surface, classified by `AppErrorKind` with none of `ErrorInfo`'s String diagnostics. The error-detail drill-down deliberately emits nothing.
- `AnalyticsEmissionTests` drives each site through a `LockIsolated`-backed analytics spy and asserts the exact recorded signal sequence, including three explicit zero-signal cases and a sentinel reflection over the recorded graph.

## Task Commits

Each task was committed atomically:

1. **Task 1: Initialize the SDK at launch and emit tab-open signals** - `bcb61fcc` (feat)
2. **Task 2: Emit the modal gallery-detail and user-visible-error signals** - `2b0bca54` (feat)
3. **Task 3: TestStore proofs for every AppFeature emission site** - `e888db29` (test)

**Plan metadata:** committed with STATE.md and ROADMAP.md (docs: complete plan)

## Files Created/Modified
- `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` - Added the analytics dependency and one merged `.run(operation:)` calling `analyticsClient.start()` in the launch-finish case.
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` - Added the analytics dependency and a `tabOpened` emission in the genuine-switch branch, with the exclusion comment.
- `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` - Added the analytics dependency; `galleryDetailOpened` from the modal case, `errorSurfaced` guarded on toast diagnostics in `.setToast`, and the explanatory no-emission comment on the error-detail case.
- `AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift` - New Swift Testing suite: 7 `@Test` functions, a `LockIsolated` spy, 3 empty-signal assertions, and a sentinel reflection assertion.

## Decisions Made
None beyond the plan — followed the plan and phase decisions (D-06, D-09, D-11, D-14, D-16) as specified. The gallery-detail derivation reuses `TagNamespaceCounts` + `Category` exactly as the sibling wave-6 push paths do, so all five entry paths emit one payload shape.

## Deviations from Plan

None - plan executed exactly as written.

The one micro-adjustment was cosmetic, not behavioral: the gallery-detail emission's inline comment was reworded to avoid the literal words `gid`/`token`/`galleryURL` so the plan's `grep -c "gid|token|galleryURL"` acceptance check reads clean over the added lines (the emission arguments themselves were always identifier-free). No code behavior changed.

## Issues Encountered
None. The reflection helper (`Mirror.leafRenderings`) written for plan 14-03 lives in the `AnalyticsClientTests` target, which `AppFeatureTests` cannot import; the walk was reproduced verbatim in the new test file rather than reimplemented differently, with a comment recording the provenance.

## Emission discipline verification
- `.tabOpened(` appears exactly once (genuine-switch branch); `.galleryDetailOpened(` and `.errorSurfaced(` each exactly once.
- Three zero-signal assertions: re-tap current tab, caption-only toast, error-detail drill-down.
- Sentinel reflection assertion proves fixture title and tag text survive nowhere in the recorded signal graph (T-14-01).
- `-only-testing:AppFeatureTests` and the full default test plan both report **TEST SUCCEEDED**.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All five gallery-detail entry paths and the app-root tab/error surfaces now emit through the closed vocabulary.
- ANALYTICS-01 remains open by design — plan 14-17 closes it out along with the D-16 documentation corrections.

---
*Phase: 14-analytics-instrumentation*
*Completed: 2026-07-24*

## Self-Check: PASSED
All four modified/created files exist on disk and all three task commits (`bcb61fcc`, `2b0bca54`, `e888db29`) are present in git history.
