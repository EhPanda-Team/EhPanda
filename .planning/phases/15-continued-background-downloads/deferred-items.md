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

## `testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving` had a one-second deadline — RESOLVED

**Resolved by 15-64 and owned since 15-74.** 15-64 removed the explicit one-second arguments from
five call sites and raised `waitForTaskValue`'s default to ten seconds; 15-74 declined IN-01's
request to restore a one-second bound at this case and its sibling detector, and wrote the
derivation — this record included — into the call site itself, so the ten-second bound is now a
decision with an owner rather than an inherited default. The historical report follows.

`DownloadDeleteConvergenceTests.testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving` waited on
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

## `DownloadsReducer.toggleDownloadPauseDone(.failure)` is silent with no report surface

Found during plan 15-73's two-reducer sweep. The downloads list offers Pause/Resume from a swipe
action and a context menu (`DownloadsView.swift:121-135`, `194-207`), both gated by the rendered
snapshot's `canTogglePause`, so the boundary refuses exactly as it does in the inspector —
`.notFound` for a vanished record, `.unknown` for a status that left the toggleable set. The list's
`toggleDownloadPauseDone` returns `.none` on both arms, so a refused toggle moves nothing and says
nothing: the same shape WR-05 names, seen from the list.

Not fixed here: plan 15-73 states "DownloadsReducer: no behavior change", and closing it is not a
branch fix — `DownloadsReducer.State` owns no toast surface (`alert` is `AppAlertState<Alert>`,
presented through `.appAlert`, which renders the `.alert` style; the toast factories are constrained
to `Action == Never` and render through a different modifier). It needs a new `@Presents` toast
value, an action case, an `.ifLet`, and a view modifier in `DownloadsView` — a presentation
addition, outside this plan's files. The disposition is stated in the reducer's type doc so it reads
as an open item rather than a considered no-report.

## `fetchDownloads` / `fetchFolders` throw into an effect with no `catch:`

Also found during the same sweep, and outside its scope (neither action is result-carrying).
`DownloadsReducer.swift:251-255` and `288-292` both `try await` inside `.run { }` with no `catch:`
arm. A throw there is reported by TCA as a runtime issue rather than handled, and on the
`fetchDownloads` path `state.loadingState` was set to `.loading` immediately before, so a throwing
fetch leaves the list spinning with no error state and no retry. Gap 4's contract covers actions
that carry a `Result`; these carry none, which is precisely why the failure has nowhere to go.

## `AppPackage/Package.swift` exceeds the 1000-line `file_length` ERROR limit

Found during plan 15-75, which removed one line from it (1129 -> 1128). SwiftLint invoked directly
over the file reports `File Length Violation: File should contain 1000 lines or less: currently
contains 1128 (file_length)`, at ERROR severity, and `.swiftlint.yml` carries no `excluded:` entry
that would exempt it.

Nothing catches this today: the SwiftLint build plugin runs per target over that target's *sources*,
and `Package.swift` is the manifest rather than a member of any target, so the warning-free
app-scheme build gate structurally cannot see it. This is pre-existing and unrelated to 15-75's key
move, so it was not fixed under the scope boundary — and it is not a branch fix either. Bringing the
manifest under the limit means splitting the target list across files (`swift-tools-version: 6.3.1`
allows manifest helper files under `Sources/<Package>/`), which is a package-layout change.
