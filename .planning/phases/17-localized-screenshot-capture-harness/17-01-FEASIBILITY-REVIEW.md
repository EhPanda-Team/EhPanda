---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-04
depth: standard
execution: inline-orchestrator
scope: task-2-native-viewport-freeze
status: viewport-freeze-toolbar-equivalence-failed
files_reviewed: 8
source_head: da93f8c7f13d79999f9a50df4fb28c665f8c7de7
---

# Task 2 native viewport freeze review

Inline gsd-code-review using SwiftUI, observable-model and testing guidance. This is an
orchestrator review, not an independent review session or whole-phase sign-off. Scope:
AppComponents/GalleryViewport.swift, HomeFeature/HomeView.swift,
GalleryListComponents/GalleryList.swift, VisualSnapshotSupport/FullContentHost.swift,
FullContentFeasibilityTests.swift, VisualTracerTests.swift, VisibleViewportTests.swift,
and Scripts/verify-full-content-capture.py.

## Contract and implementation

The Boolean environment entry defaults to false. Each modifier owns its latest measured
size and last forwarded size; native geometry events are forwarded unless frozen, and thaw
emits the latest value only if it differs. Home and GalleryList use this at their original
measurement sites. No harness size, scene-size approximation or safe-area formula remains.
Unrelated gesture/LiveText geometry observers are unchanged. Three hosted SwiftUI tests
observe actual layout and freeze propagation independently of the callback being tested.

The host uses the existing stable observable-backed root and Boolean key-path injection;
no new app dependency is linked into VisualSnapshotSupport. It waits a layout frame after
freezing and requires exact canonical RGBA equality before growth. Native/full parity still
uses the original reference. Shared restoration code returns the window/controller to the
original viewport and removes the status-bar companion before clearing the flag; successful
restoration also waits a frame before thaw. Deferred error cleanup and dismiss restore first.

The runner includes the new test file in source hashes and the three tests in exact expected
counts (phone 15, tablet 12). It checks the renamed freeze-parity evidence. External rotation,
serial execution, no retries, exact coordinate coverage and cleanup remain intact. Rendering,
seams, census, artwork, reader pixel size and composite budget are unchanged.

## Verification and blocking finding

Fresh clean and orientation builds pass with zero compiler/lint diagnostics. Phone native
15/15, portrait rotation 1/1 and cleanup 1/1 pass; zero skips/Repetition and unchanged source
hashes. The three new modifier behavior tests pass. Five matrix coordinates pass, including
AX5 Home with exact native/full parity and 6/6 census.

**Blocking:** AX5 Comments changes its compose glyph while still at native viewport size,
after the freeze environment transition. Its 2648 changed pixels occupy only a 76×76 pixel
region; the dark glyph support shrinks from 76×76 to 64×64, while the rest of the image is
identical. Comments has no sampling modifier or freeze-key read. Root cause is not established;
the failed inertness guard is retained. No source defect was established that can be corrected
without first explaining this native toolbar transition. No tolerances or coverage exceptions
were introduced.

Current coverage is 5 captured / 1 failed / 26 pending. iPad/landscape validation and Task 2
completion remain open. Full evidence and diagnostic-finalization limits are in
17-01-FEASIBILITY-GATE.md under `/tmp/ehpanda-phase17-viewport-freeze-gate-01/`.
