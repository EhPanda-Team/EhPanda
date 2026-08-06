---
phase: 15-continued-background-downloads
plan: 48
subsystem: downloads
tags: [download-coordinator, continued-session, run-lifetime, trust-basis, gap-closure, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-47's single derived pending-work predicate (PreparedWorkingRun.pendingPageIndices, evaluated once inside prepareWorkingSeedAnnouncingProgress), which this plan re-owns the lifetime of without introducing a second evaluation"
provides:
  - "provenPageWorkRunGIDs — the run-scoped proof of page work, recorded unconditionally at the run's own preparation and retired at the run's end"
  - "Every session start seeds its trust set from that owner inside the synchronous reset, where the card's opening subtitle is still computed from"
  - "The run-end retirement at processDownload's defer, the one point all five run exits pass, gated so a superseded run cannot drop a live successor's proof"
  - "Three ordering regressions: a preparation with no live session, an unavailable teardown mid-run, and the lifetime pin proven sensitive by an observed failure"
  - "testRunScopedPageWorkProofSitesMatchTheRecordedCensus — the run-vs-session lifetime pinned in source rather than in review"
  - "The spy's terminal-event contract corrected: .unavailable releases the held identity exactly as .expired does, matching the live store's endSession"
affects: [15-49]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A fact about a run is owned by the run and READ by whatever session is live, never owned by the session"
    - "A guard that passes vacuously before a fix is not a pin until it has been observed failing with the fix's load-bearing half removed"
    - "A test double's terminal-event contract is derived from the live implementation, not from the one event a suite happened to need"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift

key-decisions:
  - "The retirement sits in processDownload's defer, not in either settle: the two settles cover only some exits, and finishActiveTaskIfOwned's body is gated behind an ownership test a non-owning exit fails"
  - "It is gated on 'no live run for the same gid at a different generation', because pause/delete/folder operations null activeTask while their run is still executing, so an ungated retirement would drop a successor's proof"
  - "NO testing accessor for the run-scoped collection: all three regressions read production-issued start subtitles, so the collection stays invisible to the test seam"
  - "The spy's emit(_:) was made terminal-contract-faithful rather than worked around; without it the second case could not reach a successor session at all"
  - "makeQueuedCoordinator gained an injectable URLSession so the lifetime pin drives a REAL processDownload to a real exit offline instead of through a retirement forwarder"
  - "The lifetime claim was PINNED, as a fifth census in DownloadSourceInventoryTests counting every site naming the run-scoped proof"

patterns-established:
  - "Run-scoped ownership with a session-scoped reader, and a retirement derived over every enumerated exit"
  - "Sensitivity-measured pins: a both-sides-green guard is reported as closing a risk only after it has been observed red"

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "A repair whose seed was prepared with no live session is credited by the next session that starts"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift#testARepairPreparedWithNoLiveSessionIsCreditedByTheNextSession"
        status: pass
    human_judgment: false
  - id: D2
    description: "An unavailable teardown mid-run does not strip the run's proof from the successor session"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift#testAnUnavailableTeardownDoesNotStripTheRunsProofFromTheNextSession"
        status: pass
    human_judgment: false
  - id: D3
    description: "A proof does not outlive its own run into a later redo of the same gallery, so D-G4-01's ceiling is not reopened from the other side"
    requirement: SC1
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift#testAProofDoesNotOutliveItsRunIntoALaterRedo"
        status: pass
    human_judgment: false
  - id: D4
    description: "The run-scoped proof has exactly four sites — declaration, recording, session-start seed, run-end retirement — so a clear added at a session boundary fails a build"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testRunScopedPageWorkProofSitesMatchTheRecordedCensus"
        status: pass
    human_judgment: false
  - id: D5
    description: "The queue-time ceiling never moves: a complete gallery queued for an update still opens the card at zero, and both refusal cases' queued windows still read zero"
    requirement: SC1
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testACompleteGalleryQueuedForUpdateOpensTheCardAtZero"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift#testAnAllPagesGoneRepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testAnAnnouncementDuringTheClientStartHopSurvivesTheSeed"
        status: pass
    human_judgment: false
  - id: D6
    description: "On a physical iOS 26 device, a repair whose session was torn down mid-run and a repair resumed from the persisted queue at launch both climb their card instead of reporting zero for the whole run"
    verification: []
    human_judgment: true
    rationale: "Backstop truth, device-only. 15-UAT.md test 2 remains an independent axis this plan does not claim."

# Metrics
duration: 33min
completed: 2026-08-06
status: complete
---

# Phase 15 Plan 48: The Run Owns Its Proof Summary

**The proof that a run has real page work is now recorded by the RUN, read by every session that starts afterwards at the position the start's own ordering requires, and retired at the one point every exit of the run passes — so a session teardown or a cold launch can no longer cost a repair its entire N-page contribution, and the guard against the opposite failure has been observed red rather than merely green.**

## Performance

- **Duration:** 33 min
- **Started:** 2026-08-06T01:23:00Z
- **Completed:** 2026-08-06T01:56:00Z
- **Tasks:** 3
- **Files modified:** 8 modified, 1 created

## Accomplishments

- Re-derived the trust-set census from source before any edit; it agreed with the plan's enumeration exactly, which is the first time this round a pre-derived census has held.
- Enumerated the run's five exits and found that **neither settle covers them all** and that `finishActiveTaskIfOwned` is not a candidate either — the `defer` is the only placement, and the disposition for two overlapping runs turned out to be load-bearing rather than theoretical.
- **Observed the lifetime pin failing**, with the retirement removed, on exactly the inherited-credit reading. It is a pin, not a vacuous green.
- Found and fixed a **contract-unfaithful test double** that would otherwise have decided the second case's outcome: the spy held its session identity across `.unavailable`, which the live store does not.

## Step 0(a) — the trust-set census, re-derived at HEAD `f59529ed`

`grep -rn 'observedIncompleteSessionGIDs' AppPackage/ App/ ShareExtension/` — eleven lines, every one classified:

| Role | Site | Count |
|---|---|---|
| Declaration | `+Manager.swift:560` | 1 |
| Read (D-G7-01's counted-basis test) | `+ExecutionSupport.swift:275` | 1 |
| Read (D-G4-01's numerator basis) | `+ContinuedSession.swift:153` | 1 |
| Clear (session start's synchronous reset) | `+ContinuedSession.swift:230` | 1 |
| Clear (teardown) | `+ContinuedSession.swift:365` | 1 |
| Snapshot-sourced merge (post-start seed) | `+ContinuedSession.swift:289` | 1 |
| Snapshot-sourced merge (retirement reconcile) | `+ContinuedSession.swift:575` | 1 |
| Departure gate | `+ContinuedSession.swift:555` | 1 |
| The run's insert | `+ExecutionSupport.swift:480` | 1 |
| Doc-comment mention (Sources) | `+ContinuedSession.swift:527` | 1 |
| Doc-comment mention (Tests) | `DownloadContinuedSessionBasisTests.swift:508` | 1 |

Nine executable sites in Sources — **one declaration, two reads, two clears, two snapshot-sourced merges, one departure gate and one insert** — which is the plan's enumeration exactly, plus two doc mentions counted separately.

**The gap record's numeral discrepancy, noted as the plan required.** G-15-26's own text writes a count that disagrees with its own enumeration. The ENUMERATION was the stop condition and it matched, so no stop was warranted; the numeral was never used.

## Step 0(b) — where the seed must land, derived from `ensureContinuedSession`

Source order, `+ContinuedSession.swift:222-238`:

1. The pending-work guard, then the **synchronous reset block** (`hasLiveContinuedSession`, `continuedSessionID`, the floor, the ledger, the observed map, the trust set).
2. `let snapshot = await schedulableSnapshot()`.
3. `await backgroundProcessingClient.start(title, continuedSessionSubtitle(for: snapshot.sessionProgress), …)`.
4. The ownership re-check, then the two post-start merges.

**The card's OPENING subtitle is computed from (2)**, which reads the state (1) left behind. The seed must therefore land in the synchronous reset. A seed folded in with the post-start merges at (4) is structurally too late: it would pass any mid-session assertion while leaving the card's opening reading at zero — which is precisely the failure Task 1's first case asserts on. That is why the first regression asserts `startSubtitles`/`startCompletedUnitCounts` rather than a later push.

## Step 0(c) — the run's exits, and why only one placement covers them

`processDownload` (`+Execution.swift:9-51`) has **five** exits:

| # | Exit | Reaches `settleCompletedDownload`? | Reaches `settleDownloadFailure`? | Reaches the `defer`? |
|---|---|---|---|---|
| 1 | Pre-fetch early return (`guard let download = await fetchDownload…`) | no | no | **yes** |
| 2 | Success path (`completeDownload`) | yes | no | **yes** |
| 3 | Mid-run cancellation guard (`guard !Task.isCancelled`) | no | no | **yes** |
| 4 | `catch is CancellationError` | no | no | **yes** |
| 5 | General failure catch (`handleProcessDownloadError`) | no | *some arms only* | **yes** |

Exit 5's arms, enumerated because the plan required the no-settle ones named: `handleProcessDownloadAppError`, `handleProcessDownloadPartialError` and `handleProcessDownloadGenericError` each return early for a cancellation-like error and again for suppressed persistence — **two arms apiece reaching no settle** — and `handleProcessDownloadIncompleteError` reaches no settle **at all**, dequeuing and reloading instead.

Candidate placements, against that table:

- **`settleCompletedDownload`** — exit 2 only.
- **`settleDownloadFailure`** — part of exit 5 only.
- **`finishActiveTaskIfOwned`** — the `defer` reaches it on every exit, but its own body is gated behind `isActiveTaskOwner`, so a non-owning exit reaches nothing inside it. **Not a candidate.**
- **The `defer` block itself** — all five, unconditionally. This is the placement.

**Disposition 1 — a run exiting before the preparation.** It recorded nothing, and `Set.remove` of an absent member is a no-op, so the retirement is harmless in the required sense. It can still clear a PREVIOUS run's entry for the same gallery, which is correct: that run is over too.

**Disposition 2 — two overlapping runs for the same gid.** Reachable and load-bearing. `scheduleNextIfNeededCore` guards on `activeTask == nil`, but `pause` (`+Scheduling.swift:294-298`), `delete`/`clearDownloadQueueIntent` (`+PublicAPI.swift:204-208`) and `deleteFolder`/`moveDownload` (`+Folders.swift:106-107`) each null `activeTask` **while the run they interrupt is still executing**, so a following resume can schedule a successor at a new `activeTaskGeneration`. An ungated retirement in the predecessor's `defer` would drop the SUCCESSOR's proof — G-15-26's zero-progress card reintroduced by its own fix. The retirement is therefore gated:

```swift
private func isSupersededByALiveRun(gid: String, generation: Int?) -> Bool {
    guard activeTask != nil, activeGalleryID == gid else { return false }
    return generation != activeTaskGeneration
}
```

and the call sits **ahead of** `finishActiveTaskIfOwned` in the `defer`, because that function nils both halves of the ownership the guard reads — after it, every owning run would look superseded and retire nothing.

## Task 1 — the honest RED

**Staging, all three cases:** a six-page record reading 6-of-6 with **no page file at all**. `reconcileWorkingManifestAgainstPageFiles` finds a successful scan accounting for none of the six claimed pages, so `blankedPageCount` reaches six and the residual guard `blankedPageCount < manifest.completedPageCount` refuses. Nothing blanked, nothing republished, `isIncomplete` false for the whole run — which is what makes the snapshot-sourced half of D-G4-01 structurally unable to admit the gallery and leaves the run's own proof as the only route. The five-of-six shape was deliberately NOT used: it blanks one page, the record turns honest, and the case would pass pre-fix on raw counting.

**Observed RED**, quoted from the xcresult of the single targeted invocation (`Test-EhPanda-2026.08.06_10-32-50-+0900.xcresult`):

> `DownloadContinuedSessionRunProofTests.swift:127: Expectation failed: (spy.startCompletedUnitCounts.last → 0) == 6`
> `DownloadContinuedSessionRunProofTests.swift:129: Expectation failed: (spy.startSubtitles.last → "0 / 6 pages · 1 gallery") == "6 / 6 pages · 1 gallery"`

> `DownloadContinuedSessionRunProofTests.swift:212: Expectation failed: (spy.startSubtitles.last → "0 / 6 pages · 1 gallery") == "6 / 6 pages · 1 gallery"`

The run was `20 tests in 1 suite`, `3 issues`, **all from the two new ordering cases**. `testAProofDoesNotOutliveItsRunIntoALaterRedo` passed, and **every one of the 17 pre-existing ledger cases passed**.

### Each case's asserted precondition, quoted

| Case | Precondition | Assertion |
|---|---|---|
| 1 | No live session at the preparation | `#expect(!(await manager.testingHasContinuedSession()))` and `#expect(spy.startCount == 0)` |
| 2 | A live session at the preparation | `#expect(await manager.testingHasContinuedSession())` and `#expect(spy.startSubtitles == ["0 / 6 pages · 1 gallery"])` |
| 2 | Pending work still queued when session 2 starts | `#expect(await manager.hasPendingWork())` |
| 3 | The run really proved page work | `#expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])` |

### Each case's hinge suspension, derived in this task from source

- **Case 1** — the client start's main-actor hop. The opening subtitle is fixed by the snapshot taken *before* `await backgroundProcessingClient.start(...)`, so that start is the first suspension whose far side cannot move the reading; the spy suspends there too (its `start` closure opens with `await Task.yield()` before recording anything). This is why a post-start seed cannot pass this case.
- **Case 2** — the event delivery itself: `for await event in clientSession.events` inside the detached `continuedSessionTask`. The teardown therefore lands asynchronously with respect to the case, which is why the case waits on `testingHasContinuedSession()` going false rather than assuming the emission landed.
- **Case 3** — `processDownload`'s own `try await fetchNormalizeAndDownload(...)`, whose `GalleryDetailRequest.response()` the injected stub answers with a transport failure; the `defer` runs as that throw unwinds. The retirement is synchronous inside the `defer`, so it has landed when the awaited call returns; only `finishActiveTaskIfOwned`'s convergence is detached, which is why the redo waits for active ownership to clear.

### The teardown is production-issued

`spy.emit(.unavailable)` — the coordinator reaches `markContinuedSessionEnded` through `handleContinuedSessionEvent`'s `.unavailable` arm, not through a forwarder. `grep -c 'testingMarkContinuedSessionEnded' …RunProofTests.swift` → **0**.

### Task-1 acceptance greps

| Grep | Result |
|---|---|
| each of the three case names | **1** each |
| `extension DownloadContinuedSessionLedgerTests` | **2** (the cases and the file-private helper extension) |
| `@Suite` | **0** |
| `testingMarkContinuedSessionEnded` | **0** |
| lines over 120 characters | **0** |
| file length | 332 lines |

**No push, start, teardown or retirement is issued by any case body.** The complete list of production calls across the three cases: `reloadDownloadIndex`, `fetchDownload`, `resumeMode`, `testingHasContinuedSession`, `testingPrepareWorkingSeedAnnouncingProgress`, `testingEnsureContinuedSession`, `spy.emit`, `hasPendingWork`, `processDownload`, `retry`, `testingHasActiveTask`, `waitUntil`.

### The third case's green, recorded PROVISIONAL

`testAProofDoesNotOutliveItsRunIntoALaterRedo` passed against pre-fix source, and **that green was vacuous**: no run-scoped collection existed, so there was nothing for a redo to inherit and the case could not have failed however wrong the eventual retirement turned out to be. It was recorded as a provisional pin whose standing depended entirely on Task 2 Step 5's sensitivity reading, and **not** reported as closing the lifetime risk at that point.

## Task 2 — the run owns the proof

**The recording, quoted** (`+ExecutionSupport.swift`):

```swift
if !pendingPages.isEmpty {
    provenPageWorkRunGIDs.insert(payload.gallery.gid)
    if let continuedSessionID {
        observedIncompleteSessionGIDs.insert(payload.gallery.gid)
        await pushContinuedSessionProgress(sessionID: continuedSessionID)
    }
}
```

The run-scoped write is outside the live-session branch; the session insert is still inside it and still ahead of the push. `grep -c 'observedIncompleteSessionGIDs.insert' …+ExecutionSupport.swift` → **1**.

**The seed, quoted** (`+ContinuedSession.swift`, inside the synchronous reset):

```swift
observedIncompleteSessionGIDs = provenPageWorkRunGIDs
```

**The whole executable diff of `+ContinuedSession.swift` is that one line.** Filtering the diff to non-comment lines yields exactly `-        observedIncompleteSessionGIDs = []` / `+        observedIncompleteSessionGIDs = provenPageWorkRunGIDs`: `markContinuedSessionEnded`'s clear of the session set is byte-unchanged, no clear of the run-scoped collection was added anywhere, and both post-start merges are untouched.

**One-evaluation greps still hold:** `pendingPageIndices(` → **2** in `+ExecutionSupport.swift` (declaration + the single call), **0** in `+ExecutionPerform.swift`.

### Step 5 — the sensitivity reading, in the order the plan required

**(a) The pin FAILING with the retirement temporarily removed**, quoted verbatim from `Test-EhPanda-2026.08.06_10-37-46-+0900.xcresult`:

> `DownloadContinuedSessionRunProofTests.swift:308:9: Expectation failed: (spy.startCompletedUnitCounts.last → 6) == 0`
> `DownloadContinuedSessionRunProofTests.swift:309:9: Expectation failed: (spy.startSubtitles.last → "6 / 6 pages · 1 gallery") == "0 / 6 pages · 1 gallery"`

**The failure reads as inherited credit exactly as required:** the redo's card opens at the record's six pages instead of at zero. That run was `20 tests in 1 suite`, `2 issues`, **both from this case alone** — and in the same run **both Task-1 RED cases had already flipped green**, which is what shows the two halves of the remedy are independent.

**(b) The pin green again after the retirement was restored**, with every other ledger case green in the same run: `25 tests in 2 suites passed`, `** TEST SUCCEEDED **` (37.99 s), covering the whole ledger suite plus `DownloadSourceInventoryTests`.

**(c) Byte-identity confirmed.** `git diff` over `+Execution.swift` after the restore shows the retirement exactly as Step 4 landed it — the four-line rationale comment plus `retireProvenPageWork(gid: gid, generation: generation)` ahead of `finishActiveTaskIfOwned` — with no residue of the probe.

The lifetime pin is therefore reported as sensitive on evidence, not on a both-sides green.

### The corrected doc sentences, quoted beside the census that produced them

**1. `+Manager.swift`, the trust set's admission rule** — the census showed the set has gained a third admission route (the seed) and lost its ownership:

> Membership is granted where the session can OBSERVE incompleteness or PROVE page work, never at queue time. The observed half is the snapshot-sourced merges, which read `isIncomplete`. The proven half is `provenPageWorkRunGIDs` below, which the run's own working-seed announcement records and which this set is SEEDED FROM at every session start — **this set is no longer the owner of that proof, only a reader of it, and G-15-26 is what that distinction cost.**

**2. `+Manager.swift`, the same declaration's session-scoped paragraph** — the retired sentence said it was "seeded from the start snapshot"; the census showed two clears and now one seed:

> Session-scoped like the two above, in the sense that no membership of this set survives into the next session on its own … What it is re-derived FROM is the run-scoped owner below plus that start's own snapshot … So a session boundary re-reads the proofs of runs that are still in flight rather than discarding them.

**3. `+Manager.swift`, the new declaration's own lifetime rule**, written as a rule rather than as a site count:

> An entry is recorded at the run's own preparation when that run's pending page list is non-empty; it is read by every session start, which seeds `observedIncompleteSessionGIDs` from it; and it is retired when that run ends, at `processDownload`'s `defer`, which is the one point every exit of a run passes through.

**4. `+ContinuedSession.swift`, `ensureContinuedSession`'s post-start merge rationale** — the retired sentence claimed "both collections were cleared by this session's own synchronous reset — so anything present at seed time is this session's own identity-gated observation, never a predecessor's", which the seed makes false for one of the two:

> `observedIncompleteSessionGIDs` was SEEDED there … so it can additionally hold proofs recorded by runs that are still in flight — including runs that prepared under a predecessor session, or under no session at all. That is not a predecessor's session state leaking in: a run's proof of its own page work is a fact about the run, which is why it outlives the session boundary and not the run boundary.

**5. `+ContinuedSession.swift`, `markContinuedSessionEnded`** — a new heading, because this teardown IS the defect's mechanism:

> **Session state only. A session boundary is not a run boundary (G-15-26).** … In particular `provenPageWorkRunGIDs` is deliberately not cleared here, and adding it would re-open the exact defect this teardown caused: the `.unavailable` arm calls this and nothing else, leaving the queue running foreground-only …

**6. `+ContinuedSession.swift`, `schedulableSnapshot`'s D-G4-01 paragraph** and its "each half earns its place" bullet, both of which named the announcement as admitting *to the trust set*:

> **The proof is owned by the run, and this set is seeded from it (G-15-26).** The recording goes to `provenPageWorkRunGIDs`, which no session boundary touches … so the same fact reaches the session by two routes and neither depends on the other.

**7. `+ExecutionSupport.swift`, the trust-admission rule** and its named-suspension paragraph (now "BOTH recordings"), plus a new paragraph on D-G7-01's composition, which the census showed is unaffected because the withdrawal reads the SESSION set:

> With no session live it withdraws nothing at all — its own guard is `continuedSessionID != nil` — and by the time a later session start has seeded the trust set from the run's proof, that session's floor has been seeded from a snapshot that already counted the gallery, so the two sides still move together.

**Pin-or-restate decision: PINNED.** The load-bearing claim is the LIFETIME — recorded at the run, read at every session start, retired at the run's end, and touched nowhere else — and its rot path is a clear appearing at a session boundary. `testRunScopedPageWorkProofSitesMatchTheRecordedCensus` is a fifth census on the established pattern (repository-root walk, known-member guard, fragment-assembled token `"provenPageWork" + "RunGIDs"`, per-file table plus a separately counted joined total), expecting one site each in `+Manager.swift`, `+ExecutionSupport.swift`, `+ContinuedSession.swift` and `+Execution.swift` and a joined total of `4`. A clear added to `markContinuedSessionEnded` takes `+ContinuedSession.swift` from one to two and fails the build. A whole-name count rather than a mutation count, deliberately: the rot is a READ or a CLEAR appearing, not an assignment.

**Testing-accessor decision: NONE.** `+Testing.swift` was left byte-unchanged. All three regressions read production-issued start subtitles, which is both the plan's stated default and the stronger assertion — an accessor would have let a case assert that the collection holds a gid while saying nothing about whether the card ever reflected it. The module's standing rule that an unconsumed forwarder is attack surface rather than a seam (G-15-11) applies directly.

## Task 3 — the residue sweep, four checks

**Check 1 — newly-orphaned symbols: none.** Nothing existed solely to support the session-scoped ownership. The trust set was never *owned* through a helper; the ownership was the absence of any other writer, so retiring it removed no symbol. Remaining caller counts across both modules:

| Symbol | Sources | Tests | App / ShareExtension | Verdict |
|---|---|---|---|---|
| `observedIncompleteSessionGIDs` | 10 (9 executable + 1 doc) | 1 (doc) | 0 | alive, unchanged in shape |
| `observedSchedulablePages` | 9 | 0 | 0 | alive |
| `retiredSessionPages` | 8 | 0 | 0 | alive |
| `lastPushedCompletedPageCount` | 8 | 2 | 0 | alive |
| `provenPageWorkRunGIDs` | 5 (4 executable + 4 doc lines) | 0 | 0 | new |
| `retireProvenPageWork` | declaration + 1 call | 0 | 0 | new |
| `isSupersededByALiveRun` | declaration + 1 call | 0 | 0 | new |

No zero-count symbol exists, so nothing was deleted.

**Check 2 — newly-dead state: none.** Every member of the session-scoped trio still has a reader after the reseeding: `lastPushedCompletedPageCount` at the push's `max()`, `retiredSessionPages` at the push's `reduce` and the departure ledger, `observedSchedulablePages` at `reconcileRetiredSessionPages`' difference, `observedIncompleteSessionGIDs` at `schedulableSnapshot`'s basis and `withdrawingCountedBasisMovement`'s counted-basis test and the departure gate. The run-scoped collection has a reader on the one path that writes it: the recording in `+ExecutionSupport.swift` is read by the seed in `+ContinuedSession.swift` and by the retirement's own `remove` in `+Execution.swift`. Neither the WR-04 write-never-read shape nor its converse is present.

**Check 3 — the same claim surviving outside this plan's scope.** Scanned for every sentence asserting where trust is admitted, when it is cleared, or that the session set owns the run's proof. Per-target result, clean results included:

| Target | Scanned | Surviving retired claims | Action |
|---|---|---|---|
| `AppPackage/Sources` | 3 files name the trust set (`+Manager.swift`, `+ExecutionSupport.swift`, `+ContinuedSession.swift`) | 0 after Task 2 | corrected in Task 2 |
| `AppPackage/Tests` | 4 files carry admission claims | **2 found, both corrected here** | see below |
| `App` | whole target | 0 | clean, no session vocabulary at all |
| `ShareExtension` | whole target | 0 | clean, no session vocabulary at all |

The two survivors were exactly the G-15-29 residue class the check exists to prevent — a Sources-scoped correction leaving the identical retired sentence in the test target, where the source census structurally cannot see it:

- `DownloadContinuedSessionLedgerRefusalTests.swift`, the K=N case: *"the only writers of the session's trust set are two `formUnion`s over `snapshot.incompleteGalleryIDs`"*. False from the moment the seed landed. Rewritten to say that every SNAPSHOT-sourced writer is closed to a complete-reading record, and that the remaining writers all trace back to the run's own proof — the insert when a session is live, and the session-start seed otherwise.
- The same file, the failed-enumeration case: *"the announcement is the only place that can admit the gallery to the session's trust set"*. Rewritten to name both routes the announcement's proof reaches the set by.

One further correction was made in the new file itself, for the same reason: its header described `ensureContinuedSession` as *resetting* the trust set, which its own fix changed to *re-deriving* it.

`DownloadContinuedSessionBasisTests.swift:508` was inspected and left alone: it names the two admissions ITS OWN case travels (the start-snapshot `formUnion` and the retirement reconcile) rather than claiming an exhaustive writer list, and both remain accurate.

**Check 4 — reachability of each corrected claim:**

| Corrected claim | Pinned or restated | By |
|---|---|---|
| The proof's lifetime: recorded at the run, read at each session start, retired at the run's end, touched nowhere else | **pinned** | `testRunScopedPageWorkProofSitesMatchTheRecordedCensus` |
| A session boundary does not clear the run-scoped proof | **pinned** | the same census (a clear in `+ContinuedSession.swift` takes its entry from 1 to 2) and `testAnUnavailableTeardownDoesNotStripTheRunsProofFromTheNextSession` |
| The seed lands where the first push can see it | **pinned** | `testARepairPreparedWithNoLiveSessionIsCreditedByTheNextSession`, which asserts the START subtitle specifically |
| The proof does not outlive its run | **pinned** | `testAProofDoesNotOutliveItsRunIntoALaterRedo`, with its sensitivity measured |
| The overlapping-run gating rationale | **restated** | Staging two genuinely overlapping runs for one gid needs a mid-run `pause`/`delete` interleave against a live `activeTask`; the fixture family that could hold that runner open is the blocking coordinator, which cannot also reach the working-seed preparation. Recorded as a known non-pin rather than left silent. |
| D-G7-01's composition is unaffected | **restated** | It is a negative — "the withdrawal reads the session set, not the run's" — and the existing basis suite already pins the withdrawal's behaviour on both disjuncts. |

## Green

| Run | Scope | Result |
|---|---|---|
| Task 1 verify (pre-fix) | `-only-testing:…/DownloadContinuedSessionLedgerTests` | **TEST FAILED** — 20 tests, 3 issues, all from the two new ordering cases; the lifetime pin and all 17 pre-existing cases passed |
| Task 2 Step 5(a) (retirement removed) | same | **TEST FAILED** — 20 tests, 2 issues, both from the lifetime pin; both ordering cases already green |
| Task 2 Step 5(b) / Step 7 targeted (retirement restored) | ledger suite + `DownloadSourceInventoryTests` | **TEST SUCCEEDED** — 25 tests in 2 suites, 38.0 s |
| Task 2 full | full `FeatureTests` | **TEST SUCCEEDED** — **879 tests, 0 failures**, 104.4 s |
| Task 3 final full | full `FeatureTests` | **TEST SUCCEEDED** — **879 tests, 0 failures**, 105.1 s |

Each was a single invocation; **none overlapped**. **Test count 879 against 15-47's 875 → net +4:** three ordering regressions and one census. No other movement. Zero compiler warnings, zero SwiftLint violations across `AppPackage/Sources/DownloadClient` and `AppPackage/Tests/DownloadsFeatureTests`, zero lines over 120 characters in any touched file.

## Task Commits

1. **Task 1: Stage the two uncovered orderings and the lifetime pin, RED-first** — `4acc408b` (test)
2. **Task 2: Re-own the proof by the run, derive its retirement, seed the session from it** — `8d769b40` (fix)
3. **Task 3: Sweep what the change left behind** — `51fba0ad` (docs)

## Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| No second evaluation of the run's pending work | **held** | `pendingPageIndices(` → 2 in `+ExecutionSupport.swift`, 0 in `+ExecutionPerform.swift`; 15-47's census green in the targeted run |
| The proof must not outlive its run | **held, and the guard is proven sensitive** | Step 5(a)'s observed failure quoted above; restored and re-observed green |
| No trust at queue time; no weakening of `shouldSchedule`/`schedulableSnapshot` | **held** | Neither function's body was touched; `testACompleteGalleryQueuedForUpdateOpensTheCardAtZero` and both refusal cases' `startSubtitles.last == "0 / 6 pages · 1 gallery"` assertions pass unchanged |
| No clear of the run-scoped collection from `markContinuedSessionEnded` or `ensureContinuedSession` | **held** | The executable diff of `+ContinuedSession.swift` is one line; the new census fails the build if a clear is added |
| No concurrency or lint escape hatch, no SwiftLint suppression | **held** | No `swiftlint:disable`, `@unchecked`, `@preconcurrency`, `try?` or force unwrap added; `swiftlint --strict` clean over both directories |

## Decisions Made

- The retirement sits in `processDownload`'s `defer`, ahead of `finishActiveTaskIfOwned`, because the two settles cover only some exits and `finishActiveTaskIfOwned`'s body is gated behind an ownership test a non-owning exit fails.
- It is gated on "no live run for the same gid at a different generation", because `pause`, `delete` and the folder operations null `activeTask` mid-run and an ungated retirement would drop a successor's proof.
- No testing accessor for the run-scoped collection: the regressions read production-issued start subtitles, which is both the plan's default and the stronger claim.
- The corrected lifetime claim was PINNED as a fifth source census rather than only restated.
- The recording nests the session insert inside the pending-work test rather than duplicating the condition; the insert stays inside the live-session branch and ahead of the push, which is what the ceiling guarantee depends on.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The spy's `.unavailable` was not contract-faithful, and would have decided the second case's outcome**

- **Found during:** Task 1
- **Issue:** `BackgroundProcessingClientSpy.emit(_:)` yielded any event while leaving the stream open and the held session identity in place. The live store does not: `ContinuedProcessingSession` yields `.unavailable` only through `endSession(yielding:success:)`, which clears the task, the continuation and the session id and finishes the stream — the same terminal path `.expired` takes, and exactly what the client seam's own doc states ("the stream finishes itself after `expired`, after `unavailable`, or after `finish`"). With the unfaithful double, the successor session's `start` would have been refused by the spy's own single-session guard, so the case could never have reached the ordering it exists to test: the DOUBLE, not production, would have decided the result.
- **Fix:** `emit(_:)` now switches on the event and routes `.expired` and `.unavailable` through the same identity-releasing terminal path, leaving `.granted` non-terminal. `expire()` became `emit(.expired)`, so its five existing callers are unchanged by construction.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift`
- **Verification:** `spy.startCount == 2` passes in the second case, proving the successor session really started; the single pre-existing `emit(.granted)` caller and all five `expire()` callers pass unchanged; full suite green.
- **Committed in:** `4acc408b`

**2. [Rule 3 - Blocking] The lifetime pin could not reach a real run exit without an injectable transport**

- **Found during:** Task 1
- **Issue:** The plan requires the third case to end its run through PRODUCTION rather than a testing shortcut. The only production run entry point is `processDownload`, whose first step is a live `GalleryDetailRequest`. `makeQueuedCoordinator` hard-coded `URLSession.shared`, so driving it would have issued a real network request to e-hentai.org — neither offline-safe nor deterministic — and the alternative was a retirement forwarder, which is exactly the testing shortcut the plan forbids.
- **Fix:** `makeQueuedCoordinator` gained a `urlSession: URLSession = .shared` parameter, mirroring the `fileManager:` parameter added for the same class of reason. The third case injects an ephemeral session carrying `SharedSessionStubURLProtocol` and a per-case header, the same seam `makeStubbedDownloadCoordinator` already opens, so the stub is scoped to that case rather than registered process-wide.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift`, and the file-private `makeStubbedURLSession` helper in the new test file.
- **Verification:** Every existing caller is unchanged by the default; the case's `processDownload` exits through the general failure catch with `lastError != nil` asserted; full suite green.
- **Committed in:** `4acc408b`

**3. [Rule 2 - Missing Critical] Two retired admission claims in the test target the plan's file list did not name**

- **Found during:** Task 3 (Check 3)
- **Issue:** `DownloadContinuedSessionLedgerRefusalTests` carried two sentences that the seed makes false — "the only writers of the session's trust set are two `formUnion`s over `snapshot.incompleteGalleryIDs`", and "the announcement is the only place that can admit the gallery to the session's trust set". This is the identical residue shape G-15-29's first item records, and it is the second consecutive round in which the test target has held a claim the Sources correction retired.
- **Fix:** Both rewritten to trace admission back to the run's own proof and to name both routes it reaches the session by. The new file's own header was corrected in the same pass (it described `ensureContinuedSession` as resetting the trust set rather than re-deriving it).
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift`, `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift`
- **Verification:** A repeat scan across all four targets returns 0 surviving instances; both refusal cases pass unchanged; final full suite green.
- **Committed in:** `51fba0ad`

**4. [Rule 2 - Missing Critical] The plan's exit enumeration listed four exits; source holds five**

- **Found during:** Task 2 (Step 0(c))
- **Issue:** The plan named "the pre-fetch early return, the success path, the cancellation return and the general failure catch". Source also has the mid-run `guard !Task.isCancelled else { return }` between `fetchNormalizeAndDownload` and `completeDownload`, which is a fifth exit reaching neither settle. The plan's own remedy shape is unaffected — the `defer` covers five exits as readily as four — so this was recorded and swept rather than treated as a stop, per the standing instruction to prefer the sweep-everything resolution.
- **Fix:** The retirement's doc enumerates all five, and the summary's exit table above records the discrepancy explicitly.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift`
- **Verification:** The `defer` placement is exit-count independent by construction; full suite green.
- **Committed in:** `8d769b40`

---

**Total deviations:** 4 auto-fixed (1 bug, 2 missing critical, 1 blocking)
**Impact on plan:** All four are inside the plan's stated scope — Step 0(c) explicitly mandated the exit enumeration that found #4, Check 3 explicitly mandated the test-target scan that found #3, and Task 1's own instruction that every asserted observation be production-issued is what forced #1 and #2. No production behavior beyond the proof's ownership and lifetime changed.

## Issues Encountered

The Step-5(a) invocation took the full 600 s wall clock, almost all of it the post-failure `IDETestOperationsObserverDebug: Failure collecting diagnostics from simulator` timeout that 15-47 recorded for the same reason. Testing itself completed in 0.16 s. This is a simulator diagnostics-collection hiccup on a FAILING run, not a hang; the passing runs finished in 38 s and 105 s. It was allowed to run to completion rather than killed, since killing an xcodebuild test invocation mid-flight wedges `testmanagerd` on this machine.

## Known Stubs

None.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern or schema change at a trust boundary. The one new stored value is an in-memory `Set<String>` of gallery identifiers on an existing actor, carrying no content-identifying text and never reaching the card, whose entire surface is integers.

## User Setup Required

None.

## Next Phase Readiness

- **G-15-26 is closed at the family.** Both uncovered orderings flip RED to green, the retirement is placed where all five enumerated exits pass with the overlapping-run case dispositioned and gated, and the lifetime pin has been observed failing so its sensitivity is measured rather than assumed.
- **G-15-29** (the hygiene/doc group) is next. Note for it: this plan's Check 3 already retired the two admission claims in `DownloadContinuedSessionLedgerRefusalTests`, so that residue is gone; the group's remaining items are the retired single-authority sentence at `DownloadContinuedSessionBasisTests.swift:257`, `PageDownloadProgress.completedCount` left dead by 15-45, and the unread `inFlightProgressUpdate` in the spy — the last of which this plan touched the surrounding code of but deliberately did not remove, since it is not this gap's residue.
- **One recorded non-pin**, carried forward honestly rather than buried: the overlapping-run gating is restated in a doc and not owned by a test, because staging two genuinely overlapping runs for one gallery needs a mid-run `pause`/`delete` against a live `activeTask`, and the fixture family that can hold a runner open cannot also reach the working-seed preparation. A later round wanting to own it needs a fixture that can do both.
- **15-UAT.md test 2** is now worth re-running on hardware. The verifier's standing caution no longer applies to a zero-progress observation on a torn-down or launch-resumed repair: that symptom is closed here, so such an observation would be new information rather than a known gap.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-06*

## Self-Check: PASSED

All 9 source and test files present on disk; all 4 commits (`4acc408b`, `8d769b40`, `51fba0ad`, `d381f366`) present in git history. No absolute home path in this document.
