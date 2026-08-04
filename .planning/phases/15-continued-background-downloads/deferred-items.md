# Deferred Items — Phase 15

Out-of-scope discoveries found while executing this phase. Logged, not fixed.

## ROADMAP.md progress table is missing a Phase 16 row

The `| Phase | Plans Complete | Status | Completed |` table in `.planning/ROADMAP.md` ends at
row 15. Phase 16 (Dynamic Type Accessibility) has a phase entry and a checklist bullet but no
progress row. Row 15 also carried Phase 16's name until plan 15-07 corrected it to
"Continued Background Downloads" — the row the plan's own tooling had to update.

## ROADMAP.md execution-order line stops at 15

`**Execution Order:** Phases execute in numeric order: 1 → … → 15` predates the Phase 16 entry
and should end at 16.

Both are documentation staleness in a file outside this phase's edit scope (the plan scopes
Task 2 to the Phase 15 detail section). Neither affects any code or gate.

## `testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving` has a one-second deadline

`DownloadDeleteConvergenceTests.testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving` waits on
its observer emission with `timeout: .seconds(1)`. It failed once during plan 15-21 — on the run
that immediately followed a full `DownloadClient` recompile, with that single case reporting 13.2
seconds of wall time under contention — and passed on the run before it and the run after it (three
green full-plan runs against one red). The same helpers file already records that one second "did
not survive CI, where the whole target's suites run in parallel and a task can sit unscheduled far
longer than the work itself takes", which is why the shared `waitUntil` uses ten seconds.

Not fixed here: the case is outside plan 15-21's scope, which is confined to new cases in
`DownloadContinuedSessionLedgerTests.swift`, and the plan forbids editing anything else in the
suite. The deadline is a fragility in the harness rather than in the product — nothing about the
delete-convergence contract it asserts is in question.

## Existing UI-test actor-isolation warnings

Building the targeted package tests with Xcode 26.6 reports two Swift concurrency warnings in
`EhPandaUITests/DeepLinkPadUITests.swift:9`: the nonisolated assertion autoclosure reads
`UIDevice.current.userInterfaceIdiom`. The file is outside Plan 15-10's session-identity scope,
and the warnings predate its changes.
