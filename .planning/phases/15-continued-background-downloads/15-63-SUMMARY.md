---
phase: 15-continued-background-downloads
plan: 63
subsystem: downloads
tags: [download-client, filesystem, path-confinement, security, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "DownloadStore's rootURL/normalizedUserFolderName vocabulary and the guarded filesystem-operation layer 15-62 last extended"
provides:
  - "DownloadStore.renameUserFolder: the one place a caller-supplied folder name may reach moveItem"
  - "confinedDirectUserFolderURL: exact-normalization plus standardized AND symlink-resolved direct-child admission"
  - "A refusal contract asserted from disk — the named source survives and the requested destination is never created"
affects: [folder rename boundary, download-root confinement, coordinator/store split]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "An untrusted name is admitted or refused, never repaired: normalizing a source selects a different object than the caller named"
    - "Lexical containment and resolved containment are separate questions; neither implies the other"
    - "Every filesystem fact a mutation depends on is re-decided inside the same lock that performs it"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift

key-decisions:
  - "CR-03: the source is admitted by exact normalization equality, never normalized — normalizing '  Photos  ' renames the real 'Photos', which is a different folder than the caller named"
  - "DEC-A: both parent comparisons are kept because neither implies the other — standardization answers a name that climbs out, resolution answers a name whose leaf links out"
  - "DEC-B: the symlink type check is required beyond resolved-parent equality, for a link pointing at another direct child of the same root"
  - "DEC-C: an unacceptable source returns fileOperationFailed, and .notFound is narrowed to a source the boundary accepted and did not find"
  - "DEC-D: the coordinator's busy guard now precedes existence and collision, which moved into the store with the mutation"

patterns-established:
  - "Assert a filesystem refusal from the filesystem: read both endpoints BEFORE the returned error, so a failing run records what actually moved"
  - "A boundary states its own requirement (single component) rather than inheriting it from what a sanitizer happens to rewrite"

requirements-completed: []

coverage:
  - id: D1
    description: "Traversal, absolute-path and nested sources are refused with the named source still in place and the destination never created"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift#testRenameFolderRefusesASourceThatIsNotADirectChild"
        status: pass
    human_judgment: false
  - id: D2
    description: "A source spelling normalization would change is refused rather than resolved onto the real sibling it would normalize to"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift#testRenameFolderRefusesASourceThatIsNotADirectChild (whitespacePaddedAlias, separatorSanitizedAlias)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A direct-child symlink escaping the root is refused with the outside target's bytes and the link itself untouched"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift#testRenameFolderRefusesASymbolicLinkSourceEscapingTheRoot"
        status: pass
    human_judgment: false
  - id: D4
    description: "Valid direct-child rename, index repoint, busy-download refusal and every other folder operation are unchanged"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (931 tests, 0 failures; downloads target 412 in 71 suites)"
        status: pass
    human_judgment: false

# Metrics
duration: 30min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 63: Folder Rename Root Confinement Summary

**CR-03 closed: a caller-supplied rename source now crosses one store-owned boundary that admits only an exactly-normalized single component whose standardized AND symlink-resolved parent is the download root, re-decided inside the lock that performs the move.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-08-10T01:34Z
- **Completed:** 2026-08-10T02:04Z
- **Tasks:** 2 (RED, GREEN)
- **Files created:** 0
- **Files modified:** 3

## Accomplishments

- **The defect was a missing boundary, not a wrong check.** `renameFolder` normalized `newName` and then handed `oldName` straight to `userFolderURL`, which only appends a component to the root. Nothing between that append and `moveItem` asked whether the result was still inside the root. The RED run recorded the consequence verbatim: with `oldName == "../Outside"` the directory at `…/<container>/Outside` — created outside the download root — was gone after the call, and `…/Downloads/Captured` existed in its place, with the operation reporting `success()`. That is `moveItem` reaching outside `rootURL` on public client input.
- **The source is admitted, never repaired, and that is the whole design.** The obvious fix — normalize `oldName` the way `newName` is normalized — is wrong in a way the two alias arguments pin: `"  Alias Target  "` and `"Alias:Target"` both normalize onto the REAL direct child `"Alias Target"`, so a normalizing boundary would happily rename a folder the caller never named. `confinedDirectUserFolderURL` therefore requires `normalizedUserFolderName(raw) == raw` byte for byte and refuses everything else. Pre-fix both arguments returned `.notFound` — the right refusal by accident, because the padded path simply did not exist; post-fix they are refused as names, which is a claim about the request rather than about the disk.
- **Two parent comparisons, because neither implies the other (DEC-A).** Standardized parent equality answers `..`, `Nested/Child` and an absolute path — every name that climbs out lexically. Symlink-resolved parent equality answers the name that is lexically perfect and still points elsewhere. The symlink argument passes all four lexical checks and is caught only by resolution, which is why the plan required both rather than a `hasPrefix` on a standardized path.
- **The symlink TYPE check is not redundant with resolution (DEC-B).** A link at `root/Linked` pointing at `root/Real` resolves to a parent that IS the root, so resolved-parent equality admits it — and renaming it would move the link while `Real` stayed put, leaving the read model naming a folder that does not exist. `attributesOfItem` describes the item rather than its target, so `.typeSymbolicLink != .typeDirectory` refuses it. The escaping link is refused twice over, by resolution and by type.
- **Every filesystem fact is re-decided at the mutation.** `confinedDirectUserFolderURL` runs again inside the `fileManager.operate` closure, immediately before `moveItem`, together with the source's type and the destination's absence. The re-run is not ceremony: the leaf's symlink status and the root's own resolution are disk state, and a decision taken before the lock is a decision about a disk that may since have changed (T-15-63-03).
- **The refusal contract is read off the disk, then off the error.** Both cases assert the named source still exists and the requested destination does not BEFORE inspecting the returned `Result`. Ordering it this way is what made the RED run state the escape in its own words instead of stopping at "expected failure, got success" — and it is the only ordering under which a rename that moved something and then reported a failure cannot pass.

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — exercise lexical, path-boundary, and symlink escape attempts** - `eae3068a` (test)
2. **Task 2: GREEN — enforce direct-child confinement inside DownloadStore** - `581f0c3f` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` - new `renameUserFolder(oldName:newName:) throws` with the CR-03 doc stating both refusals; new private `confinedDirectUserFolderURL(named:)` (non-empty, not `.`/`..`, exactly one path component, exact normalization equality, standardized parent == standardized root, resolved parent == resolved root); new private `itemType(at:using:)` and `invalidUserFolderNameError()`.
- `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` - `renameFolder` keeps the busy guard, post-failure reload, index repoint and observer notification and delegates the mutation to `storage.renameUserFolder`; the unconstrained `userFolderURL(name: oldName)` and the direct `moveItem` are gone; the same-name short circuit compares names; the private index-repoint helper renamed `renameUserFolder` → `repointRenamedUserFolder` so the two consecutive lines at the call site do not read as the same operation.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift` - new `RenameEscapeSource` table (6 arguments) and its parameterized case; new symlink case; new `DownloadFolderEscapeEnvironment` plus `makeEscapeEnvironment()` nesting the download root one level inside a container the test owns. No existing case was touched.

## Decisions Made

- **DEC-A: both parent comparisons are kept.** Collapsing to the resolved one alone would drop a cheap, total lexical answer and make every refusal depend on the filesystem being readable; collapsing to the standardized one alone re-opens the symlink argument. They are different questions.
- **DEC-B: type is checked as well as resolution.** Resolution cannot refuse a link that points at a sibling direct child, and that link is still not the folder the caller named. The check costs one `lstat` on a path already being stat'd.
- **DEC-C: `.notFound` is narrowed.** Pre-fix, three of the six escape arguments returned `.notFound` — true of the constructed path, misleading about the request, and an invitation to create the "missing" folder. `.notFound` now means only "a name this boundary accepted, with nothing there"; everything else is `.fileOperationFailed` carrying the invalid-folder-name string, which is the surface the plan required rather than a new public error case.
- **DEC-D: the busy guard now precedes existence and collision.** Those two moved into the store with the mutation, so the coordinator's guard is what remains ahead of them. Nothing observable turns on the order: the guard keys on an indexed record's `parentFolderName`, which is always a real direct child produced by the filesystem scan, so it cannot fire for any name the store would refuse. Recorded on the function.
- **DEC-E: the escape environment nests the download root inside its own container.** `..` from the root has to name something, and pointing it at the shared system temporary directory would make a test's failure mode "attempt to move the temp directory". The container is created and removed by the case, so `..` and the outside sibling are both test-owned.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] The private index-repoint helper shadowed the new store operation's name**

- **Found during:** Task 2 (GREEN)
- **Issue:** `DownloadClient+Folders.swift` already had a private `renameUserFolder(oldName:newName:)` that repoints the in-memory index. After the delegation landed, `storage.renameUserFolder(...)` and `renameUserFolder(...)` sat four lines apart doing entirely different things — one the filesystem, one the read model — with only the receiver to tell them apart. The plan mandates the store symbol's name, so the collision had to be resolved on the coordinator's side.
- **Fix:** Renamed the private helper to `repointRenamedUserFolder(oldName:newName:)` and gave it a doc comment saying which half it owns. Private, single call site, no behavior change.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift`
- **Verification:** `grep -n "renameUserFolder" AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` shows the store call and the doc references only; full suite green.
- **Committed in:** `581f0c3f` (Task 2 commit)

### Test-file scope

Task 2 declares `DownloadFolderOperationTests.swift` in its `<files>` for making the RED cases green "without relaxing disk-state assertions". No edit was needed: the fix made all 12 recorded issues disappear with the assertions exactly as Task 1 committed them. The file is unchanged between `eae3068a` and `581f0c3f`.

---

**Total deviations:** 1 auto-fixed (a name collision this change created)
**Impact on plan:** None outside the plan's contract. No assertion was weakened and no check was relaxed to make a case pass.

## Banked Falsifiability

The RED cases failed against pre-fix production with **12 verbatim issues** across 6 of the 7 new arguments:

| Argument | Pre-fix (recorded) | Post-fix |
|---|---|---|
| `traversalToSibling` | `fileExists(…/<container>/Outside)` FAILED, `!fileExists(…/Downloads/Captured)` FAILED, result `success()` | outside directory intact, no destination, refused |
| symlink case | `fileExists(…/Downloads/Linked)` FAILED, `!fileExists(…/Downloads/Captured)` FAILED, result `success()` | link and target intact, no destination, refused |
| `nestedComponents` | `fileExists(…/Alias Target/Nested)` FAILED, result `success()` | nested directory intact, refused |
| `absolutePath` | result `failure(AppError.notFound)` | `fileOperationFailed`, refused as a name |
| `whitespacePaddedAlias` | result `failure(AppError.notFound)` | `fileOperationFailed`, refused as a name |
| `separatorSanitizedAlias` | result `failure(AppError.notFound)` | `fileOperationFailed`, refused as a name |

`parentDirectory` (`oldName == ".."`) PASSED pre-fix and is the boundary pin rather than the discriminator: `rename(2)` returns `EINVAL` when the destination is inside the source, so the kernel refused what the app did not. The logged `NSPOSIXErrorDomain Code=22 "Invalid argument"` is recorded here because it is the reason the argument is safe to run at all — the case documents that the pre-fix code reached the syscall with the root's parent as its source.

The first RED run asserted the returned error before the disk; it produced 6 issues and reported only "got success()". Reordering to read the filesystem first raised the same run to 12 issues and made the escape self-describing. Both runs are RED; the second is the one banked, and the ordering is now a stated property of the cases.

## Issues Encountered

- **Three of the six escape arguments were already refused pre-fix, for the wrong reason.** `absolutePath`, `whitespacePaddedAlias` and `separatorSanitizedAlias` all returned `.notFound`, because appending a padded or absolute string to the root yields a path that happens not to exist. A refusal-only assertion would have been green over the defect in half the table; asserting the error FAMILY (an invalid name, not a missing one) is what made them discriminate, and it is also the behavior CR-03 asks for.
- **The symlink case needed the target's bytes, not the link's survival.** Pre-fix, `moveItem` renamed the link and left the outside directory alone, so "the target still exists" passes over the defect. The case asserts the sentinel file's contents, the link's own presence, and the link's destination after the refusal.

## Verification Evidence

Run one xcodebuild invocation at a time, `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`:

1. Task 1 RED gate — `-only-testing:DownloadsFeatureTests/DownloadFolderOperationTests` — **TEST FAILED**, 11 tests, 12 issues.
2. Task 2 gate — same invocation — **TEST SUCCEEDED**, 11 tests in 1 suite, 0 warnings.
3. Full `FeatureTests` — **TEST SUCCEEDED**, **931 tests / 0 failures** across all targets (929 baseline + 2); downloads target 412 tests in 71 suites (+2). Zero `warning:` lines in the whole run.
4. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1563DerivedData build` — **BUILD SUCCEEDED**, **0 warnings** (the SwiftLint build-tool plugin runs in-build, so this is lint-clean over `Sources/`).
5. Standalone SwiftLint `--strict` over all 3 touched files (the app scheme does not lint `Tests/`) — **0 violations, 0 serious**.

Acceptance greps:

- `grep -n "moveItem" AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` → one hit, inside `moveDownload`; `renameFolder` has none.
- `grep -n "userFolderURL(name: oldName)" AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` → no hit.
- `grep -c "func renameUserFolder" AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` → exactly 1 declaration; the only caller is `storage.renameUserFolder` in the coordinator.
- No `hasPrefix` containment is used on the rename path; the two parent equalities are exact.
- `git diff --diff-filter=D --name-only HEAD~2 HEAD` → empty on both task commits.
- File lengths after the change: `DownloadStore+Operations.swift` 620, `DownloadClient+Folders.swift` 286, `DownloadFolderOperationTests.swift` 434 — all well under the 1000-line error.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift` — FOUND
- Commit `eae3068a` — FOUND
- Commit `581f0c3f` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced; every symbol added has a live production consumer.

## Threat Flags

None. The plan's registered threats are addressed rather than extended: T-15-63-01 by exact normalization equality plus standardized direct-parent equality, T-15-63-02 by resolved-parent equality plus the symbolic-link type rejection, T-15-63-03 by re-deciding both inside the `operate` closure that calls `moveItem`, and T-15-63-04 (accepted) by leaving the collision and busy guards in place on the established recoverable-error surface. No new network endpoint, auth path or schema was introduced, no log line was added, and the one filesystem mutation now has strictly fewer reachable arguments than before.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-03 is closed at its root. `15-REVIEW.md`'s remaining blocker CR-04 (an invalid page selection widening into a whole-gallery repair) is independent and untouched; CR-01 closed in 15-62 and CR-02 in 15-61.
- Two neighbours were audited rather than assumed while the boundary was written, and both are already confined: `moveDownload` takes its source from the index (`download.folderURL`) and normalizes its destination folder name, and `deleteFolder` routes through `storage.removeFolder(at:)`, whose standardized prefix check refuses a traversing path. Neither is a hole; neither is in this plan's scope. A symlinked direct child would be *removed as a link* by delete, which is the correct outcome there.
- One narrowing worth knowing: a root-level directory created outside the app whose name is not its own normalized form (padding, a trailing dot, over 255 UTF-8 bytes) is now listed but not renameable in-app. That is the deliberate consequence of refusing rather than repairing a source; renaming it would mean choosing a different directory than the user pointed at.
- `DownloadFeatureTestHelpers.swift` remains at 976 of the 1000-line limit; this plan added nothing there — the escape environment is local to `DownloadFolderOperationTests.swift`, which is at 434.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
