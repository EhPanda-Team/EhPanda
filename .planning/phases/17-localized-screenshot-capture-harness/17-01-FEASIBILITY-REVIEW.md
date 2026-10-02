---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-10-03
depth: standard
execution: inline-orchestrator
scope: task-2-work-in-progress
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

The matrix's native hierarchy output is black. The separate default layer probe displays
all twelve comments but fails before native viewport parity evidence is written, and the
run reports an appearance-transition imbalance. Independent saved-PNG comparison confirms
20,284 differing viewport pixels. The exact InvalidTransition source remains unknown.
Do not apply the default strategy to the matrix, relax comparison, promote baselines or
claim Task 2 complete. See `17-01-FEASIBILITY-GATE.md` for concrete reproduction and evidence.

## WARNING — Isolated Comments probe does not freeze time zone

`testCommentsDefaultLibraryStrategy` freezes Date and locale but leaves the global and
SwiftUI time zone inherited. Its date text differs from the UTC-pinned matrix. Before a
future accepted probe, apply the matrix's existing UTC setup/restoration and timeZone
environment. The current probe is diagnostic evidence only, not deterministic acceptance.

## Review boundaries

The exporter validates requested fixture/asset/route identity before writing and rejects
nonempty destinations. Both successful materializations match byte hashes. Paths in
manifests are fixed repository-relative values; source provenance matches the current source.
Native scene orientation is requested and measured; Dynamic Type traits/readiness are
configured explicitly. Matrix outcome accounting retains failed/pending coordinates and
halts on the first error. Home extraction retains three passing actual tests. None of
these partial successes resolve the blocker or the unstarted tablet matrix.
