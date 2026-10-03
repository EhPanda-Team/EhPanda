---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-03
depth: standard
execution: inline-orchestrator
scope: task-2-render-server-slices
status: blocked-by-full-matrix
files_reviewed: 6
source_head: 9906f9a61923d5957084aaa93c4f25afbc8d1bc8
---

# Task 2 scoped code and evidence review

Inline review under gsd-code-review and Swift concurrency guidance; this is not an
independent reviewer session or whole-phase sign-off. Reviewed FullContentHost.swift,
RenderServerCapture.swift, PublicVisualFixtures.swift, FullContentFeasibilityTests.swift,
RenderServerCaptureTests.swift and VisualTracerTests.swift, plus both pin diffs and the
final clean/test evidence. Read-only ReadingView/AdvancedList review informs the viewport
risk below; those production files were not modified.

The owner-adopted architecture in `73bf3e4b59` is settled. Current source retains stationary
reads of one committed full-height layout, one output image under D-08 and all acceptance
gates. Clean integration is green with zero compiler/deprecation/SwiftLint diagnostics.
Task 2 is blocked by actual capture evidence, not by an unapproved slicing decision.

## BLOCKER — Both final matrices fail Downloads native viewport parity

The final default-traits phone run has nine actual tests, eight passes and one matrix
failure; tablet has one actual matrix test and one failure. Both stop at portrait/large
Downloads, with 2 captured / 1 failed / 13 pending coordinates each. Zero skips and zero
Repetition nodes; exit 65. Strict native comparison reports matched:false. Saved-PNG
inspection finds 147 phone and 55 tablet glass-toolbar pixels, maximum channel delta one.
The tablet output is below 8192 native pixels and uses one slice, so a seam/size-limit
explanation is insufficient. Census is not evaluated at these failed coordinates.

No tolerance, pixel mask, fallback renderer, output-scale reduction or altered fixture
is permitted to turn these failures into passes. Do not record baselines, complete
Task 2/17-01 or continue dependent plans. See 17-01-FEASIBILITY-GATE.md for exact paths.

## BLOCKER — Reader fidelity is not established

Earlier diagnostic matrices reached Reader. The tablet reports a strict seam mismatch:
an entire 64-point overlap is cyan in one read and opaque black in another despite
successful draw Booleans. A phone experiment shows broad native/full viewport differences
and visible top blur. These are separate from tiny toolbar differences. They precede the
final source and are preserved as diagnostic evidence, not current-coordinate passes or
proof of an exact render-server mechanism. The final matrices stop before Reader.

## Open design risk — Native viewport inputs versus output extent

ReadingView observes its rendered size into gestureHandler.containerSize and derives
isLandscape from that size. A full-height host can change this production layout input
while native scene orientation remains unchanged. This is a concrete landscape risk;
it is not a proven cause of the observed portrait blur or black read. No production
adaptation is included in this WIP. If needed, revise Task 2's exact ownership before
editing production source. Preserve native scroll-edge effects and designed navigation.

## Reviewed safeguards and resolved local issues

- Every replicant draw checks its Boolean; each read stays within 8192 native pixels.
  The window/content root is not scrolled or re-hosted. Replicants are removed with defer.
- Sixty-four-point read context is reserved inside the limit and cropped without redraw.
  The whole 64-point seam still compares exactly. This fixes the observed Downloads
  two-pixel crop-edge mismatch without excluding content from the seam check.
- CPU composition copies the canonical bytes verified by seams. Native and full captures
  use the same path and renderer range; physical scale and strict comparison are retained.
- Failure diagnostics retain original slices, geometry and failed/pending accounting.
  Restored native geometry, tail, artwork and exact-once census remain required.
- Scene setup omits only redundant orientation requests; required requests still fail on
  errors and actual scene orientation/bounds are measured. Landscape remains unverified.
- Main-actor UIKit ownership and deterministic date, locale, time zone, IDs, ordering,
  inert dependencies and animation control remain explicit. No concurrency/lint suppression.
- Public export validates requested identities, rejects nonempty destinations and emits
  repeatable hashes from committed public fixtures. Both final phone exporter tests pass.
- Both lockfiles add only SnapshotTesting 1.19.6; all previous pins are unchanged. The
  required clean integration has passed before committing these Task 2 pins.

## Remaining verification boundaries

Combined final matrix: 4/32 captured, 2 failed, 26 pending. AX5 OCR ownership/marker
height, actual landscape and all Reader acceptance remain unproven. Earlier incremental
Comments/Home proof is valid partial evidence, not a full matrix. No approved baseline or
SUMMARY exists. One expected intentional direct-render error belongs to its unit test;
IOSurfaceClientSetSurfaceNotify remains an unresolved full-log diagnostic. Optional
post-test diagnostic collectors were stopped only after the test engines completed.

Earlier review findings about transparent Comments, withdrawn 1x proposals and upstream
reports are retained as historical evidence in 17-01-FEASIBILITY-GATE.md and
17-01-RENDER-SIZE-GATE.md. They do not supersede the current adopted architecture.
