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

## Force the inspector's Pause/Resume refusal through the existing UI-test seam

Surfaced closing UAT test 12. Both refusal arms of `togglePause`
(`DownloadClient+PublicAPI.swift:189-214`, `.notFound` and `.unknown`) are unreachable by hand on a
device: `canTogglePause` already excludes every status that triggers them, so the control is only
tappable during a render-versus-tap race, and the inspector's reload closes that race before a tap
can land. Two device attacks were tried and both failed (deleting the record underneath an open
inspector; letting a background repair complete while the UI was frozen on `.active`).

The seam to do it deterministically already exists and is already sanctioned in this repo:
`AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift` reads `EHPANDA_UITEST_*`
environment keys under `#if DEBUG` and installs overrides via `prepareDependencies`, and
`DownloadClient` is a struct of closures. One override would force either arm:

```swift
if let arm = trimmedValue(environment: environment, key: "EHPANDA_UITEST_FORCE_PAUSE_REFUSAL") {
    prepareDependencies { $0.downloadClient.togglePause = { _ in throw arm == "unknown" ? AppError.unknown : .notFound } }
}
```

Not done in phase 15: UAT test 12 closed by composition instead (both refusal arms pin their exact
caption in `DownloadInspectorPauseFailureTests.swift`, and BOTH toast styles are now device-observed
— `.success` "Image data is valid" and `.error` "Page 1 is missing." with its Warning icon), so the
only unobserved link is SwiftUI presenting a value type it already presents. Adding production code
during a phase close-out re-opens review for a residual risk that is a presentation identity. Worth
doing if a permanent device-visible regression guard is ever wanted.

## Replace the convergence detectors' wall-clock wait with a fence

Surfaced ratifying UAT test 13. The two missing-notification detectors
(`DownloadDeleteConvergenceTests.swift:127`, `DownloadOwnershipConvergenceTests.swift:94`) use
`waitForTaskValue(timeout:)`. The 10-second bound was ratified and stands: 1 second is refuted by
plan 15-21's recorded 13.2s wall time at this exact call site, and no middle value has a basis
because scheduler delay under a parallel suite is unbounded.

But the instrument is still wrong, for the reason the source comment itself states: wall time cannot
distinguish "the notification will never arrive" from "the parallel suite has not scheduled the
collector". Two structural facts make a clock unnecessary. `DownloadObserverHub.observe` builds the
stream with `AsyncStream.makeStream(of:)` — unbounded buffer — and registers the continuation before
returning (`DownloadClient+Manager.swift:760-786`); and `delete(gid:)` awaits `notifyObservers()` on
every exit path (`DownloadClient+PublicAPI.swift:236, 249, 256, 267`). So when `delete` returns, the
notification is either already buffered or will never come. That is a positive fact about state, and
it admits a fence rather than a deadline.

Preferred shape, which needs NO production change: `observerHub` is `public let` and `notify` is
public, so after `delete` returns the test pushes a distinct sentinel snapshot, and the collector
reads until it sees the sentinel and breaks. The assertion becomes about sequence, not time, and the
pre-fix bug fails immediately with a name. Do not rely on cancellation draining the buffer —
`AsyncStream`'s post-cancellation delivery is an implementation detail, not a documented contract.

## Delete the hand-typed localization key literals by forwarding to Xcode's generated symbols

Surfaced closing UAT test 14, which asked a narrower question (should eight download error-message
strings be value-pinned?). The reframing: `ResourceStringSymbols.swift` hand-types the key literal in
all 43 accessors, the compiler never checks those literals against the `.xcstrings` catalogs, and a
renamed, mistyped, or deleted key still compiles and renders the raw key name into user-facing UI.
Behavioural tests cannot catch it — state and logic stay correct, only rendering degrades. The eight
download keys are a quarter of the exposure, and are only the part phase 15 happened to touch.

`STRING_CATALOG_GENERATE_SYMBOLS = YES` is already set (`EhPanda.xcodeproj/project.pbxproj:563, 624`)
and Xcode already generates internal symbols for the Resources module's catalogs, names matching the
hand-written ones 1:1, with semantic labels already generated for `%#@name@` substitution keys. The
hand-written layer cannot simply be deleted because the generated symbols are `internal` and
`Resources` must export them — access level is the reason the layer exists, with labels only a
secondary reason. So keep every public signature and replace each body with a forwarder:

```swift
public static var cancel: LocalizedStringResource { .cancel }
public static func downloadStorePageMissing(page: Int) -> LocalizedStringResource { .downloadStorePageMissing(page) }
```

The key literals vanish and a bad key becomes a compile error, which makes any runtime
"does it resolve" test redundant. Not done in phase 15: it is a Resources-module concern predating
this phase, touching all 43 accessors across every module's strings, and folding it into a 77-plan
phase's close-out would spread review scope well outside downloads. Keep the two
`continued_session` value pins regardless — they take arguments, so the rendered string is what
proves plural categories and argument positions.
