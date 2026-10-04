---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-04
depth: standard
execution: inline-orchestrator
scope: task-2-scale-robust-census
status: passed-final-tree-gate
files_reviewed: 5
source_head: f12ecb8333
---

# Task 2 scale-robust census review

Inline gsd-code-review using the snapshot-testing, testing and concurrency guidance;
not independent or whole-phase review. Scope: FullContentHost.swift,
RenderedContentInspection.swift, RenderedContentInspectionTests.swift,
Scripts/verify-full-content-capture.py and the owner-approved .swiftlint.yml change.

The owner-supplied revision replaces fragile ownership of one OCR band with redundant reads
at two scales. Fine windows preserve body-text resolution; full-width viewport-height
windows accommodate large Reader markers. Inner-edge margins reject clipped word candidates,
while exact image-boundary edges remain eligible. Only expected census words merge, the
same label at separate locations remains separate, and different census labels at one
location throw an explicit error. Thus a missing/duplicated marker still fails exact-once
counting. The generated-canvas Vision test exercises both failure sensitivities, in addition
to ten focused window/merge cases.

At most eight child tasks own crop/request work at once. Results carry their window index
and are sorted before flattening, preserving merge order independently of completion order.
The task group propagates request/cancellation failures. FullContentHost persists every
confident read before attempting merging, so an ambiguity retains its supporting evidence.
Census, frame and trailing-marker checks consistently consume the merged occurrences.
Diagnostic changes retain every key the gate reads; the runner adds all eleven new tests
and expects exactly 27 phone / 24 tablet native passes.

Extraction was checked against 898fb65afb: the block moved into the new file is byte-identical
apart from outer blank lines and the file's imports. Host capture/error/serialization remain
at their prior ownership site. The lint change removes the whitespace allowance between a
base and its subscript bracket, matching the owner's array-literal correction; it introduces
no suppression and leaves actual flush subscripts checked. No additional implementation
change is needed for this handoff.

Supplied source-898fb65afb gate: `/tmp/ehpanda-phase17-census-gate-01/gate.json` reports 32/32.
Research evidence: `/tmp/ehpanda-phase17-size-probe-evidence/ocr-census/RESULTS.md`.
Final-tree verification at f12ecb8333 passed under
`/tmp/ehpanda-phase17-census-final-gate-01/`: 32/32 coordinates and 66/66 tests across
17 invocations, including all eleven census tests on each family. Clean builds have no
compiler/lint diagnostics; result bundles have no failures, skips, expected failures,
Repetition nodes or runtimeWarnings. Independent audits verify unchanged source hashes,
exact native/frozen/full viewport parity, categories/classes, diagnostic read indices,
41 fixture exports and both simulators restoring their original size/state. The canonical
v2 fixture export is materialized byte-for-byte in .capture/regression, with the previous
directory backed up in the evidence root. No baseline was promoted. No new review finding
was identified in the adopted change; Task 2 can close.

## Historical device-level Dynamic Type review

Inline gsd-code-review using the previously read snapshot-testing and testing guidance;
not independent or whole-phase review. Scope: FullContentHost.swift,
FullContentFeasibilityTests.swift and Scripts/verify-full-content-capture.py.

The device setting is now the single category source. The runner saves the original size
after boot, sets/readbacks the invocation's requested category before launch, and records
both commands' exit codes and observed output. Cleanup restores portrait first and then
original content size before any gate-owned shutdown; nested finally blocks preserve
shutdown even if restoration fails. Existing Booted devices remain Booted. Six focused
control tests cover positive cleanup and rejection paths; mocks do not substitute for the
actual simulator evidence.

Tests split size and orientation into four methods per family and require app/scene/request
agreement before host construction. Host creation rejects app mismatch before adding a
window. The window category override and duplicate SwiftUI Dynamic Type environment source
are removed; existing viewport trait assertions remain. No production toolbar, sampling,
size-class, census or fixture rule changes. The previous research's glyph explanation is
now supported by both orientations passing with 70 × 85-pixel native/frozen/full glyphs.

Clean/UI builds and strict lint pass. Native tests pass 16/16 phone and 13/13 tablet; all
16 phone matrix coordinates, 12 tablet portrait/landscape-AX5 cells and tablet landscape
Large Home pass. The new failure is tablet landscape Large Comments OCR: visually present
VC5 is omitted and VC7 is recorded as LOA. Native/frozen/full parity is exact, category and
classes agree, and the whole 2420 × 3926 output is one slice. No defect was found in this
content-size implementation; the full Task 2 gate remains open at 29 captured / 1 failed /
2 pending. No census relaxation is implied. Evidence and exact bounds are recorded in
17-01-FEASIBILITY-GATE.md and `/tmp/ehpanda-phase17-content-size-gate-01/`.

## Historical v2 carousel fixture review

Inline gsd-code-review using snapshot-testing and testing guidance; not an independent or
whole-phase review. Scope: PublicVisualFixtures.swift and FullContentFeasibilityTests.swift.

The owner-approved fixture uses distinct PEEK1/PEEK2 IDs outside the six expected Home
markers. Their title shape and page count match VH1, and the unchanged seed/current-ID
still center VH1. Both neighbors pass through the existing image cache and Gallery creation
path. Assertions preserve three-or-more popular entries and marker disjointness. Exact-once
census and production rendering code are unchanged. The Task 1 tracer is untouched.

Fixture v2 exports both canonical-size covers, lists them in home-finite assets, and includes
their metadata. Both export-dimension checks cover the new files; the existing repeatability
and missing-input tests remain. Eighteen extracted exports were independently verified for
47 file sizes/hashes, current generator source hash, cover dimensions and scenario membership.

Evidence: `/tmp/ehpanda-phase17-carousel-v2-gate-01/`. Strict SwiftLint and clean/UI builds pass without compiler/lint
diagnostics. Native tests pass 16/16. All eight portrait cells and all four Large landscape
cells pass. Landscape Large Home now has census 6/6 with VH1 exactly once. No fixture/export
implementation defect was found in this review.

The remaining integration gate is AX5 landscape Home growth parity: 2206 changed pixels,
confined to the reload glyph, despite exact native/frozen bytes and stable regular/compact
traits. One render slice covers the full image. Its root cause remains unknown; this review
does not attribute it to the fixture or declare all 32 cells complete. Coverage is
12 captured / 1 failed / 19 pending. All iPad cells remain unverified in this run.

## Historical simulator lifecycle and native traits review


Inline gsd-code-review using the previously read snapshot-testing and testing guidance.
This is not independent review or whole-phase sign-off. Scope: FullContentHost.swift and
Scripts/verify-full-content-capture.py; the earlier allocation review is preserved below.

The runner records session ownership before booting, checks Booted around every build/test
invocation, restores portrait before owned shutdown, and retains already-booted devices.
Families enter sequentially. A failed matrix still passes through portrait/session cleanup.
The current failure path verifies the phone returns to its original Shutdown state; the
already-Booted iPad remains unchanged because its session was not reached. The tablet session
path itself is therefore not claimed as runtime-verified. Build-time failures precede any
rotation and still execute session shutdown.

The capture window receives both scene size classes before first rendering, beside its
existing deterministic trait overrides. No post-reference environment/trait transition is
introduced. Scene/window values are recorded at native and expanded sizes; successful matrix
coordinates are checked by the runner. The failed landscape coordinate's four values were
also inspected manually and all equal regular/compact. Strict byte parity proves the
creation-time overrides preserve this actual Home viewport and its growth result.

Evidence: `/tmp/ehpanda-phase17-lifecycle-traits-gate-01/`. Clean/UI builds are free of compiler/lint diagnostics;
strict no-cache lint passed FullContentHost.swift before the gate. Phone native 16/16,
focused AX5 Comments and portrait 8/8 pass. Source hashes remain unchanged, test skips and
Repetition nodes are zero. Lifecycle restoration completed without interrupted processes.

No new lifecycle or trait-pinning implementation defect was found. The remaining failure is
an acceptance mismatch exposed by native landscape: the one-gallery fixture is rendered by
an infinite carousel, and its visible neighboring replica yields a second VH1 marker in the
same OCR band. Both occur in the byte-identical native viewport. The exact-once global
marker census has no approved rule for this behavior. That contract remains unresolved;
coverage is 8 captured / 1 failed / 23 pending, with no Task 2 completion claim.

## Historical composite area and ownership review


Inline gsd-code-review using pfw-snapshot-testing, pfw-testing, pfw-custom-dump and
swift-concurrency-pro guidance. This is not an independent review or whole-phase sign-off.
Scope: RenderServerCapture.swift, FullContentHost.swift, RenderServerCaptureTests.swift,
FullContentFeasibilityTests.swift and Scripts/verify-full-content-capture.py.

## Allocation and ownership

The allocation owner rejects pixelHeight greater than budget / pixelWidth before frames
are read or Data allocated. Division avoids a potentially overflowing area multiplication.
The documented policy is 89,653,248 pixels, separate from the 8191-pixel read ceiling.
Each canonicalized read writes directly into the destination row range. Copy blending
replaces overlap alpha rather than accumulating it. Strict original overlap comparisons
precede each write. Adjacent raw reads survive only for seam diagnostics; their indexes
are retained when writing the failing pair. Result contains slice geometry and the immutable
canonical Data. The CGDataProvider owns the bridged Data for the image's lifetime, and the
census receives the same value without mutation. Native measurements confirm no second
full-buffer footprint increase. Parity-failure slices crop the composite.

UIKit capture remains MainActor-isolated. Raw pointers are confined to Data's mutable-byte
closures and synchronous CGContext drawing. No escaping raw pointer, unchecked Sendable,
new module dependency or production view change was introduced. Geometry tracing precedes
each resize and final allocation, preserving evidence on convergence or area rejection.
Restore/error/dismiss ordering and stable observable freeze delivery are unchanged.

## Verification

Current evidence: `/tmp/ehpanda-phase17-area-budget-gate-02/`.
Clean FeatureTests/orientation builds have zero compiler/lint diagnostics. Strict no-cache
SwiftLint passes all four changed Swift files. Native 16/16 tests pass, including the
89,652,780-pixel boundary, actual slice joins, next-row refusal, and footprint attachment.
The immutable Data adds 342.172 MiB resident footprint for a 341.998 MiB buffer; census reuse
adds none. Total measured peak is 517.565 MiB (443.453 MiB above the pre-composite sample).
No claim is made that whole capture/verification memory is bounded to this measurement.

AX5 Comments passes at 1260 × 46,989 px, 7 slices, exact viewport parity and census 12/12.
All phone portrait coordinates pass (8/8). The runner checks exact test counts, provenance,
zero skips/Repetition, acceptance and freeze/native parity before advancing.

## Open integration gate

No new allocation, pixel-sharing or concurrency defect was found in this review.
External landscape UI rotation passes, but the following app invocation remains portrait
for all 97 readiness samples over 5.043 seconds (420 × 912; device orientation unknown).
The bounded check observes actual geometry and yields while waiting; it never treats elapsed
time as successful readiness and never requests orientation itself. This remains an
unresolved integration failure, so no complete-matrix or Task 2 success is claimed.
Coverage: 8 captured / 1 failed / 23 pending; iPad remains unverified in this gate.
