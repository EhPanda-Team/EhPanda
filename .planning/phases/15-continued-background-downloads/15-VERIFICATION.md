---
phase: 15-continued-background-downloads
verified: 2026-08-10T03:08:11Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "Folder rename can move a source outside the persisted download root — closed at its root by DownloadStore.renameUserFolder + confinedDirectUserFolderURL (single component, normalization identity, standardized parent, resolved parent, re-checked inside the operate closure, symlink source refused by attributesOfItem), with an argument-driven escape suite."
    - "retryPages widens an all-invalid selection into whole-gallery repair work — closed at its root: the domain filter and the empty refusal now precede mode resolution, update delegation, failure clearing, generation advance, enqueue, scheduling and session ensure, and normalizeFetchedPayload preserves .some(empty) via rawPageSelection.map."
  gaps_remaining:
    - "Validation/read paths still delete a rejected page file while reconciling nothing (CR-01 relocated onto loadManifest / sanitizeLocalFilesIfNeeded / resumeMode, not eliminated)."
  regressions:
    - "The 15-61 generation fix introduced a NEW unbracketed downward mover of the credited session basis (advanceQueueIntentGeneration), which the stale monotonic floor then masks — the G-15-6/G-15-7 failure mode the module's own doc forbids."
    - "deleteFolder(name:) is the un-swept sibling of the rename confinement fix and still builds its filesystem target from an unnormalized, unconfined caller name."
gaps:
  - truth: "The system-provided progress UI reflects real download progress (SC2)."
    status: failed
    reason: "advanceQueueIntentGeneration(for:) is now a deliberate DOWNWARD mover of the credited session basis — for a gallery with a complete record whose observation was stamped under the previous generation, sessionCreditedPages steps from `recorded` to 0 the instant the generation increments (DownloadClient+ContinuedSession.swift:243-247). None of its four call sites is enclosed by withdrawingCountedBasisMovement, so lastPushedCompletedPageCount is never lowered by the matching amount and the monotonic floor sits N pages above the honest sum. The next N pages of genuine work — the re-queued gallery's or the keeper's — move the card not at all. That is exactly the masking the file's own doc names as G-15-6/G-15-7, it falsifies the invariant restated at ContinuedSession.swift:235-236 (\"No regime boundary can therefore drop the credited count on its own; deliberate movers are bracketed\"), and it feeds ContinuedTaskScheduling's most-stalled expiration policy a task that appears to have stopped progressing. prepareWorkingSeed's bracket cannot recover it: by the time the redo runs, creditedBefore == creditedAfter == 0, so it withdraws nothing (DownloadClient+ExecutionSupport.swift:277-284). enqueue has the same shape with the advance (PublicAPI.swift:107) landing AFTER writeInitialManifest's bracket closes (PublicAPI.swift:143-157), so that bracket measures both endpoints under the old generation."
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
        issue: "advanceQueueIntentGeneration (line 823-825) is a bare increment with no D-G7-01 bracket, despite now being a mover of the quantity sessionCreditedPages is summed from."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: "sessionCreditedPages (243-247) drops from `recorded` to 0 on a generation mismatch; reconcileRetiredSessionPages (769-771, 790-796) simultaneously drops the gallery's retirement ledger entry, so the summed numerator falls in one step with no withdrawal."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift"
        issue: "Both queue-mobilizing advances (performRetry line 37, performRetryPages line 117) are unbracketed."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
        issue: "resume's advance (line 360) is unbracketed."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift"
        issue: "enqueue's advance (line 107) sits after writeInitialManifest's bracket has already closed (line 157), so no bracket spans the movement."
      - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
        issue: "testARequeuedGalleryInheritsNoPredecessorObservationCredit lands SIX keeper pages in one flush specifically to clear the floor in a single jump (its own doc, lines 640-646, states the re-queue's own push 'discriminates nothing'). It therefore cannot observe the frozen frames it was written to protect."
    missing:
      - "Sweep ALL EXIT PATHS, not the named one: wrap the movement itself — `advanceQueueIntentGeneration` wraps its own increment in `withdrawingCountedBasisMovement(gid:)` — so every present and future call site is enclosed by construction. Do NOT patch the four call sites individually; that is the branch-scoped shape this phase has re-opened repeatedly."
      - "Verify the bracket composes as a SIBLING at every site (never nested inside prepareWorkingSeed's or writeInitialManifest's bracket), per the composition rule at ExecutionSupport.swift:262-268."
      - "Add a regression that lands the keeper's pages ONE AT A TIME across the re-queue and asserts the pushed numerator moves on the FIRST one. A test that lands them in a single flush cannot discriminate the defect."
      - "Re-audit the enumerated invariant at ContinuedSession.swift:230-236 against source after the fix, so the doc's claim that every deliberate mover is bracketed is true rather than asserted."
  - truth: "Ordinary read paths never destroy a page file, and any scan that observes the manifest's claim to be wrong reconciles the manifest durably at that moment (SC2/SC3; CLAUDE.md manifest-SSOT invariant)."
    status: failed
    reason: "The CR-01 fix moved the deleting probe off the validateImageData route but left it on the read routes; `validate(download:verifiesContentHashes:discardingRejected:)` still defaults discardingRejected to TRUE and both remaining callers take the default. Opening a downloaded gallery runs loadManifest -> sanitizeLocalFilesIfNeeded -> scanCompletedFolder, whose two probes discard their results (`_ =`) and exist purely for the side effect, both on the discarding default (PersistenceHelpers.swift:32-39); a zero-byte or non-regular page file is DELETED there. loadManifest then calls storage.validate on the discarding default (PublicAPI.swift:271-274) and returns .missingFiles for the page the sweep just removed. Nothing writes the manifest on this path — not reconcileWorkingManifestAgainstPageFiles, not refreshManifestPageFileHashes — so the page's hash stays non-empty, the gallery keeps deriving .completed under D-SSOT-07, the badge keeps counting the page, and the divergence survives relaunch. Not even a session-scoped signal is recorded (loadManifest touches neither downloadErrors nor validationErrors). resumeMode(for:) (SchedulingHelpers.swift:68-73) takes the same discarding validate to decide repair-versus-redownload. The justification written at DownloadStore+Operations.swift:494-498 — that these callers' 'answer feeds nothing destructive' — is the wrong test: the hazard is that FORMING the answer deletes files. This is CR-01's end state reached by opening the reader instead of by tapping Validate, and it is a direct violation of the CLAUDE.md rule that a scan observing the record's claim to be wrong must reconcile the manifest durably at that moment and that in-memory state must never be required to make the record truthful."
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+PersistenceHelpers.swift"
        issue: "scanCompletedFolder (27-40) calls existingPageRelativePaths and existingCoverRelativePath with no discardingRejected argument, so the default `true` deletes rejected files during an ordinary read, and both results are discarded."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift"
        issue: "loadManifest (265-286) calls storage.validate without discardingRejected and reconciles nothing on .missingFiles."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift"
        issue: "resumeMode's storage.validate (68-71) takes the same discarding default."
      - path: "AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift"
        issue: "validate's discardingRejected defaults to true (line 502), making the destructive behavior opt-out instead of opt-in."
      - path: "AppPackage/Sources/DownloadClient/DownloadStore.swift"
        issue: "probeAssetFile's rejection branches (884-895) delete via discardRejectedAssetIfPermitted whenever the caller took the default."
    missing:
      - "Sweep EVERY caller of validate / existingPageRelativePaths / existingCoverRelativePath / pageFileScan / sanitizeAssetFileIfNeeded, not just the two the review named. Establish the property by construction: flip the discardingRejected default to FALSE so mutation is opt-in and every deleting caller must name it, or give scanCompletedFolder a real reconciling contract (take a full pageFileScan(discardingRejected: true) and run the deleted pages through reconcileWorkingManifestAgainstPageFiles under withdrawingCountedBasisMovement, exactly as blankingPass does)."
      - "Add a case that opens loadManifest over a one-page gallery whose only page file is zero bytes and asserts BOTH that the file survives AND that the manifest still matches the disk afterwards."
      - "WR-01 (same subsystem, will re-open otherwise): the new fourth clause at ExecutionSupport.swift:704 shrinks blankedPageCount, which the wholesale guard at line 719 compares against manifest.completedPageCount — so a mixed rejected-plus-absent shape can now drop BELOW the all-or-nothing threshold and license blanking the guard previously refused. That contradicts 15-62's self-reported 'can only blank less'. Either measure the guard over the pages the loop WOULD have considered (absences plus surviving rejections), or state the widened behavior at lines 648-656 and pin it with a mixed-shape case; the doc at 711-718 currently enumerates only 'yielded or unprobed' and omits rejected."
      - "WR-02 (same subsystem): probeAssetFileContent (DownloadStore.swift:949-957) returns .rejected(fileRemains: true) UNCONDITIONALLY and never deletes, so even a discarding caller now records that page in rejectedPageRelativePaths and skips blanking it. removeRefutedPageFiles is reached only from reconcileValidatedRecordAgainstPageFiles, so on the automatic routes (prepareWorkingSeed, blankingPass) the record keeps a non-empty hash beside positively refuted bytes indefinitely. Correct the two doc claims that rest on rejections being deleted (DownloadStore.swift:96-100 and ExecutionSupport.swift:645-647, 'every pre-existing caller is byte for byte unchanged'), and decide the substantive question: remove the surviving refuted file before the discarding callers' reconciliation, or record the refutation durably."
  - truth: "A destructive folder operation cannot reach a filesystem target the caller did not name, and the persisted record converges with the disk afterwards (SC3; CLAUDE.md manifest-SSOT invariant)."
    status: failed
    reason: "15-63 gave renameFolder a real boundary and left the adjacent destructive operation on the old construction — the un-swept sibling. deleteFolder(name:) passes the raw, unnormalized name straight to storage.userFolderURL(name:) (Folders.swift:97), which only appends the component, then to storage.removeFolder(at:). removeFolder's guard is lexical prefix containment only — `targetURL.path.hasPrefix(rootURL.standardizedFileURL.path + \"/\")` (DownloadStore+Operations.swift:379-388) — which stops `..` and absolute paths but ADMITS any nested path under the root, so `\"MyFolder/[123_abc] Some Title\"` recursively deletes a gallery folder. None of renameUserFolder's refusals apply: no single-component check, no normalization-identity check, no symlink-source check, no directory-type check. The recovery path then diverges from the manifest: the coordinator's cleanup keys on parentFolderName == name (Folders.swift:102), which matches nothing for a nested name, so downloadIndex, the queue store and the background-task store keep entries for a gallery whose folder this call just erased, and the deleted gallery goes on reading .completed from an in-memory record. Two of the three arguments that made the rename case a blocker apply verbatim — it is a public DownloadClient endpoint, and its filesystem boundary must enforce confinement itself — with the third (escaping the sandbox root) replaced by unbounded data loss inside it. The escape suite added by 15-63 covers renameFolder only; DownloadFolderOperationTests has no deleteFolder confinement case."
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift"
        issue: "deleteFolder (96-153) constructs its target from an unconfined caller name and its record cleanup keys on an exact parentFolderName match that a nested name never satisfies."
      - path: "AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift"
        issue: "removeFolder(at:) (379-388) enforces lexical prefix containment only — nested paths under the root are admitted, and symlinks are not resolved before the comparison."
      - path: "AppPackage/Sources/DownloadClient/DownloadStore.swift"
        issue: "userFolderURL(name:) (161-163) is plain path appending and offers no confinement guarantee to any caller."
      - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift"
        issue: "RenameEscapeSource covers renameFolder only; there is no deleteFolder escape suite."
    missing:
      - "Sweep EVERY user-folder filesystem operation that takes a caller-supplied name — deleteFolder, createFolder, moveDownload's destination parent, and any future sibling — through the one store-owned boundary (confinedDirectUserFolderURL), rather than fixing deleteFolder alone. Make userFolderURL(name:) unreachable as a mutation target, so the next sibling cannot regress."
      - "Add a store-owned deleteUserFolder(named:) that re-checks confinement and directory type inside the same fileManager.operate closure that performs the removal, matching renameUserFolder's ordering."
      - "Tighten removeFolder(at:) itself — the shared primitive — to resolve symlinks before the prefix comparison and to refuse nested targets for user-folder callers."
      - "Extend the escape suite (or add a sibling arguments: suite) so `..`, `../Outside`, an absolute path, a nested `\"Alias Target/Nested\"`, a whitespace-padded alias and a symlinked direct child are all asserted refused with the target's bytes intact."
      - "Assert record convergence: after a refused or a legitimate delete, downloadIndex / queueStore / backgroundTaskStore hold no entry for a gallery whose folder is gone."
  - truth: "A retry request the client refuses is reported to the user, and a selection that collapses at fetch time does not settle the run as a failure (SC2 — consequences of the CR-04 narrowing, review WR-04/WR-05)."
    status: partial
    reason: "CR-04 itself is closed at its root, but two consequences of the narrowing are unhandled at the callers. (a) retryPagesDone(.failure) clears retryingPageIndices and re-sends .loadInspection without setting state.toast (DownloadInspectorReducer.swift:188-193), even though the reducer owns a toast surface and uses it for validation results at line 235 — so the new .notFound refusal turns a tap on Retry into a visible no-op: rows flash to .pending from the optimistic rewrite and silently revert. .failure(.notFound) is also the same value retryPages returns when the gallery is absent (RetryHelpers.swift:73) and when its folder is absent (line 88), so the localized message cannot match what happened. (b) An empty-but-present selection that only becomes inadmissible at fetch time is not a no-op: pendingPageIndices returns [], the announcement gate declines, downloadCoverImage still runs, and finalizeBatchResult calls missingFinalizedPageIndices over the WHOLE manifest, so any page the .repair seed just blanked throws IncompleteDownloadError and the gallery settles into a persistent .error record for work the user never requested."
    artifacts:
      - path: "AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift"
        issue: "The retryPagesDone failure branch (188-193) surfaces nothing; the only state.toast assignment in the file is the validation one at line 235."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift"
        issue: ".failure(.notFound) conflates 'this download is gone' (line 73), 'its folder is gone' (line 88) and 'the pages you named are outside this gallery' (line 81)."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift"
        issue: "normalizeFetchedPayload (185-191) preserves the empty selection correctly but does not detect the collapse, so the run proceeds to finalize."
    missing:
      - "Introduce a distinct error for an inadmissible selection (e.g. .fileOperationFailed(String(localized: .downloadStoreInvalidPageSelection))) and surface it on the failure branch, matching the validation action's toast; assert the toast in DownloadRetryPagesTests."
      - "Detect the fetch-time collapse at normalizeFetchedPayload's boundary — a non-nil raw selection the fetched count empties is a request that can no longer be honoured — and throw a named AppError there instead of letting finalize report a generic incomplete-download error about pages the run was never asked to fetch."
      - "Sweep every consumer of the three-state selection contract (pendingPageIndices, the announcement gate, downloadCoverImage, finalizeBatchResult / missingFinalizedPageIndices) for the explicit-empty case, not just the two the review named."
deferred: []
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just started keeps running when the app is backgrounded, surfaced by the system-provided progress UI, instead of being cut short by the short grace period that bounded the previous behavior.

**Verified:** 2026-08-10T03:08:11Z
**Status:** gaps_found
**Re-verification:** Yes — after gap-closure plans 15-61 … 15-64 and the re-review committed as `df007657`.

## Goal Achievement

### Observable Truths

| # | Roadmap success criterion | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding, past the old `beginBackgroundTask` grace period. | ✓ VERIFIED | `ContinuedTaskScheduling.swift` submits a `BGContinuedProcessingTaskRequest` with `request.strategy = .queue` (line 102-109) and is the only file in the package that imports `BackgroundTasks` or touches `BGTaskScheduler`. A source census over `App`, `AppPackage/Sources` and `ShareExtension` returns zero hits for `BGProcessingTask`, `beginBackgroundTask`, `endBackgroundTask`, `BackgroundTaskClient`, `downloads.processing` and `downloads.assertion`. `App/Info.plist` carries `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` and the `processing` background mode. Physical-device UAT test 1 (>60 s backgrounded) passed and nothing in `782013eb..HEAD` touches this path. |
| SC2 | The system progress UI reflects real download progress; its cancel affordance stops the queue, leaving state consistent with an in-app cancel. | ✗ FAILED | Two independently reproduced defects. (1) `advanceQueueIntentGeneration` is now an unbracketed downward mover of the credited basis, so the stale monotonic floor absorbs the next N pages of genuine work and the card freezes — see gap 1. (2) Ordinary read paths delete page files while reconciling nothing, so persisted completion claims and the disk disagree, permanently — see gap 2. |
| SC3 | Best-effort submission, no fallback tier; refusal/queue/expiration suspend and resume next foreground with no lost or duplicated work and no user-visible error. | ✗ FAILED | The no-fallback-tier half is verified (census above; `.queue`, `.unavailable`, `.expired` and silent teardown are wired through the self-finishing event stream, and physical-device UAT test 3 passed). The **no lost work** half fails: an ordinary reader open silently deletes a rejected page file whose manifest hash stays non-empty, so the page is lost and never re-fetched, across relaunch (gap 2); and `deleteFolder` can erase a nested gallery folder from an unconfined caller name while `downloadIndex`, the queue store and the background-task store keep its entries (gap 3). |
| SC4 | A testable `BackgroundProcessingClient` seam exposes start / update-progress / complete with events on a self-finishing stream, `testValue` unimplemented, no reducer **or coordinator** touching the scheduler. | ✓ VERIFIED | `BackgroundProcessingClient` is a `@DependencyClient` struct with exactly `start`, `updateProgress`, `finish`; the macro-synthesized `BackgroundProcessingClient()` leaves every endpoint unimplemented and `testUnimplementedClientReportsAnIssueForEveryEndpoint` calls all three. `.live` forwards to the `@MainActor` `ContinuedProcessingSession`; `.noop` is explicit and suspends in all three closures. `endSession` clears the held task and continuation, yields the terminal event and calls `finish()` on the stream (ContinuedProcessingSession.swift:347-368). `DownloadClient.live()` injects `.live` at line 77; nothing outside the `BackgroundProcessingClient` module imports `BackgroundTasks`. |

**Score:** 2/4 truths verified (0 present-but-behavior-unverified)

The two SCs that failed did so for defects observable in the present tree, not for the historical G-15-34 progress defect (closed by plans 54-60 and covered by the device UAT).

### Verdict on the four prior blockers

| Prior blocker | Independent verdict | Evidence |
|---|---|---|
| CR-01 — validation deletes a rejected page file before the guard | **Relocated, not closed** | The `validateImageData` route is genuinely fixed: `PersistenceNormalize.swift:133, 250, 367` all pass `discardingRejected: false`, rejected pages carry a file identity through `PageFileScan.rejectedPageRelativePaths`, and removal happens after the combined guard. But `validate`'s parameter still **defaults to `true`** (`DownloadStore+Operations.swift:502`) and the two read callers take the default. New gap 2. |
| CR-02 — stale observation credits a redo | **Closed at its root; the fix introduced a new defect** | Generation stamping is correct and all four queue-mobilizing entry points advance before their snapshot. The advance is now an unbracketed downward mover. New gap 1. |
| CR-03 — rename source path traversal | **Closed at its root; sibling not swept** | `renameUserFolder` + `confinedDirectUserFolderURL` is a solid boundary (non-empty, not `.`/`..`, single component, normalization identity, standardized parent, resolved parent, re-checked inside `operate`, symlink source refused by `attributesOfItem`), with an argument-driven escape suite. `deleteFolder` was not swept. New gap 3. |
| CR-04 — invalid page selection widens to whole-gallery repair | **Closed at its root** | `retryPages` filters against `download.pageCount` and refuses an empty result at `RetryHelpers.swift:78-81`, before mode resolution, update delegation, failure clearing, the generation advance, the enqueue, the schedule and `ensureContinuedSession`. `normalizeFetchedPayload` preserves `.some(empty)` through `rawPageSelection.map` (`ExecutionFetch.swift:188-190`). Two caller-side consequences remain (gap 4, partial). |

### Deferred Items

None. Phase 16 is Dynamic Type Accessibility and addresses none of these gaps. No later milestone phase covers them.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` | Injectable session API, unimplemented default | ✓ VERIFIED | Three endpoints, macro-synthesized unimplemented value, explicit `.noop`, `.live` forwards to the main-actor store. |
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` | Main-actor lifecycle, self-finishing events | ✓ VERIFIED | Single active task guard, `.unavailable`/`.expired` arms, terminal `endSession` yields then `finish()`es the continuation. |
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift` | Sole `BGTaskScheduler` boundary | ✓ VERIFIED | Only file importing `BackgroundTasks`; register / submit `.queue` / cancel / cancelAll. |
| `App/Info.plist` | Continued-processing wildcard + processing mode | ✓ VERIFIED | Both present, with the retention rationale documented in place. |
| `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` | Generation-scoped credit and progress publication | ✗ DEFECTIVE | Generation equality is correct, but the basis it moves is moved outside every D-G7-01 bracket; the file's own stated invariant (lines 235-236) is false against source. |
| `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` | Session accounting state | ✗ DEFECTIVE | `advanceQueueIntentGeneration` (823-825) is a bare increment. |
| `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceHelpers.swift` | Non-destructive sanitation read | ✗ DEFECTIVE | `scanCompletedFolder` deletes on the discarding default and discards both results. |
| `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` | Reader entry that does not mutate | ✗ DEFECTIVE | `loadManifest` scans and validates on the discarding default and reconciles nothing on failure. |
| `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` | Confined folder operations, opt-in mutation | ⚠️ PARTIAL | `renameUserFolder` is a real boundary; `removeFolder(at:)` remains prefix-only and `validate`'s destructive behavior remains opt-out. |
| `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` | Coordinator orchestration behind the boundary | ✗ DEFECTIVE | `renameFolder` delegates correctly; `deleteFolder` still constructs its own unconfined target. |
| `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift` | Selection boundary before any queue mutation | ✓ VERIFIED | Domain filter and empty refusal precede every mutation. |
| `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift` | Three-state selection normalization | ✓ VERIFIED | `nil` / `.some(empty)` / `.some(nonempty)` preserved. |
| `AppPackage/Tests/DownloadsFeatureTests` | Regressions that discriminate the fixed defects | ⚠️ PARTIAL | The rename escape suite and the retry boundary suite discriminate. The CR-02 regression does not (see below), and no test covers the read-path deletion or `deleteFolder` confinement. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Foreground queue intent | `BackgroundProcessingClient.start` | `ensureContinuedSession` after enqueue/retry | ✓ WIRED | Only a foreground user action submits; cold-launch queue resumption deliberately does not. |
| Download progress snapshot | System `Progress` | coordinator push → client → main-actor store | ✗ DEFECTIVE | Path is wired, but an unwithdrawn floor freezes the pushed numerator for N pages after any re-queue. |
| System expiration/cancel event | Durable queue pause/cancel | self-finishing stream consumed by the coordinator | ✓ WIRED | Terminal event, stream finish, durable queue operation; device UAT confirmed cancel parity. |
| `DownloadClient` / reducers | System scheduler | only through `BackgroundProcessingClient` | ✓ WIRED | No reducer or coordinator source imports `BackgroundTasks`. |
| Reader open | Persisted manifest | `loadManifest` → sanitize → validate | ✗ NOT SAFE | A read deletes files and writes no correction. |
| Folder delete | Persisted record convergence | `deleteFolder` → `removeFolder` → index/queue cleanup | ✗ NOT SAFE | A nested name erases a gallery folder and matches no cleanup key. |
| Retry refusal | User-visible feedback | `retryPagesDone(.failure)` → toast | ✗ NOT WIRED | No toast is set; the tap is a silent no-op. |

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| Continued-session system card | `completedPageCount` / `pageCount` | live schedulable snapshot + retirement ledger + run bases | Yes | ✗ FLOWING BUT FROZEN after an unbracketed generation advance |
| Continued-task request | title / subtitle / identifier | foreground queue intent + coordinator snapshot | Yes | ✓ FLOWING |
| Durable queue resume | queued GIDs / modes / selections | `DownloadQueueStore` + per-gallery manifest | Yes | ✓ FLOWING |
| Downloads list / badge completeness | manifest page hashes | persisted manifest (D-SSOT-07) | Yes | ✗ DIVERGES from disk after a reader open deletes a rejected page |
| Inspector retry outcome | `state.toast` | `retryPagesDone` | No | ✗ HOLLOW — the failure branch never writes it |

### Behavioral Spot-Checks

Per the task brief, the clean app-scheme build (0 warnings, SwiftLint plugin clean) and the full `FeatureTests` run (939 tests, 0 failures, 22 targets) were established before verification and were not re-run; only one `xcodebuild` invocation may run at a time on this machine and no new one was needed.

| Behavior | Command / evidence | Result | Status |
|---|---|---|---|
| Legacy fallback tier absent | `grep -rn "BGProcessingTask\|beginBackgroundTask\|endBackgroundTask\|BackgroundTaskClient\|downloads.processing\|downloads.assertion" --include="*.swift" App AppPackage/Sources ShareExtension` | no output | ✓ PASS |
| Scheduler isolated to one module | `grep -rln "BGTaskScheduler\|import BackgroundTasks" --include="*.swift" App AppPackage/Sources` | `ContinuedTaskScheduling.swift` only | ✓ PASS |
| Entitlement surface present | `grep -n "BGTaskSchedulerPermittedIdentifiers\|UIBackgroundModes" App/Info.plist` | wildcard + `processing` | ✓ PASS |
| No unreferenced debt markers in phase-modified sources | `git diff --name-only 782013eb..HEAD -- '*.swift' \| xargs grep -nE "TBD\|FIXME\|XXX\|swiftlint:disable"` | no matches (exit 1) | ✓ PASS |
| CR-02 regression discriminates its defect | Read `testARequeuedGalleryInheritsNoPredecessorObservationCredit` (DownloadContinuedSessionTests.swift:653-813) | Lands six keeper pages in ONE flush; its own doc (640-646) states the re-queue's push "discriminates nothing" and that six pages are needed to lift the numerator "clear of that floor" | ✗ FAIL — a green suite here is not evidence for gap 1 |
| Read-path deletion covered by a test | `grep -rln loadManifest AppPackage/Tests` cross-read against the zero-byte fixtures | No case opens `loadManifest` over a zero-byte page file | ✗ FAIL (uncovered) |
| `deleteFolder` confinement covered by a test | `grep -n "func test" AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift` | `RenameEscapeSource` suite covers rename only; `testDeleteFolderRemovesContainedDownloadsAndQueueIntents` is a happy path | ✗ FAIL (uncovered) |

**Green tests are not evidence for the three gaps above.** The suite passes precisely because none of these three sequences is staged, and in the CR-02 case the new regression is written in a shape that cannot observe the defect its own doc describes.

### Probe Execution

Skipped: no Phase 15 plan or summary declares a probe, and no `scripts/*/tests/probe-*.sh` exists in the repository.

### Requirements Coverage

`.planning/REQUIREMENTS.md` maps no requirement ID to Phase 15; ROADMAP.md line 805 states this explicitly ("None mapped — the scope contract is this phase's four success criteria, referenced by plans as SC-labels"). Traceability is therefore against the four SC labels, all four of which are declared across the 64 plan frontmatters and all four of which are accounted for below. No orphaned requirement exists.

| Label | Declared by | Status | Evidence |
|---|---|---|---|
| SC1 | 33 plans (incl. none of 61-64) | ✓ SATISFIED | Continued-processing request path, entitlements, device UAT test 1. |
| SC2 | 41 plans (incl. 15-61, 15-62, 15-64) | ✗ BLOCKED | Gaps 1 and 2; gap 4 partial. |
| SC3 | 16 plans (incl. 15-62, 15-63, 15-64) | ✗ BLOCKED | Gaps 2 and 3. The no-fallback-tier half is satisfied; the no-lost-work half is not. |
| SC4 | 9 plans | ✓ SATISFIED | Client seam, unimplemented default, self-finishing stream, scheduler isolation. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `DownloadClient+Manager.swift` | 823-825 | Deliberate basis mover outside its own bracket | 🛑 BLOCKER | Frozen system-progress card for N pages of real work; feeds the scheduler a falsely stalled task. |
| `DownloadClient+PersistenceHelpers.swift` | 32-39 | Mutating probe used purely for its side effect, results discarded | 🛑 BLOCKER | An ordinary read deletes page files. |
| `DownloadStore+Operations.swift` | 502 | Destructive behavior as the parameter DEFAULT | 🛑 BLOCKER | Every unnamed caller mutates; the safe behavior is opt-out. |
| `DownloadClient+Folders.swift` | 97, 102 | Unconfined caller-controlled path + exact-match cleanup key | 🛑 BLOCKER | Nested-name recursive delete with no record convergence. |
| `DownloadStore+Operations.swift` | 379-388 | Lexical prefix containment as a security boundary | ⚠️ WARNING | Admits nested targets and unresolved symlinks; shared primitive. |
| `DownloadInspectorReducer.swift` | 188-193 | Failure branch with no user-visible surface | ⚠️ WARNING | Retry tap becomes a silent no-op. |
| `DownloadStore+Operations.swift` | 9-35 | Doc comment orphaned onto an inserted type (review WR-03) | ℹ️ INFO | `ContentMismatchScan` is left undocumented; Quick Help attaches its prose to `DownloadValidationPolicy`. |
| `DownloadStore+Operations.swift` | 436-438 vs 485 | Two spellings of the same localized-key style eight lines apart (review IN-02) | ℹ️ INFO | New code carries both conventions rather than settling one. |
| `DownloadFeatureTestHelpers.swift` | 96-106 | 10 s default `waitForTaskValue` deadline (review IN-01) | ℹ️ INFO | Two deliberate missing-notification detectors now cost 10 s each to fail; verified no assertion changed. |

No unreferenced `TBD`/`FIXME`/`XXX`, no `swiftlint:disable`, no `@unchecked Sendable`, no `nonisolated(unsafe)`, and no `try?` were found in the files this phase modified.

### Human Verification Required

None is required to reach the verdict above — all three blockers are deterministic and observable in source. Two items should be scheduled **after** the gaps close, because they are the device-only half of SC1/SC2 and the existing UAT predates these fixes:

1. **Card series across a same-session re-queue.** Start two galleries, let the first complete while the second holds the session open, re-queue the first, then let the second's pages land **one at a time**. Expect the card's completed count to move on the very first page. Why human: the system-provided card's repaint is owned by the OS and no in-process assertion observes what it renders.
2. **Reader open over a damaged page.** Truncate one page file of a completed gallery to zero bytes outside the app, open the gallery in the reader, then relaunch. Expect the file to survive, or the badge/list to stop claiming the page — never a `.completed` gallery over a page the app itself deleted. Why human: it needs an out-of-app filesystem mutation and a process boundary.

### Gaps Summary

The iOS 26 continued-processing architecture itself is sound and unchanged: the request path, the entitlement surface, the dependency seam and the scheduler isolation all verify, and the fallback tier is genuinely gone. Two of the four success criteria still fail.

Two of the three blockers are the phase's recurring **branch-scoped fix** shape. 15-62 fixed the deleting probe on the route it was reported against and left the same deletion reachable from an ordinary reader open and from `resumeMode`, both on a parameter that still defaults to destroying. 15-63 gave rename a real confinement boundary and left the adjacent destructive folder operation building its own unconfined URL. The third is a regression the fix itself introduced: 15-61 correctly bound observation credit to the queue-intent generation, but the generation advance is now a deliberate downward mover of the credited basis that no D-G7-01 bracket spans, so the monotonic floor — the very mechanism the phase documents as the G-15-6/G-15-7 defect when it masks a coordinator-made movement — absorbs the next N pages of genuine progress.

Each gap's `missing[]` is therefore written as an all-exit-path sweep: wrap the movement rather than the four call sites, flip the destructive default rather than the two named callers, and route every user-folder mutation through the one store-owned boundary rather than patching `deleteFolder` alone. Review warnings WR-01 and WR-02 are folded into gap 2 because they live in the same rejected-page subsystem and a fix scoped to CR-03's two callers would leave them to re-open the round.

---

_Verified: 2026-08-10T03:08:11Z_
_Verifier: the agent (gsd-verifier)_
