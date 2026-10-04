---
status: checkpoint-continuous-corner-seam
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
