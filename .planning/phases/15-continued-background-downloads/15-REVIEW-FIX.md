---
phase: 15-continued-background-downloads
fixed_at: 2026-08-11T21:30:00Z
review_path: .planning/phases/15-continued-background-downloads/15-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 4
skipped: 1
status: partial
---

# Phase 15: Code Review Fix Report

**Fixed at:** 2026-08-11T21:30:00Z
**Source review:** `.planning/phases/15-continued-background-downloads/15-REVIEW.md` (fourth review)
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (WR-01 … WR-05; 0 Critical, `fix_scope: critical_warning` so the 5 Info
  findings are out of scope)
- Fixed: 4
- Skipped: 1

Every fix was verified by a full package test run (`AppPackage-Package` on the pinned iPhone Air
simulator) before its commit: `** TEST SUCCEEDED **`, zero `✘`, and zero compiler or SwiftLint
diagnostics attributable to the change. Work was done in an isolated git worktree and
fast-forwarded onto `feature/gsd-phase-15`.

## Fixed Issues

### WR-01: A staged case-only rename could strand the user's logs in `Logs-migrating-<UUID>` permanently

**Files modified:** `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift`,
`AppPackage/Tests/AppToolsTests/LogsDirectoryMigrationTests.swift`
**Commit:** `32132857`

**Applied fix:** Both halves of the reviewer's remedy.

1. A fourth regime, `Regime.recoverStaging(named:)`, keyed on a new private `stagingPrefix`
   (`"\(Defaults.FilePath.logs)-migrating-"`, derived from the *current* constant since a residue is
   this type's own making, unlike the frozen `legacyDirectoryName`). It is classified **ahead of**
   the legacy-name guard, because a residue is precisely the state in which the legacy name is
   already gone — which is why no prior regime could see it. The listing is `sorted()` first so
   which residue is picked is a function of the names, not of filesystem ordering. `run` routes it
   through a new `recoverStaging(_:to:fileManager:)`: move onto `Logs` when free, fold in through
   `mergeContents` when occupied, and it carries the same `isDirectory` guard the legacy name has,
   since the staging name is user-visible under File Sharing too.
2. `renameThroughStaging`'s merge-with-skips exit now falls through to `restore` as well. The
   discriminator is exact rather than approximate: `mergeContents` removes the directory it merged
   *from* only when it emptied it, which is exactly `.merged(_, skippedCount: 0)`, so every other
   outcome leaves the staged directory standing and is restored. `restore` was regeneralized from
   `after reason: String` to `reporting outcome: Outcome`, returning the fold-in's own outcome on a
   successful restore and only downgrading to `.failed` when the restore itself fails.

`Outcome.failed`'s doc claim that "the next launch retries from the state left behind" is now true
for every state this type can leave, and the module header records why the staging name is a
first-class regime rather than an internal detail.

**Tests added (6, all passing):** `aStoredStagingNameIsRecovered`,
`aStoredStagingNameOutranksEveryOtherRegime`, `whichResidueIsPickedDoesNotDependOnTheListingOrder`,
`aStagedResidueIsRecoveredOntoAFreeDestination`,
`aStagedResidueIsFoldedIntoAnOccupiedDestinationAndConverges` (this is the reviewer's third case —
a second `run` over exactly the state the first left behind, asserting convergence), and
`aRegularFileWithTheStagingPrefixIsLeftAlone`.

**Residual, stated rather than hidden:** `renameThroughStaging`'s own two exits still cannot be
driven directly — they need a `Logs` directory to appear *between* the function's two moves, which
no fixture can stage without a `FileManager` seam this module deliberately does not have. What the
new cases pin instead is the state those exits leave behind and its recovery, which is what makes
the exits non-terminal. That is the property the finding was about.

### WR-02: `mergeContents` recursively deleted its source on a stale-listing premise

**Files modified:** `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift`,
`AppPackage/Tests/AppToolsTests/LogsDirectoryMigrationTests.swift`
**Commit:** `06bff82b`

**Applied fix:** The removal is now licensed by a listing taken at the moment of removal instead of
by `decision.skips`, which describes the directory as it was *before* the moves. A file that
appeared in `source` in that window is counted into `skippedCount` and left alone rather than being
destroyed by the recursive `removeItem`.

**Deviation from the suggested patch, deliberate:** the review's snippet uses
`(try? fileManager.contentsOfDirectory(...)) ?? ["<unlistable>"]`. `try?` is banned as an *error* by
this project's `optional_try` custom lint rule, so the re-listing is a `do`/`catch` that reports
`.failed` with the underlying description when the directory cannot be listed. This also keeps the
invariant WR-01's fix depends on intact — the source directory was removed **iff** the outcome is
`.merged(_, skippedCount: 0)`.

The doc was corrected as asked: the false "Nothing is ever overwritten or deleted" is replaced with
what is true — nothing at the destination is overwritten, no *file* is deleted, and the source
*directory* is removed only on a fresh listing showing it empty — plus the reason the guarantee
cannot rest on caller behaviour (`public`, two arbitrary URLs). `Outcome.merged`'s doc now says
`skippedCount` counts everything left behind, not only destination collisions.

**Test added:** `aFileAppearingWhileTheMergeRunsIsNeitherDeletedNorMiscounted`, which stages the
race deterministically with a `LateWriteFileManager` double that drops one file into the directory
it has just moved a file out of. It discriminates: pre-fix the run reports `.merged(1, 0)` with the
late file destroyed; post-fix it reports `.merged(1, 1)` with the bytes intact. Both halves are
asserted, since a fix that merely stopped removing would still leave the file uncounted.

### WR-03: The migration's only failure diagnostic was redacted, and the per-file errors behind it were discarded

**Files modified:** `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift`,
`AppPackage/Sources/AppTools/LogsDirectoryMigration.swift`,
`AppPackage/Tests/AppToolsTests/LogsDirectoryMigrationTests.swift`
**Commit:** `da5a0675`

**Applied fix:** Both the consumer and the producer.

- The `.failed` branch now logs `\(reason, privacy: .public)`, matching the two `.notice` branches
  three lines above. The comment records why the payload is safe to publish: `Outcome.failed`'s
  reason is app-authored prose over the app's own container and its own log file names, with
  nothing gallery-derived or user-authored in it.
- `mergeContents`' per-file `catch` accumulates `(name: String, error: any Error)` instead of
  swallowing the error, and a new `failureReason(_:outOf:)` builds a reason that names the first
  `namedFailureCount` (3) failures by file and by cause, then counts the remainder so the list never
  reads as exhaustive. The cap is deliberate — a directory whose every move fails would otherwise
  produce a log line as long as the directory, and such failures share one cause far more often than
  not.

**Test added:** `aFailedMoveIsReportedByNameAndByCause`, driven by a `RefusingMoveFileManager`
double and a sentinel `RefusedMove` error. All three parts are asserted — the count, the file name,
and the cause's text — because the count alone is what this used to carry.

### WR-04: `moveDownload` could mint a folder name the app's own minting rules refuse

**Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift`
**Commit:** `a5b9e3f5`

**Applied fix:** A minting guard sits between the admission guard and `blockScheduling`, so it
precedes every side effect and needs neither a release nor a convergence — the same placement
property the existing invalid-name guard documents. `ensureUserFolder` is left in place; what
changed is that reaching it is now licensed.

**Deviation from the suggested patch, and why it matters:** the review's snippet licenses creation
solely by `normalizedUserFolderName(folderName) == folderName` whenever the destination parent does
not exist. Applied literally that **regresses CR-01**: `"Art  Books"` is a real listed folder the
app would spell `"Art Books"`, so a user who removed it through the Files app could no longer be
moved back into it. The guard shipped here licenses creation by either of the two things that make
a folder this app's to make:

```swift
guard fileManager.operate({ $0.fileExists(atPath: destinationParentURL.path) })
        || userFolders.contains(folderName)
        || storage.normalizedUserFolderName(folderName) == folderName
else { ... }
```

A folder that is already there mints nothing; a name the listing carries is recreated verbatim
(CR-01's property); a name the app would mint is minted. All four rows of the review's table fail
all three clauses and are refused.

**Tests added:** `testMoveDownloadRefusesToMintANameTheAppWouldNotMake`, parameterized over a new
`UnmintableMoveDestination` catalog carrying exactly the review's four rows (`".hidden"`, `"  "`,
`"Misc etc."`, a 400-byte name), asserted against `moveDownload` through the suite's existing
`expectRefusal` so each is pinned to `.invalidName` rather than to "some failure". Both halves are
checked — the refusal *and* the absence of the folder on disk — because the pre-fix failure was
silent: the folder was created and the move reported success. Plus
`testMoveDownloadRecreatesAListedFolderTheAppWouldNotMint`, the counterpart that fails if the guard
is ever tightened into "normalize the destination", which is the rewrite CR-01 removed.

## Skipped Issues

### WR-05: The per-row delete confirmation is attached to the row, against the project convention that names this exact case

**File:** `AppPackage/Sources/DownloadsFeature/DownloadsView.swift:227-229`
**Reason:** Correct finding, but the remedy is an owner decision that an automated fixer must not
make, and the option the review leads with would regress `9421b7bb` / `15afbde4` into a defect the
owner's own research has already identified.

**Reconciliation against the project's own rule, as required.** The finding is **not** wrong: the
convention's exception says *"for a per-row destructive action whose row can scroll out of view, the
stable action-source is the enclosing list container, so attach it there,"* and the swipe Delete is
exactly a per-row destructive action in a scrolling `List` with its dialog attached to `DownloadRow`.
The review's two supporting observations are also both accurate — the file is internally
inconsistent (the list-level move dialog *is* on the container at line 56), and the given-up
property is untested (a row leaving `visibleRows` while its dialog is up is reachable through a
background `folderName` repoint under an active folder filter, not only through scrolling).

**Why it is nonetheless not fixable here.** The review itself frames the remedy as a choice — *"Either
honour the rule or record the override"* — and both branches are owner-owned:

1. **Honouring the rule** means hoisting the modifier to the `List`. On iOS 26,
   `.confirmationDialog` anchors to its attachment view **on iPhone too**, not only on iPad
   (WWDC25 sessions 284/323). The phase's own choreography research records the consequence in
   terms: *"container attachment ⇒ arrow at list top, wrong-looking for a row action"*, and closes
   with *"re-evaluate the dialog-placement rule for iOS 26 anchoring first."* So this option trades
   a rare, fail-safe teardown (the dialog vanishes; no deletion fires) for a permanently
   wrong-looking anchor on every delete on every device. It also makes `DownloadRowFeature`'s per-row
   state vestigial, undoing the architecture `9421b7bb` deliberately introduced.
2. **Recording the override** is by definition an owner decision, not a code change — the review's
   own words are *"get an owner decision on record rather than a comment."*

The convention's exception predates the iOS 26 anchoring change that its own research flags for
re-evaluation, so the honest resolution may well be to amend the rule rather than the code. Applying
either branch unilaterally would be a guess dressed as a fix, so this is left open.

**Suggested next step for the owner:** decide between (a) amending the
`Confirmation dialog / alert placement` rule in `CLAUDE.md` to carve out per-row destructive actions
whose anchoring is user-visible under iOS 26, keeping the current placement and the reasoning at
`DownloadsView.swift:173-177` as the rule's citation; or (b) hoisting the modifier to the `List` and
accepting the list-top anchor. Either way the untested half is worth closing — a `DownloadsReducer`
test asserting what happens when a row with a presented dialog leaves `rows` (today: the dialog
vanishes silently and the deletion never fires). That test was not added here because it would pin
behaviour that option (b) changes.

## Out of Scope

IN-01 … IN-05 were not attempted (`fix_scope: critical_warning`). Two of them touch code this run
changed and are worth carrying forward:

- **IN-01** (`LogsDirectoryMigration`'s three `public` members exist for the test target alone) is
  now slightly *sharper*: `mergeContents` gained the guard in WR-02 and the failure accumulation in
  WR-03, so the member the finding singles out as the one that should not stay public is the one
  that grew. Nothing in this run widened the surface — `stagingPrefix`, `recoverStaging`, `restore`
  and `failureReason` are all `private`.
- **IN-02** (`run` reports `.nothingToMigrate` for a regular file named `logs`) now has a second
  instance: the `recoverStaging` route reports the same outcome for a regular file carrying the
  staging prefix, pinned by `aRegularFileWithTheStagingPrefixIsLeftAlone`. If the suggested
  `legacyNameIsNotADirectory` case is added, both sites should take it.

---

_Fixed: 2026-08-11_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
