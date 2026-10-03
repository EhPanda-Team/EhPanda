---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-04
depth: standard
execution: inline-orchestrator
scope: task-2-viewport-pin-and-external-rotation
status: viewport-pin-equivalence-failed
files_reviewed: 7
source_head: 76ca3010f03d7b662524eef1b2614852c05e29a7
---

# Task 2 scoped source and evidence review

Inline gsd-code-review with SwiftUI, observable-model and SnapshotTesting guidance;
this is not an independent review session or whole-phase sign-off. Reviewed
AppComponents/GalleryViewport.swift, HomeFeature/HomeView.swift,
VisualSnapshotSupport/FullContentHost.swift, FullContentFeasibilityTests.swift,
VisualTracerTests.swift, VisualCaptureOrientationUITests.swift and
Scripts/verify-full-content-capture.py. The earlier render-slice and reader-export
implementation remains unchanged from 3b4e460722 / 8e2122c92b.

## Adopted viewport contract

The optional environment entry defaults to nil. Home uses its measured ScrollView size
unless the entry is supplied; horizontal size class, navigation, search, scroll-edge
policy and card selection rules are unchanged. Windowed production layouts keep their
container-based semantics.

The host owns one MainActor observable box and applies it through a stable SwiftUI
wrapper. Native test entry points pass the app's environment key path, keeping the support
library independent of the app graph. A direct AppComponents dependency caused Xcode to
promote shared modules to dynamic frameworks without string-symbol generation. Explicit
symbol generation and static support linkage did not repair that graph; those experiments
are reverted. The retained implementation changes no package linkage or resource source.

Each capture settles an unpinned reference, measures the selected native UIScrollView's
bounds, applies the pin, waits for layout and settles again before any growth. Both native
images are retained and canonical 8-bit sRGB RGBA bytes must match exactly. A mismatch
writes explicit evidence and throws. Full-content parity still compares against the
original unpinned image. The pin remains held throughout convergence, slicing and census,
and is cleared in successful restoration, deferred failure cleanup and dismissal.

No coordinate is excluded. The same pin contract applies to all 32 full-content captures,
including phone AX5 Home. Rendering, seam equality, census, artwork completeness, reader
non-resampling, status-bar and restored-geometry assertions remain strict.

## Native orientation and runner contract

Two matrix methods each exercise eight coordinates per device family. They require actual
scene orientation and bounds; no in-process orientation request or pretend landscape
window size remains. The two native UI tests rotate XCUIDevice without launching the app.
The runner serializes portrait rotation, native gates, portrait capture, landscape rotation
and landscape capture, then restores portrait in a finally block, including failures.

Generated xctestrun copies omit Xcode's TestRepetitionPolicy. Source plans and built test
binaries remain intact. Exact expected test counts, device identity, zero failures/skips/
repetitions and compiler/lint diagnostics are checked. Fresh result directories retain
commands, exit codes, summaries, trees and extracted directory attachments. Matrix outcome
keys must match all eight requested coordinates, with pin/native parity and acceptance
artifacts present. Tracked app/test resources and code plus the runner are hashed before
building and checked before subsequent work and final acceptance. Cleanup still runs if
that source guard fires.

## Verification and open finding

Final-source evidence is `/tmp/ehpanda-phase17-viewport-gate-03/`: clean and UI-test builds
pass with zero diagnostics, phone native tests pass 12/12, portrait rotation and cleanup
pass 1/1 each, and all trees have zero skips/Repetition. Source hashes remain unchanged.

**Blocking finding:** the owner-specified UIScrollView bounds pin does not preserve native
phone AX5 Home rendering. Its 420 x 912 pt input changes 706625 viewport pixels before any
window growth; the title expands from two truncated lines to three lines, increasing the
card height. The new guard correctly stops here. Home's private SwiftUI measurement has
not been instrumented, so the exact measurement discrepancy is still unproven. The approved
input protocol must be reconciled before changing that measurement or resuming the matrix.

Current matrix coverage is 4 captured / 1 failed / 27 pending. New-code landscape and iPad
captures are unexecuted. Earlier 12/32 captures remain historical. Task 2 is incomplete;
no SUMMARY, baseline approval, coverage exception or later-plan completion is implied.

The failed test suite finished before its matching post-test simctl diagnostic collector
was terminated to let Xcode finalize the xcresult and perform portrait cleanup. Optional
simulator diagnostics may be incomplete; the original test failure and artifacts remain.
