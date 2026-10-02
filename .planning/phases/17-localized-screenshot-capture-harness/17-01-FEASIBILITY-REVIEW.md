---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-03
depth: standard
execution: inline-orchestrator
scope: task-2-recovery-cycle-2
status: blocked
files_reviewed: 4
---

# Task 2 WIP code review

Inline scoped review under gsd-code-review and Swift concurrency guidance. This is not
an independent reviewer session or whole-phase sign-off. Reviewed FullContentHost.swift,
PublicVisualFixtures.swift, FullContentFeasibilityTests.swift and VisualTracerTests.swift,
including the pinned library's controller/frame/appearance cleanup code and actual results.
The earlier Task 1 review remains historical and does not certify these changed files.

## BLOCKER — Actual Comments capture has not passed

The actual matrix and both native UIViewController/SwiftUI hierarchy probes produce
black Comments images with render-server errors at 1260 x 8394 pixels. The default layer
probe draws the twelve rows but strict native viewport comparison remains false. The
three authorized recovery-cycle-2 runs each retained Home 3/3 and failed Comments; the
current direct SwiftUI wrapper also logs an appearance imbalance. Do not expand the
matrix, promote baselines or complete Task 2. See `17-01-FEASIBILITY-GATE.md`.

The comparison now explicitly converts both inputs to the same 8-bit premultiplied sRGB
format already used by the library's strict comparator, preserving dimensions/scale and
raw candidates. It writes a truthful matched:false result and caught error type before
XCTFail reports the failed gate. No threshold/error/lint suppression is introduced.
Reporting the actual capture failure does not establish the source of the historical
secondary InvalidTransition error; no framework fix is claimed.

## Resolved warning — diagnostic time zone

The current testCommentsNativeLibraryStrategy pins global and SwiftUI time zone to UTC,
restores global state at test exit and retains fixed Date/locale/IDs/animations. The previous
unfrozen-time-zone warning is resolved. This does not resolve native render feasibility.

## Pending owner decision

Separating native device scale from explicit output scale and probing 1x is a proposed
capture-resolution revision. It is not implemented or approved. Keep actual native
viewport measurement honest and strict configured-scale comparisons if approved; do not
present lower output resolution as an unchanged 3x gate.

## Review boundaries

The exporter validates requested fixture/asset/route identity before writing and rejects
nonempty destinations. Both successful materializations match byte hashes. Paths in
manifests are fixed repository-relative values; source provenance matches the current source.
Native scene orientation is requested and measured; Dynamic Type traits/readiness are
configured explicitly. Matrix outcome accounting retains failed/pending coordinates and
halts on the first error. Home extraction retains three passing actual tests. None of
these partial successes resolve the blocker or the unstarted tablet matrix.
