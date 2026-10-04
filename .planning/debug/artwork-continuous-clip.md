---
status: checkpoint-artwork-clip-contract
trigger: Phase 17-02 source-content verification after integral cover sizing
created: 2026-10-05
updated: 2026-10-05
execution: inline
---

# Continuous cover clip and source-pixel verification

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
