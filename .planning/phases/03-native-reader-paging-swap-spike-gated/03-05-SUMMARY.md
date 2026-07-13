---
phase: 03-native-reader-paging-swap-spike-gated
plan: 05
subsystem: build
tags: [dependency-removal, spm, dep-05, go-no-go, spike-to-keep]

requires:
  - phase: 03-native-reader-paging-swap-spike-gated
    provides: 03-02 native carousel + 03-04 native reader (full D-10 spike surface, both call sites)
provides:
  - 03-GO-NO-GO.md — the D-11 signed parity checklist and D-02 decision record (GO, owner device sign-off)
  - SwiftUIPager-free dependency set (Package.swift + both Package.resolved regenerated)
  - AboutView acknowledgement row + xcstrings keys removed; throwaway spike logging removed
affects: []

tech-stack:
  added: []
  removed: [SwiftUIPager]
  patterns: [spike-to-keep behind an owner-signed all-or-nothing gate]

key-files:
  created:
    - .planning/phases/03-native-reader-paging-swap-spike-gated/03-GO-NO-GO.md
  modified:
    - AppPackage/Package.swift
    - AppPackage/Package.resolved
    - EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    - AppPackage/Sources/SettingFeature/Components/AboutView.swift
    - AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift

key-decisions:
  - "GO decision (D-02 all-or-nothing gate): all 16 parity rows passed on device — SwiftUIPager removed, DEP-05 satisfied, spike is KEEP. No half-migration path taken."
  - "The stale appFeature .targetDependency(.swiftUIPager) was removed alongside the real homeFeature/readingFeature entries — AppFeature never imported it."
  - "G-03-C5 (loop re-center defect) was fixed within the gate before sign-off (sliding-window rebase + .viewAligned(limitBehavior: .always)); G-03-C2 (binary-step fade) was closed as accepted behavior, exact-interpolation parity deliberately dropped."
  - "Historical SwiftUIPager mentions remain only in code comments (parity rationale) — the grep gate is against the product name in usage, which returns no matches."

patterns-established:
  - "Dependency removal mirrors the Phase 2 WaterfallGrid shape: drop the .package decl + product alias + all .targetDependency entries, regenerate Package.resolved, delete the acknowledgement row + its xcstrings keys together."

requirements-completed: [DEP-05]

coverage:
  - id: D1
    description: "D-11 go/no-go checklist enumerates every D-10 parity item (reader + carousel) with a Pass/Gap mark and owner sign-off before any dependency removal"
    requirement: DEP-05
    verification:
      - kind: manual
        ref: "03-GO-NO-GO.md — 16/16 Pass, Decision: GO, owner device sign-off 2026-07-12; detailed evidence in 03-UAT.md (status: passed)"
        status: pass
    human_judgment: true
    rationale: "Device-observable paging/rotation/gesture parity is the D-02 gate; the owner walked all 16 rows on iPhone Air / iOS 26.5 across 4 rounds"
  - id: D2
    description: "On GO, SwiftUIPager is fully removed from the dependency set, resolved graph, acknowledgement, and xcstrings, with a clean green build"
    requirement: DEP-05
    verification:
      - kind: build
        ref: "AppPackage-Package suite green under SwiftLint-as-error; grep for the SwiftUIPager product across AppPackage/Sources + Package.swift returns no usage (only historical comments)"
        status: pass
    human_judgment: false
    rationale: "Compile-time removal verified by the full suite and the usage grep"

duration: 10min
completed: 2026-07-12
status: complete
---

# Phase 3 Plan 05: D-11 Go/No-Go Gate + SwiftUIPager Removal Summary

**The D-02 all-or-nothing gate closed GO: the owner walked every D-10 parity item on device (16/16 Pass), so SwiftUIPager was removed from both call sites' dependency graph, its acknowledgement + xcstrings keys deleted, the throwaway spike logging pruned, and DEP-05 satisfied — spike-to-keep (D-11).**

## Performance

- **Duration:** ~10 min active (gate walk spanned 4 device rounds on 2026-07-12)
- **Completed:** 2026-07-12
- **Tasks:** 3 (author checklist → owner device gate → GO-only removal)
- **Files modified:** 7 (1 created)

## Accomplishments

- **Task 1 — authored the D-11 parity checklist** (`1025324a`): `03-GO-NO-GO.md` enumerates every D-10 parity item, grouped Reader (11 rows) / Carousel (5 rows), each with a Pass/Gap column, a how-to-verify instruction (from `03-VALIDATION.md` § Manual-Only Verifications), and an evidence slot — including the reader dual-page-landscape row, the COMBINED RTL × dual-page spread-order row (03-REVIEWS HIGH), and the carousel infinite-loop-invisibility row (the highest-risk item), plus the Decision / D-02-outcome block. Marks left blank for the owner.
- **Task 2 — owner walked the gate on device and signed GO.** All 16 parity rows passed on iPhone Air / iOS 26.5 across 4 rounds. Two in-scope findings surfaced and were resolved before sign-off:
  - **G-03-C5** (loop re-center visible defect — blank edge peek under hard flicking, ColorfulX playback reset at the wrap, in-flight gesture cancellation): fixed with the sliding-window rebase (`windowBase` shifts so the settled id sits mid-window; `scrollPositionID` is never programmatically written) + `.viewAligned(limitBehavior: .always)` (one card per swipe = SwiftUIPager parity, bounds per-gesture travel) — `c6b64b34`. Owner re-verified all three symptoms clean on device.
  - **G-03-C2** (off-center fade is a binary step, not interpolated): closed as accepted behavior; the one-line interpolation fix was withdrawn per owner decision — exact `.interactive(opacity:)` parity deliberately dropped.
- **Task 3 — on GO, removed SwiftUIPager** (`ed4621fa`, `a4caa1ef`): dropped the `.package(url: .../fermoya/SwiftUIPager)` decl, the `swiftUIPager` product alias, and all 3 `.targetDependency(.swiftUIPager)` entries (stale `appFeature` + real `homeFeature` + `readingFeature`); regenerated both `Package.resolved` files (the SwiftUIPager pin gone); deleted the `AboutView` acknowledgement row and the `acknowledgement.swiftUIPager` / `acknowledgement.swiftUIPager_link` xcstrings keys (each a `shouldTranslate:false` all-locale entry, removed whole); pruned the throwaway landed-id / carousel spike logging and the now-dead `OSLogExt` dependency added only for the spike. Full `AppPackage-Package` suite green under SwiftLint-as-error; a grep for the SwiftUIPager product across `AppPackage/Sources` + `Package.swift` returns no usage (only historical parity comments remain).
- **DEP-05 marked complete** in ROADMAP / REQUIREMENTS / STATE (`b4455487`).

## Task Commits

1. **Task 1: Author the D-11 go/no-go parity checklist** — `1025324a` (docs)
2. **Task 2: Owner device gate → GO** (in-gate fix) — `c6b64b34` (fix: sliding-window carousel loop, G-03-C5)
3. **Task 3: Remove throwaway spike logs** — `ed4621fa` (chore)
4. **Task 3: Drop SwiftUIPager dependency (DEP-05)** — `a4caa1ef` (chore)
5. **Close-out: mark DEP-05 / Phase 3 complete** — `b4455487` (docs)

## Files Created/Modified

- `.planning/phases/03-native-reader-paging-swap-spike-gated/03-GO-NO-GO.md` — created; the D-11 signed parity checklist / D-02 decision record (GO)
- `AppPackage/Package.swift` — SwiftUIPager decl, product alias, and all 3 target deps removed
- `AppPackage/Package.resolved` + `EhPanda.xcodeproj/.../swiftpm/Package.resolved` — regenerated without the SwiftUIPager pin
- `AppPackage/Sources/SettingFeature/Components/AboutView.swift` — acknowledgement row removed
- `AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings` — `acknowledgement.swiftUIPager` + `_link` keys removed
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` — throwaway landed-id logging removed
- `AppPackage/Sources/HomeFeature/HomeView+Sections.swift` — carousel spike logging removed; sliding-window loop fix (C5)

## Decisions Made

- **GO, not NO-GO:** every parity item passed on device, so the all-or-nothing gate opened and SwiftUIPager left the dependency set. No half-migration was committed at any point — the dependency stayed declared through the entire gate so rollback was always a single revert (D-02).
- **Fix-within-gate over defer:** the C5 loop defect was a genuine in-scope gap, but standard-component approaches (D-03) closed it (sliding-window rebase + `.viewAligned` limit) rather than forcing a NO-GO. Two measured dead ends (mid-flight rebase self-retrigger; window-widening alone) are documented in code comments.

## Deviations from Plan

- The plan listed `ReadingView.swift` for the throwaway-log removal; the carousel spike logs in `HomeView+Sections.swift` and the dead `OSLogExt` dep were also pruned in the same cleanup — a strict superset of the plan's removal scope, no behavior change.

## Issues Encountered

- G-03-C5 surfaced during the device gate (three owner-reported symptoms rooted in the tripled-buffer `.idle` re-center). Root-caused and fixed before sign-off; see `03-UAT.md` Gaps for the full analysis.

## User Setup Required

None.

## Next Phase Readiness

- Phase 3 is complete: both native swaps (grid in Phase 2, reader + carousel here) are kept, SwiftUIPager is gone, DEP-05 satisfied. The reader/carousel surfaces are now the substrate Phase 5 (Adaptive Layout & Universal Orientation) refines on top of.

---
*Phase: 03-native-reader-paging-swap-spike-gated*
*Completed: 2026-07-12*
