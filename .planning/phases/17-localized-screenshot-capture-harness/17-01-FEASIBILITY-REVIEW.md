---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-04
depth: standard
execution: inline-orchestrator
scope: task-2-observation-delivery
status: observation-passed-composite-height-budget-blocked
files_reviewed: 5
source_head: 5d618fa0908a8ab5187784df9967932ea8a2729b
---

# Task 2 observation delivery review

Inline gsd-code-review using the existing SwiftUI, observable-model and testing guidance;
not an independent review session or whole-phase sign-off. Changed source scope:
AppComponents/GalleryViewport.swift, VisualSnapshotSupport/FullContentHost.swift,
FullContentFeasibilityTests.swift, VisualTracerTests.swift and VisibleViewportTests.swift.

## Source contract

VisibleViewportSampling is a public MainActor observable reference with false initial state.
The optional environment entry defaults to nil, preserving normal production sampling.
The modifier observes the reference's Boolean property; forwarding, suppression and thaw
logic are unchanged. Home/GalleryList callers and unrelated geometry readers are unchanged.

The host's generic initializer accepts the object, its optional environment key and a
ReferenceWritableKeyPath to the Boolean. The stable wrapper installs the same reference
before first render and never reads the Boolean. Its body therefore does not subscribe to
the freeze signal. A stored setter closes over the object/key path for type erasure;
all mutation remains inside the MainActor host. The private observable box and Boolean
environment updates are removed. The support library gains no AppComponents dependency.

All four call sites create fresh sampling objects. Tests install the object in the hosting
root once and mutate its property; independent raw geometry proves layout changes while
the frozen callback output remains unchanged. Initial freezing, thaw emission and duplicate
prevention remain covered. There is no hierarchy priming or production toolbar change.

## Verification and open capacity boundary

`/tmp/ehpanda-phase17-observation-gate-01/` contains clean/UI builds with zero diagnostics,
15/15 phone native tests, rotation/cleanup 1/1 each, zero skips/Repetition and identical
source hashes. Five matrix coordinates pass again. AX5 Comments native/frozen decoded RGBA
images are now exactly identical; the prior 2648-pixel glyph failure is resolved at this step.

The next guard rejects a requested 35820-pixel composite height against the approved 32768
limit. The rejected extent is 11940 points at 3x. One 1260×35820 RGBA buffer is 172.1695 MiB;
this is not peak memory and not proof of final convergence. No long image, growth parity,
census or memory measurement exists for that coordinate yet. The existing cap is preserved.

No source defect was established in the observation change. The unresolved issue is reconciling
the required full-content extent with the explicit composite budget. Matrix coverage is
5 captured / 1 failed / 26 pending, with no current iPad/landscape result. Task 2 remains open.
