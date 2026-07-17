---
phase: 10-ui-polish
plan: 02
subsystem: ui
tags: [swiftui, foregroundStyle, tint, deprecation-sweep, appearance-parity]

# Dependency graph
requires:
  - phase: 10-ui-polish
    provides: 10-01 SystemNotification module rename (same importer files touched)
provides:
  - Every deprecated `.foregroundColor(_:)` modifier swapped to `.foregroundStyle(_:)` (30 files)
  - Every deprecated `.accentColor(_:)` modifier swapped to `.tint(_:)` (13 files); static `.accentColor` reads left intact
  - CustomToolbarItem Optional-tint preserved via conditional `if let` foregroundStyle application (inherit-when-nil intact)
  - Root app tint migrated to `.tint(.primary)` (drives tab-bar + link tinting app-wide)
affects: [10-ui-polish plan 10-03 (remaining deferred color-modifier sites), 11-lint-capstone lint ratchet]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Deprecated color-modifier sweep: 1:1 modifier swap at exact appearance parity (foregroundColor->foregroundStyle, accentColor-modifier->tint)"
    - "Optional-color modifier: apply foregroundStyle only inside `if let` (no default substitution, no AnyShapeStyle erasure) so nil keeps inheriting ambient tint"

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppComponents/ToolbarItems.swift
    - AppPackage/Sources/AppFeature/RootView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - "40 further AppPackage/Sources/** view files (grep-driven sweep)"

key-decisions:
  - "None - plan executed as written; work was pre-committed, this plan reconciles bookkeeping only"

patterns-established:
  - "Optional-color modifier trap: conditional foregroundStyle via if-let preserves inherit-when-nil (ToolbarItems, ArchivesView)"
  - "Static implicit-member `.accentColor` value reads are NOT deprecated and are left untouched by the modifier sweep"

requirements-completed: [CRIT-07]

coverage:
  - id: D1
    description: "All deprecated `.foregroundColor(_:)` modifier calls converted to `.foregroundStyle(_:)`; zero remain across AppPackage/Sources, App, ShareExtension"
    requirement: "CRIT-07"
    verification:
      - kind: other
        ref: "grep -rnF '.foregroundColor(' AppPackage/Sources App ShareExtension --include=*.swift | wc -l => 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "All deprecated `.accentColor(_:)` modifier calls converted to `.tint(_:)`; the 4 static implicit-member `.accentColor` reads (3 files) survive untouched"
    requirement: "CRIT-07"
    verification:
      - kind: other
        ref: "grep -rnF '.accentColor(' AppPackage/Sources App ShareExtension --include=*.swift | wc -l => 0"
        status: pass
      - kind: other
        ref: "grep -rnE '\\.accentColor([^(]|$)' EhSettingView+Sections1.swift ControlPanel.swift LiveTextView.swift | wc -l => 4 (unchanged)"
        status: pass
    human_judgment: false
  - id: D3
    description: "CustomToolbarItem Optional-tint preserved: foregroundStyle applied only inside `if let tint`, else content unmodified (inherit-when-nil parity, no forced default)"
    requirement: "CRIT-07"
    verification:
      - kind: other
        ref: "git show 97aef2d4 -- ToolbarItems.swift: `@ViewBuilder tintedContent` with `if let tint { stack.foregroundStyle(tint) } else { stack }`"
        status: pass
    human_judgment: false
  - id: D4
    description: "Clean build with zero warnings (SwiftLint build plugin clean) and full test suite green after the sweep"
    requirement: "CRIT-07"
    verification:
      - kind: integration
        ref: "xcodebuild build -scheme AppFeature: ** BUILD SUCCEEDED **, 0 warnings; xcodebuild test -scheme AppPackage-Package: ** TEST SUCCEEDED **"
        status: pass
    human_judgment: false
  - id: D5
    description: "Root tint (.tint(.primary)) and app-wide tab-bar/link tinting render unchanged vs the pre-swap deprecated modifier"
    verification: []
    human_judgment: true
    rationale: "Visual tab-bar/link tint parity is a runtime appearance judgment; not re-run during this bookkeeping close-out. Parity rests on the D-11 diff-review tier + the documented 1:1 appearance-identity of foregroundColor->foregroundStyle and accentColor->tint."

# Metrics
duration: 9min
completed: 2026-07-17
status: complete
---

# Phase 10 Plan 02: Deprecated Color-Modifier Sweep Summary

**Swept the two highest-count deprecated SwiftUI color modifiers to their modern equivalents at exact appearance parity — every `.foregroundColor(_:)` -> `.foregroundStyle(_:)` (30 files) and every `.accentColor(_:)` modifier -> `.tint(_:)` (13 files) — with the CustomToolbarItem Optional-tint inherit-when-nil behavior preserved and static `.accentColor` value reads left intact.**

## Performance

- **Duration:** ~9 min (code work: commits span 09:03:51–09:12:28 +09:00)
- **Started:** 2026-07-17T09:03:51+09:00
- **Completed:** 2026-07-17T09:12:28+09:00
- **Tasks:** 3 (2 code, 1 verification-only)
- **Files modified:** 42 unique

## Accomplishments
- All deprecated `.foregroundColor(_:)` modifier calls converted to `.foregroundStyle(_:)` (grep now 0); Optional-color sites (ToolbarItems `CustomToolbarItem`, ArchivesView) apply foregroundStyle only via `if let`, so nil still inherits the ambient tint (no default substituted, no `AnyShapeStyle` erasure)
- All deprecated `.accentColor(_:)` modifier calls converted to `.tint(_:)` (grep now 0); RootView root tint became `.tint(.primary)` (tab-bar + link tinting app-wide); ReadingView's redundant deprecated line was deleted (the identical `.tint` was already stacked)
- The 4 static implicit-member `.accentColor` value reads across 3 files (EhSettingView+Sections1:102, ControlPanel:380, LiveTextView:71,79) are correctly left untouched — the static property is not deprecated
- Clean build (`** BUILD SUCCEEDED **`, 0 warnings, SwiftLint build plugin clean) and full test suite green (`** TEST SUCCEEDED **`, ~550 tests / all targets, 2 pre-existing known-issue markers)

## Task Commits

Each task was committed atomically (pre-committed by a prior executor; this plan reconciles bookkeeping only):

1. **Task 1: foregroundColor -> foregroundStyle sweep (incl. Optional-tint trap)** - `97aef2d4` (refactor)
2. **Task 2: accentColor modifier -> tint sweep (static reads left)** - `b0599d58` (refactor)
3. **Task 1 follow-up: qualify Color in foregroundStyle ternaries** - `1c08b84c` (fix)
4. **Task 3: Build, lint, full-suite gate** - verification only, no code change (no commit)

**Plan metadata:** this SUMMARY + STATE + ROADMAP docs commit

## Files Created/Modified
- `AppPackage/Sources/AppComponents/ToolbarItems.swift` - `CustomToolbarItem` restructured to `@ViewBuilder tintedContent` applying `foregroundStyle` only under `if let tint`
- `AppPackage/Sources/AppFeature/RootView.swift` - root `.accentColor(.primary)` -> `.tint(.primary)`
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - deleted the redundant deprecated `.accentColor` line (duplicate of adjacent `.tint`); share-sheet `.accentColor` -> `.tint`
- `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift`, `.../SettingFeature/EhSetting/EhSettingView+Sections1.swift` - foregroundStyle ternaries qualified with explicit `Color.` (fix commit)
- 38 further view files across AppComponents, DetailFeature, GalleryListComponents, HomeFeature, QuickSearchFeature, SearchFeature, SettingFeature, and the TabBar/Favorites/Downloads/Frontpage/Watched/DetailSearch/Comments feature views - 1:1 modifier swaps

## Decisions Made
None - followed plan as specified. The two swaps are documented 1:1 appearance-identical mechanism changes (D-11 diff-review tier).

## Deviations from Plan

None in the source work - the three commits execute the plan exactly (both grep gates at 0, static-read baseline of 4 preserved, Optional-tint handled via `if let`, RootView/ReadingView special cases done).

**One close-out scope note (not a source deviation):** Task 3 step 3 named a `sim-use` visual spot-check of tab-bar/link tint. This close-out's verification scope (per the reconciliation objective) is the grep battery + clean build + full test suite, all green. The runtime visual spot-check was not re-run; it is recorded as a human-judgment deliverable (coverage D5). Appearance parity rests on the D-11 diff-review tier plus the documented appearance-identity of `foregroundColor`->`foregroundStyle` and the `accentColor`-modifier->`tint` swap.

## Issues Encountered
- The plan's Task 3 build/test commands named `-scheme AppPackage-Package -destination '...iPhone 17 Pro'`. This checkout exposes no `AppPackage-Package` scheme at the project level and has no iPhone 17 Pro simulator. Built via the `AppFeature` scheme (whole graph + SwiftLint build plugin) on `generic/platform=iOS Simulator`; ran the full suite via `AppPackage-Package` from `AppPackage/` on the concrete booted `iPhone Air` (id `ADE09605-...`). Environment/invocation only, no code impact.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Criterion 7 (color-modifier portion) satisfied at appearance parity; down-payment on the Phase 11 lint ratchet.
- Remaining `.foregroundColor`/`.accentColor` sites explicitly deferred to plan 10-03 are expected and out of this plan's scope.
- No blockers.

## Self-Check: PASSED

- FOUND: AppPackage/Sources/AppComponents/ToolbarItems.swift (contains `if let tint` + `foregroundStyle`)
- FOUND: AppPackage/Sources/AppFeature/RootView.swift (contains `.tint(.primary)`)
- FOUND commit: 97aef2d4
- FOUND commit: b0599d58
- FOUND commit: 1c08b84c
- foregroundColor( modifier grep: 0 hits; accentColor( modifier grep: 0 hits; static `.accentColor` reads: 4 (unchanged)
- Build: ** BUILD SUCCEEDED ** (0 warnings); Tests: ** TEST SUCCEEDED **

---
*Phase: 10-ui-polish*
*Completed: 2026-07-17*
