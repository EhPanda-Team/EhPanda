---
status: checkpoint-equal-read-glass-seam
trigger: Phase 17-02 full tracer after equal viewport-sized read correction
created: 2026-10-05
updated: 2026-10-05
execution: inline
---

# Equal-sized reads disagree on a native glass edge

## Equal-read Liquid Glass seam checkpoint — 2026-10-05

The full tracer .capture/tracer-matrix-03 passed 43 coordinates, then failed at
home-populated__de__accessibility3__portrait__iphone__dark. This is one actual
failed invocation, not a repeated probe. Its saved capture-error.json identifies
RenderServerCaptureError.seamMismatch(sliceIndex: 2). XCTest reports a subsequent
InvalidTransition idle -> failed(deinit) during failure unwind. That diagnostic is
absent from all preceding passing invocations; no teardown change is inferred.

Both raw reads are 420 x 912 pt at 3x, with origins y=1440 and 2160 pt (4320 and
6480 px, both on the 16-pixel grid). The seam is (0,2224,420,64) pt and stays 64 pt
inside the upper bottom and lower top edges. The actual output is 1260 x 7421 px
(420 x 2473.6666666666665 pt). The lower read ends at 3072 pt and extends 1795 px
past the content bottom; the upper read is fully in bounds.

Exactly one of 241,920 seam pixels differs: window pixel (918,6743), RGBA
(5,5,5,255) in read 2 versus (6,6,6,255) in read 3. Visual inspection locates it
on the top-right edge of the Beliebt card in Sonstiges, rendered by MiscGridItem's
`.glassEffect(.clear.tint(.init(.systemGray6)), in: .rect(cornerRadius: 15))`.
This is outside fixture artwork. The full 576-pixel shared region has three
one-level differences; the other two are outside the protected seam, closer to
the upper read's bottom. The glass edge's difference is established; its cause is
not isolated. Equal size and 16-pixel alignment are therefore insufficient for
all currently requested content, despite passing the previous compatibility set.

The sibling German AX3 light and all 24 English phone portrait combinations pass.
Viewport freeze equality passes in the failed coordinate. Composition throws before
full-content parity, census and source-artwork verification, so those later checks
are not claimed for it. The original raw reads and every failed attachment remain.
Evidence: /tmp/ehpanda-phase17-equal-read-seam/ (57 byte-identical copied files,
difference.json, full-overlap-difference.json, A/B/diff crops and research-prompt.txt).
The prompt describes the unresolved cause without prescribing a research method.

Independent partial audit: 43 captured / one executed failure / 532 unexecuted;
all 576 requested outcomes are present (the runner reports 533 failed placeholders,
including the unexecuted coordinates). Native totals are 55 passed / one failed
across 56 invocations, with no skips, repetitions or runtime warnings. The successful
captures contain 258 exact artwork images (27,147,325 compared pixels) and 108
validated reads. All 795 native hashes, producer hashes, pin and fixtures remain
unchanged; references and original simulator states are preserved. No process was
interrupted and no native job remains. Audit: .capture/tracer-matrix-03/
partial-equal-read-audit.json.

The implementation remains WIP and the 32-coordinate compatibility pass remains
valid, but Task 2 / full tracer acceptance, SUMMARY and baseline approval are not
complete. No tolerance, seam exclusion, geometry retry or further layout change
is adopted. The next step is research on this preserved equal-read glass mismatch.
