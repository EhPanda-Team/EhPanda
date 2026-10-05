---
phase: 17-localized-screenshot-capture-harness
plan: "02"
reviewed: 2026-10-04
execution: inline-orchestrator
scope: task-1-matrix-producer-and-localized-ocr
status: passed
source_head: 624fddfed6
---

# Task 1 matrix producer review

Inline gsd-code-review using snapshot-testing, testing, custom-dump and dependency
guidance; not an independent or whole-phase review. Scope: the nine implementation
files committed in 624fddfed6, plus the Task 2 contract additions. Full 576-coordinate
acceptance remains in progress and is not claimed by this source review.

The catalog enumerates explicit locale/size/orientation/family/theme coordinates and
keeps scenario identity independently of pixels or shared fixture payloads. Filters
must be nonempty and match requested rows; reduced runs cannot report complete coverage.
Each requested row has a terminal failed placeholder before dispatch and retains its
reason on interruption. Named attachments, test counts, configuration identity, native
PNG dimensions, size classes, strict viewport parity and exact-once census are checked.
Candidate captures write to run-local outputs; comparison uses record:.never against
separate references. Reference fingerprints are checked before and after a run.

The real rendering-pin validator runs before fixture loading and dispatch. Fixture
assets, aggregate digest, generator source and route IDs are validated; source/catalog
and all tracked native source hashes span preflight and dispatch. The final pin bytes
and validated fixture manifest must equal their original inputs. Output roots cannot
overlap source catalog, fixtures, pin or references; artifact paths cannot escape.
Native execution is serial, uses one selected test, prohibits repetition and rejects
zero tests, warnings, skips and failures. Existing simulator lifecycle/rotation code
preserves boot state, content size and appearance and restores portrait.

Two findings were reproduced and fixed before GREEN: an empty filter previously selected
all rows, and the last-capture boundary could miss pin/valid-fixture/native-source
replacement. Explicit negative tests fail on the former implementation and pass on the
fix. The current Python suite passes 55 tests, including Task 2 identity/order coverage.
No open source-review finding remains in this scope.

The owner's A–D amendment separates English fixture evidence (confidence >=0.8) from
native-language exact heading evidence (no confidence floor), sharing recognition for
English. The same windows/interior/location rules apply, passes merge independently,
and raw diagnostics retain pass/label/confidence/frame/window. Trailing label presence,
bounds and required content height remain mandatory. All six labels, CJK omission and
duplicate sensitivity, pass isolation and bounds/height guards pass in 15 focused
native tests on each device. The current 32-coordinate compatibility gate passes 74
native tests with source hashes intact, restored states and every previous census count
unchanged. Its independent audit verifies raw pass attribution and occurrence indices.

Actual integration is additionally verified by all six Home locales at phone portrait
Large/light: 6/576 reduced coverage, 18 native invocations including preflight/rotation,
unchanged references and pinned input digests. Evidence is
`.capture/tracer-localized-passes-01/independent-audit.json` and
`/tmp/ehpanda-phase17-localized-passes-gate-01/localized-passes-audit.json`.
Task 2's first full matrix stopped before capture on simctl capitalization; all requested
outcomes and restoration evidence are retained. The observed 24-case spelling table
supports a case-insensitive category comparison without accepting a different category
or failed command. Three added tests reproduce the failure and protect rejection paths;
58 Python tests now pass. A fresh full matrix runs in `.capture/tracer-matrix-02/`;
Task 2 acceptance remains pending. The fresh run subsequently passed the first light
coordinate and failed dark xSmall strict parity. Two diagnostic invocations isolate
a stable read-rectangle-height dependency: the native-height crop matches exactly,
while taller reads differ at one pixel by one red-channel level. Temporary Swift
changes are fully restored; no source fix or relaxed comparison is claimed. See the
current checkpoint in 17-02-INTEGRATION-NOTES.md.

## Task 2 native read-geometry review (verification in progress)

The correction separates output ownership, raw read rectangles and seam comparison
rectangles. Read 0 retains the original viewport geometry and owns every native row;
later ownership partitions the remaining pixel rows without overwriting native edge
pixels. Integer device-pixel planning keeps later origins on the measured 16-pixel
grid and each 64-point comparison band at least 64 points inside both raw reads.
Strict canonical-byte seam comparison occurs before copying a read's owned rows.
Raw failure diagnostics retain both reads and all three rectangles; success retains
only geometry and shared canonical bytes. The allocation-area budget is unchanged
and checked before read/composite allocation. Width rejection still precedes viewport
validation. No tolerance, pixel exclusion or fallback was added.

The three new geometry tests reached RED on the missing API and now pass with the
four existing device tests: 7/7 on iPhone and iPad, zero diagnostics/skips/repetitions
or runtime warnings. Strict SwiftLint is zero; Python contracts remain 58/58.
Evidence: `/tmp/ehpanda-phase17-read-plan-green-01/`. No source-review finding was
identified in this scope. Platform fidelity across content is not proven by geometry
tests: the actual dark/light xSmall pair, the 32-coordinate compatibility gate and
the full 576 tracer matrix remain the acceptance sequence.

The first compatibility gate exposed a stale test assumption, not a capture failure:
iPad Comments and Downloads expected one read below the server ceiling. The native-first
contract requires at least two whenever content exceeds the viewport. The feasibility
helper now asserts that rule from evidence and no longer reads scene/screen state.
This is a required contract update; strict capture comparisons remain unchanged.
Gate 01 retains the original failures and all 16 successful phone coordinates; gate
02 revalidates the final test source.

Gate 02 confirms the updated helper passes on iPad and the native suites pass 34/31.
It then exposes a fidelity limit at iPad portrait AX5 Downloads: 120 seam pixels differ
by one despite satisfying all planned geometry invariants. This is an open capture
correctness finding, not a passed whole-Task-2 review. The original dark xSmall result
is verified, but compatibility stands at 22 captured / one failure / nine unexecuted.
See `debug/ipad-ax5-downloads-seam.md`; no acceptance relaxation is approved or applied.

## Coordinate artwork / half-pixel extent checkpoint — 2026-10-05

The supplied seam-artwork research exactly reproduces the 120-pixel iPad Downloads
failure and demonstrates stable 1:1 artwork at 2x. The orchestrator adopted A in the
fixture/test scope. PublicVisualFixtures v3 accepts per-image integral pixel sizes;
FixtureArtwork uses production cover roles and the headline metric. Both actual
capture consumers export per coordinate and compare source PNG dimensions with
pixel-derived artwork frames. Canonical inputs remain validated; derivative exports
retain their own manifest, source aggregate and sizing/measurement records. The
Reader guard now checks both dimensions. No production view or strict seam rule changed.

RED: `/tmp/ehpanda-phase17-artwork-red-01/`, missing export API.
Focused GREEN: `/tmp/ehpanda-phase17-artwork-green-01/`, seven actual passes: three
export/metric tests on each family plus iPad portrait AX5 Downloads. All twelve
categories match SwiftUI GalleryCoverMetrics. Downloads remains 834 x 5196 pt with
three unchanged reads; sixteen covers measure exactly 218 x 300 px, census 16/16,
and native parity and seams pass. Zero build diagnostics or runtime warnings; source
hashes unchanged and devices restored. Independent record: artwork-audit.json.
Python contracts pass 30 + 28 = 58; strict no-cache SwiftLint passes changed Swift files.

Compatibility: `/tmp/ehpanda-phase17-artwork-gate-01/` stops at iPhone portrait AX5
Home. Phone native tests pass 37/37; the Large portrait invocation passes all four
coordinates. The AX5 invocation produces all four images but fails two new size
assertions on Home. Gate-accepted matrix rows are therefore 4/32; independent artifact
inspection finds seven of the eight produced coordinates pass all checks, one fails,
and twenty-four remain unexecuted. Native totals: 41 passed / one failed / no skips,
repetitions or runtime warnings. Both builds have zero diagnostics; sources unchanged.
Phone restored portrait/Large/Shutdown; this compatibility run never used the iPad.
No diagnostic process was interrupted and no native job remains.

Home's compact role is 81.818181... x 112.5 pt at AX5. At 3x the nominal height is
337.5 px; all three sources are rounded to 245 x 338 px. Measured frames:

| Item | Pixel origin | Exported size | Measured size |
|---|---|---|---|
| VH4 | 60,4179 | 245 x 338 | 245 x 337 |
| VH5 | 60,5070 | 245 x 338 | 245 x 338 |
| VH6 | 60,5962 | 245 x 338 | 245 x 337 |

Strict native/frozen/full viewport parity, seams and census still pass for this Home
capture (1260 x 7986 px). Direct center-column inspection finds sharp colored-to-white
edges without an extra faint row. An offline source-versus-capture interior comparison
(excluding a 20 px border for diagnosis only) finds VH5 exact across 61,090 pixels;
VH4/VH6 differ at 1,461/1,545 of 60,885 pixels, max channel delta 134. A one-row source
shift is not exact either. This is more than a flood-fill bounding-box discrepancy;
rounding the common role size does not preserve source pixels at every row position.
The internal rasterization mechanism and correct export contract remain unresolved.
No capture acceptance exclusion or tolerance was added.

Short evidence: `/tmp/ehpanda-phase17-artwork-rounding/`, including original capture,
fixtures, edge-analysis.json, source-interior-comparison.json and research-prompt.txt.
The full run's partial-artwork-audit.json distinguishes produced images from accepted
coordinates. The original 2x research has not established the 3x half-height case.
B (all reads native viewport height) was separately presented to the owner and has no
answer yet; it remains unapplied. Task 2 and the full 576 matrix remain incomplete.

Canonical v3 output is `.capture/regression-v3` (47 assets plus manifest), copied
byte-for-byte from the successful phone native export attachment. Its aggregate is
`a0a579a9633aca7fbdf10bd034e10c559b63f595d58cdd83655cd1bf15ab127a`; unchanged default
asset bytes do not imply unchanged version or generator. Generator SHA-256 is
`2013618b4ba572eeb1d9d5b2fa1960d1caa4c9e85b55ec1f2b09e68272065e09`. The prior v2
`.capture/regression` is preserved. No baseline promotion or Task 2 source commit.

## Pixel-integral cover sizing / continuous-clip checkpoint — 2026-10-05

The orchestrator adopted the supplied cover-snapping A/B correction (scope recorded
in 17-02-PLAN.md). GalleryCoverStyle now rounds height then width at the environment
display scale, including maximum-height clamps; production metrics and fixture exports
share this function. Height changes by at most 0.5 px, while width derived from that
rounded height can differ from its nominal value by more than 0.5 but less than 1 px.
No separate per-instance export or origin adjustment was introduced.

RED build evidence is `/tmp/ehpanda-phase17-cover-snap-red-01/` (missing sizing API)
and `/tmp/ehpanda-phase17-cover-content-red-01/` (missing pixel comparison API).
The final-source build and six artwork tests pass on iPhone in
`/tmp/ehpanda-phase17-cover-snap-green-01/`; all six pass on iPad in
`/tmp/ehpanda-phase17-cover-snap-tablet-01/`. They cover all twelve categories at 2x/3x,
all roles and height clamps, SwiftUI metric equivalence, one-byte corruption and
same-dimension content shifts. Existing GalleryCoverLayoutTests pass five declarations
per family in `/tmp/ehpanda-phase17-cover-layout-tests-01/`, including parameterized
card/title/height cases. Native acceptance is 22 passed / one failed, with no skips,
expected failures, repetitions or runtime warnings. Build and lint diagnostics are
empty; Python contracts pass 58/58. All 795 source hashes remain unchanged during
these native runs; both simulator categories and boot states are restored.

The actual iPhone portrait AX5 Home capture fixes the old extent failure: compact
VH4/VH5/VH6 each export and measure 246 x 338 px at pixel origins (60,4180),
(60,5072), (60,5964). Hero is 409 x 563; both standard covers are 327 x 450.
Native/frozen/full viewport parity, strict seams and six exact-once census counts
pass; output is 1260 x 7988 px in two reads. The capture nevertheless remains failed:
the new byte-exact source-content check reports 60/62/62/56/56/56 differing pixels
after excluding the proposed four 15-pixel corner squares. Every first difference
is local pixel (15,0), with maximum channel difference 27 or 28.

GalleryCover's `.rect(cornerRadius: 5)` defaults to `.continuous`, confirmed in the
installed iOS 27 SwiftUICore interface. Offline comparison finds all differences
inside four 23-pixel corner squares (22 for compact); every remaining pixel is exact.
This is diagnostic evidence that the assumed mask extent is insufficient, not a
validated exclusion rule or evidence of an origin-tie shift. The test still fails
under the adopted 15-pixel rule. The correct fully-inside-clip comparison contract
needs reconciliation before another actual capture or the compatibility set.

Evidence: `/tmp/ehpanda-phase17-cover-snap-corners/`, including original capture and
fixtures, artwork-verification.json, corner-analysis.json, independent-audit.json
and research-prompt.txt. Its 61 copied files match the final xcresult attachment.
The failed test log also reports InvalidTransition idle -> failed(deinit) during
host dismissal; its cause is not diagnosed. Only Xcode's post-test simctl diagnose
collector (PID 94357) was terminated after test completion; no test process was
interrupted. The original failed xcresult remains available.

The implementation remains uncommitted WIP. No full compatibility or 576-coordinate
run was started on this sizing change; Task 2, SUMMARY and baseline approval remain
incomplete. Native viewport and seam comparisons retain every pixel and zero
tolerance. The earlier constant-viewport-height read proposal remains unanswered
and unapplied; it is distinct from this checkpoint's artwork-content verification.

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

## Equal-size read-plan review — 2026-10-05

The latest orchestrator disposition adopts equal native-viewport read sizes after
an independent probe reproduces the exact four-pixel corner seam. The planner now
uses viewportRows for every raw read. A final read may extend beyond content, but
its owned frame ends exactly at the output height; the existing crop copies only
those rows. Read 0 ownership, 16-pixel origin alignment and strict interior-band
comparison are unchanged. The minimum-height guard reserves enough context for
read 1 to advance beyond the already-owned native viewport without a zero stride.

The focused RED fails on the previous short final-read contract. GREEN passes all
eight renderer tests on both devices and the real failing landscape Downloads
coordinate, including final overflow, eight reads and exact artwork/parity/census.
The allocation-boundary tests still pass and record footprint without asserting a
new limit. Python contracts pass 58/58 and strict no-cache lint is clean. No new
source-review finding was identified in this change. This is inline review; full
compatibility and the complete 576-coordinate tracer remain acceptance requirements.
Evidence: /tmp/ehpanda-phase17-viewport-reads-green-01/independent-audit.json.

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

The subsequent full tracer exposes one unresolved correctness finding: equal-sized
reads still differ by one grayscale level on a native Liquid Glass corner in
German phone portrait AX3 dark Home. Forty-three coordinates pass; one fails and
532 remain unexecuted. The 32-coordinate compatibility result remains valid, but
whole-Task-2 acceptance does not pass. No comparison relaxation is applied. See
17-02-INTEGRATION-NOTES.md and debug/equal-viewport-glass-seam.md for exact evidence.

## Same-rect verification implementation — 2026-10-05

The owner approved replacing cross-origin seam equality with two complete passes
of identical-rect digest comparison. The implementation keeps original read
geometry and strict downstream checks. It composes canonical bytes directly,
validates each read's dimensions and row ownership, hashes full reads including
unowned context and final overflow, and retains original failure samples on disk.
The former seamFrame/overlap diagnostics are now contextFrame/contextBandHeight;
no cross-origin equality is asserted. The precise authority and limitations are
recorded in 17-02-PLAN.md's same-rect approval.

Seven added native tests cover full pass order, every composed row, origin-dependent
but repeatable content, changes during the first/second pass, changes outside owned
rows, invalid dimensions and actual failure samples. The suite has 15 tests. Four
new Python tests plus the runner boundary check reject missing or false verification
evidence; all 62 Python tests pass after a recorded RED. Strict no-cache lint passes.
Native verification is running in /tmp/ehpanda-phase17-reread-green-01. Task 2 is
incomplete; no final-source compatibility or complete matrix result is claimed yet.

### Same-rect focused verification passed

/tmp/ehpanda-phase17-reread-green-01/independent-audit.json verifies 15/15 renderer
tests on each device, no skips/repetitions/runtime warnings/InvalidTransition,
unchanged native sources and restored simulator states. At the existing composite
budget, phone/tablet use 33/27 reads and take 3494.02/3479.53 ms for composition plus
the second pass. Measured process peaks are 463,031,080/473,779,008 bytes. These
budget tests use no diagnostic directory, so the measurements exclude first-pass
diagnostic disk writes. The allocation policy is unchanged.

The actual original failing coordinate passes in
.capture/tracer-reread-de-AX3-dark-01/independent-audit.json: German AX3 dark iPhone
portrait Home, output 420 x 2473.6667 pt, four reads with exact two-pass digests,
strict native/frozen parity, all six census counts and 761,315 checked artwork
pixels. The complete runner/preflight has 13/13 native passes; all source inputs
and references remain unchanged, states restore, and no InvalidTransition occurs.

The final-source 32-coordinate compatibility gate is now running at
/tmp/ehpanda-phase17-reread-gate-01. It expects 110 native tests across 17
invocations. The 576-coordinate tracer remains pending; Task 2 is not complete.

### Settlement correction GREEN; compatibility restarted

The first compatibility gate completed without interrupting its diagnostic collector:
47/49 phone native tests passed, two failed, no skips/repetitions/runtime warnings,
and the phone restored its original state. No matrix coordinates had executed.
Its failed-gate-audit.json preserves unchanged-source proof.

/tmp/ehpanda-phase17-reread-settle-green-01/independent-audit.json verifies the
corrected Comments and Home native cases plus the original German AX3 dark phone
portrait coordinate: 3/3 passes, strict native parity and final reread records,
unchanged sources, restored state and no InvalidTransition. This focused run had no
intra-sample transition; earlier failed samples remain the diagnostic RED. The final
capture path and its negative read-change tests are unchanged. The clean full gate
is now running at /tmp/ehpanda-phase17-reread-gate-02; no full-matrix pass is claimed.

## Final-source same-rect compatibility passed — 2026-10-05

/tmp/ehpanda-phase17-reread-gate-02/artwork-compatibility-audit.json verifies all
32 coordinates and 110/110 native tests across 17 invocations. All 359 planned
rects have matching full canonical SHA-256 values across two passes (718 actual
full-content reads). Ownership geometry partitions every output row. Native/frozen
viewport parity, all exact-once census counts and 240 source artwork images
(404,257,696 checked pixels) pass. Output sizes match the prior equal-read gate.
No skips, repetitions, compiler/lint diagnostics, runtime warnings or
InvalidTransition occur. Native source hashes remain unchanged and both simulators
restore their original content size, orientation and boot state. Four reserved
owner-staged entries remain byte-identical to the 11,977-byte saved patch.

The corrected bounded viewport settlement path is exercised: Downloads native
sample 3 and four matrix settlement samples record an intra-sample glass change,
reset the stable run and retain both actual samples in their own directories. Every
accepted reference subsequently satisfies the original 500 ms exact stability
requirement; every final full-content read pair matches. No final-capture recovery,
pixel tolerance, geometry search or cross-origin equality claim is introduced.

The full tracer is now running under the real immutable-pin runner at
.capture/tracer-matrix-04 with all 576 requested coordinates. This compatibility
pass does not complete 17-02 Task 2 or approve references; source implementation
remains WIP until complete tracer acceptance.
