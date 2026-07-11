---
phase: 03-native-reader-paging-swap-spike-gated
plan: 04
subsystem: ui
tags: [swiftui, scrollposition, autoplay, slider, tap-to-turn, dep-05]

requires:
  - phase: 03-native-reader-paging-swap-spike-gated
    provides: 03-03 PageModel + horizontal paging ScrollView + performingChanges guard
provides:
  - single guarded jump(toPagerIndex:) — clamped to containerDataSource bounds, feedback-guarded, animation on the scroll write
  - autoplay .next, slider seek, and tap-to-turn all routed through the guarded jump
  - throwaway landed-id logging (requested vs settled scrollPosition id) via the existing file logger
  - D-09 coexistence wiring confirmed (freeze under zoom / pan while zoomed / RTL edge tap)
affects: [03-05]

tech-stack:
  added: []
  patterns: [one clamped programmatic write path for a shared scroll index]

key-files:
  created: []
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift

key-decisions:
  - "Jump animates the scrollPosition write (withAnimation) for parity with Pager's animated page transitions; the settle write is idempotent so the late .idle callback cannot loop"
  - "Landed-id log fires at the .idle settle (not on a fixed delay), so animated jumps log the true landing"
  - "Vertical-mode autoplay is now clamped to the last stack — deliberate improvement over Page's unclamped vertical .next (totalPages was only populated by a rendered Pager), not drift"

patterns-established:
  - "All reader programmatic writes go through jump(toPagerIndex:); bare pageModel.update calls outside it are a review smell"

requirements-completed: [DEP-05]

coverage:
  - id: D1
    description: "Autoplay, slider seek, and tap-to-turn advance the shared PageModel through one clamped, feedback-guarded jump path"
    requirement: DEP-05
    verification:
      - kind: unit
        ref: "ReadingFeatureTests green post-rewiring; full AppPackage-Package suite TEST SUCCEEDED (reducer contract intact)"
        status: pass
    human_judgment: true
    rationale: "Landed-id fidelity (no glitch/off-by-one) is device-observable; the logs are the evidence the Plan 05 owner gate cross-checks"
  - id: D2
    description: "Gesture coexistence per D-09: paging frozen at scale != 1, pan while zoomed, RTL-aware edge tap preserved"
    requirement: DEP-05
    verification: []
    human_judgment: true
    rationale: "Multi-gesture composition cannot be exercised headlessly — Plan 05 owner gate item"

duration: 10min
completed: 2026-07-12
status: complete
---

# Phase 3 Plan 04: Guarded Programmatic Jumps Summary

**Autoplay `.next`, slider seek, and tap-to-turn all rewired through a single `jump(toPagerIndex:)` — clamped to `containerDataSource` bounds, `performingChanges`-guarded against the scroll-read feedback loop, with settle-time landed-id logging as the go/no-go off-by-one evidence**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-07-12T07:36:00+09:00
- **Completed:** 2026-07-12T07:55:00+09:00 (includes a user scope-confirmation pause)
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `jump(toPagerIndex:)` in ReadingView's handler extension: clamps the target into the live `containerDataSource(setting:isLandscape:).indices`, early-returns on no-op targets, sets `performingChanges`, writes `pageModel` and `scrollPositionID` together (scroll write animated for Pager-transition parity), re-arms after the 0.2 s settle — the AdvancedList guard idiom.
- `setPageIndex(sliderValue:)` now maps via `mapToPager` then jumps; `setAutoPlayPolocy`'s `updatePageAction` advances via `jump(toPagerIndex: pageModel.index + 1)` — clamped at the last stack, no wrap.
- Tap-to-turn (`setPageIndexOffsetAction`) calls `jump(toPagerIndex: pageModel.index + $0)` with the offset sign exactly as `GestureHandler.onSingleTapGestureEnded` supplies it — the RTL inversion stays in GestureHandler, untouched (Pitfall 6).
- Throwaway landed-id instrumentation through the EXISTING file-level `logger` (no redeclaration — 03-REVIEWS LOW): `pendingJumpTarget` records each request; the `.onScrollPhaseChange == .idle` settle logs `requested:` vs `landed:` — logging at settle (not a fixed delay) so animated jumps log the true landing.
- D-09 coexistence confirmed wired: `.scrollDisabled(gestureHandler.scale != 1)` freezes paging under zoom (a); `.highPriorityGesture(dragGesture.simultaneously(with: tapGesture), isEnabled: scale > 1)` pans while zoomed (b); RTL edge single-tap turns via the untouched GestureHandler inversion, and the tap point is screen-space (`TouchHandler.shared.currentPoint`) read outside the flipped subtree (c). Plan 03's RTL fix re-verified: flip on the ScrollView, per-page `.leftToRight` re-normalization, gesture modifiers outside the flipped subtree.

## Task Commits

1. **Task 1: Route autoplay + slider through the guarded, clamped jump with landed-id logging** - `41a78ff2` (feat)
2. **Task 2: Route tap-to-turn through the jump; confirm D-09 coexistence** - `41d0f9cd` (feat)

## Files Created/Modified
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - jump helper + pendingJumpTarget + settle logging; slider/autoplay rerouted
- `AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift` - tap closure rerouted through jump

## Decisions Made
- **Animated vs suppressed jump:** the scroll write runs inside `withAnimation` so programmatic turns keep today's animated feel (Pager animated its transitions). The feedback loop is prevented by the flag plus idempotence: the animation-end `.idle` settle writes the same index, so no second `syncReadingProgress` fires. If the owner gate finds animated jumps glitchy under `.paging`, switching to a `disablesAnimations` transaction is a one-line D-03 fallback.
- **Clamp nuance recorded (03-REVIEWS LOW):** horizontal clamping is exact `Page` parity (`Page.index` clamps via `totalPages`); vertical `.next` was effectively unclamped under SwiftUIPager because `totalPages` was only populated by a rendered `Pager` — the clamped jump is a deliberate small improvement there, not drift. The go/no-go should not misread it.

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None.

## Next Phase Readiness
- The full spike surface (D-10) is now built across both call sites: carousel (03-02) + reader core (03-03) + programmatic-jump hardening (03-04), with the 03-01 mapping guard green throughout and the full AppPackage-Package suite green at the wave merge.
- Ready for Plan 05: the owner-gated D-11 go/no-go walk (checklist authoring + device verification + GO-only SwiftUIPager removal). SwiftUIPager is still declared — rollback remains a single revert.
- Evidence to collect on device: the `jump requested:/landed:` log lines during slider/autoplay/tap/resume jumps.

---
*Phase: 03-native-reader-paging-swap-spike-gated*
*Completed: 2026-07-12*
