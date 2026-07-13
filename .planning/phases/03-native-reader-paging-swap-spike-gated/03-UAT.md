---
status: passed
phase: 03-native-reader-paging-swap-spike-gated
source: [03-01-SUMMARY.md, 03-02-SUMMARY.md, 03-03-SUMMARY.md, 03-04-SUMMARY.md]
gate: 03-GO-NO-GO.md (D-11 all-or-nothing parity checklist)
device: iPhone Air, iOS 26.5
rounds: 4
started: 2026-07-12T08:05:19Z
updated: 2026-07-13T00:00:00Z
---

## Current Test

[ALL 16 parity rows PASSED — D-11 GO/NO-GO gate is GO (owner device sign-off, 2026-07-12)]

Round 4 closed every reader + carousel row. The last open item, C5, was a confirmed defect (three
owner-reported symptoms rooted in the tripled-buffer `.idle` re-center; see G-03-C5); the
sliding-window-rebase + `.viewAligned(limitBehavior: .always)` fix landed, was sim-verified, and
the owner re-verified all three symptoms clean on device ("沒問題了，測試通過"). D-11 is fully
satisfied — the spike is KEEP.

## Tests

<!-- Rows mirror 03-GO-NO-GO.md exactly. result: pass | partial | pending.
     "partial" = core path verified, an edge/mode still open. -->

### C1. Carousel — centered snap & symmetric peek
expected: Settled card centered; equal neighbor peek on both sides
result: pass
evidence: "R1 — centered snap Passed; symmetric neighboring peek Passed"

### C2. Carousel — 0.2 off-center fade
expected: Focused card fully opaque; off-center cards fade to ~0.2 with no flicker, at rest AND during drag
result: pass
evidence: "R1 — passed at rest. R4 — owner device pass (2026-07-12): drag-time behavior accepted as-is; F-1 interpolation fix deliberately withdrawn, binary step is the accepted look."

### C3. Carousel — 20pt spacing
expected: Uniform 20pt gap, stable through paging and loop re-center
result: pass
evidence: "R1 — confirmed from accessibility frames"

### C4. Carousel — pageIndex synchronization
expected: Outward pageIndex always matches the centered logical card, incl. both loop boundaries
result: pass
evidence: "F-3 sim session — THROWAWAY crossing/settled logs proved settled buffer%count matched every crossing incl. the 5→0 wrap. R4 — owner device pass (2026-07-12)."

### C5. Carousel — infinite-loop invisibility
expected: Continuous ordering with no flash/stutter/jump/duplicate at the loop wrap
result: pass
evidence: "R1 — 18 forward + 18 reverse swipes preserved the six-card sequence with no settled-state discontinuity. R4 — owner reported 3 defect symptoms (see G-03-C5); fix landed (sliding-window rebase, `scrollPositionID` never written, + `.viewAligned(limitBehavior: .always)`), sim-verified (rebases at every settle with no binding rewrite; crossings modular-continuous through wraps incl. negative windowBase; human-velocity flick = 1 card), and owner re-verified all three symptoms clean on device (2026-07-12): no blank peek under hard flicking, no ColorfulX reset at the wrap, no gesture interruption after settle; one-card-per-swipe feel accepted."

### R1. Reader — horizontal (LTR portrait) paging
expected: Every release snaps to exactly one full-width page; progress/index follows the visible page
result: pass
evidence: "R2 — full swipes settled 1→2→3→4→3→2; partial drag snapped back to page 2; progress text + slider stayed synchronized; no crash"

### R2. Reader — RTL direction & logical index
expected: Axis reverses; requested logical page still lands; progress/index matches visible page
result: pass
evidence: "R3 — RTL axis reversal and logical indexing passed"

### R3. Reader — dual-page landscape paging & snap
expected: Every gesture settles on one complete spread; no half-offset / skipped stack / drift; FB16486510 absent
result: pass
evidence: "R4 — owner device pass (2026-07-12): dual-page landscape confirmed active and snapping cleanly."

### R4. Reader — RTL × dual-page landscape spread order
expected: Paging axis runs right-to-left AND the earlier page appears on the RIGHT in every spread
result: pass
evidence: "R4 — owner device pass (2026-07-12)."

### R5. Reader — PageHandler index mapping incl. dual-page cover math
expected: Visible page matches slider/progress in single-page, dual-page, and dual-page-with-cover; seek/return round-trips
result: pass
evidence: "Single-page wiring verified via R2/R3 slider seeks + progress sync. Math auto-covered by green PageHandlerTests (58 cases) + ContainerDataSourceTests (13 cases). R4 — owner device pass (2026-07-12) incl. dual-page."

### R6. Reader — slider seek
expected: First, middle, penultimate, and final targets land exactly once, smooth, no off-by-one — single- AND dual-page
result: pass
evidence: "R2 — middle 111/255, final 255/255. R3 — first, middle, final. R4 — owner device pass (2026-07-12) incl. penultimate + dual-page."

### R7. Reader — autoplay .next
expected: Advances exactly once per interval, clamps at the last stack, no off-by-one/feedback jump — single- AND dual-page
result: pass
evidence: "R3 — single-page advances once per interval and clamps at the final page. R4 — owner device pass (2026-07-12) incl. dual-page. Post-R3 behavior change (owner-requested, b6730a48): autoplay now auto-resets to .off on reaching the last stack instead of idling clamped."

### R8. Reader — tap-to-turn
expected: At scale 1, each edge tap moves exactly one logical page/stack in the reading-mode direction — LTR AND RTL, single- AND dual-page
result: pass
evidence: "R3 — RTL left/right edge tap directions passed. R4 — owner device pass (2026-07-12) incl. LTR + dual-page."

### R9. Reader — resume-page seed
expected: Reopen shows the saved page/stack immediately, no first-frame wrong page or corrective jump — single- AND dual-page
result: pass
evidence: "R3 — single-page reopens directly on the saved page. R4 — owner device pass (2026-07-12) incl. dual-page."

### R10. Reader — zoom, pan & tap coexistence
expected: Paging frozen while zoomed; pan works; scale returns to 1×; RTL edge taps correct; center tap toggles panel
result: pass
evidence: "R3 — zoomed paging frozen; zoomed image pans; scale returns cleanly to 1×; RTL edge taps correct. R1/R2 — center-panel toggle passed. All four checklist observations covered."

### R11. Reader — vertical AdvancedList shared-index seam
expected: Visible page, progress, seek, autoplay result, and resume page all share one logical index, no ±1 regression
result: pass
evidence: "R3 — vertical scrolling, progress, slider, autoplay, and resume all share the same index"

## Summary

total: 16
passed: 16
partial: 0
pending: 0
failed: 0
issues: 0   # G-03-C5 FIXED + owner-verified; G-03-C2 CLOSED (owner accepted the binary-step fade)
skipped: 0
out_of_scope_bugs: 1   # F-2: pre-existing blank slider-preview tray (not a phase-3 regression) — FIXED anyway

## Outstanding (grouped)

**None — D-11 GO/NO-GO gate is GO, phase closed out.** All 16 parity rows passed with owner
device sign-off (2026-07-12). G-03-C5 fixed + verified; G-03-C2 closed as accepted-behavior. The
spike is KEEP. Post-gate closeout DONE (2026-07-12): THROWAWAY spike logs removed (carousel
crossing/settled/scrollPositionID/rebase + reader jump requested/landed + dead HomeFeature Logger
helper + dead OSLogExt dep, `65dc1677`); SwiftUIPager dropped from Package.swift/both
Package.resolved/AboutView/xcstrings (`89d85539`); DEP-05 marked complete in ROADMAP/REQUIREMENTS/STATE.

## Re-review findings (2026-07-12, pre-gate code read)

- **F-1 — carousel off-center fade is a hard step, not an interpolation (IN SCOPE, affects C2).**
  Old `Pager` used `.interactive(opacity: 0.2)`, which interpolates opacity 1→0.2 smoothly with
  drag progress. The native replacement uses `content.opacity(phase.isIdentity ? 1 : 0.2)` — a
  binary step that snaps to 0.2 the instant a card leaves identity. High-confidence cause of the
  "drag-time flicker" on C2. A one-line interpolation fix (on `phase.value`) was applied and
  committed, then **WITHDRAWN per owner decision (2026-07-12)** — the carousel keeps the original
  `phase.isIdentity ? 1 : 0.2` binary step. C2 stays OPEN; revisit the fade approach later if wanted.
  Blast radius: C2 only (C1/C3/C5 are opacity-independent).
- **F-3 — focused-card gradient handoff lagged ~0.5-0.8s behind the visual snap (IN SCOPE, FIXED).**
  Owner-reported: the outgoing card's gradient persisted ~0.5s after the new card centered. Root cause:
  `currentCardID` was only written at scroll `.idle`, but `.viewAligned`'s deceleration tail runs
  ~0.8s past the visual centering (SwiftUIPager updated its index at drag end, so the native swap
  changed the handoff timing — a parity regression). Fix (`ccf29af9`): `onScrollGeometryChange`
  flips `pageIndex` when the nearest-center logical card crosses the container midline — which is
  also `.viewAligned`'s own settle target, so snap-backs never mis-claim; the `.idle` write stays as
  reconciliation and the logical-index dedup keeps the tripled-buffer re-center event-silent.
  **Sim-verified with THROWAWAY logs** (kept until D-11 sign-off; they double as C4's pageIndex
  observability): crossing preceded settle by ~780ms on all 8 swipes incl. the 5→0 wrap;
  settled buffer%count matched every crossing; the re-center emitted no crossing event.
  Measured datum: the `scrollPosition(id:)` binding updated ~15ms after the crossing (at target
  determination, not at rest) — option A would have been near-timely for flicks, but geometry wins
  for slow finger-down drags and carries a guaranteed, documented timing.
  **Owner-confirmed on device ("效果很讚"): handoff feel + fast-fling hop-through accepted.**
  Follow-on polish: 0.5s ease-in-out opacity cross-fade on the gradient insert/remove
  (`feat(home): cross-fade card gradient on focus`, owner-tuned duration) — also confirmed.
- **F-2 — reader slider preview tray is blank (PRE-EXISTING, OUT OF SCOPE, not a phase-3 regression).**
  Git-confirmed: phase-3 paging commits never touched ControlPanel.swift / ReadingReducer+ImageFetch.swift
  / +Body.swift. Root cause is a fetch-bootstrap deadlock: `SliderPreivew.previewsIndices` returns `[]`
  while `previewURLs.isEmpty`, so no slot renders, so no `.onAppear` fires, so `fetchPreviewURLs` is never
  sent, so `previewURLs` stays empty. Does NOT block the D-11 gate.
  **Runtime-confirmed blank, then FIXED** (removed the empty-guard in `previewsIndices` so the window is
  computed from `sliderValue` and the slots' `.onAppear` can bootstrap the fetch) and **re-verified on
  sim: the tray now renders page thumbnails.** Fix in `ControlPanel.swift`.

## Test ownership (human vs agent)

Human-required (tiny glitch / fast / real-time feel / value not exposed to accessibility):
- C2 drag-time fade continuity (re-test after F-1 fix)
- C5 loop re-center flash (drag-time)
- C4 carousel pageIndex at loop boundary (not exposed to accessibility)
- R3 dual-page landscape snap smoothness + FB16486510
- R10 zoom/pan/tap coexistence feel (re-confirm; was agent-passed)
- R6/R7/R8 visual smoothness overlay (correctness is agent-verifiable via landed-id logs)

Agent-testable via sim-use (correctness / static / log-verifiable):
- C1, C3, R1, R2, R5, R6 (incl. penultimate), R7 (incl. end-clamp), R8 (incl. LTR edge taps),
  R9, R11, R4 (static spread order), R3 static snap alignment + dual-page activation confirm,
  plus F-2 preview-tray runtime confirmation.

## Sim-use session — 2026-07-12 (fixed build, iPhone Air / iOS 26.5)

Ran against a fresh full-app build that INCLUDES the F-1 fade fix (installed 17:2x).

Confirmed:
- **C1 centered snap + symmetric peek — PASS** (accessibility frames: middle card centered at
  screen-width/2; left/right peek ~22pt each, symmetric).
- **C3 20pt spacing — PASS** (frames: adjacent-card gaps measured exactly 20pt both sides).
- **F-2 blank slider-preview tray — CONFIRMED at runtime.** Long-press raises the tray but it is
  an empty dark panel with zero thumbnails; page stays "1 / 26" during hold (seek correctly defers
  to release). Matches the fetch-bootstrap deadlock diagnosis. Then FIXED + re-verified on sim
  (tray now renders thumbnails). F-2 committed; F-1 fade fix was committed then WITHDRAWN per owner.

Automation limits discovered (these items are now hard-classified device/human, not agent):
- **Cannot drive the simulator into landscape** from this toolchain: sim-use `gesture rotate-cw`
  is a two-finger rotate GESTURE (not device orientation); the Simulator hardware-rotate shortcut
  needs accessibility permission that isn't granted (osascript keystroke blocked). ⇒ **R3 / R4 and
  all dual-page-landscape verification must be done on device by a human.**
- **SwiftUI Menu popups don't open reliably** via the a11y tap (reading-direction picker, autoplay
  timer). ⇒ switching reading direction to LTR and driving autoplay via the menu aren't automatable
  here, so **R8 LTR edge taps and R7 via-menu autoplay** fall to device/human too.

Net: sim-use closed C1/C3 (re-confirm on fixed build) + F-2 repro. The remaining OPEN reader gaps
(penultimate single-page seek precision, LTR edge taps, dual-page cluster) are not cleanly
automatable from here and join the human list.

## Sim-use session — 2026-07-12 evening (C5 sliding-window fix verification)

Iterated three builds against THROWAWAY carousel logs (`log stream --level debug`):
1. **5-block window, idle rebase**: mechanics perfect (rebase at settle, zero binding rewrites,
   modular-continuous crossings through the 5→0 wrap) but machine-gun flicking (15 chained
   0.08s/350pt swipes, no settle pauses) clamped at the window edge — headroom is finite.
2. **+ emergency mid-flight rebase**: RUNAWAY — windowBase 12→180+ in 250ms. Root cause: in-flight
   content offset is pinned, so a mid-flight window shift makes `scrollPosition(id:)` re-derive its
   id by the same shift and the trigger refires forever. Mid-flight rebase is architecturally
   impossible; reverted. Finding documented in the `windowBlocks` code comment.
3. **15-block window + `.viewAligned(limitBehavior: .always)`** (owner-chosen): human-velocity
   flick (~2000pt/s) = exactly 1 card (SwiftUIPager parity); ~4400pt/s = 2; only non-human
   synthetic ~10,000pt/s bursts still out-run the cap, and the worst case degrades gracefully
   (brief edge clamp, self-heals at the next idle rebase). Reverse loops drive `windowBase`
   negative — positive-modulo verified. Final screenshot healthy (centered card + gradient +
   both peeks).

## Gaps

<!-- Only IN-SCOPE, phase-3-caused defects become gaps. F-2 is pre-existing → not a gap here. -->
- gap_id: G-03-C2
  truth: "Off-center carousel cards fade smoothly (interpolated 1→0.2) during drag, matching SwiftUIPager's .interactive(opacity:)"
  status: closed
  reason: "Owner accepted the binary-step fade on device (R4, 2026-07-12); exact-interpolation parity deliberately dropped"
  severity: minor
  test: C2
  root_cause: "CardSlideSection.card(for:) .scrollTransition ignores phase.value; steps to 0.2 on any non-identity phase"
  artifacts:
    - path: "AppPackage/Sources/HomeFeature/HomeView+Sections.swift"
      issue: ".scrollTransition uses phase.isIdentity binary instead of interpolating on phase.value"
  fix_applied: false   # F-1 interpolation fix was applied+committed, then WITHDRAWN per owner (2026-07-12); carousel keeps the binary step
  status_note: "CLOSED as accepted-behavior — C2 marked pass per owner sign-off"
- gap_id: G-03-C5
  truth: "Infinite loop is invisible: no blank edge peek, no gradient/playback reset, no gesture interruption at the wrap"
  status: closed
  reason: "Owner-reported on device (R4, 2026-07-12): ① blank next-page peek at the logical last card after hard flicking; ② centered card's ColorfulX playback resets when the re-center fills it; ③ an in-flight drag is cancelled if it overlaps the re-center write"
  severity: major
  test: C5
  root_cause: "The `.idle` re-center WRITES `scrollPositionID` (a programmatic scroll): it changes the focused card's buffer id → view identity → gradient rebuild (②); it cancels overlapping gestures (③); and it only fires at `.idle` behind a 0.2s `performingChanges` window that swallows fast consecutive settles, letting the scroll drift to the real buffer edge (①)"
  artifacts:
    - path: "AppPackage/Sources/HomeFeature/HomeView+Sections.swift"
      issue: ".onScrollPhaseChange idle handler re-centers by writing scrollPositionID inside a disabled-animation Transaction, gated by performingChanges"
  fix_applied: true
  status_note: "FIXED + owner-verified on device (2026-07-12). Design: (a) sliding-window rebase — ids are an unbounded integer window (15 blocks); at `.idle` shift `windowBase` so the settled id sits in the middle block; `scrollPosition(id:)` preserves the anchored view's offset across the pure-data diff and `scrollPositionID` is NEVER written (kills ② and ③ architecturally). (b) `.viewAligned(limitBehavior: .always)` — one card per swipe, which is exact SwiftUIPager parity (git-confirmed: old Pager had no `.multiplePagination()`) and bounds per-gesture travel so the window edge is humanly unreachable (kills ①). Owner chose .always over .alwaysByFew / free-fling. Sim evidence: rebases at every settle with zero binding rewrites (incl. negative windowBase after reverse loops); human-velocity flick = exactly 1 card. Two dead ends measured and documented in code comments: mid-flight rebase self-retriggers endlessly (content offset is pinned in flight, the binding re-derives by the same shift), and window widening alone loses to synthetic machine-gun flicking (~10,000pt/s, 40+ cards per burst — non-human; worst case degrades gracefully: brief edge clamp, self-heals at idle)."
