---
phase: 15-continued-background-downloads
plan: 43
subsystem: downloads
tags: [swift, downloads, continued-processing, reconciliation, trust-basis, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "D-G5-01's three reconciliation refusal exits (rounds 11/12/13) and D-G4-01's trust-rationed basis, whose interaction this plan closes"
  - phase: 15-continued-background-downloads
    provides: "15-42's `ExpirationPauseTarget` rework of `pauseAllSchedulable`, which shares `DownloadClient+ContinuedSession.swift` with this plan's doc corrections"
provides:
  - "G-15-23 closed at the FAMILY: the run-start announcement follows real page work, so all three refusal kinds over a complete-reading record announce and earn trust"
  - "The trust set's first `insert` writer, issued at the run's own preparation ahead of its push"
  - "Two ledger regressions — the K=N residual refusal and the failed-enumeration companion — in a new extension file of the ledger suite"
  - "The trust-writer census, the real-page-work predicate derivation, and the D-G7-01 bracket-side derivation recorded in source docs"
affects: [continued-background-downloads verification, SC1, SC2]

tech-stack:
  added: []
  patterns:
    - "Gate a session-accounting announcement on what the run will actually FETCH (`existingPages.count < manifest.pageCount`, the same predicate `pendingPageIndices` filters on) rather than on what the record claims"
    - "Grant trust after the enclosing withdrawal bracket closes, so the granting movement withdraws nothing and every later movement of the same gid withdraws its counted portion"
    - "Replace a doc's site-count claim with the RULE the sites obey, so adding a writer cannot make the doc false"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift

key-decisions:
  - "15-43: the announcement gate REPLACES the completeness test rather than OR-ing with it, and the one shape that loses its announcement is derived and documented rather than left implicit — a record reading incomplete while its folder holds every page it claims. `pendingPageIndices` fetches nothing there, so trusting it would retire N pages this session never downloaded, which is exactly the D-G4-01 ceiling. Under-reporting is the direction D-G4-01 and the retirement ledger both choose deliberately."
  - "15-43: the failed-enumeration companion drops the folder to `0o311` (write+execute, no read), not the plan's literal `0o000`. Source discipline: `0o000` also denies the by-name `manifest.json` open that `ensureWorkingManifest` needs, so the staging would fail before reaching the refusal. `0o311` is the shape the existing wholesale-failure case already derives, and it isolates the lost LISTING."
  - "15-43: the companion stages FIVE of six page files, not all six. `resumeMode` must resolve `.repair` through its missing-files branch to ground the production route, and with every file present `storage.validate` reports `.valid` and the route becomes `.redownload`, which deletes the folder and never reaches a refusal at all."
  - "15-43: `restorePermissions` was promoted from the reconciliation file's private extension into `DownloadFeatureTestHelpers.swift` rather than duplicated, since both refusal families now stage an unreadable working folder. No case body changed."
  - "15-43: `pageResults(for:in:indices:)` stays file-private in the new test file rather than joining the shared helpers. Both consumers are in that file, and the shared surface earns a member when a second suite needs one."

patterns-established:
  - "A ledger-side companion file for a defence's REFUSAL family: the reconciliation suite asserts what a refusal does to the manifest, the ledger extension asserts what the session goes on to report for the run that follows one"
  - "A case doc that records why a standard series helper is deliberately NOT asserted, so the omission reads as a derived property of the family rather than as a weakened assertion"

requirements: [SC1, SC2]
status: complete
---

# Phase 15 Plan 43: Real-Page-Work Announcement and Explicit Trust Summary

A reconciliation that refuses over a complete-reading record now announces its run and admits the gallery to the session's trust set, so a repair whose files are gone climbs its card honestly instead of finishing a terminal `0 / 1 page · 0 galleries` over N pages of real work.

## What was built

**Task 1 — the family regressions, RED-first** (commit `1a201867`).

`AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift`, an
`extension DownloadContinuedSessionLedgerTests` (no new `@Suite`: membership, traits and test
identity preserved, the 15-41 relocation pattern applied to additions). A new file because the
ledger suite sits at 812 lines against a `file_length` limit of 1000 at error severity — and it
stayed at 812, untouched.

- `testAnAllPagesGoneRepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull` — the K=N residual
  refusal. The K=1 case's staging with exactly one difference: no page file is written at all, so a
  successful scan accounts for none of the six claimed pages and `blankedPageCount == 6 ==
  completedPageCount` trips the residual exit. Carries the queued-window zero assertion
  (`spy.startSubtitles.last == "0 / 6 pages · 1 gallery"`), which is D-G4-01's ceiling pin.
- `testAFailedEnumerationRepairOfACompleteReadingRecordStillEarnsSessionTrust` — the directory-level
  refusal. Five of six page files present (the sixth missing is what grounds `.repair`), then the
  working folder dropped to `0o311` so `contentsOfDirectory` throws `EACCES` while the by-name
  manifest read still works, with the permissions-restoring `defer` discipline.

Both ground the route through production — `#expect(await manager.resumeMode(for: staged) ==
.repair)` before `retryPages` — and every push asserted is production-issued: the session ensure
inside `retryPages`, its convergence push, the preparation's own announcement, and the drain's. No
push is hand-issued, and the ledger file's private index-patch seam is not used; record state comes
only from fixture manifests, `writePageFiles` and production writes.

`expectTheFractionReachesOneOnlyAtTheDrain` is deliberately not asserted on this family, recorded in
the K=N case's doc: a trusted complete-reading record honestly rides at its own ceiling during a
refused repair, since the record genuinely claims N and the refusal is the defence against
destroying those N hashes. The harm the case pins is the pinned-ZERO run, not the ceiling.

**Task 2 — the gate, the insert, the docs** (commit `8570cd5b`).

The only executable change in the whole plan, in `prepareWorkingSeedAnnouncingProgress`:

```swift
let hasRealPageWork = workingSeed.existingPages.count < workingSeed.manifest.pageCount
if let continuedSessionID, hasRealPageWork {
    observedIncompleteSessionGIDs.insert(payload.gallery.gid)
    await pushContinuedSessionProgress(sessionID: continuedSessionID)
}
```

`git diff -U0` over `AppPackage/Sources/DownloadClient/` outside doc comments is exactly those three
added lines and the one replaced condition — `reconcileWorkingManifestAgainstPageFiles`,
`schedulableSnapshot`, `shouldSchedule` and the retirement ledger have no executable change.

## Step-0 derivations (taken from source before any edit)

**The `observedIncompleteSessionGIDs` writer census**, `grep -rn` over `AppPackage/Sources`, nine
occurrences:

| Site | Kind |
|------|------|
| `+Manager.swift:522` | declaration |
| `+ContinuedSession.swift:215` (`ensureContinuedSession`) | reset to `[]` |
| `+ContinuedSession.swift:350` (`markContinuedSessionEnded`) | reset to `[]` |
| `+ExecutionSupport.swift:275` (`withdrawingCountedBasisMovement`) | read — `wasCountedBasis` |
| `+ContinuedSession.swift:138` (`schedulableSnapshot`) | read — `isSessionWork` disjunct |
| `+ContinuedSession.swift:539` (`reconcileRetiredSessionPages`) | read — departure gate |
| `+ContinuedSession.swift:274` (start seed) | additive — `formUnion(snapshot.incompleteGalleryIDs)` |
| `+ContinuedSession.swift:559` (push reconcile) | additive — `formUnion(snapshot.incompleteGalleryIDs)` |
| `+ContinuedSession.swift:511` | doc mention only |

The verifier's claim is CONFIRMED: both additive writers take `snapshot.incompleteGalleryIDs`, built
at `+ContinuedSession.swift:152` as `Set(downloads.filter(\.isIncomplete).map(\.gid))`, so neither
can contain a record that reads complete. An announcement without an insert would provably have
changed nothing on this family. No `insert` existed before this plan.

**The real-page-work predicate, derived not assumed.** `workingSeed.existingPages` is assigned from
`destinationScan.pages` (`+ExecutionSupport.swift`, inside `prepareWorkingSeed`), and
`DownloadStore.pageFileScan` fills `pages` only with manifest-claimed page numbers whose file the
listing yielded AND whose probe returned `.usable` — `.rejected` and `.unprobeable` never land
there, and a failed listing returns `pages: [:]` outright. `pendingPageIndices`
(`+ExecutionSupport.swift:726`) then filters `1...pageCount` down to exactly the pages absent from
that map, ignoring the manifest's hash claims entirely. So `existingPages.count < manifest.pageCount`
is precisely "this run has pages to fetch". Branch by branch:

- failed enumeration → `pages == [:]` → `0 < N` true;
- all-unprobed → unprobed pages are not in `pages` → true;
- all-or-nothing residual → the scan accounted for none of the N claimed pages → `0 < N` true;
- proceeding branch (some file gone) → that page is not in `pages` → true, as `!isComplete` was;
- fresh all-empty manifest (`.update`/`.redownload`/`.initial`) → `existingPages` empty → true;
- folder supplies every claimed page → `N < N` false, correctly: that redo downloads nothing.

**The bracket-side derivation (D-G7-01).** The insert lands AFTER the bracket has closed:
`prepareWorkingSeed` opens and closes `withdrawingCountedBasisMovement` around its own movements and
has returned before the announcing wrapper's `if` runs. So the preparation's OWN movement is measured
against the pre-announcement trust state — an untrusted complete-reading record read `wasCountedBasis`
false, contributed nothing to the floor and withdraws nothing from it, which keeps D-G4-01's ceiling
guarantee intact. Every LATER movement of the same gid in the same session finds `wasCountedBasis`
true through the trust set and withdraws its counted portion, correct because from the announcement
on the gallery's pages really are in the numerator. Recorded in the function's doc as well as here.

## RED readings and green flips

Pre-fix (`Test-EhPanda-2026.08.06_00-44-45-+0900.xcresult`), both cases, all pre-existing ledger
cases passing in the same run:

```
:116: (spy.progressUpdates.map(\.subtitle) → ["0 / 6 pages · 1 gallery"]).contains("6 / 6 pages · 1 gallery")
:128: (terminalPair.completedUnitCount → 0) == 6
:129: (terminalPair.totalUnitCount → 1) == 6
:130: (terminalPair.subtitle → "0 / 1 page · 0 galleries") == "6 / 6 pages · 0 galleries"
:214: (spy.progressUpdates.map(\.subtitle) → ["0 / 6 pages · 1 gallery"]).contains("6 / 6 pages · 1 gallery")
:228: (terminalPair.completedUnitCount → 0) == 6
:229: (terminalPair.totalUnitCount → 1) == 6
:230: (terminalPair.subtitle → "0 / 1 page · 0 galleries") == "6 / 6 pages · 0 galleries"
```

The predicted shape exactly: the only push the session ever made was the queued-window zero, and the
drain reported `0 / 1 page · 0 galleries` — G-15-5's terminal card over six pages of real work.

Post-fix: `Test run with 15 tests in 1 suite passed`. Both new cases green with no assertion changed,
and the pins that had to hold did — `testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull`
(K=1, the proceeding side), `testACompleteGalleryQueuedForUpdateOpensTheCardAtZero` (the ceiling),
`testAnAnnouncementDuringTheClientStartHopSurvivesTheSeed`, and the three reconciliation-refusal
cases, all byte-unchanged.

## Corrected docs (quoted)

**The single-admission sentence** (`prepareWorkingSeedAnnouncingProgress`). Was: "Session trust is
admitted in exactly one place — the `formUnion` inside a push's `reconcileRetiredSessionPages`".
Now, phrased as the rule rather than as a count so no number can drift:

> **Trust is admitted where the session can OBSERVE incompleteness or PROVE page work.** Those are
> the push-side `formUnion` over a snapshot's incomplete galleries — inside
> `reconcileRetiredSessionPages`, and in the start seed built from the same snapshot shape — and the
> insert below, over a record whose working folder cannot supply the pages its manifest claims.
> Written as that rule rather than as a count of sites, because a count is a number that goes stale
> the moment a writer is added.

**The refuted cost claim** (the D-G5-01 defence doc). Was: "the record's honesty catches up at flush
time". Now:

> What the cost is NOT is a merely delayed honesty. This paragraph used to close by claiming the
> flush restores the record, and for the refusal family that claim is refuted: the flush path is
> monotone upward — `refreshManifestPageFileHashes` only ever assigns non-empty hashes — so a record
> that reads COMPLETE when a refusal hands the manifest back never becomes incomplete during the
> run, and the session's push-side trust writer, sourced from `isIncomplete`, can never admit it.
> What covers that family is the explicit admission in `prepareWorkingSeedAnnouncingProgress`, taken
> on the run's own proof of page work rather than on the record (G-15-23).

**`resumeMode`'s (a)/(b) doc, re-verified and quoted as re-verified** in the same paragraph: a
refusal is exactly its case (a), and the branch still routes such a record to `.repair`. Unchanged.

Also corrected from the census: `schedulableSnapshot`'s D-G4-01 statement and
`reconcileRetiredSessionPages`' "record's authority is earned" paragraph (both said "observed
incomplete" where the set now also holds proven-work gids), `schedulableSnapshot`'s "trust is
admitted only inside a push's reconcile" paragraph and its repair-always-blanks claim, and the trust
set's own declaration doc in `+Manager.swift`, which now states the admission rule ahead of its
session-scope note.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The companion's `0o000` staging would not have reached its refusal**
- **Found during:** Task 1
- **Issue:** The plan specifies dropping the working folder to `0o000`. That denies the by-name
  `manifest.json` open `ensureWorkingManifest` performs, so `prepareWorkingSeed` would fail before
  `pageFileScan` ran and the case would exercise no refusal exit at all.
- **Fix:** `0o311` (owner write + execute, no read anywhere) — the shape the existing
  `testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing` derives, which denies the
  listing and nothing else.
- **Files modified:** `DownloadContinuedSessionLedgerRefusalTests.swift`
- **Commit:** `1a201867`

**2. [Rule 1 - Bug] The companion's "all six page files present" staging could not ground `.repair`**
- **Found during:** Task 1
- **Issue:** With every file present, `storage.validate(verifiesContentHashes: false)` reports
  `.valid`, so `resumeMode` resolves `.redownload` — which deletes the working folder and arrives
  with a fresh all-empty manifest, never reaching a refusal.
- **Fix:** Five of six page files staged. The missing sixth is what makes `.missingFiles` fire and
  the route resolve `.repair`; the read bit is cleared afterwards, so the drop still isolates the
  enumeration.
- **Files modified:** `DownloadContinuedSessionLedgerRefusalTests.swift`
- **Commit:** `1a201867`

### Deliberate scope additions

**3. [Rule 2 - Missing derivation] The shape the new predicate stops announcing, documented**
- **Found during:** Task 2, Step 0
- **Issue:** Replacing `!manifest.isComplete` outright is not a superset on one shape: a record that
  reads incomplete while its folder holds every page it claims (an interruption between a page write
  and its manifest flush) previously announced and now does not. Left undocumented this reads as an
  oversight.
- **Fix:** Derived and recorded in the function doc — that run fetches nothing, its record already
  reads incomplete so the raw-counting half of the basis covers it while it does, and trusting it
  would retire N pages the session never downloaded, which is the D-G4-01 ceiling. Under-reporting
  is the direction D-G4-01 and the retirement ledger both choose on purpose.
- **Files modified:** `DownloadClient+ExecutionSupport.swift`
- **Commit:** `8570cd5b`

**4. [Rule 3 - Blocking] `restorePermissions` was file-private to the reconciliation suite**
- **Found during:** Task 1
- **Issue:** The companion needs the same restore discipline, and it extends a different suite type,
  so the helper was unreachable. Duplicating it is explicitly prohibited.
- **Fix:** Promoted into `DownloadFeatureTestHelpers.swift` as a `DownloadFeatureTestCase` member and
  deleted from the reconciliation file's private extension. No case body changed.
- **Files modified:** `DownloadFeatureTestHelpers.swift`, `DownloadContinuedSessionReconciliationTests.swift`
- **Commit:** `1a201867`

### Authentication gates

None.

## Verification

| Check | Result |
|-------|--------|
| Targeted ledger suite, RED (Task 1) | 2 failing / 13 passing, readings quoted above |
| Targeted ledger suite, GREEN (Task 2) | `Test run with 15 tests in 1 suite passed` |
| Full FeatureTests plan, one invocation | `** TEST SUCCEEDED ** [96.637 sec]` |
| SwiftLint `--strict`, `AppPackage/Sources/DownloadClient/` | 0 violations in 34 files |
| SwiftLint `--strict`, the three touched test files | 0 violations |
| `grep -c 'observedIncompleteSessionGIDs.insert' +ExecutionSupport.swift` | `1` |
| `grep -c 'workingSeed.manifest.isComplete' +ExecutionSupport.swift` | `0` |
| `grep -c 'catches up at flush time' +ExecutionSupport.swift` | `0` |
| `grep -c 'in exactly one place' +ExecutionSupport.swift` | `0` |
| `grep -c 'extension DownloadContinuedSessionLedgerTests'` in the new file | `1` |
| `grep -c '@Suite'` in the new file | `0` |
| `wc -l DownloadContinuedSessionLedgerTests.swift` | `812`, unchanged |

xcodebuild invocations were run strictly one at a time.

## Prohibitions

| Prohibition | Status |
|-------------|--------|
| No trust at queue time; `shouldSchedule`/`schedulableSnapshot` unweakened | HELD — the insert is in the run's preparation only; the K=N queued-window assertion and `testACompleteGalleryQueuedForUpdateOpensTheCardAtZero` both pass |
| `reconcileWorkingManifestAgainstPageFiles`' executable lines untouched | HELD — its diff is doc-only |
| No existing case weakened, deleted or restaged | HELD — K=1, the three reconciliation-refusal cases and the client-start-hop case are byte-unchanged |
| New cases in a new extension file; no hand-issued push | HELD — the ledger file is byte-unchanged at 812 lines; only `testingEnsureContinuedSession` (via `retryPages`) and `testingPrepareWorkingSeedAnnouncingProgress` issue pushes |
| No concurrency or lint escape hatch, no SwiftLint suppression | HELD — no `swiftlint:disable`, no `@unchecked`, no `try?` |

## Threat Flags

None. No new network endpoint, auth path, file-access pattern or trust-boundary schema change: the
plan adds one in-memory `Set` insert and a gate on an existing scan result. No BackgroundTasks verb
is touched, so `COVERAGE.md` is unchanged.

## Known Stubs

None.

## Not claimed by this plan

The physical-device UAT re-run (`15-UAT.md` test 2) remains open, as the plan states: the backstop
truth records the device-only observation without closing it. It is now worth running — until this
gap closed, a refused repair's zero card was a known symptom rather than new information.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND
- commit `1a201867` — FOUND
- commit `8570cd5b` — FOUND
