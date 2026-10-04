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
Task 2's complete matrix is running separately in `.capture/tracer-matrix/`.
