---
phase: quick-260819-n3y
plan: 01
subsystem: downloads
tags: [tca, toast, dependency-client, swift-testing, async-stream, ui-test-seam]
status: complete

requires:
  - phase: 15-continued-background-downloads
    provides: "the five deferred items (DEF-15-05, 06, 08, 09, 11) and the reducers, detectors and seam they name"
provides:
  - "the downloads list reports a refused Pause/Resume through a toast, sharing the inspector's mapping"
  - "`fetchDownloads`/`fetchFolders` are non-throwing at the interface, so no effect throws into a `.run` without a `catch:`"
  - "`EHPANDA_UITEST_FORCE_PAUSE_REFUSAL` forces either `togglePause` refusal arm on a device, on both surfaces"
  - "the two convergence detectors are fenced by a sentinel snapshot instead of a wall clock"
  - "the row's delete dialog is pinned against reorder and leave-then-return snapshot changes"
affects: [downloads, verification-round-21]

tech-stack:
  added: []
  patterns:
    - "module-shared `AppError.actionFailureToast` in its own file, three consumers"
    - "sentinel-fence snapshot collection in tests instead of a deadline"

key-files:
  created:
    - AppPackage/Sources/DownloadsFeature/AppError+ActionFailureToast.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadsPauseFailureTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureFenceHelpers.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Download.swift
    - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerReducer.swift
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
    - AppPackage/Tests/AppFeatureTests/UITestStubTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerRefreshTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRowConfirmationTests.swift

key-decisions:
  - "DEF-15-06 was fixed at the interface rather than at the call sites: both reads are pure actor-state reads that cannot fail, so the `throws` was removed instead of `catch:` arms being invented for failures that cannot happen."
  - "The list reports a refused pause WITHOUT reloading: its rows are the live `observeDownloads` stream, unlike the inspector's separately loaded `inspection`."
  - "The fence helper lives in a new test file, because `DownloadFeatureTestHelpers.swift` is at 992 of the 1000-line `file_length` ERROR limit."
  - "The convergence detectors pin gid MEMBERSHIP per emission, not intra-snapshot order: the published index orders by modification date, which neither detector is about."

requirements-completed: [DEF-15-05, DEF-15-06, DEF-15-08, DEF-15-09, DEF-15-11]
---

# Quick task 260819-n3y: close DEF-15-05 / 06 / 08 / 09 / 11 Summary

Five Phase 15 deferred items closed in five atomic commits on `feature/gsd-phase-15`: the downloads
list now reports a refused Pause/Resume, the two download reads stopped declaring a failure they
cannot produce, the refusal arms became forceable on a device through the existing UI-test seam, the
two convergence detectors traded a wall clock for a sentinel fence, and the row's delete dialog is
pinned against the two snapshot changes the amended placement rule names.

Baseline 1009 tests / 0 failures → final **1020 tests / 0 failures**. Every commit was preceded by a
warning-free `AppFeature` build (0 warnings, 0 errors — the SwiftLint plugin runs in it) and ONE full
`AppPackage-Package` run reporting `** TEST SUCCEEDED **`. Test files, which the app-scheme build
does not lint, were additionally linted with the standalone SwiftLint binary: 0 violations.

## Per item

| Item | Commit | Tests | Result |
|------|--------|-------|--------|
| DEF-15-06 | `ace21ed5` `refactor(15): make download reads non-throwing` | 1009 → 1009 (0) | interface fixed at the root |
| DEF-15-05 | `668c57be` `fix(15): report a refused pause from the list` | 1009 → 1014 (+5) | list owns a toast, shared mapping |
| DEF-15-08 | `a87bbc10` `feat(15): add a pause-refusal UI-test seam` | 1014 → 1019 (+5) | both arms forceable, strict parse |
| DEF-15-09 | `f704ece5` `test(15): fence the convergence detectors` | 1019 → 1019 (0) | fence replaces the deadline |
| DEF-15-11 | `9c8145a1` `test(15): pin the row dialog across snapshots` | 1019 → 1020 (+1) | reorder + leave-then-return pinned |

### DEF-15-06 — the PD-1 consequence, stated

`DownloadClient.fetchDownloads` and `fetchFolders` are now
`@Sendable () async -> …` with the `= { [] }` default `@DependencyClient` requires. Both live
implementations are pure reads of coordinator state (`DownloadCoordinator.fetchDownloads()`,
`fetchFolders()`), so the `throws` promised a failure no implementation could produce.

**Four `try` sites dropped it**, not the two the item named:

1. `AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift` — the `.fetchDownloads` effect
2. `AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift` — the `.fetchFolders` effect
3. `AppPackage/Sources/DetailFeature/DetailReducer+Download.swift` — `.fetchDownloadFolders`
4. `AppPackage/Sources/DetailFeature/FolderManager/FolderManagerReducer.swift` — `.fetchFolders`

**The removed view branch:** `DownloadsView.downloadsList` no longer carries
`case .failed(let error) where store.downloads.isEmpty: ErrorView(error:action: fetchDownloads)`. It
was unreachable — `DownloadsReducer.State.loadingState` is written only at the two sites that set
`.loading` and `.idle` — and leaving it in place would have read as a live retry surface for a
failure that cannot occur. The property now carries a doc saying so. The `switch` keeps its
`.loading where empty → LoadingView()` case and its `default → List` case; `LoadingState` stays the
type. If either read ever gains a real failure mode, restoring `throws` makes the compiler enumerate
all four sites — the property this buys.

Warning-free build is the proof no `try` was left behind (each would be a
`no calls to throwing functions occur within 'try'` warning) and that no test double throws from
either endpoint (each would be a test-build error). Neither fired.

### DEF-15-05

`DownloadsReducer.State` gained `@Presents public var toast: AppAlertState<Never>?`, `Action` gained
`case toast(PresentationAction<Never>)`, the body gained `.ifLet(\.$toast, action: \.toast)`, and
`toggleDownloadPauseDone`'s failure arm sets `state.toast = error.actionFailureToast`.
`DownloadsView` renders it with `.toast($store.scope(\.$toast, action: \.toast))` beside the existing
list-level confirmation dialog. The accepted arm stays silent, and there is deliberately **no
reload**: unlike the inspector's separately loaded `inspection`, the list's rows come from the live
`observeDownloads` stream, so both refusal arms are already reflected on screen.

The mapping moved out of `DownloadInspectorReducer.swift` into
`AppPackage/Sources/DownloadsFeature/AppError+ActionFailureToast.swift` as a module-internal
extension, with its doc's opening paragraph naming the three consumers (inspector retry WR-04,
inspector pause WR-05, list pause DEF-15-05) and keeping the "which is why it is not named for
either" reasoning. The reducer type doc's failure-reporting policy was rewritten: the list now owns a
toast surface added for exactly one action; `moveDownloadDone`, `updateDownloadDone` and
`deleteDownloadDone` stay deliberately silent on their unchanged record-says-so reasoning;
`openReadingDone` reports by behaviour; `toggleDownloadPauseDone` reports.

Five new list-side cases (`DownloadsPauseFailureTests`) mirror the inspector suite one for one,
including the tap path through a throwing `togglePause` double and the accepted arm under FULL
exhaustivity (pinning "no toast AND no reload"). The declared collateral was real:
`DownloadsReducerRefreshTests`' exhaustive `receive(\.toggleDownloadPauseDone)` now asserts the
`networkingFailed` toast.

### DEF-15-08 — the device recipe

`EHPANDA_UITEST_FORCE_PAUSE_REFUSAL` resolves to `UITestAutomation.PauseRefusal` (`notFound` |
`unknown`, whitespace-trimmed, anything else is not an override), opts the configuration in on its
own, and `prepare` installs `$0.downloadClient.togglePause = { _ in throw refusal.error }` inside the
same single `prepareDependencies` block as the clipboard override — everything under the existing
`#if DEBUG`.

**Recipe:** run the app with ONLY that key set (no `EHPANDA_UITEST_STUB_NETWORK`, so the real library
is on screen), value exactly `notFound` or `unknown`. Open Downloads, then tap Pause or Resume on any
active or paused download — from the row's swipe action, from its context menu, or from inside the
inspector sheet. Every one of those routes raises the forced refusal, and the toast appears: the
list's since DEF-15-05, the inspector's as before. One documented cost, DEBUG-only and only when the
key is set: reading `$0.downloadClient` to install the override creates the live `DownloadClient`
inside `EhPandaApp.init`, earlier than it would otherwise be built.

No XCUITest: a hermetic UI test would need a `canTogglePause` row, and the stubbed launch cannot
produce one. The seam plus its five unit pins is the deliverable, and none of those pins calls
`prepare` (it mutates process-global dependencies).

### DEF-15-09 — the pre-fix-mutation observation

Both detectors now push a fresh-gid sentinel through `fixture.manager.observerHub.notify([fence])`
after the operation returns, read until the sentinel, and assert the sequence before it. No deadline,
no `defer { observerTask.cancel() }`, no reliance on cancellation draining the buffer. The
fence-versus-clock reasoning has a single owner: the doc on
`collectSnapshots(from:untilFence:)`. `waitForTaskValue` and its 9 remaining caller files are
untouched.

**The mutation was performed, observed, and restored — never committed.** Two rounds, and the first
is worth recording because it contradicts the plan's stated expectation:

1. **Commenting out `await notifyObservers()` on `delete`'s not-found exit alone does NOT falsify the
   detector.** With that single line removed and the target rebuilt (compilation of
   `DownloadClient+PublicAPI.swift` confirmed in the build log),
   `DownloadsFeatureTests/DownloadDeleteConvergenceTests` passed 2/2 in 0.037 s. The reason is the
   sibling call on the same exit: `scheduleNextIfNeeded()` schedules the second gallery and its own
   path publishes the converged index, so the second emission still arrives.
2. **The faithful pre-fix shape does falsify it, immediately and by name.** Removing the exit's whole
   convergence tail (`notifyObservers()` and `scheduleNextIfNeeded()`, which is what the branch
   looked like before the CR-04 convergence fix) produced, in **0.050 s** rather than after any
   timeout:
   - `Expectation failed: (emissions.count → 1) >= 2`
   - `Expectation failed: (emittedGIDs.dropFirst().first → nil) == ([secondGallery.gid] → ["scheduled-second"])`
   - plus the pre-existing `scheduledGalleryRecorder.snapshot() → []` pin, and 2 issues in the
     sibling last-record case.

   `git checkout --` restored the file; `git diff --quiet -- AppPackage/Sources` held before the
   Task 4 commit, which is test-only.

### DEF-15-11

`testARowLeavingTheSnapshotDropsItsDialog` became
`testARowLeavingTheSnapshotDropsItsDialogAndFiresNoDeletion`: exhaustive from the removal onwards
(`$0.rows.remove(id:)` is the structural proof that the dialog cannot be stranded), then the record
returns in a later tick and comes back DISARMED, then `store.finish()` and `deleted.value.isEmpty` —
full exhaustivity is what proves no `.deleteDownload` was ever sent. The new
`testAReorderingSnapshotKeepsTheArmedRowsDialogAndItsAction` reorders `[a, b]` to `[b, a]` with `b`
armed, pins `rows.ids == [b, a]`, `b` armed and `a` not, and then confirms `b`'s dialog and asserts
the client deleted `b`. The suite doc carries the DEF-15-11 reasoning and states why filter/gate
flips are unreachable while a row dialog is up and therefore not pinned. The stale `DownloadRow` doc
paragraph in `DownloadsView.swift` was rewritten to the amended rule and points at this suite; no
code change in the view, and `DownloadsSwipeActionSourceTests`' three scan anchors are untouched
(still 3 matches, suite green).

## Deviations

1. **[Rule 3 — blocking] The fence helper went into a new file.** PD-5 places
   `collectSnapshots(from:untilFence:)` in `DownloadFeatureTestHelpers.swift`. That file is at **992
   of the 1000-line `file_length` ERROR limit** (verified: standalone SwiftLint reports it clean
   today, and the helper is ~45 lines with its doc), so the addition would have violated a hard lint
   rule — and neither a `swiftlint:disable` nor a rule edit is permitted. The helper is instead a
   `DownloadFeatureTestCase` extension in a new
   `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureFenceHelpers.swift`, which is also the
   split the file has been flagged as needing. Everything else about PD-5 is as written; the task's
   verify grep for `untilFence` was run against the new file.
2. **[Rule 1 — bug] Sequence pins use optional-safe reads, not `emissions[0]`/`emissions[1]`.** A
   literal subscript traps when the pre-fix run produces one emission, crashing the test process
   instead of producing the named failure the whole item is about. `emissions.first` /
   `.dropFirst().first` state exactly the same properties and fail by name — confirmed by the
   mutation run above, where `dropFirst().first → nil` is one of the reported issues.
3. **[Rule 1 — bug] Pair emissions are compared by gid MEMBERSHIP, not array order.** PD-5's
   `emissions[0].map(\.gid) == [first, second]` form was written and run first: it failed 5 cases
   (1 delete + 4 ownership arguments). The published index orders by modification date — the delete
   case's initial emission read `["scheduled-second", "vanished-first"]`, and the ownership case's
   converged emission reshuffles relative to its own initial one. Intra-snapshot order is not what
   either detector is about and would tie under a same-millisecond write, so each emission is now
   compared as `Set(...)`; the single-element converged emission in the delete case still pins its
   exact content, and the `dropFirst().allSatisfy` sweep is kept.
4. **The plan's named pre-fix mutation is insufficient** (detail in the DEF-15-09 section above): the
   single `notifyObservers()` line is not the detector's sole source of the second emission. The
   faithful pre-fix shape was used instead, and it fails immediately as the item requires.
5. **[Cosmetic] The DEF-15-08 `<behavior>` list was written as five separate `@Test` cases.** A first
   pass grouped the five expectations into two cases; it was split so the count matches the plan's
   expected +5 and each expectation fails in isolation.

## Notes

- One `xcodebuild test` invocation (the run that surfaced deviation 3's five failures) had printed
  every target's result but had not exited after 10 minutes and was terminated at that mark. No
  overlapping invocation was ever started, no run was force-killed mid-launch, and every subsequent
  full run completed normally in ~50 s. Later runs were backgrounded and polled rather than run under
  a foreground timeout, so no further run risked a mid-flight kill.
- Simulator: the pinned id `ADE09605-A44E-4F00-BE12-235970217355` (iPhone Air) was available; nothing
  in the command was changed.
- No `swiftlint:disable`, no lint-rule edit, no new localized string, no `try?`, no force unwrap. No
  absolute home path and no local reference-project name in any artifact.
- Not touched, as instructed: `deferred-items.md`, `15-UAT.md`, `STATE.md`, `ROADMAP.md`, the
  PLAN.md. This SUMMARY is left uncommitted for the orchestrator's docs commit.

## Orchestrator follow-up (review)

All five commits were reviewed diff by diff; the deviations above were accepted (each is the more
correct reading of its item). Three doc-comment wording nits were fixed in a sixth commit,
`0e9803e1` `docs(15): tighten three new doc comments` — the shared mapping's "not named for either"
with three consumers, the seam's comment that implied a single preparation was REQUIRED for the
get-then-set (it is only tidier; the acceptance comes from get and set sharing one preparation), and
a garbled sentence in the fence helper's history paragraph — re-verified with a warning-free
`AppFeature` build and one full `AppPackage-Package` run (1020 tests, 0 failures). `deferred-items.md`
rows 05/06/08/09/11 were marked resolved with these SHAs, DEF-15-03 gained a supersession note for
the two fenced sites, and `STATE.md` carries the quick-task row.

## Self-Check: PASSED

- Files created exist: `AppError+ActionFailureToast.swift`, `DownloadsPauseFailureTests.swift`,
  `DownloadFeatureFenceHelpers.swift`.
- Commits exist and are in order, newest last: `ace21ed5`, `668c57be`, `a87bbc10`, `f704ece5`,
  `9c8145a1`.
- Working tree clean after the fifth commit; `git diff --quiet -- AppPackage/Sources` held before the
  test-only Task 4 commit.
- Final full run: `** TEST SUCCEEDED **`, 1020 tests, 0 failures; `AppFeature` build 0 warnings.
