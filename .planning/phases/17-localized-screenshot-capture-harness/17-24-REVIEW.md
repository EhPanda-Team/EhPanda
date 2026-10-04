---
phase: 17-localized-screenshot-capture-harness
plan: "24"
reviewed: 2026-10-04
execution: inline-orchestrator
scope: environment-producer-and-pin
status: passed
source_head: af5db7dd
---

# Environment producer and pin review

Inline gsd-code-review with the snapshot-testing, testing and dependency guidance;
not an independent or whole-phase review. Reviewed the five plan-owned files.

The producer reuses the existing verified native test invocation and simulator lifecycle
implementation. GeometryTests runs in the real app host, checks attachment, orientation,
app/window category and scene/window size classes, requires stable geometry, and compares
the actual native pixel rectangle. It records observed font metrics and reference settings.
No device layout preset or reduced-window axis is introduced.

The tracked pin has a closed schema and excludes run-local IDs and paths. Destination lookup
requires an exact available runtime build and unique matching model. Validation measures
again, compares every pinned field, records the original input SHA-256 and never writes
the input. Missing/invalid pins fail before measurement. Output must be a new directory
separate from the pin. Named geometry attachments must belong to the requested test/device;
missing, repeated, unsettled or misattributed evidence is rejected.

The first real validation exposed a producer ordering bug: sorted JSON placed ipad before
iphone, while build setup ran only on the phone path. The failure was retained under
`/tmp/ehpanda-phase17-environment-pin-order-failed/`; the pin bytes and original simulator
state remained intact. A regression test reproduced the failure before the explicit
phone-first execution fix. Producer measurements were rerun and committed before retrying
Task 2. No pin values, dimensions or acceptance conditions were changed to pass.

Final evidence: `.capture/environment-measurement/` and `.capture/environment-pin-check/`.
Each has four successful geometry measurements and ten passing native test invocations,
with no failed/skipped/expected-failure tests, Repetition nodes or runtimeWarnings. Build
compiler/lint diagnostic files are empty. Both independent-audit.json files verify source
hashes, attribution, geometry and simulator restoration. Strict SwiftLint reports zero
violations for GeometryTests. All 28 Python contract tests pass, including every-leaf
comparison, immutable success/failure paths and sorted-pin execution ordering.

The pin SHA-256 stays
`ffd7689fcaf9a312202fdfbf9787f0198711fd477d1e72a2a013851df85a394a` across failed and successful
validation. Reference settings and all geometry match the independently repeated measurement.
No open finding remains in this plan. Regression/marketing dispatch and baseline acceptance
remain downstream work; this review does not claim those unimplemented behaviors.
