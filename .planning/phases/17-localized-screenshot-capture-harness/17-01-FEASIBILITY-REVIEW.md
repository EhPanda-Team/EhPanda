---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-04
depth: standard
execution: inline-orchestrator
scope: task-2-parity-handoff
status: owner-viewport-decision-and-native-orientation
files_reviewed: 6
source_head: 723a117fd2193e30bdeffff737708d50fd7f0112
---

# Task 2 scoped source and evidence review

Inline gsd-code-review with SnapshotTesting/concurrency guidance, not an independent
session or whole-phase sign-off. Reviewed FullContentHost.swift, RenderServerCapture.swift,
PublicVisualFixtures.swift, FullContentFeasibilityTests.swift, RenderServerCaptureTests.swift
and VisualTracerTests.swift. Read-only HomeView, GalleryCardCell and GalleryViewport
inspection confirms the remaining height-dependent layout contract. Root changes docs only.

## Resolved — Previously failed capture parity

aefc47df samples viewport bytes until a continuous identical run spans 500 ms, bounded
by 40 samples with cancellation/failure. This addresses measured render settling rather
than using layout stability as a rendering guarantee. Replicant reads stay below the
silent-black 8192-pixel case, at most 8191 native pixels per dimension. Device-derived
height/width controls replace phone-only hard-coded renderer fixtures. Strict full-band
seam comparison and canonical byte composition remain intact.

The native full-screen non-key companion mirrors the measured status-bar state, checks
that state during convergence, and is removed during native restoration, deferred cleanup
and dismiss. It preserves Reader status-bar/safe-area/soft-edge behavior when the key
window becomes tall. Main-actor UIKit ownership remains explicit; no suppressions added.

723a117f preserves public eight-page 8:11 semantics while exporting at rendered pixel
width. Per-coordinate fresh paths and measured artwork-width assertions establish 1:1
rendering. The default export asset aggregate remains unchanged; generator provenance
changes and is recorded separately. Original viewport/full/slice/census evidence remains.

All four phone portrait/large shapes and all eight tablet portrait coordinates pass in
the supplied matrices, including Reader and Downloads that previously failed. These
resolve the old observed failures on those coordinates, not every possible runtime/device.

## BLOCKER — Phone AX5 Home changes its intended container-based layout

The AX5 viewport/full crop differs at 706625 pixels (max channel delta 255). Home observes
its own container size and feeds GalleryViewport.maximumSlideshowHeight; GalleryCardCell
selects title lines with ViewThatFits against that ceiling. A tall capture increases the
ceiling and changes line wrapping, shifting following content. This is not unresolved
glass rasterization and not an app defect established by the capture. The harness must
preserve the native logical viewport to retain the approved acceptance.

The handoff records owner options: exclude AX5 full-content Home, use scene size, or add
an injectable viewport defaulting to native container behavior. No option is selected.
Production adaptation exceeds current Task 2 ownership; exclusion changes acceptance.
Obtain owner direction before either change. Preserve existing native navigation/search
and container/window adaptivity instead of silently substituting a different size source.

## BLOCKER — iPad landscape scene request is rejected before capture

The actual scene returns UISceneErrorDomain 101 after eight portrait passes. All landscape
coordinates remain unverified (one failed request, seven pending). A scene-accepted native
rotation mechanism is required before exporting/capturing that orientation. Window resize
alone violates the measured scene-width premise and cannot establish a landscape pass.

## Verification and provenance boundaries

Current inspected bundles: phone native gate 2/2, tablet native gate 9/9; both zero
skips/Repetition. Each matrix has one actual failed test, zero skips/Repetition; combined
coordinates 12 captured, 2 failed, 18 pending. The handoff's earlier phone 12/12 report
has separate surviving attachments; the current same-named bundle has only two cases.
Do not present it as a twelve-test gate. VisualTracerTests.testHomeFullContentTracer still
asserts phone idiom; tablet Home proof comes from matrix captures, not that test.

Earlier matrix/default-export manifests name generator source hash 26da899c...feb3a5,
while current source and current phone Reader attachment name 5c7e4901...95b25.
The inspected asset hashes are valid. Those earlier matrices are informational evidence,
not a frozen current-source full matrix. Incremental builds have zero diagnostics; a new
final-source clean/full-matrix gate remains required before Task 2 completion.

Tablet AX5 exact census now validates its four portrait shapes, including twelve Comments
and eight Reader pages. Phone AX5 and all landscape OCR/geometry remain pending. Expected
direct-render refusal belongs to the tablet renderer pin; current phone two-test run has
no pin. IOSurface messages remain in logs and coexist with passing captures. No baseline,
SUMMARY, production patch or acceptance waiver is introduced by this review.
