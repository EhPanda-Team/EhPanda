# Phase 15: Continued Background Downloads - Context

**Gathered:** 2026-07-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just started keeps
running when the app is backgrounded, surfaced by the system-provided progress card. Scope
anchor is **ROADMAP.md §Phase 15's four success criteria** — but the owner's discussion
decisions supersede two of them as written:

- **SC3 is superseded (D-01/D-02).** There is no fallback tier anymore: the discretionary
  `BGProcessingTask` path AND the `beginBackgroundTask` grace-window assertion are both
  **deleted**, not fallen back to. When no continued session is granted, downloads simply
  suspend with the process and continue on next foreground. The ROADMAP entry must be
  amended during planning to say this.
- **SC4's "mirroring its `register`/`schedule`/`cancel` shape" wording is superseded
  (D-04).** The rebuilt client exposes a continued-processing session API (start /
  update-progress / complete, events via a self-finishing stream). SC4's *essence* stands
  unchanged: a testable client seam in the `BackgroundProcessingClient` module,
  `testValue` unimplemented, and no reducer (or coordinator) touching `BGTaskScheduler`
  directly.

SC1 (a foreground-started download outlasts the old grace period after backgrounding) and
SC2 (the system card shows real progress; its cancel stops the queue consistently with an
in-app cancel) stand as written.

An implementation reference exists: a reference project on the contributor's machine has a
production `BGContinuedProcessingTask` client whose API-level findings are captured
(name-free) in `<code_context>` below. Downstream agents get those findings from this file —
they must not name or cite that project in any artifact (see AGENTS.md reference-privacy
rule) and should verify API claims against Apple's official `BackgroundTasks` documentation.

</domain>

<decisions>
## Implementation Decisions

### Tier topology — full replacement

- **D-01: `BGProcessingTask` is removed entirely.** No discretionary path remains anywhere:
  delete the `register`/`schedule`/`cancel` discretionary endpoints and their
  `BGTaskScheduler` runtime from `BackgroundProcessingClient`, the AppDelegate registration
  + `handleProcessingTask` drain handler, the `AppReducer` scene-phase `.background`
  scheduling, and the `app.ehpanda.downloads.processing` entry in
  `BGTaskSchedulerPermittedIdentifiers`. Owner's words: "there will be no BGProcessingTask
  anywhere."
- **D-02: `BackgroundTaskClient` (the `beginBackgroundTask` assertion) is removed too.**
  The continued task is the **only** background-execution mechanism. Accepted consequence:
  if the system refuses or never starts a session, downloads suspend within seconds of
  backgrounding and resume on next foreground. Delete the assertion client, the
  coordinator's `reconcileBackgroundAssertion`/token state, and the
  `app.ehpanda.downloads.assertion` name.
- **D-03: Submission strategy is `.queue`.** If the system can't start the task
  immediately, the request waits in the system's queue rather than failing — with no
  fallback tier left, this maximizes the chance a backgrounded download keeps running. The
  card may show the task as pending before it starts; that is accepted.

### Client seam

- **D-04: General-shape API, same module.** The rebuilt client stays in
  `AppPackage/Sources/BackgroundProcessingClient` under its existing name. It is
  domain-agnostic: callers pass a localized title/subtitle and progress fractions; nothing
  download-specific lives in the client. Session events come back as a self-finishing
  `AsyncStream` (granted / expired / unavailable vocabulary — exact naming is planner
  detail). Downloads are the only call site this milestone.
- **D-05: `DownloadCoordinator` owns the session lifecycle.** The client is injected into
  the coordinator the way `BackgroundTaskClient` was (a stored dependency, not a
  reducer-resolved one) — download-start calls already flow synchronously from user
  actions into the coordinator, and it is the only place that knows real queue progress.
  Reducers stay untouched. With per-session dynamic registration (see `<code_context>`),
  nothing needs the client at app launch: the AppDelegate `register` call disappears.

### Session granularity & submission moments

- **D-06: One queue-wide session.** A session covers all schedulable work. Starting
  another gallery while a session is live folds into the same session (progress totals
  recompute); no per-gallery supersession, no re-submission churn.
- **D-07: Every queue-mobilizing tap ensures a session exists** — start download, resume
  (pause-toggle to active), retry, and update. Work that becomes schedulable without a
  user action (e.g. the queue auto-resuming at cold launch) cannot submit a session (the
  API requires a foreground user action) and therefore runs foreground-only until the next
  qualifying tap; that is accepted.
- **D-08: The session survives foreground returns.** It lives until the queue drains, the
  system expires it, or the user cancels — never completed early on `.active`, because
  re-submission would need a fresh tap. The system card staying visible while the app is
  open is accepted.

### System card & cancel mapping

- **D-09: Card content is neutral counts only.** No gallery titles, tags, or any
  content-identifying text — the card renders in system UI outside the privacy mask's
  reach, and the Phase 14 never-send list already treats titles as radioactive. Shape:
  a static localized title (e.g. "Downloading galleries") plus a count subtitle (e.g.
  "128 of 340 pages · 2 galleries"). Exact wording is Claude's discretion.
- **D-10: Progress fraction = completed pages / total pages across all schedulable
  galleries.** Smooth, honest motion; steady progress reporting is also what keeps the
  system from expiring the task early. Totals recompute when galleries join the queue.
- **D-11: Expiration pauses all schedulable work.** A user cancel on the card and a system
  reclaim arrive as the same expiration callback and are indistinguishable, so one policy
  covers both: pause every active/queued download, exactly as if the user tapped pause on
  each in-app (`toggleDownloadPause` semantics). A deliberate cancel is fully honored
  (SC2 as written); the cost — a system reclaim also leaves the queue paused, requiring a
  manual resume next launch — is accepted, and with no fallback tier the work could not
  have continued after reclaim anyway.

### Claude's Discretion

- Exact card strings and their localization placement, observing the repo's
  labeled-numeric-format-argument rules (`%#@variable@` substitutions for the counts) and
  the every-locale rule for any non-translated key.
- The event-stream vocabulary and the client's exact endpoint names/signatures within the
  D-04 shape.
- Identifier naming under the required bundle-ID prefix, and the wildcard
  `BGTaskSchedulerPermittedIdentifiers` entry (`$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`
  pattern) — verify against official docs.
- Whether `UIBackgroundModes: processing` is still required once `BGProcessingTask` is
  gone (research; remove it if not).
- How pause-all (D-11) is expressed in the coordinator — reuse of the existing per-gallery
  pause primitive vs a bulk operation — and how progress-total recomputation interacts
  with the system `Progress` object (including whether a regressing fraction is
  acceptable when totals grow).
- What happens to now-orphaned machinery: `runQueueUntilIdle` (the old drain loop) may be
  repurposed as the continued session's drain or deleted; `hasPendingWork` may survive as
  the submission/completion gate. Dead code must be deleted, not stranded.
- Concurrency design for the system task object (see the lint constraint in
  `<code_context>` — avoiding `@unchecked Sendable` is strongly preferred; if it proves
  truly unavoidable, that requires the owner's explicit permission first, never a silent
  suppression).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & project rules
- `.planning/ROADMAP.md` §Phase 15 — goal + four success criteria (SC3 and SC4's shape
  wording superseded per `<domain>`; amend the entry during planning).
- `.planning/PROJECT.md` — milestone theme, core value ("download galleries keeps
  working"), parity bar.
- `CLAUDE.md` (repo root) — reducer `Feature` suffix; per-module `.swiftlint.yml`
  requirement; labeled localized-format arguments; local-project-reference privacy
  (absolute, non-waivable — applies to this phase's reference project); no absolute home
  paths in generated docs.
- `.swiftlint.yml` (repo root) — read before writing Swift. Note `no_unchecked_sendable`
  at error severity: directly relevant to wrapping the non-Sendable system task object.

### Code being deleted or rebuilt
- `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` — the
  module being rebuilt (D-01/D-04); current discretionary register/schedule/cancel all go.
- `AppPackage/Sources/DownloadClient/BackgroundTaskClient.swift` — deleted entirely (D-02).
- `AppPackage/Sources/DownloadClient/DownloadClient+BackgroundAssertion.swift` —
  assertion reconciliation deleted (D-02); `hasPendingWork` may survive as the
  submission/completion gate.
- `AppPackage/Sources/DownloadClient/DownloadClient+BackgroundProcessing.swift` —
  `runQueueUntilIdle`, the old `BGProcessingTask` drain; repurpose or delete.
- `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` — `handleProcessingTask`
  + registration deleted (D-01). **Keep** `handleEventsForBackgroundURLSession` /
  `DownloadBackgroundSessionEvents`: that is background-`URLSession` machinery, not
  `BGTaskScheduler`, and is out of this phase's removal scope.
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` — the `.background` scene-phase
  `schedule()` call deleted (D-01).
- `App/Info.plist` — `BGTaskSchedulerPermittedIdentifiers` loses
  `app.ehpanda.downloads.processing`, gains the wildcard continued entry;
  `UIBackgroundModes` per research.

### Code the phase integrates with
- `AppPackage/Sources/DownloadClient/DownloadCoordinator.swift` — the session owner (D-05):
  injection site, queue state, `scheduleNextIfNeeded` convergence point, progress source.
- `AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift` — `toggleDownloadPause`
  (the in-app pause semantics D-11 mirrors), retry/update actions (D-07 submission
  moments).

### External
- Apple `BackgroundTasks` documentation for `BGContinuedProcessingTask` /
  `BGContinuedProcessingTaskRequest` (developer.apple.com) — the researcher must verify
  every API claim in `<code_context>` against the official docs, including the wildcard
  identifier requirement, submission strategies, and expiration semantics.

</canonical_refs>

<code_context>
## Existing Code Insights

### Current machinery (what D-01/D-02 remove)
- Two cooperating paths exist today: `DownloadCoordinator` holds a `beginBackgroundTask`
  assertion (reconciled at the tail of `scheduleNextIfNeeded()`, the single convergence
  point of every queue mutation) for the grace window, and `AppReducer` schedules the
  discretionary `BGProcessingTask` on `.background` when `hasPendingWork()`, drained by
  `AppDelegateReducer.handleProcessingTask` via `runQueueUntilIdle()`.
- `hasPendingWork()` already defines "schedulable work" (active task, or indexed downloads
  not scheduling-blocked) — the natural gate for session submission and completion.

### API findings from a reference project (verify against official docs; keep name-free)
- `BGContinuedProcessingTaskRequest(identifier:title:subtitle:)` carries the user-visible
  card strings at submission; `request.strategy` selects `.fail` (immediate refusal) or
  `.queue` (wait behind other work — chosen per D-03).
- Continued-task identifiers **must be prefixed with the running bundle identifier**, and
  the Info.plist permits them via a wildcard entry
  (`$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`). A launch handler can only ever be
  registered once per identifier, so each session registers a fresh UUID-suffixed
  identifier at submission time — meaning registration happens per-session in the
  foreground, and no launch-time registration exists for continued tasks.
- **Progress reporting keeps the task alive**: the system expires tasks that report no
  progress before those that do. The card is driven via `task.progress`
  (`totalUnitCount`/`completedUnitCount`) and `task.updateTitle(_:subtitle:)`.
- **A user cancel on the card and a system reclaim are indistinguishable** — both arrive
  as the task's expiration handler. D-11's single policy exists because of this.
- The system task object is **non-Sendable and system-owned**. The reference design needed
  an `@unchecked Sendable` handle because it registered on an arbitrary queue and hopped
  onto an actor. EhPanda bans `@unchecked Sendable` at error severity
  (`no_unchecked_sendable`) — the existing `BackgroundProcessingClient` avoids the whole
  problem by registering `using: .main` with `@MainActor` closures, keeping every touch of
  the task object main-actor-confined. Prefer that confinement design; a lint exception
  would need explicit owner permission.
- Client API shape that worked in production: `start(title:subtitle:) → AsyncStream<Event>`
  (self-finishing after expiration/unavailability, so consuming effects need no external
  cancellation), `updateProgress(fraction:subtitle:)`, `complete(success:)`.

### Established patterns
- `@Dependency` client idiom (15 modules): `liveValue` / `previewValue: .noop` /
  `testValue` unimplemented — SC4 requires the unimplemented `testValue` so unexpected
  calls fail loudly in tests.
- Direct coordinator injection precedent: `BackgroundTaskClient` was injected straight
  into `DownloadCoordinator` (like `pageDownloader`) rather than resolved via
  `DependencyValues` — D-05 follows that shape for the session client.
- Per-module `.swiftlint.yml` with `parent_config` — the rebuilt module already carries
  one; keep it.
- Analytics: `downloadStateChanged` signals exist (Phase 14). Whether an
  expiration-driven pause emits one is planner detail — if it does, it must ride the
  existing closed-enum vocabulary.

### Integration points
- `DownloadCoordinator.scheduleNextIfNeeded()` tail — where assertion reconciliation dies
  (D-02) and where session progress/completion reconciliation naturally lives.
- Download-start/resume/retry/update call chains from reducers into `DownloadClient` —
  the D-07 submission moments; all reach the coordinator synchronously from a user action.
- `EhPandaApp` / `AppDelegateReducer` — registration/scheduling call sites being deleted.
- Tests: `DownloadsFeatureTests` + coordinator tests currently exercise
  `BackgroundTaskClient` (`noop`/`unimplemented`) — those seams change with D-02; the
  flaky-turned-deterministic `DownloadSchedulingTests` must stay green (a failure there is
  a real regression, not flake).

</code_context>

<specifics>
## Specific Ideas

- The owner's topology instruction was verbatim: "i want you to replace BGProcessingTask
  usage with BGContinuedProcessingTask, there will be no BGProcessingTask anywhere" — and
  when offered the grace-window assertion as a fallback, chose "Remove it too." Downstream
  agents must not quietly retain either mechanism as a safety net; the deletion IS the
  design.
- A reference project on the contributor's machine provided the API-level findings above.
  Its name must never appear in any repository artifact (AGENTS.md rule, absolute).
  Everything needed from it is already captured in this file.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 15-continued-background-downloads*
*Context gathered: 2026-07-28*
