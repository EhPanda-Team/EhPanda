---
phase: 15-continued-background-downloads
plan: 53
subsystem: downloads
tags: [continued-session, run-proof, retirement-gate, source-census, self-exclusion, gap-closure, doc-vs-source]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-50's re-derived run-proof census (four sites to six) in DownloadSourceInventoryTests, one of the seven tables this plan's scan change had to leave unmoved"
  - phase: 15-continued-background-downloads
    provides: "15-52's two-part client-double census over the downloads test target — the only tables the narrowed scan could have re-based, since the excluded file lives in that tree"
  - phase: 15-continued-background-downloads
    provides: "15-52's head 19f72be6 and its 886/0 full-suite total, the baseline this plan's 887 is accounted against"
  - phase: 15-continued-background-downloads
    provides: "DownloadLogPrivacyInvariantTests.scannedFiles()'s path-exclusion SHAPE and its invariantFilePath binding name — and nothing else, because that function documents nothing"
provides:
  - "An explicit generation-less branch in isSupersededByALiveRun, with the direction and the cost asymmetry recorded as its reason"
  - "A caller-derived rationale on isActiveTaskOwner's own nil arm, which had none"
  - "testAGenerationLessRunRetiresNothingWhileALiveRunOwnsTheSlot — the arm's pin, reached through the public processDownload entry point and observed failing with the branch inverted"
  - "A self-excluding source-inventory scanner, so the file that owns the prose rule can state the rule in plain words"
  - "The corrected record that 15-REVIEW.md:443-445's block quotation has no source referent, and that the G-15-33 gap record inherited it"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A policy reached by optional promotion is written as a branch even when behaviour-identical, so a reader can tell the case was decided rather than inherited from the types"
    - "An equivalence read off the type system is labelled UNPROVEN until a case that fails with the branch inverted has been observed"
    - "A prose-policing scanner excludes itself by path, so the one file whose job is to describe the rule is not the one file forbidden to state it"
    - "A scan-scope change to a census suite re-derives EVERY table in the file at the head it lands on, including tables sibling plans of the same round added or moved"
    - "An inherited quotation is verified against source before a plan argues from it; a whole-file search returning nothing is the finding, not a formality"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift

# Decisions
decisions:
  - "The generation-less arm returns true (superseded, retires nothing) and the reason recorded is the asymmetry rather than the choice: one stale proof bounded by the owning run's exit, against dropping a live successor's proof, which is the G-15-26 zero-progress card reached through its own fix."
  - "The branch sits AFTER the ownership guard, so a gallery no live run owns still answers false for a generation-less caller."
  - "isActiveTaskOwner's nil arm is documented in scope rather than deferred: same generator one function down, same file already in files_modified, doc-only with no branch and no behaviour change."
  - "The sibling scanner supplies the exclusion's SHAPE and its binding NAME only. Its scannedFiles() carries no doc comment, so the rationale is authored in this plan and attributed to nobody else."
  - "The plainly-worded statement of the retired claim STAYS in the excluded file: it is the capability the exclusion exists to grant, so removing it would leave the exclusion unexercised."
  - "An extra exclusion-disabled reading was taken beyond the plan's two directions, because the pass with the in-file instance proves the exclusion only by derivation until the disabled run is observed."

# Metrics
duration: 45min
completed: 2026-08-07
tasks_completed: 2
files_changed: 3
status: complete
---

# Phase 15 Plan 53: Written Nil-Generation Policy and a Self-Excluding Scanner Summary

Both halves of G-15-33 are closed at the omission that produced them: the retirement gate now says in
a branch what it does with a generation-less run and why that direction is the safe one, and the
source-inventory scanner no longer polices its own prose, so the file that owns the retired claim can
finally state it. Neither item was a defect, and one inherited premise underneath each of them turned
out to be false against source.

## The false-premise finding, stated rather than quietly fixed

`15-REVIEW.md:443-445` presents this as a block QUOTATION of
`DownloadLogPrivacyInvariantTests.scannedFiles()`'s own rationale:

> "Excluding this file by path is a second line of defence behind the assembled tokens: even if a
> future edit spelled one out, the scan would not read it back as a violation of itself"

**That sentence exists nowhere in the file.** Verified two ways at this head:

```
$ grep -rn "second line of defence\|second line of defense\|read it back as a violation" \
    AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
--- exit 1 (1 = no match)
```

```
252: []
253: [// MARK: - Scanning]
254: []
255: [private extension DownloadLogPrivacyInvariantTests {]
256: [    private static func scannedFiles() throws -> [ScannedFile] {]
257: [        let root = try repositoryRoot()]
```

`:253` is a MARK, `:254` is blank, `:255` opens the private extension and `:256` is the function, so
that scanner carries **no doc comment at all**. It implements the exclusion and explains nothing.

The G-15-33 gap record in `15-VERIFICATION.md` inherited the quotation from the review, so the false
premise was three artifacts deep. This plan is where it stops: the sibling supplied the exclusion's
SHAPE and its binding NAME, the rationale is authored here, and no sentence in the new doc is
attributed to it.

The sibling's two nearest real docs are named here so a later reader cannot mistake them for the
missing rationale. `:45-46` and `:73-75` both record the **assembled-fragment** reason — "spelling a
complete banned shape here would make repository grep gates match the invariant that enforces them",
and "a repository grep gate counting a log classification must not match the invariant that enforces
it". That is a different reason for a different mechanism, and it is not evidence about the path
exclusion.

The same shape of inherited claim appears in WR-03: both the review and the gap record describe
`isActiveTaskOwner` as handling its optional "with an explicit branch **and a recorded rationale**".
Source disagreed — `:315` was blank and the doc block above it belongs to `retireProvenPageWork` — so
the convention argument here rests on the written BRANCH alone. Step 2b then gave that sibling a
rationale for the first time, dated to this plan.

## Task 1 (WR-04): the scanner stops policing its own prose

### Step 1: every census inventoried at this head, before touching the scanner

Derived at head `19f72be6`, after 15-50 moved the run-proof table and 15-52 added the two
double-fidelity tables:

| # | Census | Token (assembled) | Per-file table | Joined total | Asserting case | Tree it counts over |
|---|--------|-------------------|----------------|--------------|----------------|---------------------|
| 1 | Scheduling-block call sites | `"block" + "Scheduling("` | Folders 2, PublicAPI 1, Scheduling 1, Testing 1 | 5 | `testSchedulingBlockCallSitesMatchTheRecordedCensus` | client module, via `clientModuleFiles(in:)` |
| 2 | Monotonic-floor writers | `"lastPushed" + "CompletedPageCount"` | ContinuedSession 4, ExecutionSupport 1 | 5 | `testFloorWriterAssignmentsMatchTheRecordedCensus` | client module |
| 3 | Schedulable-read callers | `"schedulable" + "Downloads()"` | ContinuedSession 2, PendingWork 1 | 3 | `testSchedulableDownloadsCallSitesMatchTheRecordedCensus` | client module |
| 4 | Pending-page-list evaluations | `"pendingPage" + "Indices("` | ExecutionSupport 1 | 1 | `testPendingPageListEvaluationsMatchTheRecordedCensus` | client module |
| 5 | Run-proof sites (**15-50 moved this one, 4 to 6**) | `"provenPageWork" + "RunPageDebts"` | ContinuedSession 2, Execution 1, ExecutionSupport 1, Manager 1, Persistence 1 | 6 | `testRunScopedPageWorkProofSitesMatchTheRecordedCensus` | client module |
| 6 | Client-double suspensions (**15-52 added**) | `"Task" + ".yield()"` | ExpirationTests 3, SupportTypes 3 | 6 | `testClientDoubleSuspensionSitesMatchTheRecordedCensus` | downloads test target, via `clientDoubleFiles(in:)` |
| 7 | Client-double construction (**15-52 added**) | `"updateProgress" + ":"` | ExpirationTests 1, SupportTypes 1 | 2 | `testClientDoubleConstructionSitesMatchTheRecordedCensus` | downloads test target, via `downloadsTestFiles(in:)` |
| 8 | The retired single-authority claim (a SENTENCE, not a count) | three assembled phrasings | offenders list | `== []` | `testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority` | **the whole scanned set** |

**Which of these a scanner change can move.** Rows 1 to 5 re-scope to the client module first, and the
excluded file is not in that tree, so they are structurally out of reach. Rows 6, 7 and 8 are the
exposed ones: 6 and 7 count over the downloads test target, which is exactly where the excluded file
lives, and 8 reads the whole set. That was the point of taking the list before the change rather than
after a surprise.

### Step 3: every census re-derived against the narrowed scan

| # | Census | Before (head `19f72be6`) | After (this plan) | Moved? |
|---|--------|--------------------------|-------------------|--------|
| 1 | Scheduling-block | Folders 2, PublicAPI 1, Scheduling 1, Testing 1 / total 5 | identical | no |
| 2 | Floor writers | ContinuedSession 4, ExecutionSupport 1 / total 5 | identical | no |
| 3 | Schedulable-read | ContinuedSession 2, PendingWork 1 / total 3 | identical | no |
| 4 | Pending-page list | ExecutionSupport 1 / total 1 | identical | no |
| 5 | Run-proof sites | ContinuedSession 2, Execution 1, ExecutionSupport 1, Manager 1, Persistence 1 / total 6 | identical | no |
| 6 | Double suspensions | ExpirationTests 3, SupportTypes 3 / total 6 | identical | no |
| 7 | Double construction | ExpirationTests 1, SupportTypes 1 / total 2 | identical | no |
| 8 | Prose assertion | offenders `[]` | offenders `[]` | no |

No table moved and no doc needed rewriting. Rows 6 and 7 were the live risk and they held for a
reason worth recording: this file's own occurrences of both tokens are written as fragments
(`"updateProgress" + ":"`, `"Task" + ".yield()"`), so it contributed zero to each table before the
exclusion and contributes zero after it. The assembled-fragment discipline is what made the scope
change safe, which is the same property that keeps it the FIRST line of defence.

Every number above is asserted by execution, not by reading: all eight cases passed at readings 3 and
5 and again in the final unfiltered run.

**`knownMembers`, confirmed by execution rather than argued to.** The two members are
`AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` and
`AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift`; neither is this
file. `requireKnownMembers(in:)` runs at the top of all eight cases, and all eight passed, so the
vacuity guard is shown still to hold rather than assumed to.

### Step 2: the exclusion, in the sibling's shape and under its binding name

The sibling, `DownloadLogPrivacyInvariantTests.swift:256-282`:

```swift
    private static func scannedFiles() throws -> [ScannedFile] {
        let root = try repositoryRoot()
        let fileManager = FileManager.default
        let invariantFilePath = URL(filePath: #filePath).standardizedFileURL.path
        var files = [ScannedFile]()

        for scannedDirectory in scannedDirectories {
            let directory = root.appending(path: scannedDirectory)
            let enumerator = try #require(
                fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: nil
                )
            )
            for case let url as URL in enumerator
            where url.pathExtension == "swift"
                && url.standardizedFileURL.path != invariantFilePath {
```

This suite, after the change:

```swift
    private static func scannedFiles() throws -> [ScannedFile] {
        let root = try repositoryRoot()
        let fileManager = FileManager.default
        let invariantFilePath = URL(filePath: #filePath).standardizedFileURL.path
        var files = [ScannedFile]()

        for scannedDirectory in scannedDirectories {
            let directory = root.appending(path: scannedDirectory)
            let enumerator = try #require(
                fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
            )
            for case let url as URL in enumerator
            where url.pathExtension == "swift"
                && url.standardizedFileURL.path != invariantFilePath {
```

Same binding name, same `where`-clause placement, same comparison against the standardized path. The
only difference is the pre-existing enumerator call formatting.

**The rationale, AUTHORED HERE.** No sentence of it is attributed to the sibling, which records none:

```swift
    /// Every Swift file under the scanned directories except this one.
    ///
    /// **Why this file is excluded, and why the reason is written here.** The exclusion's shape and
    /// its binding name come from `DownloadLogPrivacyInvariantTests.scannedFiles()`, which does the
    /// same thing so that two scanners built from one template stay readable as one pattern. Nothing
    /// else comes from there: that function carries no doc comment, so it implements this decision
    /// without recording it, and the argument below is this suite's own rather than a copy.
    ///
    /// The assembled fragments above remain the FIRST line of defence and this is the second. They
    /// have to: a census counts occurrences, so a token spelled whole here would count itself in
    /// every file it also appears in, and no path filter repairs that. What the exclusion buys is
    /// the one thing fragments cannot. `testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority`
    /// reads WHOLE FILES rather than executable lines — policing prose is its entire point — so
    /// while this file was in its own scan, the one file whose job is to explain what the retired
    /// claim IS could not spell it out, and the first plainly-worded maintenance edit would have
    /// failed the suite on its own documentation.
    ///
    /// That asymmetry is what made it a scheduled failure rather than a tidy-up: every census
    /// already drops comment lines through `executableLines(in:)`, precisely so a doc describing an
    /// inventory does not become part of it, while the prose assertion deliberately reads past that
    /// filter and went on reading the file that has to describe the rule.
```

The detection fragments were not weakened and the prose assertion's tokens were not relaxed; the
ordering is asserted from this suite's own tokens (`retiredAuthorityPhrases`, still three assembled
phrasings) rather than from any sibling's account of its own.

### Step 4: the exclusion proven in both directions, and a vacuity caught on the way

Five readings, strictly serialized, in this order.

**Reading 1 — PASS, and VACUOUS. Recorded because the vacuity is the finding.** The plainly-worded
instance was written across a line wrap, so `contents.contains("sole authority")` never matched and
the suite would have passed with or without the exclusion:

```
✔ Test testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority() passed after 0.163 seconds.
✔ Test run with 8 tests in 1 suite passed after 0.235 seconds.
** TEST SUCCEEDED **
```

The wrap was caught by a `grep -rn "sole authority" AppPackage/ App/` that returned NOTHING when it
should have returned this file. The sentence was rewritten so the phrase sits contiguously on one
line, and the reading was retaken. This is exactly the class the plan exists to refuse — a green
reading standing in for a claim that was never executed — reached inside the proof of a plan about
unexecuted claims.

**Reading 2 — the walk still reaches everything else.** A temporary plant in a DIFFERENT scanned
file, `DownloadContinuedSessionBasisTests.swift`:

```
✘ Expectation failed: (offenders.sorted() → ["AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift"]) == []
↳ The retired single-authority claim is present in AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift. …
✘ Test run with 8 tests in 1 suite failed after 0.247 seconds with 1 issue.
** TEST FAILED **
```

The offenders list names the planted file and ONLY the planted file, which is the second direction
read in the same breath: the walk still reaches the rest of the tree.

**Reading 3 — the exclusion grants the capability, non-vacuously this time.** Plant removed, the
in-file instance now contiguous:

```
✔ Test testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority() passed after 0.174 seconds.
✔ Test run with 8 tests in 1 suite passed after 0.269 seconds.
** TEST SUCCEEDED ** [36.017 sec]
```

**Reading 4 — the exclusion is load-bearing, OBSERVED rather than derived.** Reading 3 proves the
capability only if one accepts by argument that the file would otherwise self-match. Taken as a
reading instead, by temporarily disabling the exclusion
(`let invariantFilePath = "/temporarily-disabled-exclusion"`, which keeps the binding used and
excludes nothing):

```
✘ Expectation failed: (offenders.sorted() → ["AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift"]) == []
✘ Test run with 8 tests in 1 suite failed after 0.328 seconds with 1 issue.
** TEST FAILED **
```

**Reading 5 — restored, green.**

```
✔ Test run with 8 tests in 1 suite passed after 0.304 seconds.
** TEST SUCCEEDED ** [37.480 sec]
```

**The plant was removed, confirmed by grep and by the tree.** `git status --short` after removal
listed only `DownloadSourceInventoryTests.swift` as modified, and the phrase now has exactly one
occurrence in the repository:

```
$ grep -rn "sole authority" AppPackage/ App/
AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:521: …
```

### Step 5: the plainly-worded description STAYS

It is the capability the exclusion exists to grant, so removing it would leave the exclusion
unexercised and the next maintainer back where WR-04 found things. Consequences, stated so a later
round does not read them as a regression:

- The one surviving instance lives in the doc comment of
  `testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority`, in
  `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` (line 521 at commit
  time).
- It is INSIDE the excluded file, which is why the suite is green with it there.
- A repository-wide grep for the retired phrasing therefore no longer sums to zero. **The live guard
  is the prose assertion, not any repository grep.** The doc itself says so, so the statement travels
  with the occurrence rather than only with this summary.

## Task 2 (WR-03): the nil-generation policy written as a branch

### Step 1: the equivalence derived per input class, and labelled UNPROVEN

`generation` is `Int?`; `activeTaskGeneration` is `Int`. Every row below assumes the ownership guard
passed (`activeTask != nil, activeGalleryID == gid`), except the last, which is the guard itself.

| Input class | Current expression `generation != activeTaskGeneration` | Written branch | Disposition moves? |
|---|---|---|---|
| `.some(g)`, `g == activeTaskGeneration` | promotes to `.some(g) != .some(g)` → `false` | falls through to the same comparison → `false` | no |
| `.some(g)`, `g != activeTaskGeneration` | `true` | `true` | no |
| `nil` | `nil != .some(activeTaskGeneration)` → `true` | early `return true` | no |
| ownership guard fails (no live task, or another gallery holds the slot) | `false` before the comparison is reached | `false`; the branch is placed AFTER the guard on purpose | no |

Recorded at derivation time as a claim that could be wrong, and labelled **UNPROVEN until Step 4
executes it**. It is now proven: the pin passes with the branch and fails with it inverted, so the
`nil` row is executed rather than read off the type system. **No input's disposition moved**, so
nothing here is a behaviour change and none is reported as one.

### Step 2: the branch and its doc

```swift
    /// Whether a DIFFERENT live run holds this gallery's active slot, so this run's exit must
    /// retire nothing.
    ///
    /// **The generation-less case is a policy, and this branch is where it is stated.**
    /// `processDownload(gid:generation:)` is public and its `generation` defaults to `nil`, while
    /// the only stamp ever issued is the scheduler's (`+Scheduling.swift`), so a run can reach this
    /// gate carrying nothing to compare. Such a run cannot prove it owns this gallery's active slot,
    /// and it is treated as superseded: it retires nothing and leaves the entry to whichever run
    /// does own the slot.
    ///
    /// **The asymmetry is the reason, not the choice.** Leaving the entry to its owner costs one
    /// stale proof, and costs it only until that owner reaches its own exit and retires it there.
    /// Retiring on a live successor's behalf drops that successor's proof, which reproduces the
    /// G-15-26 zero-progress card — an in-flight repair contributing nothing for the rest of its
    /// re-download — through the very fix that exists to prevent it. A bounded overcount against an
    /// unbounded stall is not a close call.
    ///
    /// The comparison below would already answer `true` for `nil` through optional promotion; the
    /// branch changes no disposition. It is written so a reader can tell the case was decided rather
    /// than inherited from the types, which is why the sibling predicate directly below spells its
    /// own optional out too. `retireProvenPageWork`'s doc owns the overlapping-run argument this
    /// direction stays consistent with, and it is not restated here.
    private func isSupersededByALiveRun(
        gid: String,
        generation: Int?
    ) -> Bool {
        guard activeTask != nil, activeGalleryID == gid else { return false }
        guard let generation else { return true }
        return generation != activeTaskGeneration
    }
```

Beside it, the sibling whose written branch is the convention evidence — the whole of it, since it
carried no rationale of its own before this plan:

```swift
        if let generation {
            return activeGalleryID == gid
                && activeTaskGeneration == generation
        }
        guard activeTask == nil else { return false }
        return activeGalleryID == nil || activeGalleryID == gid
```

Two adjacent predicates over one optional input now answer it the same way, so a reader can tell
`nil` was considered in both. That is the argument; a preference for branches over promotions is not.

**Who owns which rule, so nothing is said twice.** `retireProvenPageWork`'s doc keeps the
overlapping-run disposition (why a live owner at a DIFFERENT generation means retire nothing), and
gained one pointer rather than a restatement:

```swift
    /// slot is held by a live run at a different generation retires nothing and leaves the entry to
    /// its owner, which retires it at its own exit. The generation-LESS case is a separate
    /// disposition and `isSupersededByALiveRun` states it; it is not repeated here.
```

### Step 2b: the sibling's nil arm, dispositioned by caller enumeration

**Scope decision, with its three reasons.** In scope and folded in deliberately: it is the same
generator as WR-03 one function down, so closing one and leaving the other hands the next round its
own finding back; the file was already in `files_modified` for WR-03, so nothing widened; and the
change is doc-only, adding no branch and no behaviour. `files_modified` did not grow to accommodate
it.

**The enumeration, run rather than assumed:**

```
$ grep -rn "isActiveTaskOwner" AppPackage/Sources/ AppPackage/Tests/
…+Execution.swift:254:  guard isActiveTaskOwner(gid: gid, generation: generation) else {
…+Execution.swift:289:  /// its own body is gated behind `isActiveTaskOwner`, …   (doc mention)
…+Execution.swift:343:  private func isActiveTaskOwner(                              (declaration)

$ grep -rn "finishActiveTaskIfOwned" AppPackage/Sources/
…+Execution.swift:19:   finishActiveTaskIfOwned(   (processDownload's defer)
…+Scheduling.swift:77:  finishActiveTaskIfOwned(   (processScheduledDownload)
```

One caller, `finishActiveTaskIfOwned`, with two of its own: `processScheduledDownload`, which always
passes the generation the scheduler stamped (`+Scheduling.swift:57-58`), and `processDownload`'s
`defer`, which forwards whatever its caller supplied. So a generation-less call is, by construction,
a run the scheduler never stamped. The enumeration DOES establish the rationale, so one was written
rather than the failure recorded:

```swift
    /// Whether this run may clear the gallery's active slot on its way out.
    ///
    /// **The generation-less arm, derived from the callers rather than asserted.** This predicate
    /// has one caller, `finishActiveTaskIfOwned`, which has two of its own: the scheduler's
    /// `processScheduledDownload`, which always passes the generation it stamped into
    /// `activeTaskGeneration`, and `processDownload`'s `defer`, which forwards whatever its own
    /// caller supplied — `nil` for anyone who took the public entry point's default. A
    /// generation-less run is therefore by construction a run the scheduler never stamped, and it
    /// has no identity to match.
    ///
    /// With no identity to check, ownership can only be inferred from the slot being IDLE, which is
    /// what the two conditions below require. A live `activeTask` means some run holds the slot and
    /// it is not this one; clearing it there would strand that run, because ACTIVE-OWNERSHIP
    /// CONVERGENCE records that once ownership is cleared the real owner's deferred cleanup is
    /// rejected, and the queue loses its last scheduling opportunity. An `activeGalleryID` claimed
    /// by a different gallery is the same hazard read through the other half of the pair.
```

The sibling acquires a rationale HERE, dated to this plan. It did not have one, which is precisely
what the review and the gap record got wrong.

### Step 4: the pin, and its sensitivity

`testAGenerationLessRunRetiresNothingWhileALiveRunOwnsTheSlot`, in
`DownloadContinuedSessionRunProofTests.swift`. The provisional home in the plan's `files_modified`
was re-derived and confirmed: that file already owns the retirement-lifetime case and the only
fixture seam in the target that drives a real `processDownload` to a real exit through its `defer`.

It is the deliberate mirror of `testAProofDoesNotOutliveItsRunIntoALaterRedo`, sharing its staging so
the single difference is the thing under test. There the exiting run owns the slot and the redo opens
at zero; here a live run owns it at a stamped generation while the exiting run carries none, and the
redo opens at the two pages the earlier run had already paid.

**Reached through a production route.** The proof is recorded through the preparation forwarder as
every sibling case records it; the exit is `processDownload(gid:)`, the public entry point taken at
its own `generation` default, so the gate really is reached with `nil`; the observable is read
through `retry(gid:mode:)`, the product's own tap, which enqueues, schedules and only then ensures
the session, whose seed comes from the surviving debts' keys. No retirement forwarder is called (none
exists) and no push is issued by the case.

**Non-vacuity, asserted rather than assumed:**

- the entry existed before the exit — `#expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])`
- two of the six were really paid inside the run, so a surviving entry cannot subtract back to zero
  and go vacuous — `#expect(spy.progressUpdates.isEmpty)` after a forced production flush with no
  session live
- ownership really is held, and by this gallery, so the gate reaches its generation comparison rather
  than returning early on the ownership guard — `#expect(await manager.testingHasActiveTask())` and
  `#expect(await manager.testingActiveGalleryID() == contested.gid)`
- the premise is still observably true AFTER the exit, not merely before it —
  `#expect(await manager.testingHasActiveTask())` again, because `finishActiveTaskIfOwned` refused
  this run too
- the generation really is absent, by construction: the call is `processDownload(gid:)` at the public
  default

**Both sensitivity readings.** The inversion is exactly one token —
`guard let generation else { return true }` becomes `guard let generation else { return false }`.

FAIL with the branch inverted:

```
✘ Test testAGenerationLessRunRetiresNothingWhileALiveRunOwnsTheSlot() recorded an issue at
  DownloadContinuedSessionRunProofTests.swift:527:9: Expectation failed:
  (spy.startCompletedUnitCounts.last → 0) == 2
✘ … at :529:9: Expectation failed:
  (spy.startSubtitles.last → "0 / 6 pages · 1 gallery") == "2 / 6 pages · 1 gallery"
✘ Test run with 24 tests in 1 suite failed after 0.710 seconds with 2 issues.
** TEST FAILED **
```

PASS with the branch restored (same suite, immediately before the inversion):

```
✔ Test testAGenerationLessRunRetiresNothingWhileALiveRunOwnsTheSlot() passed after 0.565 seconds.
✔ Test run with 24 tests in 1 suite passed after 0.663 seconds.
** TEST SUCCEEDED ** [35.620 sec]
```

Two things fall out of the inverted reading beyond the pin itself. The failure is on the numerator
AND on the rendered subtitle, so it is not an artefact of one accessor. And the other 23 cases in the
suite stayed green while the `nil` disposition was flipped, which is the direct evidence that no
pre-existing case exercised this arm — the arm was unpinned, which is what WR-03 said and what this
case fixes.

### Step 5: the residue sweep

**(a) No census moved.** Confirmed by execution, not argument: all seven tables and both joined
totals are green in the final unfiltered run. The production change adds no censused token to an
executable line of `+Execution.swift` (the branch is `guard let generation else { return true }`), and
doc lines are excluded by `executableLines(in:)` in every census.

**(b) No stale doc left behind.** A sweep for docs still describing the generation-less disposition as
falling out of a comparison returns only the two NEW docs, which name the promotion in order to say
the branch now states the policy. A sweep for docs describing the scanner as reading every scanned
file including its own returns nothing — and `scannedDirectories`' doc gained an explicit sentence so
the narrowed scope is discoverable where the scope is declared:

```swift
    /// The walk excludes this file itself, so the prose assertion cannot read this suite's own
    /// description of the rule back as a violation of it; `scannedFiles()` carries that argument.
```

**(c) Both items closed at their root.**

| Item | The omission that produced it | The written thing now in its place |
|------|-------------------------------|------------------------------------|
| WR-03 | The nil-generation policy existed only as a CONSEQUENCE of optional promotion, so a reader could not tell an intended policy from an accident of the types | `guard let generation else { return true }`, placed after the ownership guard, with a doc giving the WHY as the cost asymmetry — plus a case that fails when the branch is inverted |
| WR-04 | The scanner's scope silently included the one file that has to describe the prose rule, so the rule was undocumentable and the first plain-English edit would have failed the build | An explicit path exclusion in the sibling's shape and under its binding name, with a rationale authored here, proven in both directions, and the retired claim now stated in plain words inside the excluded file |

**(d) This plan created no new instance of its own generator.** Every invariant it introduced is
written rather than implied: the exclusion carries its rationale, the branch carries its policy and
direction, the sibling predicate's nil arm carries a caller-derived WHY, `scannedDirectories` records
the narrowed scope, and the retirement doc says which predicate owns the generation-less case.

## Verification

**Full unfiltered FeatureTests** — the plan's final proof and the last invocation of the round:

```
** TEST SUCCEEDED ** [97.322 sec]
passedTests: 880, expectedFailures: 7, failedTests: 0, skippedTests: 0, result: "Passed"
```

**887 tests, 0 failures** (880 passed plus the 7 pre-existing expected failures).

| Head | Total | Movement |
|------|-------|----------|
| 15-49 (`880`) | 880 | the round's baseline |
| 15-50 + 15-51 | 884 | +4 |
| 15-52 (`19f72be6`) | 886 | +2, the two census cases 15-52 added |
| **this plan** | **887** | **+1, the nil-arm case** |

Accounted case by case: the single addition is
`testAGenerationLessRunRetiresNothingWhileALiveRunOwnsTheSlot`. Task 1 left no case behind — its
two-direction proof used temporary edits only, all reverted, and the plainly-worded description it
kept is a doc comment rather than a case.

**Lint.** SwiftLint from the DerivedData artifactbundle
(`$HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/…/macos/swiftlint`,
with `AppPackage/.build` removed first), run `--strict` over all three changed files: **exit 0**. No
rule was suppressed, disabled or annotated away.

**Budgets.** `awk 'length($0)>120'` over every changed Swift file returns nothing. File lengths
against the 1000-line ERROR limit: `DownloadClient+Execution.swift` 394 (from 354),
`DownloadSourceInventoryTests.swift` 742 (from 707), `DownloadContinuedSessionRunProofTests.swift`
747 (from 624). No relocation was needed.

**`xcodebuild` serialization.** Seven invocations, strictly one at a time; none overlapped and none
was killed. One of them (reading 4) exceeded a 600-second tool timeout and finished in the background
with exit 0; its tests ran in 0.33 seconds, so the wall time was a rebuild rather than a hang, and it
was allowed to complete rather than interrupted.

## Deviations from Plan

**1. [Rule 1 — vacuity caught in this plan's own proof] The first exclusion reading was vacuous.**
- **Found during:** Task 1, Step 4.
- **Issue:** the plainly-worded instance was written across a line wrap, so
  `contents.contains("sole authority")` never matched and the prose assertion would have passed with
  or without the exclusion. A `grep` that should have found the phrase returned nothing, which is how
  it surfaced.
- **Fix:** the sentence was rewritten so the phrase is contiguous, and the reading retaken
  (reading 3).
- **Recorded rather than silently corrected** because it is the plan's own subject occurring inside
  the plan's own evidence.
- **Commit:** `4902ce48`.

**2. [Rule 2 — a derived claim converted to an observed one] One reading beyond the plan's two
directions.** Reading 3 proves the exclusion grants the capability only if one accepts by ARGUMENT
that the file would otherwise self-match. Reading 4 disables the exclusion and observes the
self-match, which is what this plan asks of every other equivalence. Cost: one extra invocation.

**3. [Rule 2 — doc honesty, CLAUDE.md deliberate-design rule] `scannedDirectories`' doc gained a
sentence** recording that the walk excludes this file, so the narrowed scope is discoverable where
the scope is declared and not only on `scannedFiles()`. This landed after the first full run, so a
SECOND full unfiltered run was taken to keep the plan's "last invocation is a green unfiltered run"
property true. Cost: one extra invocation.

**4. Invocation count.** The plan's `<verification>` anticipated between two and four `xcodebuild`
invocations; seven were taken, for the three reasons above plus the retaken reading 1. The hard
constraint — never two at once, never one killed — was honoured throughout.

## Rewritten `files_modified`

The plan's provisional candidate line is replaced by what actually landed. The candidate destination
was correct and needed no relocation:

- `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift`

`AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` was touched
temporarily by reading 2's plant and restored; it is not in any commit of this plan.

## What this plan did NOT close

- **15-UAT.md test 2** still needs its physical-device iOS 26 re-run covering the `.redownload` route
  and a `.repair` gallery in a multi-gallery queue. It is an independent axis, no plan of round 17
  advances it, and closing G-15-30 through G-15-33 does not discharge it. No device-observable
  behaviour changed here: the equivalence derivation held on every input class.
- **The overlapping-run gating recorded in 15-48-SUMMARY** is still restated in a doc and not owned by
  a test, because no current fixture can both hold a runner open mid-run and reach the working-seed
  preparation.
- **Two upstream artifacts still carry the false premise.** `15-REVIEW.md:443-445` and the G-15-33
  record in `15-VERIFICATION.md` were not edited by this plan; the correction lives here and in the
  new doc. A verification round reading those two files will meet the quotation again.

## Threat Flags

None. The change set is one internal predicate, one test scanner and one test case; no new network
endpoint, auth path, file access pattern or schema change at a trust boundary. `T-15-53-07` was
dispositioned `accept` at `low` for exactly this reason and the residue sweep confirms it.

## Commits

- `4902ce48` — `test(15-53): stop the inventory scanner policing its own prose`
- `87167590` — `fix(15-53): state the nil-generation retirement policy as a branch`

## Self-Check: PASSED

Files asserted to exist, verified on disk:

- `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift` — FOUND

Commits asserted to exist, verified in `git log`:

- `4902ce48` — FOUND
- `87167590` — FOUND
</content>
</invoke>
