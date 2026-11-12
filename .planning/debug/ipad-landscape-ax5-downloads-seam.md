---
status: resolved
trigger: Phase 17-02 compatibility after shared clip extent correction
created: 2026-10-05
updated: 2026-10-05
execution: inline
---

# iPad landscape AX5 Downloads corner seam

## Production clip correction / landscape seam checkpoint — 2026-10-05

The supplied corner-clip research corrects the exclusion's geometric basis. The
orchestrator adopted it in 17-02-PLAN.md: GalleryCover exposes its continuous shape
once, production uses it, and FixtureArtwork derives the curve extent from its
actual-size path. Source comparison excludes four squares of ceil(extent * scale),
measuring 16 px at 2x and 23 px at 3x. The measured 1.527 ratio is not a constant.
Native viewport and read-to-read seam comparisons still compare every pixel.

RED: /tmp/ehpanda-phase17-clip-extent-red-01/, missing extent API. Focused GREEN:
/tmp/ehpanda-phase17-clip-extent-green-01/, seven artwork tests per family and actual
phone portrait AX5 Home (15/15, zero skips/repetitions/runtime warnings). Tests pin
the production extent and reject an interior one-pixel shift. Home compares 761,315
pixels with zero differences; dimensions, parity, seams and census pass, and
InvalidTransition is absent. Sources remain unchanged and device states restore.
The independent-audit.json retains the checks. Python contracts pass 58/58 and
changed Swift files pass strict no-cache lint.

Full compatibility at /tmp/ehpanda-phase17-clip-extent-gate-01/ passes both builds,
41 phone / 38 tablet native tests, all 16 phone coordinates and eight iPad portrait
coordinates. Original iPad portrait AX5 Downloads passes: 834 x 5196 pt, three reads,
sixteen 218 x 300 px covers with exact source content outside the derived corners,
and exact seams. iPad landscape AX5 Home and Comments also capture, but Downloads
then fails seamMismatch(1). Its Reader and four iPad landscape Large coordinates
remain unexecuted. Gate-accepted coordinates are 24/32; independent artifact checks
confirm 26 successful captures, one failed coordinate and five unexecuted. Native
totals are 92 passed / one failed across 16 invocations, without skips, repetitions
or runtime warnings. All 186 checked artwork images match (273,497,908 pixels).
Successful census results match the previously verified gate. All 795 source hashes
remain unchanged; simulator states restore. No native job remains and no process
was interrupted. InvalidTransition is absent from all logs, including this failure.

The new seam failure is four single-channel, one-level differences on VD15's top
two continuous corners. At 2x the reads are (0,640,1210,4095) and (0,4536,1210,660)
pt; the seam is (0,4607,1210,64) pt. Both satisfy the 16-pixel origin grid and 64-pt
interior padding. Window pixels (87,9216), (290,9216), (80,9223), (297,9223) change
blue 175 -> 174, with RGBA otherwise (173,231,_,255). The actual VD15 lower-read
frame is (80,9216,218,300) px. Its 64,376 source pixels outside four 16-pixel corner
squares are exact in an offline comparison. Composition fails before the native
artwork check and OCR census. This is read-to-read clip rasterization, distinct
from the corrected source-content mask.

Short evidence and English research prompt: /tmp/ehpanda-phase17-ipad-landscape-seam/.
The original run retains partial-clip-extent-audit.json and all failed raw reads.
No seam exclusions, tolerance, read retry or constant-viewport-height read change
is adopted. That earlier read-plan proposal remains an unanswered owner decision.
Implementation remains WIP; the 576 tracer has not restarted, Task 2 / SUMMARY remain
incomplete, and no baseline is promoted.

## Equal native-viewport reads — 2026-10-05

The supplied corner-seam probe reproduces the four real VD15 differences with the
same read rectangles. Equal-sized reads agree, including a final viewport read
extending beyond the window. Earlier vector evidence also changes away from the
ceiling, so a smaller ceiling is not an adequate general correction. The orchestrator
explicitly adopts the previously pending B proposal in 17-02-PLAN.md. This supersedes
the pending-B status in earlier historical checkpoints.

Every read now retains the original native viewport size. Read 0 still owns the
whole native viewport; later origins remain on the 16-device-pixel grid, and seams
stay 64 pt inside both adjacent reads. Owned frames partition only the actual
content. The final read may extend below it, and composition crops those extra rows.
Strict seam and native parity comparisons retain every pixel with zero tolerance.

RED: /tmp/ehpanda-phase17-viewport-reads-red-01/ reproduces the old final-read plan's
failure against the new contract. Focused GREEN:
/tmp/ehpanda-phase17-viewport-reads-green-01/ passes 19/19 native tests across five
invocations: eight renderer tests per family, landscape rotation, real AX5 Downloads,
and portrait restoration. Geometry tests cover all four pinned viewports, nonzero
bounds origins, whole-row partition, interior seam context, final overflow and the
existing allocation budget. The native band test checks the actual final pixel.

The formerly failing iPad landscape AX5 Downloads now passes: viewport 1210 x 834 pt,
output 1210 x 5196 pt, eight equally sized reads. The final read is 4480..5314 pt,
owns only 4610..5196 pt, and compares seam 4546..4610 pt. All sixteen artwork images,
exact-once census, frozen/native/full parity and every seam pass. InvalidTransition
is absent. The independent-audit.json confirms source stability (795 hashes) and
restored simulator states. Python contracts pass 58/58; changed Swift files pass
strict no-cache lint. No test or diagnostic collector was interrupted.

At the unchanged composite area budget, the phone uses 33 reads for 89,652,780 pixels
in 1128.33 ms; the tablet uses 27 reads for 89,651,664 pixels in 1032.19 ms. Recorded
peak physical footprints are 452,856,664 and 467,290,920 bytes, respectively. The
post-composite footprints are 421,530,384 and 424,774,368 bytes; census reuse and PNG
encoding add no further full-size raster copy. Footprint is evidence, not a new
asserted acceptance limit. Exact measurements remain in the native attachments.

The complete compatibility gate is running at
/tmp/ehpanda-phase17-viewport-reads-gate-01/. Native sources stay unchanged during
that run. Full 32-coordinate acceptance and the 576-coordinate tracer are still
pending; Task 2 and baseline approval remain incomplete.

Compatibility completed: /tmp/ehpanda-phase17-viewport-reads-gate-01/ passes all
32 coordinates and 96/96 native tests across 17 invocations. The independent audit
confirms all 359 reads satisfy equal native sizes, pixel-grid origins, interior
seams and exact output ownership; all prior census results match. All 240 checked
artwork images match over 404,257,696 source pixels. Native/frozen/full parity and
strict all-pixel seams pass. Source hashes remain unchanged, simulator states
restore, and no diagnostics, runtime warnings, skips, repetitions or InvalidTransition
appear. The reserved owner-staged patch remains byte-identical (11977 bytes).

The full 576-coordinate tracer is now running in fresh .capture/tracer-matrix-03,
using canonical .capture/regression-v3 and the immutable tracked environment pin.
Command: `python3 -B Scripts/visual/run-regression.py --all --mode candidate --fixtures
.capture/regression-v3 --environment Scripts/visual/regression-environment.json
--output .capture/tracer-matrix-03`. Log: /tmp/ehpanda-phase17-tracer-matrix-03.log.
Task 2 and the 17-02 SUMMARY remain pending until that complete run is verified.
