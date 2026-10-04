---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-04
depth: standard
execution: inline-orchestrator
scope: task-2-composite-area-and-ownership
status: area-budget-passed-external-orientation-blocked
files_reviewed: 5
source_head: 040064f2b2bcc3dd3bc3a0a65b160443ff34edb8
---

# Task 2 composite area and ownership review

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
