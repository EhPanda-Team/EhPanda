---
phase: 15-continued-background-downloads
reviewed: 2026-08-06T00:00:00Z
depth: standard
files_reviewed: 55
files_reviewed_list:
  - App/Info.plist
  - AppPackage/Package.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
findings:
  critical: 1
  warning: 4
  info: 0
  total: 5
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-06
**Depth:** standard
**Files Reviewed:** 55
**Status:** issues_found

## Summary

Re-review after gap-closure rounds 15-46 … 15-49. Every finding in the round-15 report was
re-derived against source at HEAD, and all five are **closed**:

- **CR-01 (round-15 report), the session-scoped page-work proof.** Closed by `provenPageWorkRunGIDs`
  (`DownloadClient+Manager.swift:595`), seeded into the session's trust set inside
  `ensureContinuedSession`'s synchronous reset (`+ContinuedSession.swift:246`, ahead of the snapshot
  the opening subtitle is built from) and retired at `processDownload`'s `defer`
  (`+Execution.swift:18`, ahead of `finishActiveTaskIfOwned` so an owning run does not read itself
  as superseded). Both uncovered orderings now have production-issued regression cases in
  `DownloadContinuedSessionRunProofTests`.
- **WR-01, the shortfall-vs-selection gate.** Closed. `prepareWorkingSeedAnnouncingProgress` now
  gates on the run's own `pendingPageIndices` (`+ExecutionSupport.swift:490-501`) and hands that one
  evaluation to `performDownload` via `PreparedWorkingRun`; the second evaluation is gone from
  `+ExecutionPerform.swift` and the one-evaluation rule is pinned by
  `testPendingPageListEvaluationsMatchTheRecordedCensus`.
- **WR-02, the selection-free refusal payloads.** Closed by `makeRetriedPagesPayload`
  (`DownloadFeatureTestHelpers.swift:560-576`), which threads the stored selection through both
  production payload steps, plus `testTheRetriedPagesPayloadCarriesExactlyTheSelectionTheRouteStores`.
- **WR-03, the retired single-authority sentence.** Closed. `grep -rn "one authority\|sole
  authority\|only authority"` over both `Sources/DownloadClient` and `Tests/DownloadsFeatureTests`
  returns nothing, and the widened walk in `DownloadSourceInventoryTests` now owns the sentence.
- **WR-04 / WR-05 hygiene.** Closed. `PageDownloadProgress.completedCount` and the spy's
  `inFlightProgressUpdate` are gone with no surviving reference.

Mechanical gates re-derived rather than trusted:

- **Censuses.** All five pinned tables match source exactly: `blockScheduling(` = Folders 2 /
  PublicAPI 1 / Scheduling 1 / Testing 1 = 5; floor writers = ContinuedSession 4 / ExecutionSupport
  1 = 5; `schedulableDownloads()` callers = ContinuedSession 2 / PendingWork 1 = 3;
  `pendingPageIndices(` = ExecutionSupport 1; `provenPageWorkRunGIDs` = ContinuedSession 1 /
  Execution 1 / ExecutionSupport 1 / Manager 1 = 4. The hash-masked log inventory also matches
  (10 total, 3/1/1/2/3).
- **Lint budget.** `awk 'length($0)>120'` over every changed Swift source returns nothing; no
  changed source file exceeds the 1000-line `file_length` error limit (`AppPackage/Package.swift`
  sits at 1129 but is pre-existing and net-shrank by one line this phase); no `swiftlint:disable`,
  `try?`, `try!`, `@unchecked Sendable` or `nonisolated(unsafe)` appears in the phase's files.
- **Localization.** All 8 keys carry all six locales. `continued_session.subtitle` exposes all three
  numeric arguments as named `%#@…@` substitutions (`completed`/`total`/`galleries`, `argNum` 1/2/3,
  `lld`); `en` and `de` category sets are identical per variable, and `ja`/`ko`/`zh-Hans`/`zh-Hant`
  are `other`-only. No bare numeric specifier appears in any outer value.

The BLOCKER below is the *inverse* of the defect the last four rounds chased. The proof-of-page-work
admission is a **boolean**, but the basis it unlocks is the record's **full** `completedPageCount` —
and for the refusal family that count is precisely the work the run has not done yet. So the family
that used to report a pinned `0 / N` now reports a pinned `N / N`, and a mid-run departure retires
`N` into both sides of the fraction: the over-retirement `reconcileRetiredSessionPages`'s own doc
names as "the defect", reached through the fix for the under-report.

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01: the run's proof unlocks the record's FULL page count, so a refusal-family repair opens at 100%, never advances, and can terminate the session as a successful `N / N` over a fraction of `N` pages

**Classification:** BLOCKER

**Files:**
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:495-501` (the boolean admission)
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:159-163` (the basis the admission unlocks)
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:591-603` (the retirement it unlocks)
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:557-564` (the written premise source now contradicts)
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift:126-129`, `:212` (the 100% opening pinned as expected)
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift:59-66`, `:147-151`

**Issue:** the admission records a bare membership,

```swift
if !pendingPages.isEmpty {
    provenPageWorkRunGIDs.insert(payload.gallery.gid)
    if let continuedSessionID {
        observedIncompleteSessionGIDs.insert(payload.gallery.gid)
        await pushContinuedSessionProgress(sessionID: continuedSessionID)
    }
}
```

and membership makes the record authoritative *in full*:

```swift
let isSessionWork = download.isIncomplete
    || observedIncompleteSessionGIDs.contains(download.gid)
pages[download.gid] = isSessionWork ? download.completedPageCount : 0
```

For the family this admission exists to serve — a `.repair` whose `reconcileWorkingManifestAgainstPageFiles`
REFUSED — `completedPageCount` is by construction the record's untouched ceiling. The refusal returns
the manifest verbatim (`+ExecutionSupport.swift:634`, `:646`, `:655`), and the flush path is monotone
upward (`refreshManifestPageFileHashes` only ever assigns non-empty hashes), so the count is `N` at the
announcement and `N` at every push until the run ends. Three consequences, all derived from source:

1. **The card opens and stays at 100% for the whole re-download.** Take the ordinary production route:
   the user deletes a downloaded gallery's page files through the Files app (`UIFileSharingEnabled`
   is `true`, `App/Info.plist:170`), then taps resume. `resumeMode` reaches `.repair` through its
   missing-files branch; `pageFileScan` succeeds and accounts for none of the six claimed pages, so
   `blankedPageCount` reaches six and the residual guard `blankedPageCount < manifest.completedPageCount`
   refuses. The run proves six pages of work, trust is granted, and `schedulableSnapshot` sums
   `6 / 6`. The system card reads **"6 / 6 pages · 1 gallery"** before a single byte is fetched. Both
   run-proof cases assert exactly that string as the expected opening
   (`DownloadContinuedSessionRunProofTests.swift:129`, `:212`).
2. **The numerator is frozen for the entire run.** `pushContinuedSessionProgress`'s own doc states the
   push exists for liveness — "the scheduler forcibly expires tasks that appear stalled, and
   prioritises terminating the ones reporting the least progress"
   (`ContinuedProcessingSession.swift:196-198`). For this family the pre-fix constant was `0` and the
   post-fix constant is `N`; in neither case does the pushed numerator move while `N` pages are
   actually downloading. In a mixed queue (`G` refusal-repair at 6/6 plus a fresh `H` at 0/10) the
   pair sits at `6 / 16` for the whole of `G`'s work. The fix moved the constant, not the stall.
3. **A mid-run departure retires the ceiling into both sides.** This is the provable harm. Pause a
   100-page refusal repair after five pages: the gid leaves the schedulable set, is in
   `observedIncompleteSessionGIDs`, and its record survives, so
   `retiredSessionPages[gid] = min(max(record.completedPageCount, 0), record.pageCount)` = **100**.
   If it was the session's only gallery, `reconcileContinuedSession`'s drain branch then pushes
   `100 / 100 pages · 0 galleries` and calls `finish(clientSessionID, true)`. The session reports a
   fully successful 100-page completion for five pages of work on a *paused* download.

`reconcileRetiredSessionPages`'s own doc forbids exactly that outcome and names the guard that is
supposed to prevent it (`+ContinuedSession.swift:557-564`):

> A redo that never ran … would otherwise retire pages the session never downloaded into both sides
> of the fraction and report a finished session. So a departed gallery outside
> `observedIncompleteSessionGIDs` retires its last observation instead …

and closes with the direction rule the change reverses (`:571-574`):

> under-retiring keeps the fraction at or below truth, while over-retiring is the defect.

15-43/15-48 put the refusal family *inside* `observedIncompleteSessionGIDs`, so the guard no longer
holds it out, and the over-retirement it forbids is now the family's normal path. The
acknowledgement in `DownloadContinuedSessionLedgerRefusalTests.swift:59-66` ("a trusted
complete-reading record honestly rides at its own ceiling … BY DESIGN") describes the *completed*
case, where the terminal `N / N` happens to be true; it does not cover the paused, deleted,
cancelled or expiration-swept departures, which reach the same retirement through the same line and
are not honest. Note that `pauseAllSchedulable` makes the expiration sweep one of those departures,
so an expiration during a refusal repair also retires the ceiling.

The trust also outlives the run inside a session: `retireProvenPageWork` removes the entry from
`provenPageWorkRunGIDs` but nothing removes it from `observedIncompleteSessionGIDs`, so after a
failed refusal repair the gid keeps contributing its full `completedPageCount` while merely queued —
the queued-window zero D-G4-01 guarantees, lost for the rest of that session.

**Fix:** make the proof carry the run's *shortfall*, not a boolean, so the basis is the work this run
has actually finished rather than the record's ceiling. The pending list is already derived exactly
once and already travels with the seed (`PreparedWorkingRun`), so the number is in hand:

```swift
// DownloadClient+Manager.swift — replace the Set with the run's own shortfall.
/// Galleries whose CURRENT RUN has proved page work, and how many pages that run still owes.
///
/// A count rather than a membership, because membership unlocks the record's FULL
/// `completedPageCount` and for the refusal family that count IS the run's remaining work: the
/// reconciliation refused, so the record reads N-of-N for the whole re-download. Crediting N there
/// opens the card at its ceiling, freezes the numerator for the run, and retires N into both sides
/// of the fraction on any mid-run departure — the over-retirement D-G2-01 forbids.
var provenPageWorkRunShortfalls = [String: Int]()
```

```swift
// DownloadClient+ExecutionSupport.swift
if !pendingPages.isEmpty {
    provenPageWorkRunShortfalls[payload.gallery.gid] = pendingPages.count
    ...
}
```

```swift
// DownloadClient+ContinuedSession.swift — schedulableSnapshot
let shortfall = provenPageWorkRunShortfalls[download.gid] ?? 0
let basis = download.isIncomplete
    ? download.completedPageCount
    : max(download.completedPageCount - shortfall, 0)
pages[download.gid] = observedIncompleteSessionGIDs.contains(download.gid) || download.isIncomplete
    ? basis
    : 0
```

Decrement the shortfall from `flushDownloadProgress` for pages the flush actually wrote (it already
holds `resolvedPages`), so the numerator climbs page by page — which is what the push exists to
report — and apply the same `max(record.completedPageCount - shortfall, 0)` clamp in
`reconcileRetiredSessionPages`, so a departure retires what the session finished rather than what the
record claims. Then correct `+ContinuedSession.swift:557-564` and
`DownloadContinuedSessionLedgerRefusalTests.swift:59-66` to state the rule source implements, and add
two cases: (a) a refusal repair PAUSED after `K` of `N` pages, asserting the terminal pair is `K / K`
rather than `N / N`; (b) a refusal repair whose intermediate pushes strictly increase across the
re-download, so the frozen-numerator reading cannot return.

**What would falsify this:** a production route that lowers a refused record's `completedPageCount`
during the run. Re-derived and there is none — `reconcileWorkingManifestAgainstPageFiles` returns the
manifest verbatim on all three refusal exits, `refreshManifestPageFileHash(es)` assigns only
non-empty hashes (`DownloadStore+Operations.swift`), `addingCurrentFileHashes` fills empty hashes
only, and `setupWorkingFolder`/`ensureWorkingManifest` do not delete or rewrite a folder on the
`.repair` branch (`shouldReuseWorkingFolder` returns `true` unconditionally for `.repair`).

### Warnings

#### WR-01: every session mints a fresh `BGTaskScheduler` identifier, so the process accumulates launch handlers it can never unregister

**Classification:** WARNING

**Files:**
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:136-152`
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift:84-98`

**Issue:** the identifier is minted per `start(...)` call,

```swift
let identifier = "\(bundleIdentifier).continued.\(UUID().uuidString)"
let registered = scheduling.register(identifier) { [weak self] task in ... }
```

and the file's own doc states the constraint that makes this unbounded: "Handlers can never be
unregistered and the system kills the app on a second registration of the same identifier". A
session ends at every queue drain, every expiration and every `.unavailable`, and the next
qualifying tap starts a new one — so a single app run with a dozen download bursts registers a dozen
permanent handlers, each retaining a closure and an identifier string, and each remaining live for
a launch that can no longer be adopted. On a device where `submit` throws persistently (the
`notPermitted` arm) every retry registers another handler while none is ever used.

The `ContinuedTaskScheduling.live` comment (`:66-83`) answers a different question. Its device
evidence establishes that post-launch registration is *honoured*; it says nothing about the cost of
repeating it, and the doc's own asymmetry argument ("moving registration earlier is structurally
impossible under a per-session identifier") is a consequence of the per-session choice rather than a
defence of it.

**Fix:** mint the identifier once per process, not per session. The stated requirement is only that
one identifier is never registered twice — which a process-scoped identifier satisfies exactly as a
per-session one does — and `endSession` already takes the pending request back, so the same
identifier can be re-submitted for the next session:

```swift
/// Minted ONCE per process, not per session. A handler can never be unregistered and a second
/// registration of one identifier kills the app, so the identifier must be unique — it does not
/// have to be fresh. Re-minting it per session registered a new permanent handler for every
/// download burst; `endSession` already takes the pending request back, so one identifier serves
/// every session sequentially.
private var registeredIdentifier: String?
```

Register on first use, guard subsequent starts on `registeredIdentifier != nil`, and keep
`didCancelStaleRequests` as-is for previous-build leftovers. Add a lifecycle case driving two
sequential sessions over one spy and asserting `registeredIdentifiers.count == 1` with
`submissions.count == 2`.

---

#### WR-02: the `.unavailable` client double is synchronous at all three endpoints, breaking the timing discipline its sibling spy documents

**Classification:** WARNING

**Files:**
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift:403-417`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:82-86` (the rule it breaks)

**Issue:** `BackgroundProcessingClientSpy`'s header states the contract every double at this seam
must honour:

> It also mirrors the live seam's *timing*: the live value is main-actor-confined, so every endpoint
> hops off the calling actor, and every one of the three closures below therefore yields at least
> once before it records. **A double that is atomic where the seam suspends certifies reentrancy
> races as impossible**, which is how a drain suite can be green against a tail that interleaves in
> production.

The `.unavailable` double one file over is atomic at all three:

```swift
static let unavailable = Self(
    start: { _, _, _, _ in
        let events = AsyncStream<BackgroundProcessingEvent> { continuation in
            continuation.yield(.unavailable)
            continuation.finish()
        }
        return BackgroundProcessingSession(id: UUID(), events: events)
    },
    updateProgress: { _, _, _, _ in },
    finish: { _, _ in }
)
```

No `await Task.yield()` anywhere. `ensureContinuedSession`'s ownership re-check
(`+ContinuedSession.swift:268`), its additive floor seed (`:283`) and its merged trust seed (`:313`)
all exist specifically to survive the client start's main-actor hop, and both cases that run this
double (`testUnavailableSessionLeavesQueueStateEqualToTheInertClient`,
`testUnavailableSessionSurfacesNothingAndLeavesNoLiveSession`) drive that path with the hop removed.
Per `DownloadContinuedSessionRunProofTests.swift:28-30` the `.unavailable` outcome is "the ordinary
outcome rather than an exotic one", so this is the family least able to afford an atomic double.

**Fix:** open each closure with `await Task.yield()`, exactly as the spy's three do, and state the
reason in the double's doc rather than leaving the reader to compare it against the sibling:

```swift
static let unavailable = Self(
    start: { _, _, _, _ in
        // Yields for the same reason `BackgroundProcessingClientSpy` does: the live seam is
        // main-actor-confined, so a start ALWAYS hops, and an atomic double certifies the start
        // window's re-checks as unreachable.
        await Task.yield()
        ...
    },
    updateProgress: { _, _, _, _ in await Task.yield() },
    finish: { _, _ in await Task.yield() }
)
```

---

#### WR-03: `isSupersededByALiveRun` encodes its nil-generation policy in an implicit `Int?` vs `Int` comparison, where its sibling states the same policy explicitly

**Classification:** WARNING

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift:308-314`

**Issue:**

```swift
private func isSupersededByALiveRun(
    gid: String,
    generation: Int?
) -> Bool {
    guard activeTask != nil, activeGalleryID == gid else { return false }
    return generation != activeTaskGeneration
}
```

`generation` is `Int?` and `activeTaskGeneration` is `Int`, so the comparison promotes and `nil`
compares unequal to every generation. The effect is a policy — *a run that presents no generation is
superseded by any live run on the same gallery, and therefore retires nothing* — reached by
type promotion rather than by a written branch. `processDownload(gid:generation:)` is `public` with
`generation` defaulting to `nil`, so the arm is reachable from outside the module, and the sibling
predicate directly below it handles the same input with an explicit branch and a recorded rationale:

```swift
private func isActiveTaskOwner(gid: String, generation: Int?) -> Bool {
    if let generation { ... }
    guard activeTask == nil else { return false }
    return activeGalleryID == nil || activeGalleryID == gid
}
```

In a module whose docs pin five separate source censuses precisely because unwritten invariants rot,
leaving this one to an optional promotion is the same failure mode one layer down: a reader cannot
tell whether `nil` was considered or merely fell out of the types, and neither can a later fix.

**Fix:** state it:

```swift
private func isSupersededByALiveRun(gid: String, generation: Int?) -> Bool {
    guard activeTask != nil, activeGalleryID == gid else { return false }
    // A generation-less run cannot prove it owns this gallery's slot, so it is treated as
    // superseded and retires nothing. That is the safe direction: leaving the entry to the run
    // that does own the slot costs one stale proof until that run exits, while dropping a live
    // successor's proof is the G-15-26 zero-progress card.
    guard let generation else { return true }
    return generation != activeTaskGeneration
}
```

---

#### WR-04: the source-inventory scanner walks its own file, where the sibling scanner built on the same pattern deliberately excludes itself

**Classification:** WARNING

**Files:**
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:442-462` (no self-exclusion)
- `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift:259`, `:270-272` (the exclusion it omits)

**Issue:** `DownloadLogPrivacyInvariantTests` removes itself from its own scan and says why —
"Excluding this file by path is a second line of defence behind the assembled tokens: even if a
future edit spelled one out, the scan would not read it back as a violation of itself".
`DownloadSourceInventoryTests` was written from the same template but its `scannedFiles()` has no
`invariantFilePath` filter, so `testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority`
polices its own prose. It passes today only because the three retired phrasings exist there as
run-time fragments (`"one" + " authority"`), never as prose — which means the one file whose whole
job is to explain what the retired claim *is* cannot spell it out, and any future maintainer who
documents the check in plain English fails it.

The gap is asymmetric with the suite's own reasoning: the census tests exclude comment lines
(`executableLines`, `:427-432`) so a doc that describes an inventory does not become part of it,
while the prose test deliberately reads whole files and then includes the file that must describe
the prose rule.

**Fix:** apply the sibling's exclusion and record the same reason:

```swift
// Excluded for the reason DownloadLogPrivacyInvariantTests states for its own scan: this file has
// to be able to DESCRIBE the retired claim to be readable, and a prose rule that reads its own
// description back is a self-match waiting for the first plainly-worded edit. The assembled
// fragments stay as the first line of defence; this is the second.
let invariantFilePath = URL(filePath: #filePath).standardizedFileURL.path
for case let url as URL in enumerator
where url.pathExtension == "swift" && url.standardizedFileURL.path != invariantFilePath {
```

Keep `knownMembers` as-is — neither named member is this file, so the vacuity guard is unaffected.

---

_Reviewed: 2026-08-06_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
