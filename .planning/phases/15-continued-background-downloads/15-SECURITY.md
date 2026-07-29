---
phase: 15
slug: continued-background-downloads
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-07-29
---

# Phase 15 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Built from the `<threat_model>` blocks authored in all 19 plans of this phase
(`15-01-PLAN.md` … `15-19-PLAN.md`) plus the `## Threat Flags` sections of
`15-08-SUMMARY.md`, `15-09-SUMMARY.md` and `15-14-SUMMARY.md` (all three: none).
Every plan carried a threat model, so the register was authored at plan time and this
audit verifies mitigations rather than retroactively discovering threats.

**Threat ID collisions.** Plans 15-14/15-15 and 15-17/15-18/15-19 independently minted
IDs in the `T-15-36` … `T-15-45` range for different threats. Each register row below is
therefore qualified by its originating plan; the pairs sharing an ID are distinct threats
with distinct mitigations and are tracked separately.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| app process → `BGTaskScheduler` daemon | The permitted-identifier declaration is the app's contract with the system scheduler; registration and submission cross here. | Task identifier (bundle id + `continued` + UUID), card title, card subtitle |
| app process → system progress card | The card renders outside the app process, outside the privacy mask and outside App Switcher snapshot protection — everything crossing is visible to anyone who can see the device. | Localized title (static), localized subtitle (three integer counts) |
| system scheduler → session store | Launch handlers can never be unregistered, so the system can hand the store a task for a request abandoned long ago. | System task object, `Progress` (never leaves the main actor) |
| actor-isolated coordinator → main-actor session store | Every session verb crosses an isolation boundary with no cross-actor FIFO guarantee; a stale continuation can land after a successor exists. | `UUID`, `Int64`, `String`, `Bool` only |
| system expiration callback → queue state | An uncorrelated, uncredentialed system signal mutates every schedulable download's state; a user cancel and a resource reclaim are indistinguishable by API. | Expiration event (no payload) |
| filesystem → in-memory download index | The disk tree is the source of truth and can change under the actor between scan boundaries; a record can vanish before a mutation reads it. | Gallery folders, manifests, page files |
| app process → system unified logging | Public log fields persist in the log store, are readable by anyone who can stream logs from the device, and are collected verbatim into sysdiagnose archives. | Operational counts and enum raw values (public); gallery identifiers (hash-masked); errors, paths, URLs, response snippets (private) |
| remote response body → log field | A rejected response's prefix is attacker-influenced and gallery-specific. | Response snippet (private) |
| repository source tree → future phases | The invariant suites are the only mechanical barrier preventing a later phase from reintroducing a deleted background-execution tier or a public identity log field. | Source tokens |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-15-01 (15-04/05/06/07) | Information Disclosure | Card title and subtitle strings | high | mitigate | `continued_session.title` is a static string; `continued_session.subtitle` carries exactly three `lld` substitutions and no `%@` argument, so no gallery value has a path onto the card. `continuedSessionSubtitle(for:)` takes a counts-only value. Verified in `Localizable.xcstrings` and `DownloadClient+ContinuedSession.swift:51-62`. | closed |
| T-15-02 (15-01/03) | Denial of Service | System scheduler's pending-request queue | medium | mitigate | A one-shot `cancelAllRequests()` sweep clears requests left by a previous build, guarded by `didCancelStaleRequests` so it can never cancel this process's own submission. `ContinuedProcessingSession.swift:100-114`. | closed |
| T-15-03 (15-01/03/07) | Elevation of Privilege | `App/Info.plist` `BGTaskSchedulerPermittedIdentifiers` | medium | mitigate | Exactly one entry, `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` — bundle-prefixed plus one semantic segment, never a bare wildcard. Minted identifiers are runtime bundle id + `.continued.` + UUID; no wildcard is ever passed to `register`. `App/Info.plist`, `ContinuedProcessingSession.swift:125`. | closed |
| T-15-04 (15-02/04/05/06) | Denial of Service | Manifest-derived page counts feeding the card | low | mitigate | Sums pass through the clamped progress model's `displayCompletedPageCount` / `displayPageCount` accessors before the `Int64` conversion, so a corrupt manifest cannot yield a negative count or a zero denominator. `DownloadClient+ContinuedSession.swift:33-49, 101-102`. | closed |
| T-15-05 (15-03) | Tampering | System task and its `Progress` inside `ContinuedProcessingSession` | medium | mitigate | The store is `@MainActor`, the launch handler registers on the main queue, and only `UUID`/`Int64`/`String`/`Bool` cross the seam. Zero `@unchecked Sendable` and zero `nonisolated(unsafe)` occurrences in `BackgroundProcessingClient/` or `DownloadClient/`; the repo's banned-unchecked-Sendable lint rule is at error severity. | closed |
| T-15-06 (15-04/06/07) | Information Disclosure | Card text persisting in system UI after backgrounding | low | accept | Counts only — a bystander learns a download is running and how far along it is, not what it is. See ACC-15-02. | closed |
| T-15-07 (15-05) | Information Disclosure | Analytics on expiration-driven pause | low | mitigate | No analytics seam exists in `DownloadClient` and none was added; a module-wide grep for `analytics`/`Analytics` returns zero hits, so Phase 14's closed-enum vocabulary and never-send list are untouched. | closed |
| T-15-08 (15-02) | Denial of Service (self-inflicted) | Download queue during the assertion-deletion window | low | accept | A backgrounded download suspends with the process and resumes on next foreground; on-disk manifests and the queue store remain the source of truth, so no work is lost or duplicated. See ACC-15-01. | closed |
| T-15-09 (15-03/05) | Denial of Service (app termination) | Scheduler registration | high | mitigate | A fresh UUID per session guarantees no identifier is ever registered twice; the store refuses re-entry before any scheduler touch (`guard task == nil, continuation == nil, !isAwaitingTask`), and the coordinator sets `hasLiveContinuedSession` synchronously before its first suspension point. `ContinuedProcessingSession.swift:85-87, 122-125`; `DownloadClient+ContinuedSession.swift:91-94`. | closed |
| T-15-10 (15-05/06) | Tampering | Expiration-driven pause-all | medium | mitigate | `pauseAllSchedulable(expiring:)` loops over the existing per-gallery `pause` primitive rather than a bulk mutation, so the scheduling-blocked set, manifest state and observer notification stay consistent; the session is marked ended before the pauses run. `DownloadClient+ContinuedSession.swift:210-220`. | closed |
| T-15-11 (15-06) | Denial of Service | Progress starvation causing early expiration | medium | mitigate | The push rides the existing throttled flush, which fires on a page-count branch as well as an elapsed-time branch, so the completed count advances between updates even on slow pages. | closed |
| T-15-11 (15-08) | Denial of Service (background coverage loss) | Abandoned pending request vs the start re-entry guard | high | mitigate | `endSession` cancels the retained `pendingIdentifier` whenever no task was adopted, so an abandoned request cannot later launch into the store and wedge the single-session guard. `ContinuedProcessingSession.swift:250-266`. | closed |
| T-15-12 (15-07) | Tampering | Future reintroduction of a deleted background-execution mechanism | medium | mitigate | `BackgroundExecutionInvariantTests` scans every Swift source in the app target and package plus the plist for forbidden tokens, refuses to pass vacuously, and was demonstrated to fail on a deliberate violation before acceptance. | closed |
| T-15-12 (15-08) | Spoofing (task identity) | `adopt(_:expecting:)` | high | mitigate | Adoption is gated on the expected identifier and on `self.task == nil`; a task that is not the awaited request is rejected, so no spurious `granted` reaches a session the task does not belong to. `ContinuedProcessingSession.swift:207-215`. | closed |
| T-15-13 (15-08) | Denial of Service (leaked system task) | Rejected or displaced launches | medium | mitigate | Every rejection path completes the arriving task with `setTaskCompleted(success: false)` instead of dropping it, so no orphan lingers to be force-expired into the live session's stream. `ContinuedProcessingSession.swift:213`. | closed |
| T-15-14 (15-08) | Information Disclosure | Card strings through the client seam | low | mitigate | The seam forwards caller-provided strings untouched and no gallery value is in scope in `BackgroundProcessingClient`; the coordinator-side exact-string cases remain the enforcement point. | closed |
| T-15-19 (15-08) | Tampering (stale counts on a live card) | Start-path seed counters | low | mitigate | Superseded and strengthened by T-15-30 (15-12): rather than zeroing, `start` records the caller's fresh snapshot into `lastCompletedUnitCount`/`lastTotalUnitCount` on the same main-actor run that submits, so no predecessor push can seed the next card and no adoption reports 0 / 0. `ContinuedProcessingSession.swift:95-98`. | closed |
| T-15-15 (15-09) | Tampering (state clobber) | `markContinuedSessionEnded(sessionID:)` | high | mitigate | Teardown is gated on the per-session UUID minted by `ensure`; a superseded session's teardown is a no-op. `DownloadClient+ContinuedSession.swift:187-188`. | closed |
| T-15-16 (15-09) | Denial of Service (stranded session) | `cancelQueuedWorkItem` non-initial branch | high | mitigate | The branch exits through the convergence forwarder, so the reconcile tail completes a session whose last work item was cancelled. | closed |
| T-15-17 (15-09) | Tampering (spurious pause-all) | `handleContinuedSessionEvent(_:sessionID:)` | medium | mitigate | Events are gated on the current session id, so an expired event surfacing from a superseded stream cannot invoke the pause-all policy against the live queue. `DownloadClient+ContinuedSession.swift:157`. | closed |
| T-15-18 (15-09) | Denial of Service (wrong-session completion) | `reconcileContinuedSession` drain branch | medium | mitigate | The id bound before the schedulable-work await is re-checked after it. `DownloadClient+ContinuedSession.swift:232-234`. | closed |
| T-15-20 (15-09) | Denial of Service (uncompletable session) | `ensureContinuedSession` post-suspension re-check | medium | mitigate | Ownership is re-checked against the minted id after each mid-start suspension; a start whose session was torn down mid-flight completes the client session it just created. `DownloadClient+ContinuedSession.swift:109, 116-119`. | closed |
| T-15-21 (15-10) | Tampering (wrong-session completion) | `finish(sessionID:success:)` and the ensure bail-out | high | mitigate | The completion verb carries the session id and the store no-ops on mismatch; the bail-out passes only the id of the handle its own start returned. `ContinuedProcessingSession.swift:185-188`. | closed |
| T-15-22 (15-10) | Denial of Service (successor's work paused) | `pauseAllSchedulable(expiring:)` | high | mitigate | The loop re-checks per iteration that the coordinator session id is nil or the expiring session's own, stopping the moment a successor exists. `DownloadClient+ContinuedSession.swift:213`. | closed |
| T-15-23 (15-10) | Tampering (untargeted drain completion) | `reconcileContinuedSession` drain branch | medium | mitigate | The drain presents the client id captured after its post-suspension re-check and completes nothing when no id is recorded. | closed |
| T-15-24 (15-10) | Denial of Service (silent dead-stream session) | `start` refusal path | medium | mitigate | Refusal is a visible nil; `ensure` rolls its bookkeeping back so the next qualifying tap starts a real session. `DownloadClient+ContinuedSession.swift:104-112`. | closed |
| T-15-25 (15-10) | Tampering (stale push into a successor) | `pushContinuedSessionProgress(sessionID:)` | low | mitigate | The push presents an id like every other late-arriving mutation, and re-checks it across its suspension. `DownloadClient+ContinuedSession.swift:258-261`. | closed |
| T-15-26 (15-11) | Repudiation (unfalsifiable invariant) | Session-identity regression coverage | high | mitigate | `DownloadContinuedSessionIdentityTests` and `DownloadContinuedSessionInterleaveTests` each pin an identity hazard with a case that fails against the pre-fix coordinator. | closed |
| T-15-27 (15-11) | Tampering (test-double drift) | `BackgroundProcessingClientSpy` staging verbs | medium | mitigate | The spy's gate records fully before parking, its refusal mints nothing, and its stream completion is identity-gated — mirroring the live store's refusal and supersession semantics. | closed |
| T-15-28 (15-11) | Denial of Service (nondeterministic suite) | Interleave staging | medium | mitigate | Rendezvous via `AsyncStream` continuations, no polling and no sleeps; a grep of the interleave and identity suites for `Task.sleep`, `usleep`, `while true` and `Date()` returns zero hits. | closed |
| T-15-29 (15-12) | Tampering | `updateProgress` across the client seam | high | mitigate | The push carries the client session id and the store drops it unless it names the held session. `ContinuedProcessingSession.swift:164-170`. | closed |
| T-15-30 (15-12) | Denial of Service (self-inflicted expiration) | Initial adopted `Progress` | high | mitigate | Counts are recorded on the same main-actor run that submits (lines 97-98, before the submit at line 141), and adoption seeds the task from them, so no launch can adopt a task reporting 0 / 0 while work is queued. `ContinuedProcessingSession.swift:219-220`. | closed |
| T-15-31 (15-12) | Information Disclosure | Card title and subtitle | medium | mitigate | The seam still accepts only already-localized strings built by `continuedSessionSubtitle`, whose only inputs are three integers. | closed |
| T-15-32 (15-12) | Repudiation (unfalsifiable invariant) | Seeded adoption and rejected foreign progress | medium | mitigate | `ContinuedProcessingSessionTests` covers adoption without an intervening push and a foreign-id push that moves nothing. | closed |
| T-15-33 (15-13) | Denial of Service (stranded queue and card) | `delete(gid:)` vanished-record branch | high | mitigate | The branch notifies observers and calls `scheduleNextIfNeeded()` before returning `.notFound`, with the reason written at the site. `DownloadClient+PublicAPI.swift:196-203`. | closed |
| T-15-34 (15-13) | Tampering (predicate drift) | Schedulable-work definition | medium | mitigate | One actor-isolated authority, `isSchedulableDownload`, is read by scheduling (`DownloadClient+Scheduling.swift:93, 103`), the pending-work gate (`DownloadClient+PendingWork.swift:26`) and the progress snapshot, documented as internal-not-private precisely so a second predicate cannot diverge. | closed |
| T-15-35 (15-13) | Repudiation (unfalsifiable invariant) | Vanished-record staging | medium | mitigate | The record is vanished through the production reload path rather than a test-only backdoor. `DownloadDeleteConvergenceTests`. | closed |
| T-15-36 (15-14) | Tampering (stale write erases newer intent) | Expiration-owned `pause(gid:)` | high | mitigate | Each expiration pause captures `ExpirationPauseOwnership(sessionID:queueIntentGeneration:)` and `ownsExpirationPause` re-checks both before every post-suspension write. `DownloadClient+Scheduling.swift:7-12, 202, 222, 252-257`. | closed |
| T-15-37 (15-14) | Denial of Service (a successful tap that mobilizes nothing) | Scheduling-blocked window | high | mitigate | The abandoned pause converges after its block is lifted — notify, schedule, ensure — so the superseding action gets both its queue movement and its session. `DownloadClient+Scheduling.swift:166-180`. | closed |
| T-15-38 (15-14) | Elevation of Scope (guard over-application) | User-initiated pause | medium | mitigate | `ownsExpirationPause` returns `true` immediately when `expiration` is nil, so the guard is inert for hand pauses. `DownloadClient+Scheduling.swift:255`. | closed |
| T-15-39 (15-14) | Denial of Service (leaked test task) | Blocking runner fixture | medium | mitigate | The runner parks on an idempotent token released from each case's `defer`, and cancellation still releases by default. | closed |
| T-15-40 (15-15) | Repudiation (unfalsifiable invariant) | Expiration reentrancy coverage | high | mitigate | The case enters the real pause through the real event handler and is held inside the awaited task cancellation by the fixture's control, so it fails against the pre-15-14 coordinator. | closed |
| T-15-41 (15-15) | Elevation of Scope (guard over-application) | User-initiated pause | medium | mitigate | A companion case retries inside a user pause's window and asserts the pause still wins. | closed |
| T-15-42 (15-15) | Denial of Service (nondeterministic suite) | Interleave staging | medium | mitigate | Every step is a rendezvous on the fixture's control token; the file-level grep gate proves no sleep, poll or clock participates. | closed |
| T-15-43 (15-16) | Spoofing (false affordance) | `DependencyValues.backgroundProcessingClient` | medium | mitigate | Owner selected option-b on 2026-07-29: the unread key and accessor were removed (`6182961c`), leaving direct constructor injection as the only composition path. No `DependencyKey`/`DependencyValues` declaration remains in `BackgroundProcessingClient/`. | closed |
| T-15-44 (15-16) | Elevation of Privilege (executor deciding for the owner) | Judgment-tier prohibition | medium | mitigate | A blocking decision checkpoint preceded the implementation task; the recorded owner selection is quoted in `15-16-SUMMARY.md`. | closed |
| T-15-45 (15-16) | Repudiation (SC4 weakened as a side effect) | Unimplemented-value evidence | medium | mitigate | The unimplemented-endpoint case stayed byte-for-byte unchanged and still exercises `start`, `updateProgress` and `finish`; both scheduler-topology invariants remained green. | closed |
| T-15-36 (15-17) | Denial of Service (work left with no background coverage) | `reconcileContinuedSession` inside an in-flight `ensureContinuedSession` | high | mitigate | Ownership is never released with a nil client id; the debt is recorded and discharged when the id lands, and the forbidden interleave is named at the site. `DownloadClient+ContinuedSession.swift:130-134, 235-237`. | closed |
| T-15-37 (15-17) | Spoofing (one session's teardown applied to another) | Deferred-reconciliation flag surviving a session boundary | medium | mitigate | `markContinuedSessionEnded` clears `continuedSessionNeedsReconciliation` with the rest of the session's state, and the flag is cleared before the discharge call so a fresh debt is not erased. `DownloadClient+ContinuedSession.swift:132, 191`. | closed |
| T-15-38 (15-17) | Repudiation (a green suite that cannot gate) | `BackgroundProcessingClientSpy` accepting overlapping starts | high | mitigate | The spy refuses a start while a session is held, on the same condition as the live store; every other double in the file was audited against its live counterpart and the outcome recorded. | closed |
| T-15-39 (15-17) | Denial of Service (hung or leaked test work) | Start gate armed without a defensive release | medium | mitigate | A `defer` release is installed at arming time in every gate-driven case; arms equal defers. | closed |
| T-15-40 (15-18) | Denial of Service (permanently stalled queue and session) | Folder-removal failure branches of `delete(gid:)` and `deleteFolder(name:)` | high | mitigate | Both branches of both functions release the scheduling block, notify and converge before returning. `DownloadClient+PublicAPI.swift:206-222`; `DownloadClient+Folders.swift:117-134`. | closed |
| T-15-41 (15-18) | Denial of Service (same defect at an uncited site) | `commitPause` error exits after the initial pause record cleared ownership | medium | mitigate | Both catch branches converge; the invariant is satisfied structurally rather than by arguing about which call can currently throw. `DownloadClient+Scheduling.swift:235-239`. | closed |
| T-15-42 (15-18) | Tampering (scheduling around the failed item) | Function-scoped `defer` not yet run when a catch returns | medium | mitigate | The scheduling block is released explicitly before converging at both function-scoped-defer sites, with the reason written at the site; the defer stays as an idempotent net. `DownloadClient+PublicAPI.swift:208-210`. | closed |
| T-15-43 (15-18) | Repudiation (invariant asserted but not enforced) | Per-branch regression coverage | high | mitigate | `DownloadOwnershipConvergenceTests` is parameterised over the enumerated exit paths and asserts one five-part invariant per argument. | closed |
| T-15-44 (15-19) | Information Disclosure | Completion and enqueue logs publishing gallery titles | high | mitigate | Titles removed from the messages entirely; the operational signal is carried by counts and a masked identifier. Zero `title, privacy: .public` occurrences module-wide; `DownloadLogPrivacyInvariantTests` fails the build if one returns. | closed |
| T-15-45 (15-19) | Information Disclosure | Gallery identifiers published across execution, public API and scheduling logs | high | mitigate | Identifiers reclassified as `private(mask: .hash)` — 8 hash-masked sites, 0 public identifier sites; the invariant enforces both halves. | closed |
| T-15-46 (15-19) | Information Disclosure | Raw error values and localized descriptions carrying gallery-named paths and URLs | high | mitigate | Every such interpolation is explicitly `private`; the rule is applied uniformly rather than per-site. Zero `error, privacy: .public` / `localizedDescription, privacy: .public` occurrences. | closed |
| T-15-47 (15-19) | Information Disclosure | Rejected-response body prefix in `DownloadClient+ResponseValidation.swift` | high | mitigate | The snippet field is `private` while the rejection reason stays public. | closed |
| T-15-48 (15-19) | Repudiation (silent regression of a closed finding) | Future edits reintroducing public identity fields | medium | mitigate | `DownloadLogPrivacyInvariantTests` scans the module, `#require`s a non-empty file set and a known member so it cannot pass vacuously, and was verified by a deliberate break in both directions before commit. | closed |
| T-15-SC (all 19 plans) | Tampering | Package-manager installs | low | accept | This phase installs no packages. `AppPackage/Package.swift` changed only to rewire intra-package module dependencies; `Package.resolved` is untouched by the phase diff and `15-RESEARCH.md` § Package Legitimacy Audit records zero entries. See ACC-15-03. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| ACC-15-01 | T-15-08 (15-02) | With the execution assertion deleted and before a continued-processing session is granted, a backgrounded download suspends with the process and resumes on next foreground. This is the accepted end-state behavior under D-02; on-disk manifests and the queue store remain the source of truth, so no work is lost or duplicated. | Owner (phase decision D-02) | 2026-07-28 |
| ACC-15-02 | T-15-06 (15-04/06/07) | The system progress card renders outside the app's privacy mask and outside App Switcher snapshot protection, so its text is readable by anyone who can see the device. It carries counts only — a bystander learns that a download is running and how many pages remain, not what is being downloaded. The user initiated the download, and the card is the API's mandated affordance with no opt-out. | Owner (phase decision D-03) | 2026-07-28 |
| ACC-15-03 | T-15-SC (all 19 plans) | No package was installed in this phase, so no supply-chain legitimacy checkpoint applies. Verified against the phase diff: `Package.swift` changed only to move `backgroundProcessingClient` between intra-package target dependency lists and to drop an unused `appModels` edge; no `Package.resolved` in the repository is touched by the phase diff. | Security audit | 2026-07-29 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-29 | 61 | 61 | 0 | /gsd-secure-phase (ASVS L1, block_on: high) |

### Audit 2026-07-29 — notes

- **Register origin:** authored at plan time. All 19 plans carried a parseable `<threat_model>` block, so this run verified mitigations rather than constructing a retroactive STRIDE register.
- **Summary threat flags:** `15-08`, `15-09` and `15-14` each declared "None"; no new network endpoint, authentication path, file-access trust boundary or schema surface was introduced beyond the plan-time models. The other 16 summaries declared no threat-flag section.
- **Public log-field sweep:** all 8 remaining `privacy: .public` interpolations in `DownloadClient` were read individually — page count, mode raw value (×2), failed-page indices, retry operation name (×2) and attempt number (×2). None carries gallery identity; `failedPages` publishes integer page indices only, which name a position within a download and not the download itself. Recorded as an observation, not a finding.
- **Threat-ID collisions** between plans 15-14/15-15 and 15-17/15-18/15-19 were resolved by qualifying every register row with its originating plan rather than merging distinct threats under a shared ID.
- **T-15-19 supersession:** plan 15-08 specified zeroing the seed counters on session start; plan 15-12 (T-15-30) replaced that with recording the caller's fresh snapshot on the submitting run, which is strictly stronger — it closes both the stale-seed hazard 15-08 named and the 0 / 0 self-expiration hazard zeroing would have introduced. The implemented code documents the reversal at the site.
- **Residual behavioral coverage:** `15-VERIFICATION.md` records `status: human_needed` with three device-only truths (SC1, SC2 and the card's cancel affordance) pending physical iOS 26 verification. None of them gates a threat in this register — every mitigation above is verified by source or by automated test — but the on-device run in `15-UAT.md` remains the confirmation that the system renders only what the app pushes (T-15-01's device leg).

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-29
