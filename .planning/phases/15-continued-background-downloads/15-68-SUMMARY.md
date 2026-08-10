---
phase: 15-continued-background-downloads
plan: 68
subsystem: downloads
tags: [download-client, filesystem, path-confinement, security, manifest-ssot, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-63's confinedDirectUserFolderURL and renameUserFolder — the boundary this round extends to the whole user-folder mutation family"
provides:
  - "mutatingConfinedUserFolder: the one function every user-folder create, move-destination and remove is written as a closure to, so a mutation has nowhere else to go"
  - "DownloadStore.deleteUserFolder / createUserFolder / ensureUserFolder: store-owned mutations that re-decide confinement inside the lock that acts"
  - "A symlink-resolving removeFolder(at:), re-documented as the record-path primitive that user-folder names no longer reach"
  - "An argument-driven delete escape suite that asserts bytes AND all three record stores on both outcomes"
affects: [user-folder boundary, download-root confinement, record/disk convergence, coordinator/store split]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Make the boundary the SHAPE of the operation: a mutation written as a closure handed to the resolver cannot skip the resolver"
    - "Delete the unconfined resolver rather than documenting it — an absent function cannot be fed into a mutation by the next sibling"
    - "A cleanup key that is exact only for well-formed input becomes exact BY CONSTRUCTION once the boundary admits nothing else"
    - "Suppress an independent actor before asserting that a call left records alone, or the assertion is decided by timing"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift

key-decisions:
  - "DEC-A: the boundary is a closure-taking function (mutatingConfinedUserFolder), not a convention — every user-folder mutation is its body, so a future sibling has nowhere to put an unconfined one"
  - "DEC-B: userFolderURL(name:) is DELETED, not demoted — unreachability enforced by the absence of the symbol rather than by an access level the same module could still reach"
  - "DEC-C: enqueue's parent-folder create is REMOVED as redundant rather than confined; writeInitialManifest already creates the same parent with intermediates two lines later"
  - "DEC-D: deleteFolder keeps its existence pre-check ahead of the store, so an absent folder still answers .notFound without moving any scheduling state — now asked only about names the boundary accepted"
  - "DEC-E: the escape suite installs a foreign active task, because the staged queue intent otherwise starts a real run whose failure path dequeues the gid the case asserts is untouched"

patterns-established:
  - "State the mutation-caller set by enumerating the symbol yourself, then give every hit a disposition in the summary — including the ones you did not change"
  - "A refusal case asserts the victim's BYTES and every persisted record, in that order, before the returned error"

requirements-completed: []

coverage:
  - id: D1
    description: "Every delete escape shape — traversal, sibling, absolute, nested gallery folder, padded alias, symlinked direct child — is refused with the target's bytes intact"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift#testDeleteFolderRefusesANameThatIsNotADirectChild"
        status: pass
    human_judgment: false
  - id: D2
    description: "A refused delete leaves downloadIndex, the queue store, the background-task store and the folder listing exactly as it found them"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift#expectStagedRecordsSurvive (asserted for all six arguments)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A legitimate delete converges all three record stores with the disk"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift#testDeleteFolderRemovesContainedDownloadsAndQueueIntents"
        status: pass
    human_judgment: false
  - id: D4
    description: "Create, rename, move, enqueue and every other folder behaviour is unchanged"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (946 tests, 0 failures, 22 targets; downloads target 427 in 72 suites)"
        status: pass
    human_judgment: false

# Metrics
duration: 40min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 68: One Confined Boundary for Every User-Folder Mutation Summary

**CR-02 is closed as a family rather than as a call site: every user-folder create, move destination and removal is now written as a closure handed to the one function that resolves and re-decides confinement, `userFolderURL(name:)` no longer exists to be fed into a mutation, and both delete outcomes are asserted against the disk AND all three record stores.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-08-10T17:57Z
- **Completed:** 2026-08-10T18:37Z
- **Tasks:** 2 (RED, GREEN)
- **Files created:** 0
- **Files modified:** 7 (4 sources, 3 test files)

## Accomplishments

- **The defect was the un-swept sibling, and the fix is shaped so there cannot be a next one.** 15-63 gave `renameFolder` a boundary and stopped; `deleteFolder` still appended a raw name to the root and handed the result to `removeFolder(at:)`, whose containment is a lexical prefix. The RED run recorded the consequence verbatim: with `name == "Keeper/[318_token] Sample"` the gallery folder was gone, its page file returned `nil` bytes, and the call reported `success()` — while `downloadIndex`, the queue store and the background-task store all still held the gallery. Rather than write a fourth guarded call site, every user-folder mutation is now the BODY of `mutatingConfinedUserFolder(named:perform:)`. There is no longer a spelling of "create, move or remove a user folder" that skips the resolution, because there is nowhere else to put the mutation.
- **The unconfined resolver is gone, not demoted (DEC-B).** The plan allowed re-documenting `userFolderURL(name:)` as read-model-only. That would have left a same-module function whose entire job is "turn a name into a URL under the root with no guarantee" sitting one autocomplete away from the next sibling — which is exactly how this gap was born. Its four mutating callers are gone, and its one non-mutating caller (`repointRenamedUserFolder`) now derives the URL from the same `relativePath` string it stores, so the record's path and its URL can no longer describe two different places. `rg -n 'userFolderURL' AppPackage/Sources` returns one line, and it is the tombstone comment explaining why.
- **The record divergence is closed at the construction, not at the cleanup.** The review's second half is that `parentFolderName == name` matches nothing for a nested name. No new cleanup logic was needed: once only a single confined component can be deleted, the set of galleries whose folder the call removes is *exactly* the set whose parent name equals it. The key became exact by construction. That argument is recorded on `deleteFolder`, because it is the kind of correctness that reads like luck if nobody writes down why it holds.
- **The shared primitive was tightened even though nothing routes user folders through it any more.** `removeFolder(at:)` now resolves symlinks before comparing, so a link staged inside the root is no longer a removal of whatever it points at. Its doc no longer implies it is a general folder-removal entry point: it states that its permissiveness is deliberate (its one caller, `removeGalleryFolders`, legitimately names gallery folders *below* user folders) and that this permissiveness is precisely why a caller-supplied name must never arrive there.
- **Two of the six escape arguments were already refused pre-fix, and three more were refused for the wrong reason.** `..` and `../Outside` are stopped by the lexical prefix check — they are boundary pins, not discriminators. `absolutePath` and `whitespacePaddedAlias` returned `.notFound`, true of the constructed path and misleading about the request. Only the error-FAMILY assertion made those two discriminate, and only the disk assertions made the nested and symlink arguments state the escape in their own words.
- **The escape suite was made deterministic before it was committed.** The first RED run logged four `Download failed, gid: 318` lines: the staged queue intent made `scheduleNextIfNeeded` start a real run, and that run's failure path removes the gid from the queue store — an independent actor mutating the very records the case asserts `deleteFolder` left alone. The assertions happened to pass, which is worse than failing. A foreign active task now holds the scheduler, the log lines are gone, and the second RED run reproduced the same 9 issues.

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — prove deleteFolder reaches unnamed targets and strands records** - `7699168b` (test)
2. **Task 2: GREEN — one confined boundary for every user-folder mutation** - `2d6e0e8a` (fix)

## The Mutation-Caller Sweep, Enumerated From Source

The family was derived by enumerating `userFolderURL` in `AppPackage/Sources` **before** reading the plan's or the review's list, then classifying each hit by what its result reaches. Five production call sites, four of them mutating:

| Site (pre-change) | Kind | Disposition |
|---|---|---|
| `DownloadClient+Folders.swift:22` (`createFolder`) | create | **Routed.** `storage.createUserFolder(named:)` — the already-exists refusal moved into the lock that creates, so the answer the caller acts on is the state the creation meets. |
| `DownloadClient+Folders.swift:97` (`deleteFolder`) | remove | **Routed.** `storage.deleteUserFolder(named:)`. The gap itself. |
| `DownloadClient+Folders.swift:199` (`moveDownload` destination parent) | create + move destination | **Routed.** Resolution moved up into the existing invalid-name guard (which the function's doc already places ahead of every side effect); the creation is `storage.ensureUserFolder(named:)`. The `moveItem` destination is a child of that confined parent. |
| `DownloadClient+PublicAPI.swift:90` (enqueue parent folder) | create | **Removed as redundant (DEC-C).** `writeInitialManifest` calls `createDirectory(at:)` — `withIntermediateDirectories: true` — on `<root>/<parent>/<gallery>` two lines later, unconditionally and before the manifest-reuse probe, so the parent was already created by the call that creates the gallery folder. |
| `DownloadClient+Folders.swift:258` (`repointRenamedUserFolder`) | read model | **Converted.** Not a mutation: it describes where the store has already put a folder. Now `storage.folderURL(relativePath:)` over the same string the record stores. |

Post-change, `rg -n 'userFolderURL' AppPackage/Sources` → **one hit**, the tombstone comment at `DownloadStore.swift:92`. No hit feeds a create, move or remove because no hit exists.

`rg -n 'deleteUserFolder' AppPackage/Sources` → the declaration (`+Operations.swift:529`), one coordinator caller (`+Folders.swift:143`) and one doc cross-reference.

`rg -n 'removeFolder\(' AppPackage/Sources`, with dispositions:

| Site | Disposition |
|---|---|
| `+Operations.swift:422` `removeFolder(relativePath:)` | Declaration. **No production caller** (verified across `App`, `AppPackage`, `ShareExtension`). Kept as the relative-path spelling of the primitive, inheriting its containment whole; the doc now says it has no caller rather than implying one. |
| `+Operations.swift:443` `removeFolder(at:)` | Declaration. Symlink resolution added ahead of the prefix comparison; doc re-derived. |
| `+Execution.swift:101` (`removeGalleryFolders`) | **The one production caller.** Passes gallery-folder URLs the scan produced — nested under a user folder by construction, which is why this primitive stays prefix-based. Unchanged. |
| `+Folders.swift:116` (`deleteFolder`) | **Gone.** Replaced by `storage.deleteUserFolder(named:)`. |

## Banked Falsifiability

The RED suite failed against pre-fix production with **9 verbatim issues** across four of the six arguments. Two arguments passed pre-fix and are recorded as pins rather than discriminators.

| Argument | Pre-fix (recorded) | Post-fix |
|---|---|---|
| `nestedGalleryFolder` | `fileExists(…/Downloads/Keeper/[318_token] Sample)` FAILED (twice — as the target and as the staged gallery), `contents(…/page-1.bin) → nil` where 11 bytes were required, result `success()`. **All three record-store assertions PASSED** — the stranded-record divergence, exactly as the review derived it. | Refused as an invalid name; folder, page bytes and all three stores untouched. |
| `symlinkedDirectChild` | `fileExists(…/Downloads/Linked)` FAILED, the link no longer resolved to `…/Downloads/Keeper`, result `success()` — `removeItem` removed the link the caller's read model still names. | Refused by the `.typeDirectory` guard; link present and still pointing at `Keeper`. |
| `absolutePath` | result `failure(AppError.notFound)` — true of the constructed path, false about the request. | `.fileOperationFailed`, refused as a name. |
| `whitespacePaddedAlias` | result `failure(AppError.notFound)` — the padded path simply did not exist; normalizing it would have selected the REAL `Keeper`. | `.fileOperationFailed`, refused as a name. |
| `parentDirectory` (`..`) | PASSED — the lexical prefix check already refuses it. | Unchanged; boundary pin. |
| `traversalToSibling` (`../Outside`) | PASSED — same. | Unchanged; boundary pin. |

The extended legitimate-delete case (`testDeleteFolderRemovesContainedDownloadsAndQueueIntents`) **passed pre-fix** with its new queue-store and background-task-store assertions. That is the point of it: it pins the convergence from the side where deletion happens, so the fix cannot buy the refusal side by making the legitimate side stop converging.

## Decisions Made

- **DEC-A: the boundary is a function that takes the mutation, not a rule the mutation follows.** `mutatingConfinedUserFolder(named:perform:)` resolves once outside the lock, re-decides the same resolution inside it, and only then runs the caller's body. Every one of the three store mutations is that body. This is the difference between "the next sibling must remember to confine" — which is the sentence this gap was — and "the next sibling has nowhere else to write its mutation".
- **DEC-B: `userFolderURL(name:)` is deleted.** Demoting it to internal would enforce nothing: all four mutating callers were in the same module. Deleting it makes the regression unwritable, and the one read-model caller came out *better* — `relativePath` and `folderURL` are now derived from a single value instead of built twice.
- **DEC-C: enqueue's parent-folder creation is removed rather than confined.** Routing it through `ensureUserFolder` would have been a real narrowing: `parentFolderName` there is either a normalized name *or* `record.parentFolderName`, which comes from a filesystem scan and need not be normalization-identical (a folder created outside the app with padding is a legitimate direct child). Confining it would have made such a gallery permanently un-enqueueable. It did not need confining at all, because it was duplicating a creation `writeInitialManifest` performs with intermediate directories. Two consequences, both wanted: the route now has no name-taking user-folder mutation, and a failed manifest write no longer leaves an empty user folder behind.
- **DEC-D: `deleteFolder` keeps its existence pre-check ahead of the store.** Dropping it would send an absent folder through `blockScheduling` and the active-task cancellation before answering `.notFound`, changing observable side effects. It is now asked only about a name the boundary already accepted, so it can no longer report on a path the caller did not name; the store answers `.notFound` too, for the folder that vanishes between the check and the removal. The observable `Result` contract is unchanged for every valid name.
- **DEC-E: the escape suite holds the scheduler.** Recorded because the failure mode is silent: without the hold the case is green or red depending on when an independent run's failure path reaches `queueStore.remove`. The invariant under test belongs to `deleteFolder`, so the scheduler is suppressed rather than raced. The hold names a gid no argument's folder contains, so `deleteFolder`'s contained-gallery cancellation never fires.
- **DEC-F: `createUserFolder` and `ensureUserFolder` are two operations, not one with a flag.** They differ in exactly one guard (must-not-exist versus may-exist) and their callers want different errors. Both call `ensureRootDirectory()` first, which is a small correction on the move path: a root recreated by `withIntermediateDirectories` alone would silently lose its backup exclusion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The escape suite's own staging let an independent actor decide its record assertions**

- **Found during:** Task 1 (RED)
- **Issue:** The first RED run logged four `Download failed, gid: 318` lines. The staged queue intent made `scheduleNextIfNeeded` start a real download for the victim gallery, and that run's failure path calls `queueStore.remove(gid)` — so `queueStore.contains(gid)`, one of the assertions the case exists to make, was being decided by timing. It happened to pass.
- **Fix:** A foreign active task (`escape-suite-scheduler-hold`) is installed before the queue intent exists, so `scheduleNextIfNeededCore`'s `guard activeTask == nil` returns early. The reason is recorded on the staging helper.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift`
- **Verification:** The re-run produced the same 9 issues with no `Download failed` line in the log.
- **Committed in:** `7699168b` (Task 1 commit — the flaky version was never committed)

### Undeclared files modified

`DownloadStoreTests.swift` (two sites) and `DownloadOwnershipConvergenceTests.swift` (one site) called `storage.userFolderURL(name:)`; deleting the symbol (DEC-B) required converting them to `storage.folderURL(relativePath:)`, which is the identical computation and the idiom already used on the adjacent lines of `DownloadStoreTests`. No assertion changed. This was the price of choosing deletion over demotion, and it is a two-word edit per site.

### Files declared but not modified

None — all five files in the plan's `files_modified` were changed.

---

**Total deviations:** 1 auto-fixed (a flake this plan's own test introduced), plus 3 mechanical test call-site conversions forced by DEC-B
**Impact on plan:** No behaviour outside the plan's contract changed. The one substantive departure from the plan's text is DEC-C, and the plan explicitly permitted a disposition other than routing at that site.

## Issues Encountered

- **A refusal-only assertion would have been green over half the table.** Three of six arguments already failed pre-fix, two of them with `.notFound`. Asserting the error family rather than merely "some failure" is what made them discriminate — the same lesson 15-63 recorded, re-confirmed on the sibling.
- **The symlink argument needed the LINK's survival, not the target's.** Pre-fix `removeItem` removed the link and left `Keeper` untouched, so "the folder still exists" passes over the defect. The case asserts the link's presence and that it still resolves to `Keeper`.
- **The nested argument is RED twice over and only one half is visible from the error.** The folder was erased *and* all three stores kept their entries; the store assertions PASSED pre-fix, which is the divergence. Reading them as "passing" would be the wrong lesson — they pass on both sides of the fix, and their job is to make the erasure's consequence explicit in the case rather than in the report.

## Verification Evidence

Run one `xcodebuild` invocation at a time, with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`. The plan's `-only-testing:DownloadsFeatureTests/DownloadFolderOperationTests` selector names a real suite here (the struct is declared in that file), so 15-67's non-selecting-filter hazard did not apply — confirmed by the reported count moving from 11 to 12.

1. Task 1 RED gate — **TEST FAILED**, 12 tests / **9 issues**, exactly the observations banked above. (A first run with the same 9 issues was discarded and re-run after the determinism fix; both are RED, the second is the one committed.)
2. Task 2 gate — the same invocation after the fix — **TEST SUCCEEDED**, 12 tests in 1 suite.
3. Full `FeatureTests` — **TEST SUCCEEDED**, **946 tests / 0 failures** across 22 targets (baseline 945, +1 for the new parameterized case); downloads target **427 in 72 suites** (+1, no new suite). Zero `warning:` lines in the whole run.
4. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1568DerivedData build` — **BUILD SUCCEEDED**, **0 warnings, 0 errors** (the SwiftLint build-tool plugin runs in-build, so this is lint-clean over `Sources/`).
5. Standalone SwiftLint `--strict` over `Sources/DownloadClient` and `Tests/DownloadsFeatureTests` (the app scheme does not lint `Tests/`) — **0 violations**.

Acceptance greps and lint metrics:

- `rg -n 'userFolderURL' App AppPackage ShareExtension` → one hit, the tombstone comment.
- `rg -n 'deleteUserFolder' AppPackage/Sources` → declaration + exactly one coordinator caller (+ one doc reference).
- `rg -n 'confinedDirectUserFolderURL' AppPackage/Sources` → the declaration, the rename's four uses, the shared mutation helper's two, and the coordinator's two RESOLUTION-only uses. No mutation bypasses it.
- File lengths: `+Operations.swift` 801, `DownloadStore.swift` 934, `+Folders.swift` 323, `+PublicAPI.swift` 432, `DownloadFolderOperationTests.swift` 700 — all under the 1000-line error. `DownloadContinuedSessionTests.swift` (993) and `DownloadFeatureTestHelpers.swift` (989) were not touched, and nothing was added to either.
- Line lengths: no line over 120 in any touched file.
- `git diff --diff-filter=D --name-only HEAD~1 HEAD` → empty on both task commits.
- No `swiftlint:disable`, no `try?`, no force unwrap, no new localized catalog entry (both refusals reuse `downloadStoreInvalidFolderName` / `downloadStoreFolderAlreadyExists`).

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift` — FOUND
- Commit `7699168b` — FOUND
- Commit `2d6e0e8a` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced. Every symbol added has a live production consumer: `deleteUserFolder` from `deleteFolder`, `createUserFolder` from `createFolder`, `ensureUserFolder` from `moveDownload`, and `mutatingConfinedUserFolder` from all three.

## Threat Flags

None. The plan's registered threats are addressed rather than extended: T-15-68-01 by the store-owned confined delete with its in-closure re-check and directory-type guard, pinned by six arguments asserting bytes intact; T-15-68-02 by symlink resolution ahead of `removeFolder(at:)`'s containment plus user-folder deletion no longer routing through it; T-15-68-03 by the cleanup key becoming exact by construction, with convergence asserted on both outcomes; T-15-68-04 (accepted) by leaving the existing hash-masked logging untouched — no log line was added or moved, so `DownloadLogPrivacyInvariantTests` is green with its masked total unchanged. No new network endpoint, auth path or schema was introduced, and every filesystem mutation in this family now has strictly fewer reachable arguments than before.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **CR-02 / verification gap 3 is closed at its root and as a family.** The delete escape catalog is fully refused with bytes intact, the nested-name unbounded-loss case is closed, every user-folder mutation site is routed or dispositioned, and `userFolderURL(name:)` cannot regress into a mutation target because it no longer exists.
- One deliberate narrowing, the sibling of the one 15-63 recorded for rename: a root-level directory created outside the app whose name is not its own normalized form (padding, a trailing dot, over 255 UTF-8 bytes) is now listed but not deletable in-app, for the same reason it is not renameable — deleting it would mean choosing a different directory than the user pointed at. Moving a download *into* such a folder is likewise refused. Enqueueing into one is deliberately still allowed (DEC-C), so an existing download in such a folder can still be re-queued.
- `removeFolder(relativePath:)` is public with no production caller. It is not dead-code removal this plan was scoped for, and its containment is now strictly stronger than before; recorded here so a later cleanup round can decide it deliberately.
- Remaining `15-REVIEW.md` items untouched and independent: **CR-01** (the unbracketed `advanceQueueIntentGeneration`, verification gap 1) and **CR-03/gap 2's read-path half** — 15-67 closed WR-01 and WR-02, but the `discardingRejected` default flip and `scanCompletedFolder`'s non-reconciling sweep are separate. WR-04/WR-05 (gap 4, partial) also remain.
- 15-67's DEC-C residual is unchanged: `materializeRepairSeed` still discards while scanning the SOURCE folder.
- 15-67's DEC-E split-before-growing rule still applies to `DownloadContinuedSessionTests.swift` (993) and `DownloadFeatureTestHelpers.swift` (989); this plan added nothing to either, and put its whole escape environment in `DownloadFolderOperationTests.swift` (700).

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
</content>
</invoke>
