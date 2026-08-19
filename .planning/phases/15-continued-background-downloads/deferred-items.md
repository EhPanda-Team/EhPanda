# Deferred Items — Phase 15

Out-of-scope discoveries found while executing this phase. Logged, not fixed.

Each entry carries a stable `DEF-15-NN` id, assigned 2026-08-19 in file order and never renumbered —
a resolved entry keeps its id rather than freeing it. Use the id to dispatch work; the headings are
prose and will drift.

| id | status | grouped into |
|----|--------|--------------|
| DEF-15-01 | resolved 2026-08-19 (f9892824) | — |
| DEF-15-02 | resolved 2026-08-19 (f9892824) | — |
| DEF-15-03 | resolved by 15-64, owned since 15-74 | — |
| DEF-15-04 | resolved 2026-08-19 (97347f5d, quick 260819-ovp) | — |
| DEF-15-05 | resolved 2026-08-19 (668c57be, quick 260819-n3y) | — |
| DEF-15-06 | resolved 2026-08-19 (ace21ed5, quick 260819-n3y) | — |
| DEF-15-07 | open, DEFERRED INDEFINITELY by the owner 2026-08-19 — do not pick up | — |
| DEF-15-08 | resolved 2026-08-19 (a87bbc10, quick 260819-n3y) | — |
| DEF-15-09 | resolved 2026-08-19 (f704ece5, quick 260819-n3y) | — |
| DEF-15-10 | resolved 2026-08-19 (15cf9273, quick 260819-ovp) | — |
| DEF-15-11 | resolved 2026-08-19 (9c8145a1, quick 260819-n3y) | — |

The two groupings are the owner's, decided 2026-08-19. They are groupings only — nothing about
scope, order or approach inside either group is settled here. The 05/06/08/09/11 group was planned
and closed the same day as quick task 260819-n3y (`.planning/quick/260819-n3y-*/`); the 04/10 group
was planned and closed the same day as quick task 260819-ovp (`.planning/quick/260819-ovp-*/`).
Only DEF-15-07 remains open, by the owner's decision.

## DEF-15-01 — ROADMAP.md progress table is missing a Phase 16 row — RESOLVED

The `| Phase | Plans Complete | Status | Completed |` table in `.planning/ROADMAP.md` ends at
row 15. Phase 16 (Dynamic Type Accessibility) has a phase entry and a checklist bullet but no
progress row. Row 15 also carried Phase 16's name until plan 15-07 corrected it to
"Continued Background Downloads" — the row the plan's own tooling had to update.

## DEF-15-02 — ROADMAP.md execution-order line stops at 15 — RESOLVED

`**Execution Order:** Phases execute in numeric order: 1 → … → 15` predates the Phase 16 entry
and should end at 16.

Both are documentation staleness in a file outside this phase's edit scope (the plan scopes
Task 2 to the Phase 15 detail section). Neither affects any code or gate.

**Both RESOLVED 2026-08-19 in commit f9892824**, during the state/roadmap sync: the progress table
gained a `| 16. Dynamic Type Accessibility | 0/0 | Not Started |  |` row and the execution-order line
now ends at 16. The historical report above is kept for the record.

## DEF-15-03 — `testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving` had a one-second deadline — RESOLVED

**Resolved by 15-64 and owned since 15-74.** 15-64 removed the explicit one-second arguments from
five call sites and raised `waitForTaskValue`'s default to ten seconds; 15-74 declined IN-01's
request to restore a one-second bound at this case and its sibling detector, and wrote the
derivation — this record included — into the call site itself, so the ten-second bound is now a
decision with an owner rather than an inherited default. Superseded at the two detector sites by
DEF-15-09 (2026-08-19): the bound there was replaced by a sentinel fence; the ten-second default
stands at every other `waitForTaskValue` caller. The historical report follows.

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

## DEF-15-04 — Existing UI-test actor-isolation warnings — RESOLVED

Building the targeted package tests with Xcode 26.6 reports two Swift concurrency warnings in
`EhPandaUITests/DeepLinkPadUITests.swift:9`: the nonisolated assertion autoclosure reads
`UIDevice.current.userInterfaceIdiom`. The file is outside Plan 15-10's session-identity scope,
and the warnings predate its changes.

**RESOLVED 2026-08-19 in commit 97347f5d (quick 260819-ovp).** The autoclosure was only the
innermost nonisolated scope: `setUpWithError()` overrides a nonisolated XCTest declaration, so the
class-level `@MainActor` never reached it either, and annotating the override is a hard error. The
idiom read now opens the test method itself (which overrides nothing, so the class's `@MainActor`
does reach it) as `guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip(...) }`
with the original message; `setUpWithError` keeps only `continueAfterFailure = false`. No
`assumeIsolated`, no `nonisolated(unsafe)`, no suppression. The `UITests` build-for-testing reports
zero Swift diagnostics (was four lines, two warnings × two architectures) and the test still passes
on an iPad Pro simulator. A future second test method in this class needs the same guard, since
shared set-up cannot host the read — the comment at the guard says why.

## DEF-15-05 — `DownloadsReducer.toggleDownloadPauseDone(.failure)` is silent with no report surface — RESOLVED

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

**RESOLVED 2026-08-19 in commit 668c57be (quick 260819-n3y).** `DownloadsReducer.State` gained
`@Presents var toast: AppAlertState<Never>?`, the failure arm of `toggleDownloadPauseDone` sets it
through the inspector's `actionFailureToast` mapping — moved out of `DownloadInspectorReducer.swift`
into the module-shared `AppError+ActionFailureToast.swift` — and `DownloadsView` renders it with
`.toast(...)`. No reload accompanies the report: the list's rows are the live `observeDownloads`
stream, so both refusal arms are already reflected on screen. Pinned by `DownloadsPauseFailureTests`
(five cases mirroring the inspector suite, all fully exhaustive). The reducer's failure-reporting
policy doc was rewritten accordingly.

## DEF-15-06 — `fetchDownloads` / `fetchFolders` throw into an effect with no `catch:` — RESOLVED

Also found during the same sweep, and outside its scope (neither action is result-carrying).
`DownloadsReducer.swift:251-255` and `288-292` both `try await` inside `.run { }` with no `catch:`
arm. A throw there is reported by TCA as a runtime issue rather than handled, and on the
`fetchDownloads` path `state.loadingState` was set to `.loading` immediately before, so a throwing
fetch leaves the list spinning with no error state and no retry. Gap 4's contract covers actions
that carry a `Result`; these carry none, which is precisely why the failure has nowhere to go.

**RESOLVED 2026-08-19 in commit ace21ed5 (quick 260819-n3y), at the interface rather than at the
call sites.** Both live implementations (`DownloadCoordinator.fetchDownloads()`, `fetchFolders()`)
are pure reads of actor state and cannot fail, and no test double anywhere throws from either, so
the `throws` on the two `DownloadClient` closures was vestigial. They are now `@Sendable () async ->
…` with the `= { [] }` default `@DependencyClient` requires, and all FOUR `try await` sites dropped
the `try` — the two this item named plus `DetailReducer+Download.swift` and
`FolderManagerReducer.swift`. The defect is gone by construction; `catch:` arms were deliberately
not added for failures that cannot happen. Consequence: `DownloadsView`'s `.failed →
ErrorView(retry)` branch was unreachable and was removed; `DownloadsReducer.State.loadingState`
carries a doc saying only `.loading`/`.idle` occur.

## DEF-15-07 — `AppPackage/Package.swift` exceeds the 1000-line `file_length` ERROR limit

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

## DEF-15-08 — Force the inspector's Pause/Resume refusal through the existing UI-test seam — RESOLVED

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

**RESOLVED 2026-08-19 in commit a87bbc10 (quick 260819-n3y).** `EHPANDA_UITEST_FORCE_PAUSE_REFUSAL`
(exactly `notFound` or `unknown`, whitespace-trimmed; anything else is not an override) resolves to
`UITestAutomation.PauseRefusal`, opts the configuration in on its own, and `prepare` installs
`$0.downloadClient.togglePause = { _ in throw refusal.error }` via `prepareDependencies`, all under
the existing `#if DEBUG`. Because it replaces the endpoint it forces BOTH surfaces — the list's
swipe and context-menu Pause (which reports since DEF-15-05) and the inspector's. Device recipe:
launch with only that key set (no stubbed network), open Downloads, tap Pause/Resume on any active
or paused download, observe the toast. Pinned by five `UITestStubTests` cases (resolution only;
`prepare` is never called with the key in tests). No XCUITest: a hermetic UI test would need a
`canTogglePause` row, which the stubbed launch cannot produce.

## DEF-15-09 — Replace the convergence detectors' wall-clock wait with a fence — RESOLVED

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

**RESOLVED 2026-08-19 in commit f704ece5 (quick 260819-n3y), in the preferred shape — no production
change.** Both detectors now push a fresh-gid sentinel through `fixture.manager.observerHub.notify`
after the operation returns, collect until it (`collectSnapshots(from:untilFence:)` in the new
`DownloadFeatureFenceHelpers.swift`, which owns the fence-versus-clock reasoning for both), and pin
the sequence before it: `count >= 2`, the initial pair first, the converged emission second,
compared by gid membership (the published index orders by modification date, which neither detector
is about). No deadline on the await — termination is by construction. `waitForTaskValue` and its
other callers are untouched. The ten-second bound DEF-15-03 recorded as "a decision with an owner"
is therefore retired at these two sites only. Falsification was checked: removing the not-found
exit's whole convergence tail fails the delete detector in 0.05 s by name (`emissions.count → 1`),
whereas removing only its `notifyObservers()` line does not, because the sibling
`scheduleNextIfNeeded()` publishes the converged index through its own path — recorded in the quick
task's SUMMARY.

## DEF-15-10 — Delete the hand-typed localization key literals by forwarding to Xcode's generated symbols — RESOLVED

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

Raised again by the owner on 2026-08-19, independently of UAT test 14. A second entry filed that day
was merged back into this one, which already carries the decisive constraint the newer note lacked:
the generated symbols are `internal`, so the public layer stays and each body becomes a forwarder.
Note also the AGENTS.md labelled-localized-format rule — shared keys carry hand-written semantic
labels for NUMERIC arguments, and forwarding must preserve them rather than fall back to positional
generated signatures.

**RESOLVED 2026-08-19 in commit 15cf9273 (quick 260819-ovp).** `ResourceStringSymbols.swift` now
hand-types nothing: every one of the 43 accessors keeps its exact public signature and forwards to
the internal symbol Xcode generates from the Resources module's two catalogs — `.cancel`,
`.days(count)` (the generated top-level `%lld` plural symbols are positional, so the `count:`/`page:`
labels stay on the public signature), `.continuedSessionSubtitle(completed:total:galleries:)` (the
generator already derives those labels from the three named substitutions), and
`Constant.responseGalleryUnavailable`. The hand-written bundle description and its `#bundle` macro
are gone with the literals. The property the item asked for was demonstrated, not asserted: a
temporary rename of the `cancel` key in `Localizable.xcstrings` failed the `Resources` build at
`ResourceStringSymbols.swift:24:62: error: type 'LocalizedStringResource' has no member 'cancel'`,
then was reverted. No catalog, consumer or test file changed; the two `continued_session` value
pins in `ContinuedProcessingSessionFoldTests` stand; 1020 tests / 0 failures; `AppFeature` build
warning-free. The file-level doc records the two reasons the public layer still exists (access
level; hand-written numeric labels) and why no runtime "does it resolve" test exists for these keys.

## DEF-15-11 — No test covers a row leaving `rows` while its confirmation dialog is presented — RESOLVED

Surfaced closing UAT test 8. The owner chose to keep the delete confirmation attached to the ROW
(`DownloadsView.swift:227-229`) and amended the `AGENTS.md` placement rule accordingly, on the
reasoning that stability must be judged against changes UNRELATED to the dialog's own action: a row
removed by its own confirmed deletion is the intended terminal state, not instability.

That decision leaves exactly one hazard live, and it is the one the amended rule now names as the
real concern. If a row leaves `rows` for a reason the dialog knows nothing about - the observe
stream delivering a refresh that reorders or drops the item, a filter or gate flipping, an ancestor
rebuilding - the dialog is torn down with the row, silently, and the deletion never fires. The user
sees the confirmation vanish and nothing happen.

Nothing asserts this today. `DownloadsSwipeActionSourceTests` pins the swipe button's role and tint
and the context-menu Delete's role, but no case drives a presented `$confirmationDialog` and then
removes its row from `rows` out from under it. Worth a reducer-level case that presents the row's
dialog, delivers a `downloadsResponse` (or equivalent observation update) whose list no longer
contains that gid, and pins what should happen - at minimum that the state does not silently strand
a dialog whose action can never fire.

Not done in phase 15: the anchoring decision closed the checkpoint, and this is a distinct
behavioural gap that predates it. The amended rule explicitly prefers "eliminating that instability,
or covering it with a test, over giving up the correct anchor", so this is the follow-through that
sentence points at.

**RESOLVED 2026-08-19 in commit 9c8145a1 (quick 260819-n3y).** Correction to the record first: a
drop case already existed when this was filed (`DownloadRowConfirmationTests`, 2026-08-11); what was
missing was the "what should happen" half. The suite now pins both shapes of the hazard at reducer
level, with no production change: a REORDERING tick keeps the armed row's dialog on that row (gid
identity) and its confirmed action still deletes that gid; a tick that DROPS the row takes the
dialog with it structurally (the rows are the storage), fires no deletion (full exhaustivity from
the removal on, plus a `delete` recorder), and a record returning in a later tick comes back
disarmed. Filter/gate flips were examined and deliberately not pinned: narrowing a filter while a
row dialog is up is unreachable (modal on iPhone; the iPad popover dismisses first), and the one
programmatic filter write widens the visible set. The stale `DownloadRow` doc paragraph in
`DownloadsView.swift` that still described the anchor as in tension with the placement rule was
rewritten to the amended rule and points at the suite.
