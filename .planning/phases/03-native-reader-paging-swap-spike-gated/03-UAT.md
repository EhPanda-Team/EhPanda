---
status: partial
phase: 03-native-reader-paging-swap-spike-gated
source: [03-01-SUMMARY.md, 03-02-SUMMARY.md, 03-03-SUMMARY.md, 03-04-SUMMARY.md]
gate: 03-GO-NO-GO.md (D-11 all-or-nothing parity checklist)
device: iPhone Air, iOS 26.5
rounds: 3
started: 2026-07-12T08:05:19Z
updated: 2026-07-12T08:05:19Z
---

## Current Test

[testing paused — 10 of 16 parity rows still open: 7 partial + 3 pending]

Every open row is verification-incomplete, not a reported defect. Zero failures across
3 rounds. The D-11 GO/NO-GO gate cannot be signed until the open rows are closed, but no
fix work is implied — see `## Outstanding (grouped)`.

## Tests

<!-- Rows mirror 03-GO-NO-GO.md exactly. result: pass | partial | pending.
     "partial" = core path verified, an edge/mode still open. -->

### C1. Carousel — centered snap & symmetric peek
expected: Settled card centered; equal neighbor peek on both sides
result: pass
evidence: "R1 — centered snap Passed; symmetric neighboring peek Passed"

### C2. Carousel — 0.2 off-center fade
expected: Focused card fully opaque; off-center cards fade to ~0.2 with no flicker, at rest AND during drag
result: partial
evidence: "R1 — passed at rest"
outstanding: "Drag-time fade continuity not conclusively measured (mid-drag flicker). Needs slow-motion / frame capture."

### C3. Carousel — 20pt spacing
expected: Uniform 20pt gap, stable through paging and loop re-center
result: pass
evidence: "R1 — confirmed from accessibility frames"

### C4. Carousel — pageIndex synchronization
expected: Outward pageIndex always matches the centered logical card, incl. both loop boundaries
result: pending
evidence: "R1 — inconclusive"
outstanding: "Outward binding is not exposed to accessibility, so it could not be observed. Needs a temporary debug readout / on-screen overlay, or an in-code assertion."

### C5. Carousel — infinite-loop invisibility
expected: Continuous ordering with no flash/stutter/jump/duplicate at the tripled-buffer re-center
result: partial
evidence: "R1 — 18 forward + 18 reverse swipes preserved the six-card sequence with no settled-state discontinuity"
outstanding: "Settled state clean; drag-time re-center flash not conclusively captured (highest-risk carousel item). Needs slow-motion / frame capture at the wrap boundary."

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
result: pending
evidence: "R3 — enable action completed but the dual-page-active verification read was rejected"
outstanding: "Blocked on confirming dual-page mode is actually active in landscape. This gate also blocks R4 and the dual-page halves of R5–R9."

### R4. Reader — RTL × dual-page landscape spread order
expected: Paging axis runs right-to-left AND the earlier page appears on the RIGHT in every spread
result: pending
evidence: "R3 — outstanding"
outstanding: "Gated on dual-page activation (R3). Watch for the double-reversed imageContainerConfigs swap (03-REVIEWS HIGH) — earlier page on the LEFT is a genuine gap."

### R5. Reader — PageHandler index mapping incl. dual-page cover math
expected: Visible page matches slider/progress in single-page, dual-page, and dual-page-with-cover; seek/return round-trips
result: partial
evidence: "Single-page wiring verified via R2/R3 slider seeks + progress sync. Underlying math auto-covered by green PageHandlerTests (58 cases) + ContainerDataSourceTests (13 cases) — 03-01-SUMMARY."
outstanding: "On-device dual-page + dual-page-with-cover mapping (first/middle/final boundary, seek-and-return) pending — gated on R3."

### R6. Reader — slider seek
expected: First, middle, penultimate, and final targets land exactly once, smooth, no off-by-one — single- AND dual-page
result: partial
evidence: "R2 — middle 111/255, final 255/255. R3 — first, middle, final all passed"
outstanding: "Exact penultimate target (single-page) not yet checked; dual-page seek pending (gated on R3)."

### R7. Reader — autoplay .next
expected: Advances exactly once per interval, clamps at the last stack, no off-by-one/feedback jump — single- AND dual-page
result: partial
evidence: "R3 — single-page advances once per interval and clamps at the final page"
outstanding: "Dual-page autoplay pending (gated on R3)."

### R8. Reader — tap-to-turn
expected: At scale 1, each edge tap moves exactly one logical page/stack in the reading-mode direction — LTR AND RTL, single- AND dual-page
result: partial
evidence: "R3 — RTL left/right edge tap directions passed"
outstanding: "LTR edge taps not explicitly recorded; dual-page tap-to-turn pending (gated on R3)."

### R9. Reader — resume-page seed
expected: Reopen shows the saved page/stack immediately, no first-frame wrong page or corrective jump — single- AND dual-page
result: partial
evidence: "R3 — single-page reopens directly on the saved page"
outstanding: "Dual-page resume pending (gated on R3)."

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
passed: 6
partial: 7
pending: 3
issues: 1   # G-03-C2 (F-1): carousel fade step-vs-interpolation; fix withdrawn per owner, C2 stays open
skipped: 0
out_of_scope_bugs: 1   # F-2: pre-existing blank slider-preview tray (not a phase-3 regression)

## Outstanding (grouped)

**A. Dual-page landscape gate — 1 blocker unlocks ~6 rows (R3, R4 + dual-page halves of R5/R6/R7/R8/R9).**
Root gate: in R3 the dual-page enable action completed but the "is it active" read was rejected. Confirm dual-page mode is genuinely active in landscape, then walk the six dual-page items in one pass. Watch FB16486510 (paging half-offset) on R3 and the RIGHT-side-earlier-page spread order on R4 (03-REVIEWS HIGH regression risk).

**B. Drag-time visual continuity — 2 rows (C2 fade, C5 loop re-center).**
Both pass at rest / settled; only the mid-drag frames are unconfirmed. Neither is observable through accessibility — needs slow-motion screen capture (or Reduce Motion off, 0.25× playback) at the transition.

**C. Observability-limited — 1 row (C4 carousel outward pageIndex).**
The outward binding isn't exposed to accessibility. Needs a temporary on-screen debug readout of `cardPageIndex`, or an in-code assertion, to verify boundary sync.

**D. Single missing single-page edges — 2 quick checks.**
R6 penultimate slider target (single-page); R8 LTR edge taps at scale 1. Fast to close in a normal portrait session.

## Re-review findings (2026-07-12, pre-gate code read)

- **F-1 — carousel off-center fade is a hard step, not an interpolation (IN SCOPE, affects C2).**
  Old `Pager` used `.interactive(opacity: 0.2)`, which interpolates opacity 1→0.2 smoothly with
  drag progress. The native replacement uses `content.opacity(phase.isIdentity ? 1 : 0.2)` — a
  binary step that snaps to 0.2 the instant a card leaves identity. High-confidence cause of the
  "drag-time flicker" on C2. A one-line interpolation fix (on `phase.value`) was applied and
  committed, then **WITHDRAWN per owner decision (2026-07-12)** — the carousel keeps the original
  `phase.isIdentity ? 1 : 0.2` binary step. C2 stays OPEN; revisit the fade approach later if wanted.
  Blast radius: C2 only (C1/C3/C5 are opacity-independent).
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

## Gaps

<!-- Only IN-SCOPE, phase-3-caused defects become gaps. F-2 is pre-existing → not a gap here. -->
- gap_id: G-03-C2
  truth: "Off-center carousel cards fade smoothly (interpolated 1→0.2) during drag, matching SwiftUIPager's .interactive(opacity:)"
  status: failed
  reason: "Code read (F-1): native impl uses phase.isIdentity ? 1 : 0.2 — a hard step, not interpolation; drag-time flicker"
  severity: minor
  test: C2
  root_cause: "CardSlideSection.card(for:) .scrollTransition ignores phase.value; steps to 0.2 on any non-identity phase"
  artifacts:
    - path: "AppPackage/Sources/HomeFeature/HomeView+Sections.swift"
      issue: ".scrollTransition uses phase.isIdentity binary instead of interpolating on phase.value"
  missing:
    - "Interpolate: content.opacity(1 - (1 - 0.2) * min(abs(phase.value), 1))"
  fix_applied: false   # F-1 interpolation fix was applied+committed, then WITHDRAWN per owner (2026-07-12); carousel keeps the binary step
  status_note: "C2 OPEN — drag-time flicker concern stands; owner chose not to change the fade for now"
