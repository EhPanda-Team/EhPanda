---
phase: 15-continued-background-downloads
verified: 2026-08-09T16:30:24Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "The previously reported G-15-34 progress handoff defect was redesigned in Plans 54-60, and the six-item physical-device UAT is complete."
  gaps_remaining:
    - "SC2 still fails because a gallery re-queued in the same continued session can inherit stale incomplete-observation credit."
    - "Validation can delete a rejected page file before the combined wholesale reconciliation guard accepts the matching manifest correction."
    - "Folder rename accepts an unconstrained oldName that can resolve outside the download root."
    - "An all-invalid retryPages selection is normalized to unrestricted repair work."
  regressions: []
gaps:
  - truth: "System progress always reflects work performed by the current continued-processing session."
    status: failed
    reason: "observedIncompleteSessionGIDs is keyed only by gallery ID and survives a fresh queue intent while the same session remains alive. A completed gallery re-queued after another gallery keeps the session open can therefore contribute its predecessor's full completed count before the new run announces work."
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: "sessionCreditedPages grants a complete record full credit from stale session-scoped gallery membership."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
        issue: "clearDownloadSessionState does not retire the prior observation when a new queue-intent generation begins."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift"
        issue: "Fresh retry and retryPages intents advance generation without clearing or generation-scoping observedIncompleteSessionGIDs."
    missing:
      - "Scope incomplete-observation evidence to the queue-intent/run generation, or retire it atomically before every fresh queue intent."
      - "Add a two-gallery regression test where gallery A completes, gallery B keeps the session alive, and A is re-queued before its successor run announces work."
  - truth: "Validation never destroys a page file unless the same pass is permitted to make the corresponding manifest correction durable."
    status: failed
    reason: "validateImageData and its first pageFileScan use the default discardingRejected behavior. A listed zero-byte or non-regular claimed file is deleted by probeAssetFile before the combined wholesale guard is evaluated; on a one-page complete gallery the guard can then refuse to blank the only hash, leaving the persisted manifest claiming a file that the pass already removed."
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift"
        issue: "The validation and presence-scan reads are mutating before prospectiveBlankPages reaches the wholesale guard."
      - path: "AppPackage/Sources/DownloadClient/DownloadStore.swift"
        issue: "pageFileScan defaults discardingRejected to true, and the rejected branch deletes the listed asset without returning its page identity to reconciliation."
    missing:
      - "Gather presence/content classifications without mutation, include rejected page identities in the prospective blank set, evaluate all refusal guards, and only then delete and persist the licensed correction."
      - "Add a one-page complete-manifest test with a zero-byte or non-regular file proving refusal leaves both disk and manifest unchanged."
  - truth: "Folder rename cannot move a source outside the persisted download root."
    status: failed
    reason: "renameFolder validates only newName. oldName is appended directly to rootURL and standardized only for equality, so values such as ../Documents can resolve outside the download root before moveItem is called."
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift"
        issue: "oldName is not normalized or confined before sourceURL is used for existence checks and moveItem."
      - path: "AppPackage/Sources/DownloadClient/DownloadStore.swift"
        issue: "userFolderURL(name:) performs plain path appending and provides no confinement guarantee."
    missing:
      - "Validate the source name and verify the standardized source remains a direct child of the download root before any filesystem action."
      - "Add traversal, absolute-path, and symlink-boundary tests for renameFolder."
  - truth: "retryPages either honors the caller's selected pages or rejects the request; it never widens an invalid selection into whole-gallery work."
    status: failed
    reason: "retryPages accepts any nonempty integers. normalizeFetchedPayload filters them against the fetched page count and converts an empty valid set to nil; pendingPageIndices interprets nil as unrestricted, so [0, 999] can schedule every missing page."
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift"
        issue: "The public API stores unvalidated indices."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift"
        issue: "An all-invalid nonempty selection collapses to nil."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
        issue: "nil pageSelection means unrestricted repair."
    missing:
      - "Preserve the distinction between no selection and a selection with no valid pages, and return a deterministic failure or no-op without enqueueing broader work."
      - "Add all-invalid, mixed-validity, and boundary selection tests."
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` on iOS 26 so a gallery download started by the user continues after backgrounding, appears in system progress UI, and no longer depends on the previous short execution grace period.

**Verified:** 2026-08-09T16:30:24Z
**Status:** gaps_found
**Re-verification:** Yes — the earlier progress redesign and device UAT were rechecked against the present tree, then the current implementation was examined for remaining counterexamples.

## Goal Achievement

### Observable Truths

| # | Roadmap contract | Status | Evidence |
|---|---|---|---|
| 1 | A foreground-started gallery download continues after the app is backgrounded beyond the old execution grace period. | ✓ VERIFIED | The live scheduler submits `BGContinuedProcessingTaskRequest` with `.queue`; the legacy UIKit assertion and discretionary-processing tokens are absent from production Swift. Physical-device UAT test 1 passed after more than 60 seconds in the background. |
| 2 | System progress reflects real work, and system cancellation has the same durable queue effect as in-app cancellation. | ✗ FAILED | Physical-device UAT covers the ordinary progress/cancel path, but the present code has a reachable same-session redo sequence that grants a fresh queue intent stale full credit. The manifest-validation ordering can also leave persisted completion claims inconsistent with disk. Those counterexamples defeat “reflects real progress” and state consistency. |
| 3 | Refusal, queueing, and expiration are best effort with no fallback tier; work resumes next foreground without lost/duplicated work or visible error. | ✓ VERIFIED | `.queue`, `.unavailable`, `.expired`, silent session teardown, and foreground rescheduling are wired in the coordinator/client. Searches found no legacy `BGProcessingTask`, UIKit execution assertion, or fallback identifiers. Physical-device UAT test 3 passed refusal, indefinite queue, expiration, and process-death scenarios. |
| 4 | A testable `BackgroundProcessingClient` seam owns start/update/complete and scheduler access; events self-finish; the default test value is unimplemented. | ✓ VERIFIED | `BackgroundProcessingClient`, `BackgroundProcessingSession`, the `@MainActor` live store, and `ContinuedTaskScheduling` are substantive. The macro-synthesized default is unimplemented, `.noop` is explicit, session streams finish in `endSession`, and `BGTaskScheduler` occurs only inside the client module. |

**Score:** 3/4 truths verified (0 present-but-behavior-unverified)

The old SC2 defect documented by the previous report is not being reused as evidence: Plans 54-60 changed the progress model and the resulting UAT passed. SC2 remains failed for independently observable counterexamples in the current code.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` | Injectable continued-session API and unimplemented test default | ✓ VERIFIED | Substantive start/update/finish dependency endpoints; live and explicit noop implementations are separated. |
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` | Main-actor task/session lifecycle and self-finishing events | ✓ VERIFIED | Owns one active system task, expiration/unavailable delivery, completion, cancellation, and stream termination. |
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift` | Sole `BGTaskScheduler` boundary | ✓ VERIFIED | Registers, submits `.queue` requests, cancels, and publishes system `Progress`; repository scan found no production scheduler call outside this module. |
| `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` | Queue-derived session lifecycle and progress publication | ✗ DEFECTIVE | Wired and substantial, but the GID-only observation set can credit a later queue generation with predecessor work. |
| `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` | Durable queue state and per-run/session accounting | ✗ DEFECTIVE | The queue-intent generation is advanced, but stale incomplete-observation membership is not retired with that generation. |
| `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` | Manifest-SSOT validation reconciliation | ✗ DEFECTIVE | A mutating scan can precede the combined wholesale guard. |
| `AppPackage/Sources/DownloadClient/DownloadStore.swift` | Confined storage operations and non-hollow scan data | ✗ DEFECTIVE | Rejected page deletion is the default scan behavior and `userFolderURL(name:)` does not confine a caller-supplied source name. |
| `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift` | Retry intent and selected-page preservation | ✗ DEFECTIVE | Invalid page numbers are accepted into a queued repair intent. |
| `App/Info.plist` | Continued-processing wildcard and processing background mode | ✓ VERIFIED | Contains `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` and the processing mode expected by the live request. |
| `AppPackage/Tests/DownloadsFeatureTests` | Deterministic lifecycle, progress, persistence, and topology tests | ⚠️ PARTIAL | FeatureTests pass, but no test covers the four blocker sequences listed in frontmatter. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Foreground queue intent | `BackgroundProcessingClient.start` | `ensureContinuedSession` after start/retry | ✓ WIRED | A user-started queue transition establishes the continued session; persisted launch recovery does not impersonate a user start. |
| Download progress snapshot | System `Progress` | coordinator update → dependency client → main-actor store | ✗ DEFECTIVE | The full path is wired, but a stale `observedIncompleteSessionGIDs` member can inject predecessor progress into a successor redo. |
| System expiration/cancel event | Durable queue pause/cancel behavior | self-finishing event stream consumed by coordinator | ✓ WIRED | The event loop tears down the session and applies the durable queue operation; UAT confirms cancellation parity. |
| `DownloadClient` | System scheduler | only through `BackgroundProcessingClient` | ✓ WIRED | No reducer/coordinator source imports BackgroundTasks or calls `BGTaskScheduler` directly. |
| Validation verdict | Persisted manifest correction | validate → scans → wholesale guard → remove/write | ✗ NOT SAFE | The first rejected-file deletion can occur before the guard, so a refused pass can mutate disk without its durable correction. |
| Selected-page retry | Pending-page execution | retry selection → fetch normalization → `pendingPageIndices` | ✗ NOT SAFE | All-invalid nonempty selection becomes nil and therefore unrestricted work. |

### Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| Continued-session system card | completed/total page progress | persisted manifests, live run bases, queue retirement ledger | Yes | ✗ FLOWING BUT INCORRECT for same-session redo generation reuse |
| Continued-task request | session identifier/title/subtitle | foreground queue intent and coordinator snapshot | Yes | ✓ FLOWING |
| Durable queue resume | queued GIDs/modes/selections | `DownloadQueueStore` and per-gallery manifest | Yes | ✓ FLOWING |
| Validation display state | manifest hashes and page-file probes | download record, filesystem scan, content hash scan | Yes | ✗ MUTATES BEFORE GUARD |
| Repair page selection | caller-selected indices | `retryPages` through fetched payload | Yes | ✗ INVALID EMPTY SET COLLAPSES TO UNRESTRICTED |

### Behavioral Spot-Checks

| Behavior | Command/evidence | Result | Status |
|---|---|---|---|
| Full feature test plan | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air' -derivedDataPath /tmp/EhPandaPhase15VerificationDerivedData` | `** TEST SUCCEEDED **`; 406 tests in the principal feature target passed with seven pre-recorded known issues, and the remaining targets passed. | ✓ PASS |
| Background continuation beyond prior grace | Physical iOS 26 UAT test 1 in `15-UAT.md` | Download continued beyond 60 seconds and completed. | ✓ PASS |
| System progress and cancellation parity | Physical iOS 26 UAT test 2 in `15-UAT.md` | Ordinary card progress and cancel behavior passed. | ✓ PASS for tested flow; insufficient to negate the static stale-generation counterexample |
| Refusal/queue/expiration/process-death recovery | Physical iOS 26 UAT test 3 in `15-UAT.md` | All tested recovery paths passed without loss, duplication, or visible error. | ✓ PASS |
| Legacy fallback removal | Static source census | Zero Swift hits for `BGProcessingTask`, `beginBackgroundTask`, `endBackgroundTask`, `BackgroundTaskClient`, `runQueueUntilIdle`, `downloads.processing`, or `downloads.assertion`; `BGTaskScheduler` appears only in `ContinuedTaskScheduling.swift`. | ✓ PASS |

The full workspace test plan was run once. It does not contain the one-page rejected-file wholesale-refusal case, the two-gallery stale-generation redo case, folder-source traversal cases, or invalid-selection widening cases, so a green suite does not prove those paths safe.

### Probe Execution

Step 7c was skipped: no Phase 15 probe was declared by a plan or summary, and no conventional `scripts/*/tests/probe-*.sh` file exists.

### Requirements Coverage

Phase 15 has no requirement ID in `.planning/REQUIREMENTS.md`; its non-negotiable scope is the four ROADMAP success criteria. All 60 plan frontmatters were cross-referenced. The labels present are exactly `SC1`, `SC2`, `SC3`, and `SC4`:

| Label | Plans declaring label | Roadmap mapping | Status |
|---|---:|---|---|
| SC1 | 33 | Foreground-started work survives backgrounding beyond the old grace period | ✓ SATISFIED |
| SC2 | 41 | Real system progress and cancel parity | ✗ BLOCKED |
| SC3 | 16 | Best-effort refusal/queue/expiration with no fallback tier | ✓ SATISFIED |
| SC4 | 9 | Testable client seam and isolated scheduler ownership | ✓ SATISFIED |

Plan 54 is a redesign decision document and has no standard `requirements:` frontmatter. Its stated scope is SC2 and is accounted for under SC2. No additional Phase 15 requirement appears in `.planning/REQUIREMENTS.md`, so there is no orphaned requirement ID. Phase 16 addresses Dynamic Type rather than any gap above; no blocker qualifies as deferred.

Older plan-level artifact names and proof shapes were sometimes deliberately superseded by later Phase 15 plans—for example, the dependency-key implementation and the pre-redesign progress proof vocabulary. Those stale shapes were not treated as current failures. Current latest-plan prohibitions were evaluated directly: scheduler isolation, fallback deletion, privacy-safe diagnostics, and no concurrency escape hatches pass; Plan 58's guard-before-deletion prohibition fails.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `DownloadClient+PersistenceNormalize.swift` | 119, 221 | Mutating classification before combined refusal guard | 🛑 BLOCKER | Disk and persisted manifest can disagree after the pass refuses wholesale correction. |
| `DownloadStore.swift` | 234, 792, 854 | Default rejected-file deletion during page scan | 🛑 BLOCKER | A read used to assemble guard evidence destroys evidence before authorization. |
| `DownloadClient+ContinuedSession.swift` | 212, 452, 780 | GID-only session observation reused across queue generations | 🛑 BLOCKER | System progress can jump to credit work not performed by the current redo. |
| `DownloadClient+Folders.swift` | 41 | Unconfined caller-controlled source path | 🛑 BLOCKER | A rename can target a sandbox path outside the download root. |
| `DownloadClient+RetryHelpers.swift` | 45 | Unvalidated nonempty page selection | 🛑 BLOCKER | Invalid narrow intent is silently widened downstream. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers, lint suppressions, `@unchecked Sendable`, `nonisolated(unsafe)`, or `@preconcurrency` escapes were found in the Phase 15 client/source/test areas.

### Review, Security, and Validation Artifact Cross-Check

- `15-REVIEW.md` is current for the present tree and reports four critical findings. Each finding was independently reproduced by tracing the cited source paths; all four remain reachable and untested.
- `15-SECURITY.md` reports no open threat, but its audit predates Plans 20-60 and the current unconfined rename source. Its conclusion cannot certify the present tree; the path-boundary finding above is a current security blocker.
- `15-VALIDATION.md` remains a draft with an obsolete incomplete plan map. The independently run FeatureTests command passes, but missing regression cases leave the four observable defects intact.
- `15-UAT.md` is complete with six passed physical-device checks. Those results establish the device-only lifecycle flows they exercised, but do not exercise the four code-derived counterexamples.

### Human Verification Required

None. The six-item physical-device UAT is complete. The remaining findings are deterministic code/test gaps, not matters of visual judgment or unavailable device evidence.

### Gaps Summary

The iOS 26 continued-processing architecture exists, is isolated behind the intended dependency seam, and succeeds in physical-device UAT. The phase nevertheless cannot pass. The system card can miscredit a fresh redo from an earlier run in the same session, validation can destroy a page before the manifest-SSOT wholesale guard authorizes the matching correction, folder rename has a source path traversal, and selected-page retry can widen an invalid request into full repair work. These are observable current-code failures and release blockers; none is assigned to a later roadmap phase.

---

_Verified: 2026-08-09T16:30:24Z_
_Verifier: the agent (gsd-verifier)_
