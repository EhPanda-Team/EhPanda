---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-04
depth: standard
execution: inline-orchestrator
scope: task-2-simulator-lifecycle-and-native-traits
status: lifecycle-traits-passed-carousel-census-blocked
files_reviewed: 2
source_head: 574362a342cc3f48cf0c03c9010ef35d8616fb79
---

# Task 2 simulator lifecycle and native traits review

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
