---
phase: 10-ui-polish
plan: 04
subsystem: ui
tags: [swiftui, environment, uikit-traits, color, privacy-mask]

# Dependency graph
requires:
  - phase: 07-privacy
    provides: privacyMask no-content-leak coverage (41 call sites) that must survive this key removal
provides:
  - Custom \.inSheet environment key removed (InSheetKey + EnvironmentValues.inSheet deleted)
  - All 3 former consumer sites render the non-elevated (inSheet==false) gray branch unconditionally
  - 5 former setter sites removed with privacyMask coverage intact
affects: [ui-polish, lint-capstone]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Presentation-context gray selection collapsed to a single static tone (owner decision: base/non-elevated everywhere)"

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppTools/EnvironmentKeys.swift (deleted)
    - AppPackage/Sources/AppComponents/Placeholder.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularView.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
    - AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift
    - AppPackage/Sources/SearchFeature/SearchRootView.swift

key-decisions:
  - "Owner rejected both the trait mechanism and the Bool-parameter fallback; the sheet-elevation distinction is removed entirely — every former site renders the inSheet==false base gray."
  - "The 4 FiltersView setters were provably dead (FiltersFeature reads neither Placeholder nor inSheet); only TabBarView's modal DetailView setter reached real consumers. Dropping all 5 collapses the modal detail to base gray, which is the intended, owner-approved shift."

patterns-established:
  - "When a custom environment key only selects a static style delta the owner deems unnecessary, delete the key and inline the base branch rather than reimplementing the delta."

requirements-completed: [CRIT-06]

coverage:
  - id: D1
    description: "Custom \\.inSheet environment key fully removed; EnvironmentKeys.swift deleted; zero references remain."
    requirement: CRIT-06
    verification:
      - kind: other
        ref: "grep -rn inSheet AppPackage/Sources AppPackage/Tests App ShareExtension --include=*.swift | wc -l == 0"
        status: pass
      - kind: integration
        ref: "xcodebuild build -scheme AppFeature -destination 'iOS Simulator,id=88B217DA (iPhone 17e)' == BUILD SUCCEEDED, 0 warnings, SwiftLint plugin clean"
        status: pass
    human_judgment: false
  - id: D2
    description: "privacyMask no-content-leak coverage preserved: the 4 chained setter sites kept .privacyMask() (call-site count stays 41)."
    requirement: CRIT-06
    verification:
      - kind: other
        ref: "grep -rnF '.privacyMask()' AppPackage/Sources --include=*.swift | wc -l == 41"
        status: pass
    human_judgment: false
  - id: D3
    description: "Intended visual shift: the modal DetailView surfaces (TagRow, CommentsSection, and modal-detail Placeholders) now render base gray instead of the former elevated gray."
    verification: []
    human_judgment: true
    rationale: "Owner-approved static gray-tone shift (systemGray4→gray5, gray5→gray6 in the elevated case). On-device visual confirmation is a human-eye D-11 judgment; not a blocker — parity of the base branch is guaranteed by construction (constants unchanged)."

# Metrics
duration: 20min
completed: 2026-07-18
status: complete
---

# Phase 10 Plan 04: Remove \.inSheet Environment Key Summary

**Custom `\.inSheet` environment key deleted; all three former consumers collapsed to the static non-elevated gray (systemGray5 / systemGray5 / systemGray6) per owner decision, with all 41 privacyMask call sites preserved.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-18
- **Tasks:** 2 code/verify tasks + 1 owner checkpoint (resolved by owner directive)
- **Files modified:** 8 (7 modified, 1 deleted)

## Accomplishments
- Deleted `InSheetKey` and `EnvironmentValues.inSheet` (whole `EnvironmentKeys.swift` file removed).
- Collapsed all three consumer read sites to the `inSheet == false` base branch, unconditionally: `Placeholder` → `Color(.systemGray5)`; `DetailView+Subviews` `TagRow` → `Color(.systemGray5)`; `CommentsSection` → `Color(.systemGray6)`.
- Removed all 5 former `.environment(\.inSheet, true)` setters; the 4 chained on `.privacyMask()` kept their mask call (count stays 41).
- Build + SwiftLint clean on the AppFeature umbrella scheme.

## Task Commits

1. **Code change (env-key removal + base-gray collapse)** — `f87bec46` (refactor)

**Plan metadata:** committed separately (docs: complete plan)

_Note: `f87bec46` was amended from an earlier trait-based implementation (commit 9c737bbe) after the owner rejected the trait mechanism, so the final tree carries no trait and no Bool parameter._

## Files Created/Modified
- `AppPackage/Sources/AppTools/EnvironmentKeys.swift` — **deleted** (was the sole home of `InSheetKey`).
- `AppPackage/Sources/AppComponents/Placeholder.swift` — dropped `@Environment(\.inSheet)`; activity placeholder is now `Color(.systemGray5)`.
- `AppPackage/Sources/DetailFeature/DetailView+Subviews.swift` — `TagRow` and `CommentsSection` background colors are now static (`systemGray5` / `systemGray6`); removed the now-unused `@Environment(\.inSheet)` (both) and `@Environment(\.colorScheme)` (CommentsSection only; TagRow keeps it for `reversedPrimary`).
- `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` — dropped the standalone `.environment(\.inSheet, true)` on the modal DetailView.
- `AppPackage/Sources/HomeFeature/{Frontpage,Popular,Watched}View.swift`, `SearchFeature/SearchRootView.swift` — dropped the `.environment(\.inSheet, true)` chained after `.privacyMask()` on the FiltersView sheets; `.privacyMask()` retained.

## Decisions Made
- **Mechanism (owner-directed, two revisions):** The plan's D-11 checkpoint offered a trait-based `UIColor` provider with a fallback of an explicit `Bool` init parameter. The owner rejected the trait approach (UIKit forces `.elevated` inside any sheet, making elevated the de-facto default and producing a delta on QuickSearch/Filters/modal-detail sheets), then superseded the Bool fallback too: the sheet-elevation distinction is removed outright. Every former site now uses the base `inSheet == false` style.
- **The 4 FiltersView setters were dead:** `FiltersFeature` renders none of the three consumers, so those setters never changed a pixel. Only `TabBarView`'s modal DetailView setter reached real consumers (TagRow, CommentsSection, modal-detail Placeholders). Collapsing to base gray therefore only visibly affects the modal DetailView surfaces.

## Deviations from Plan

The plan's Task 1 prescribed a trait-based `UIColor` dynamic provider and Task 3 was a blocking owner checkpoint. The owner rejected the trait mechanism at the checkpoint and issued a directive (with one same-session correction) to instead remove the distinction entirely. This is a checkpoint-driven design change, not an auto-fix — the final implementation follows the owner's directive rather than the plan's original mechanism. `\.inSheet` removal, the `EnvironmentKeys.swift` deletion, and the 41-site privacyMask preservation (the plan's hard invariants) are all intact.

**Environment adaptation (Rule 3, same as plan 10-03):** the plan's `AppPackage-Package` scheme is not exposed on the `.xcodeproj` and `iPhone 17 Pro` is not installed. Built the `AppFeature` umbrella scheme (transitively covers every touched module) against the installed `iPhone 17e` simulator.

## Issues Encountered
None beyond the mechanism revisions above. Build succeeded (0 warnings, lint clean) on the collapsed implementation.

## User Setup Required
None.

## Next Phase Readiness
- Criterion 6 satisfied: the custom environment value is removed and its presentation-context logic is retired (not reimplemented) per owner decision.
- Deferred (non-blocking): on-device visual confirmation of the intended base-gray shift on the modal DetailView surfaces — a human-eye D-11 judgment (coverage D3).

---
*Phase: 10-ui-polish*
*Completed: 2026-07-18*
