---
phase: 17-localized-screenshot-capture-harness
plan: "02"
reviewed: 2026-10-04
execution: inline-orchestrator
scope: task-1-matrix-producer-and-localized-ocr
status: passed
source_head: 7de15e6a
---

# Task 1 matrix producer review

Inline gsd-code-review using snapshot-testing, testing, custom-dump and dependency
guidance; not an independent or whole-phase review. Scope: the nine implementation
files committed in 7de15e6a, plus the Task 2 contract additions. Full 576-coordinate
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
