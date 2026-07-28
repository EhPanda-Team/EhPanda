# Phase 15: Continued Background Downloads - Research

**Researched:** 2026-07-28
**Domain:** iOS 26 `BackgroundTasks` — `BGContinuedProcessingTask` adoption, actor-confined system-object handling, TCA `@Dependency` client seam
**Confidence:** HIGH (API surface verified against the installed iOS 26.5 SDK headers; one MEDIUM/LOW item flagged in the Assumptions Log)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Tier topology — full replacement

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

#### Client seam

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

#### Session granularity & submission moments

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

#### System card & cancel mapping

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

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

No REQUIREMENTS.md IDs are mapped to this phase. The scope contract is the four ROADMAP
success criteria, referenced by plans as SC-labels. SC3 and SC4's shape wording are
superseded by CONTEXT.md `<domain>`; the amended contract is below.

| ID | Description (as amended by CONTEXT.md) | Research Support |
|----|----------------------------------------|------------------|
| SC1 | A download started in the foreground continues to completion after the app is backgrounded, for a queue large enough to outlast the `beginBackgroundTask` grace period that bounds today's behavior. | Pattern 1 (dynamic register-then-submit), Pattern 2 (session ownership at `scheduleNextIfNeeded()`), Pitfall 2 (foreground-only submission), Pitfall 5 (non-blocking launch handler) |
| SC2 | The system-provided progress UI reflects real download progress and its cancel affordance stops the queue, leaving download state consistent with an in-app cancel. | Pattern 3 (progress + `updateTitle`), Pattern 4 (expiration → pause-all), Pitfall 3 (stall expiration), Pitfall 4 (cancel indistinguishable from reclaim) |
| SC3 (**superseded**) | ~~Falls back to `BackgroundTaskClient` / `BackgroundProcessingClient`~~ → **There is no fallback tier.** When the system refuses or expires the request, downloads suspend with the process and resume on next foreground, with no lost or duplicated work and no user-visible error. | Deletion Blast Radius, Pattern 5 (unavailable event is silent), Runtime State Inventory (stranded `BGProcessingTaskRequest`) |
| SC4 (**shape superseded**) | A testable client seam in the `BackgroundProcessingClient` module exposing a continued-processing **session** API (start / update-progress / complete, events via a self-finishing stream), `testValue` unimplemented, and no reducer *or coordinator* touching `BGTaskScheduler` directly. | Pattern 6 (client seam + MainActor confinement), Validation Architecture, Don't Hand-Roll |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These are directives, not suggestions. The planner must verify compliance in every plan.

| Directive | Effect on this phase |
|-----------|----------------------|
| **Reducer `Feature` suffix** | No new reducers in this phase; if one appears it must be `…Feature`. |
| **Per-module `.swiftlint.yml`** | `AppPackage/Sources/BackgroundProcessingClient/.swiftlint.yml` already exists with `parent_config: ../../../.swiftlint.yml` — keep it. No new module is created, so no new config is needed. |
| **Labeled localized-format arguments** | The card's count subtitle is numeric and must be a `%#@variable@` substitution in a module-local `.xcstrings`, generating `func key(variable: Int)`. Never a bare `%lld` in the outer value. String (`%@`) args stay positional. |
| **Non-translated keys need every locale filled** | Any `"shouldTranslate": false` key must carry a `stringUnit` for `en`, `de`, `ja`, `ko`, `zh-Hans`, `zh-Hant`. |
| **Confirmation dialog / alert placement** | Not applicable — this phase adds no SwiftUI presentation. |
| **Local project reference privacy** (absolute, non-waivable) | The API-level findings inherited from CONTEXT.md are reproduced here name-free and re-verified against Apple sources. No external project is named anywhere in this phase's artifacts. |
| **No absolute home paths in generated docs** | All paths in this file are repository-relative or `$HOME/…`. |
| **`.swiftlint.yml` rules read before writing Swift** | `no_unchecked_sendable` (**error**), `no_preconcurrency` (**error**), `no_nslock` (**error**, use `Mutex`), `optional_try` (**error**), `force_unwrapping` / `force_try` (**error**), `sorted_imports` (**error**), `line_length` 120 (**error**), `file_length` 1000 (**error**), `labeled_tuple_elements` (**error**), `single_line_trailing_closure` (**error**), `date_property_at_suffix` (**error**), `swiftlint_disable_requires_reason` (**error**). Suppressing any rule requires the owner's explicit permission. |

## Summary

`BGContinuedProcessingTask` is a genuinely different animal from the two mechanisms it
replaces, and almost every design consequence in this phase follows from three verified
facts. First, **there is no launch-time registration**: the SDK header explicitly exempts
continued-processing registrations from the "register before `applicationDidFinishLaunching`
returns" rule, and Apple's DTS confirms the intended pattern is to register a fresh, unique
identifier *immediately before* submitting a request with that identifier. Registering a
single wildcard handler is deliberately rejected at runtime. That kills the AppDelegate
registration call outright (D-05) and forces a per-session UUID-suffixed identifier — and
because "the system kills the app on the second registration of the same task identifier",
identifier uniqueness is a correctness requirement, not hygiene.

Second, **progress reporting is load-bearing, not cosmetic**. The header states the
scheduler forcibly expires tasks that appear stalled and prioritizes terminating tasks
reporting minimal progress. D-10's page-granular fraction is therefore the mechanism that
keeps SC1 alive, and the update must be driven from the per-page flush cadence, not only
from queue mutations. Third, **the expiration handler is the only signal you get**: a user
tapping cancel on the system card and a system resource reclaim are indistinguishable — an
Apple DTS engineer called this "a significant oversight in the current API" (FB21890081).
D-11's single pause-all policy is not a simplification; it is the only policy the API
permits.

The concurrency shape falls out cleanly. `BGContinuedProcessingTask` is a system-owned,
non-`Sendable` class whose `progress` is a non-`Sendable` `Progress`. The repo bans
`@unchecked Sendable` at error severity, and it does not need it: register with
`using: .main`, keep the task object and its `Progress` inside a `@MainActor`-isolated
store owned by the client, and let the actor-isolated `DownloadCoordinator` push only
`Sendable` scalars (`Int64`, `String`, `Bool`) across the seam. The system object never
crosses an isolation boundary. This is the same confinement the existing
`BackgroundProcessingClient.live` already uses for `BGProcessingTask`.

**Primary recommendation:** Rebuild `BackgroundProcessingClient` as a three-endpoint
session seam (`start(title:subtitle:) -> AsyncStream<Event>`, `updateProgress(...)`,
`finish(success:)`) backed by a `@MainActor final class` session store that registers a
`app.ehpanda.continued.<UUID>` identifier and submits with `.queue` in the same
main-actor hop; inject it into `DownloadCoordinator`; start sessions from the D-07 tap
paths; drive progress from the existing page-flush cadence; and replace
`reconcileBackgroundAssertion()` at the tail of `scheduleNextIfNeeded()` with a
`reconcileContinuedSession()` that updates totals and completes the session when
`hasPendingWork()` goes false.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `BGTaskScheduler` register/submit/cancel | Client seam (`BackgroundProcessingClient`) | — | SC4 forbids any other layer touching `BGTaskScheduler`. |
| Holding the `BGContinuedProcessingTask` object + its `Progress` | `@MainActor` store inside the client module | — | System object is non-`Sendable`; `using: .main` makes main-actor confinement sound without `@unchecked Sendable`. |
| Deciding *when* a session should exist | `DownloadCoordinator` (actor) | — | D-05: only the coordinator knows queue state; `scheduleNextIfNeeded()` is the single convergence point. |
| Computing progress totals (completed/total pages) | `DownloadCoordinator` | `DownloadClient+PageDownload` flush cadence | Coordinator owns `downloadIndex`; the flush cadence is where in-gallery page progress advances. |
| Localized card strings | `DownloadClient` module catalog | — | D-04 keeps the client domain-agnostic; the caller supplies strings. |
| Pause-all on expiration | `DownloadCoordinator` | `DownloadClient+PublicAPI.pause(gid:)` | D-11 mirrors in-app pause semantics; the primitive already exists. |
| Session lifecycle triggering from user taps | `DownloadsReducer` → `DownloadClient` → coordinator | — | D-07 moments already flow synchronously from reducer actions. Reducers stay unchanged (they call existing `DownloadClient` endpoints). |
| App-launch background-task registration | **Deleted** | — | D-01/D-05: continued tasks are exempt from launch-time registration. |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `BackgroundTasks` (system framework) | iOS 26.0+ | `BGContinuedProcessingTask`, `BGContinuedProcessingTaskRequest`, `BGTaskScheduler` | The only API that provides foreground-started, background-continuing execution with system-owned progress UI. [VERIFIED: iPhoneOS26.5 SDK `BackgroundTasks.framework/Headers`] |
| `Foundation` (`Progress`, `ProgressReporting`) | — | Progress reporting required by the task | `BGContinuedProcessingTask: BGTask<NSProgressReporting>`. [VERIFIED: `BGTask.h`] |
| `ComposableArchitecture` / `Dependencies` | already in `Package.swift` (swift-dependencies 1.14.1) | `@DependencyClient`, `liveValue`/`previewValue`/`testValue` | Existing repo idiom across 15 client modules. [VERIFIED: codebase grep] |
| Swift Testing | bundled with Xcode 26.6 | Unit tests | Repo standard; `AppPackage/Tests/**` is entirely Swift Testing. [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Synchronization` (`Mutex`) | stdlib | Test-spy state | Only in test doubles. `no_nslock` bans `NSLock`; the existing `BackgroundTaskClientSpy` already uses `Mutex`. [VERIFIED: `AppPackage/Tests/DownloadsFeatureTests/DownloadBackgroundAssertionTests.swift:199`] |
| `OSLogExt` (repo module) | — | `Logger` for submission/expiration diagnostics | The module already declares `Logger+.swift`; keep the file-local `private let logger` placement convention. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Per-session UUID identifier + register-at-submit | One static identifier registered at launch | **Not viable.** Re-registering the same identifier for a second session kills the app; and a static identifier can only ever back one session per process. Only viable if exactly one session ever runs per process launch — a constraint D-06/D-08 do not guarantee (a session completes when the queue drains, and a later tap must be able to start another). [VERIFIED: `BGTaskScheduler.h`] |
| `@MainActor` store confinement | `@unchecked Sendable` box around the task | Banned at error severity by `no_unchecked_sendable`; would need explicit owner permission. Unnecessary — see Pattern 6. |
| `@MainActor` store confinement | `nonisolated(unsafe)` on the stored task | Not lint-banned, but it is the same unchecked escape hatch with a different spelling and provides no safety. Only reach for it if the compiler rejects the confinement design (it should not — the existing `BGProcessingTask` code proves the shape). |
| `.queue` submission strategy | `.fail` | Locked by D-03. `.fail` yields `BGTaskScheduler.Error.Code.immediateRunIneligible` and, with no fallback tier, would lose the session outright. Note the header's `.queue` caveat: queued requests are cancelled when the user removes the app from the app switcher. |
| Deleting `runQueueUntilIdle` | Repurposing it as the session drain | Delete it. Under `BGProcessingTask` the app was *relaunched* into a fresh background process, so the handler had to pump the scheduler. Under a continued task the process is already running and the existing detached reschedule chain (`finishActiveTaskIfOwned` → `scheduleNextIfNeeded`) keeps the queue moving. A second pump would race it. |

**Installation:** No package installation. This phase adds `import BackgroundTasks` (already
imported by the module) and one Info.plist edit.

**Version verification:** Not applicable — no third-party packages are added or changed.
API surface was verified directly against the installed SDK:
`/Applications/Xcode-26.6.0.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk/System/Library/Frameworks/BackgroundTasks.framework/Headers/`.

## Package Legitimacy Audit

**This phase installs no external packages.** `BackgroundTasks` and `Foundation` are Apple
system frameworks shipped in the SDK; `ComposableArchitecture`, `swift-dependencies` and
Swift Testing are already resolved dependencies of `AppPackage`. No registry lookup applies.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| — | — | — | — | — | — | No packages added |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Verified API Surface

Everything in this section is quoted or paraphrased from the installed SDK headers.
[VERIFIED: iPhoneOS26.5 SDK]

### `BGContinuedProcessingTaskRequest` (`BGTaskRequest.h`)

```objc
BG_EXTERN API_AVAILABLE(ios(26.0))
API_UNAVAILABLE(macos, tvos, visionos, watchos, macCatalyst)
@interface BGContinuedProcessingTaskRequest : BGTaskRequest
@property (copy, nonnull) NSString *title;
@property (copy, nonnull) NSString *subtitle;
@property (nonatomic) BGContinuedProcessingTaskRequestSubmissionStrategy strategy;   // default: Queue
@property (nonatomic) BGContinuedProcessingTaskRequestResources requiredResources;   // default: Default
- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                          subtitle:(NSString *)subtitle;
@end
```

Swift: `BGContinuedProcessingTaskRequest(identifier:title:subtitle:)`,
`request.strategy: BGContinuedProcessingTaskRequest.SubmissionStrategy` (`.fail` / `.queue`),
`request.requiredResources: BGContinuedProcessingTaskRequest.Resources` (`.default` / `.gpu`).

Header notes that matter here:

- *"`earliestBeginDate` will be outright ignored by the scheduler in favor of `NSDate.now`."*
- *"The identifier ought to use wildcard notation, where the prefix of the identifier must
  at least contain the bundle ID of the submitting application, followed by optional
  semantic context, and finally ending with `.*`. An example: `<MainBundle>.<SemanticContext>.*`
  … Thus, a submitted identifier would be of the form
  `com.foo.MyApplication.continuedProcessingTask.HD830D`."*
- *"Successful creation of this object does not guarantee successful submission to the scheduler."*
- `.queue` docs: *"Add the request to the back of a queue … Queued `BGContinuedProcessingTaskRequest`s
  will be cancelled when the user removes your app from the app switcher."*
- `.gpu` requires the `com.apple.developer.background-tasks.continued-processing.gpu`
  entitlement — **not needed here** (page downloads are network + disk).

### `BGContinuedProcessingTask` (`BGTask.h`)

```objc
BG_EXTERN API_AVAILABLE(ios(26.0))
API_UNAVAILABLE(macos, tvos, visionos, watchos, macCatalyst)
@interface BGContinuedProcessingTask : BGTask<NSProgressReporting>
@property (copy, readonly) NSString *title;
@property (copy, readonly) NSString *subtitle;
- (void)updateTitle:(NSString *)title subtitle:(NSString *)subtitle;
@end
```

Swift: `task.title`, `task.subtitle`, `task.updateTitle(_:subtitle:)`, `task.progress`
(from `ProgressReporting`), plus inherited `task.identifier`,
`task.expirationHandler: (() -> Void)?`, `task.setTaskCompleted(success:)`.

Header notes that matter here:

- *"`BGContinuedProcessingTask`s **must** report progress via the `NSProgressReporting`
  protocol conformance during runtime and are subject to expiration based on changing system
  conditions and user input. Tasks that appear stalled may be forcibly expired by the
  scheduler to preserve system resources."*
- `expirationHandler` is *"cleared after it is called by the system or when
  `setTaskCompletedWithSuccess:` is called"* (deliberate retain-cycle mitigation).
- *"Not setting an expiration handler results in the system marking your task as complete
  and unsuccessful instead of sending a warning."*
- *"Not calling `setTaskCompletedWithSuccess:` before the time for the task expires may
  result in the system killing your app."* **There is no documented post-expiration time
  budget** — treat it as "as short as possible" and make the expiration path do nothing but
  flip a flag / yield an event.

### `BGTaskScheduler` (`BGTaskScheduler.h`)

```objc
@property (class, readonly) BGContinuedProcessingTaskRequestResources supportedResources
    API_AVAILABLE(ios(26.0));

- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier
                           usingQueue:(nullable dispatch_queue_t)queue
                        launchHandler:(void (^)(__kindof BGTask *task))launchHandler;

- (BOOL)submitTaskRequest:(BGTaskRequest *)taskRequest error:(NSError * _Nullable *)error;
- (void)cancelTaskRequestWithIdentifier:(NSString *)identifier;
- (void)cancelAllTaskRequests;
```

Swift names via `BackgroundTasks.apinotes`: `register(forTaskWithIdentifier:using:launchHandler:)`,
`submit(_:)` (throws), `cancel(taskRequestWithIdentifier:)`, `cancelAllTaskRequests()`.
`supportedResources` is a **type** property (`BGTaskScheduler.supportedResources`) — some
third-party write-ups show `BGTaskScheduler.shared.supportedResources`, which is wrong.

Header notes that matter here:

- *"You must register launch handlers before your application finishes launching
  (**`BGContinuedProcessingTask` registrations are exempt from this requirement**).
  Attempting to register a handler after launch or **multiple handlers for the same
  identifier is an error**."*
- *"**Register each task identifier only once. The system kills the app on the second
  registration of the same task identifier.**"*
- `register` returns `false` *"if the identifier isn't included in the
  `BGTaskSchedulerPermittedIdentifiers` `Info.plist`"* — a usable misconfiguration probe.
- `queue: nil` = *"a default background queue"*. Passing `.main` delivers the launch handler
  on the main queue.

### `BGTaskScheduler.Error.Code`

| Case | Raw | When |
|------|-----|------|
| `.unavailable` | 1 | Background refresh disabled by user, **or the app is running on Simulator, which doesn't support background processing** |
| `.tooManyPendingTaskRequests` | 2 | Too many pending requests of the type |
| `.notPermitted` | 3 | Missing appropriate `UIBackgroundModes` entry, identifier not in `BGTaskSchedulerPermittedIdentifiers`, requested `Resources` unavailable, or user denied background launches |
| `.immediateRunIneligible` | 4 | **Only** returned when submitting with `.fail`. With D-03's `.queue` this case is unreachable. |

## Architecture Patterns

### System Architecture Diagram

```
  USER TAP (start / resume / retry / update)          ── D-07 submission moments
        │  (foreground, synchronous)
        ▼
  DownloadsReducer.Action  ──►  DownloadClient (façade)  ──►  DownloadCoordinator (actor)
                                                                  │
                                        ┌─────────────────────────┤
                                        │                         │
                          ensureSession()│                        │scheduleNextIfNeeded()
                                        │                         │  (single convergence
                                        ▼                         │   point of every
                       BackgroundProcessingClient                 │   queue mutation)
                       (@Dependency-shaped struct                 │
                        of @Sendable closures)                    ▼
                                        │                 activeTask ─► page workers
                                        │                         │
                              hop to @MainActor                   │ per-page flush cadence
                                        ▼                         │ (throttled)
                       ┌───────────────────────────────┐          │
                       │ @MainActor ContinuedSession   │◄─────────┘
                       │  • BGContinuedProcessingTask  │   updateProgress(completed,
                       │  • Progress (non-Sendable)    │                 total, subtitle)
                       │  • AsyncStream.Continuation   │
                       └───────────────┬───────────────┘
                                       │
      register(id: "<bundle>.continued.<UUID>", using: .main) ──┐
      submit(BGContinuedProcessingTaskRequest, strategy: .queue)│
                                       │                        │
                                       ▼                        ▼
                              ╔══════════════════════════════════════╗
                              ║          BGTaskScheduler             ║
                              ╚══════════════════════════════════════╝
                                       │            │            │
                     launchHandler ────┘            │            └──── expirationHandler
                     (main queue, MUST return       │                  (user cancel on card
                      immediately)                  │                   OR system reclaim —
                              │                     ▼                   indistinguishable)
                              │            SYSTEM PROGRESS CARD                │
                              │            (title + subtitle +                 │
                              │             progress fraction,                 │
                              │             cancel affordance)                 │
                              ▼                                                ▼
                   AsyncStream yields .granted                    AsyncStream yields .expired
                              │                                     then FINISHES
                              ▼                                                │
                   coordinator: nothing to do                                  ▼
                   (work already running)                     coordinator: pause ALL
                                                              schedulable galleries (D-11)
                                                              via existing pause(gid:)

  Queue drains (hasPendingWork() == false)  ──►  client.finish(success: true)
                                                 ──► task.setTaskCompleted(success: true)
                                                 ──► stream finishes
```

Data-flow notes the diagram encodes:

- The **only** arrow into `BGTaskScheduler` originates in the client module (SC4).
- The system task object and its `Progress` live behind the `@MainActor` boundary; the
  actor-isolated coordinator sends only `Int64` / `String` / `Bool` across it.
- The `AsyncStream` is the *return* channel; it self-finishes on `.expired` / `.unavailable`
  / normal completion, so the consuming effect needs no external cancellation (D-04).
- Progress updates arrive from **two** sources: the queue-mutation convergence point
  (totals change when galleries join/leave) and the per-page flush cadence (completed count
  advances inside one gallery). Both are required — see Pitfall 3.

### Recommended Project Structure

```
AppPackage/Sources/BackgroundProcessingClient/
├── .swiftlint.yml                        # unchanged (parent_config)
├── Logger+.swift                         # unchanged
├── BackgroundProcessingClient.swift      # rebuilt: session seam + DependencyKey + noop
└── ContinuedProcessingSession.swift      # new: @MainActor store, the ONLY BGTaskScheduler caller

AppPackage/Sources/DownloadClient/
├── BackgroundTaskClient.swift            # DELETED
├── DownloadClient+BackgroundAssertion.swift  # rewritten → DownloadClient+ContinuedSession.swift
│                                             #   keeps hasPendingWork(), replaces
│                                             #   reconcileBackgroundAssertion()
├── DownloadClient+BackgroundProcessing.swift # DELETED (runQueueUntilIdle)
└── Resources/Localizable.xcstrings        # + card title/subtitle keys (6 locales)
```

### Pattern 1: Dynamic register-then-submit, one hop, one identifier

**What:** A session is created by generating a fresh identifier, registering a launch
handler for exactly that identifier, then submitting a request with it — all inside a single
`@MainActor` hop, in the foreground, in direct response to a user action.

**When to use:** Every D-07 submission moment, gated on "no live session already"
(D-06/D-08).

**Example:**

```swift
// Source: SDK BGTaskScheduler.h + BGTaskRequest.h; Apple, "Performing long-running tasks
// on iOS and iPadOS"; Apple DTS, developer.apple.com/forums/thread/799126
@MainActor
final class ContinuedProcessingSession {
    static let shared = ContinuedProcessingSession()

    private var task: BGContinuedProcessingTask?
    private var continuation: AsyncStream<BackgroundProcessingEvent>.Continuation?

    func start(title: String, subtitle: String) -> AsyncStream<BackgroundProcessingEvent> {
        guard task == nil, continuation == nil else { return .finished }

        let (stream, continuation) = AsyncStream.makeStream(
            of: BackgroundProcessingEvent.self
        )
        self.continuation = continuation

        // Unique per session: re-registering an identifier kills the app.
        let identifier = "\(Self.identifierPrefix).\(UUID().uuidString)"

        // The closure is NOT @Sendable, so it inherits this method's @MainActor isolation;
        // `using: .main` is what makes that sound.
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: .main
        ) { [weak self] task in
            guard let self, let task = task as? BGContinuedProcessingTask else { return }
            self.adopt(task)
        }
        guard registered else {
            // Identifier not permitted by Info.plist — surface and finish immediately.
            finish(with: .unavailable)
            return stream
        }

        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: title,
            subtitle: subtitle
        )
        request.strategy = .queue           // D-03
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("\(error, privacy: .public)")
            finish(with: .unavailable)
        }
        return stream
    }
}
```

**Why the identifier prefix:** the header requires the identifier to be prefixed with the
submitting app's bundle ID. With `PRODUCT_BUNDLE_IDENTIFIER = app.ehpanda`, a valid
concrete identifier is `app.ehpanda.continued.<UUID>` and the plist wildcard entry is
`$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`.

### Pattern 2: Session ownership at the queue convergence point

**What:** `scheduleNextIfNeeded()` already reconciles the old assertion at its tail because
it is the single point every queue mutation converges on. Replace that call in place.

**When to use:** For *completing* a session and for *refreshing totals* — never for
*starting* one (starting requires a foreground user action, which the convergence point
cannot guarantee).

```swift
// AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
public func scheduleNextIfNeeded() async {
    await scheduleNextIfNeededCore()
    // Was: await reconcileBackgroundAssertion()
    await reconcileContinuedSession()
}

// AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
func reconcileContinuedSession() async {
    guard hasLiveSession else { return }
    guard await hasPendingWork() else {
        await continuedProcessingClient.finish(success: true)   // queue drained (D-08)
        hasLiveSession = false
        return
    }
    await pushProgress()                                        // totals may have grown (D-06)
}
```

### Pattern 3: Progress that satisfies both the card and the stall detector

**What:** `Progress.totalUnitCount` = total pages across all schedulable galleries;
`Progress.completedUnitCount` = completed pages across the same set. Both `Int64`.

**When to use:** Every flush. `DownloadProgress` (AppModels) already models exactly this
pair (`completedPageCount` / `pageCount`, both `Int`, plus `fraction`) and is `Sendable` —
reuse it as the transport value rather than a tuple (`labeled_tuple_elements` is at error).

```swift
// Source: SDK BGTask.h ("must report progress … Tasks that appear stalled may be forcibly
// expired"); Apple, "Performing long-running tasks on iOS and iPadOS"
@MainActor
func updateProgress(completedUnitCount: Int64, totalUnitCount: Int64, subtitle: String) {
    guard let task else { return }
    // Grow the total first so the fraction never transiently exceeds 1.
    if totalUnitCount != task.progress.totalUnitCount {
        task.progress.totalUnitCount = totalUnitCount
    }
    task.progress.completedUnitCount = completedUnitCount
    task.updateTitle(task.title, subtitle: subtitle)
}
```

**On the regressing fraction (Claude's-discretion question in CONTEXT.md):** a regressing
*fraction* is legal and safe. `Progress` places no monotonicity constraint on
`totalUnitCount`, and D-06 explicitly accepts totals recomputing when galleries join.
What must **not** regress is `completedUnitCount` within a session — that is the signal the
scheduler's stall heuristic reads, and the community-reported card behaviour is that the
system UI only refreshes once a unit *completes*. Practical rule for the plan:

- Recompute both counts from the same snapshot each flush (never mix snapshots).
- Clamp `completedUnitCount` to be non-decreasing within a session, so removing a gallery
  from the queue shrinks the total but never rewinds completion.
- Clamp `completedUnitCount <= totalUnitCount`.

### Pattern 4: One expiration policy, because there is only one signal

```swift
// Source: SDK BGTask.h; Apple DTS, developer.apple.com/forums/thread/805088
// A user cancel on the system card and a system reclaim are indistinguishable (FB21890081).
task.expirationHandler = { [weak self] in
    // Do the minimum: flip state, notify, complete. No I/O, no awaits.
    self?.finish(with: .expired)
}
```

The coordinator's stream consumer maps `.expired` onto D-11's pause-all:

```swift
for await event in stream {
    switch event {
    case .granted:
        continue                    // work is already running; nothing to start
    case .expired:
        await pauseAllSchedulable() // mirrors toggleDownloadPause per gallery
    case .unavailable:
        continue                    // silent; no fallback tier remains (SC3 amended)
    }
}
// Stream is self-finishing: falling out of the loop needs no cancellation.
```

`pauseAllSchedulable()` should be built on the existing `pause(gid:)` primitive
(`DownloadClient+PublicAPI.swift:148`) applied to every gallery satisfying
`isSchedulableDownload`, rather than a new bulk mutation — that is what makes SC2's
"consistent with an in-app cancel" literally true, and `pause(gid:)` already maintains
`schedulingBlockedGalleryIDs` and observer notification.

### Pattern 5: `unavailable` is silent

SC3 as amended requires "no user-visible error". Submission failure, `register` returning
`false`, and Simulator unavailability all resolve to a logged `.unavailable` event and a
finished stream. Nothing reaches a reducer, no toast, no `AppError`. The download queue
behaves exactly as it does today in the foreground.

### Pattern 6: Client seam shape

```swift
// AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
public enum BackgroundProcessingEvent: Equatable, Sendable {
    case granted
    case expired
    case unavailable
}

@DependencyClient
public struct BackgroundProcessingClient: Sendable {
    /// Registers and submits a continued-processing session. The returned stream finishes
    /// itself after `.expired`/`.unavailable` or after `finish(success:)`.
    public var start: @Sendable (_ title: String, _ subtitle: String) async
        -> AsyncStream<BackgroundProcessingEvent> = { _, _ in .finished }
    /// Pushes progress and a refreshed subtitle to the system card.
    public var updateProgress: @Sendable (
        _ completedUnitCount: Int64,
        _ totalUnitCount: Int64,
        _ subtitle: String
    ) async -> Void
    /// Completes the session and finishes the stream.
    public var finish: @Sendable (_ success: Bool) async -> Void
}

public enum BackgroundProcessingClientKey: DependencyKey {
    public static let liveValue = BackgroundProcessingClient.live
    public static let previewValue = BackgroundProcessingClient.noop
    public static let testValue = BackgroundProcessingClient()   // unimplemented (SC4)
}
```

Each live closure body is `await ContinuedProcessingSession.shared.…`, which is the
`@MainActor` hop. Nothing but `Sendable` scalars crosses.

**D-05 injection:** `DownloadCoordinator` stores it like `backgroundTaskClient` did —
`public let backgroundProcessingClient: BackgroundProcessingClient` with a
`= .noop` default in `init` (`DownloadClient+Manager.swift:350`), wired to `.live` in
`DownloadClient.live(...)` (`DownloadClient.swift:78`). The `DependencyValues` accessor may
stay (harmless, and it keeps `previewValue`/`testValue` meaningful) but no reducer resolves
it any more.

### Anti-Patterns to Avoid

- **Blocking inside the launch handler.** Registering with `using: .main` and then running
  a `while` loop (as Apple's article sample does) freezes the UI. The handler must adopt the
  task, yield `.granted`, and return. DTS confirms returning from the handler does not
  complete the task.
- **Registering a wildcard identifier as a handler.** `BGTaskScheduler.shared.register(forTaskWithIdentifier: "app.ehpanda.continued.*", ...)` crashes on submit with
  `NSInternalInconsistencyException: 'No launch handler registered for task with identifier …'`.
  The wildcard is a *plist permission pattern only*.
- **Reusing an identifier across sessions.** Second registration of the same identifier
  kills the app.
- **Starting a session from `scheduleNextIfNeeded()`.** That path runs from non-user,
  non-foreground contexts (cold-launch queue resume); submission would fail. D-07 already
  scopes starts to taps.
- **Completing the session on foreground return.** D-08 forbids it, and re-submission would
  require a fresh tap.
- **Putting gallery titles in the card.** D-09 — the card renders outside the privacy mask.
- **Leaving `DownloadClient.runBackgroundProcessing` / `hasPendingWork` in the `@DependencyClient` façade if nothing calls them.** `hasPendingWork` survives *inside* the
  coordinator; the *façade endpoint* has no remaining consumer once `AppReducer` and
  `AppDelegate` stop calling it. Delete the façade endpoint, keep the coordinator method.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Keeping downloads alive after backgrounding | A `beginBackgroundTask` chain / renewal loop | `BGContinuedProcessingTask` | D-01/D-02 delete both alternatives; renewal chaining is explicitly not supported by iOS. |
| Progress UI while backgrounded | A Live Activity via ActivityKit | The task's system-provided card | The card is free with the API, is what SC2 refers to, and adding ActivityKit would need a new widget extension. |
| Progress arithmetic + fraction | Ad-hoc `Double` math | `Progress` (`totalUnitCount`/`completedUnitCount`) + existing `DownloadProgress` for transport | The system reads `Progress` directly; `DownloadProgress` already clamps and computes `fraction` (`AppModels/Download/DownloadProgress.swift`). |
| Making the non-`Sendable` task usable from an actor | `@unchecked Sendable` / `nonisolated(unsafe)` box | `@MainActor` store + `using: .main` registration | Lint-banned at error severity; confinement is both safe and already proven in this module. |
| Distinguishing user cancel from system reclaim | Heuristics on timing / app state | Accept D-11's single policy | Apple DTS confirmed the API provides no distinction (FB21890081). Any heuristic would be a guess that silently mis-pauses. |
| Pause-all | A new bulk mutation path | Iterate the existing `pause(gid:)` | SC2 requires "consistent with an in-app cancel"; the primitive already handles `schedulingBlockedGalleryIDs`, manifest state and observer notification. |
| Test doubles for the seam | Hand-rolled protocol + mock class | `@DependencyClient` `testValue` (unimplemented) + per-test struct literal | Repo idiom; unimplemented `testValue` is SC4's literal requirement. |

**Key insight:** every hand-rolled alternative here re-implements something the system either
owns (progress UI, expiration policy) or actively forbids (assertion chaining, unchecked
concurrency escapes). The phase's whole value is deleting bespoke machinery, not adding it.

## Runtime State Inventory

This is a deletion/replacement phase, so runtime state that outlives the code edit matters.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| **Stored data** | None in app-owned stores. `DownloadQueueStore` (`queue.json`) and `DownloadBackgroundTaskStore` (background-URLSession task registry) are untouched by this phase; neither stores a `BGTaskScheduler` identifier. [VERIFIED: grep — no `BGTaskScheduler`/`downloads.processing` reference under `DownloadStore`/`DownloadBackgroundTaskStore`] | none |
| **Live service config (system-side)** | **`BGTaskScheduler` holds a pending `BGProcessingTaskRequest` with identifier `app.ehpanda.downloads.processing`** for any install that backgrounded the app with pending work under the current build. After D-01 removes that identifier from `BGTaskSchedulerPermittedIdentifiers` and deletes its handler, the system holds a request the app can no longer service. | **Code edit** — call `BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "app.ehpanda.downloads.processing")` once (or `cancelAllTaskRequests()`) on first launch of the new build, then delete that cleanup in a later milestone. Cheap insurance; also prevents a stale request from ever routing to a missing handler. |
| **OS-registered state** | Launch-handler registrations are **process-local** — they are established per launch by `AppDelegate` and vanish with the process. No OS-persisted registration exists. The `beginBackgroundTask` name `app.ehpanda.downloads.assertion` is likewise process-local (`UIApplication` only). | none beyond deleting the code |
| **Secrets / env vars** | None. No secret, entitlement or environment variable references background tasks. `TelemetryDeckAppID`/`Salt` are unrelated. The `.gpu` resource entitlement is **not** adopted. [VERIFIED: grep over `App/Info.plist`, `*.entitlements`] | none |
| **Build artifacts / installed packages** | None — no package graph change, so `Package.resolved` is untouched. The built app's `Info.plist` changes (permitted identifiers), which is regenerated on every build. | none |
| **In-flight background URLSession** | The background `URLSession` `app.ehpanda.downloads.pages` (`sessionSendsLaunchEvents = true`, `isDiscretionary = false`) and `handleEventsForBackgroundURLSession` are **explicitly out of scope** (CONTEXT.md canonical refs). Its out-of-process transfers already survive suspension independently of `BGTaskScheduler`. | none — do not touch |

**The canonical question — after every file is updated, what still has the old string?**
Only the system scheduler's pending `BGProcessingTaskRequest`. Everything else is
process-local.

## Deletion Blast Radius

Grep-verified inventory. Every symbol below must be deleted or repointed; nothing may be
left stranded.

### Files deleted outright

| Path | Contents |
|------|----------|
| `AppPackage/Sources/DownloadClient/BackgroundTaskClient.swift` | `BackgroundTaskClient`, `BackgroundTaskToken`, `.live`, `.noop`, `.unimplemented`, `placeholder()`, `"app.ehpanda.downloads.assertion"` |
| `AppPackage/Sources/DownloadClient/DownloadClient+BackgroundProcessing.swift` | `runQueueUntilIdle()` |

### Files rewritten

| Path | Deleted | Kept / Added |
|------|---------|--------------|
| `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` | `BackgroundProcessing.downloadTaskIdentifier`, `register`, `schedule`, `cancel`, the `BGProcessingTask` runtime, matching `.noop` members | New session seam (Pattern 6); `DependencyKey` with `testValue = BackgroundProcessingClient()`; `.noop` |
| `AppPackage/Sources/DownloadClient/DownloadClient+BackgroundAssertion.swift` → rename to `…+ContinuedSession.swift` | `reconcileBackgroundAssertion()`, `endBackgroundAssertion()` | `hasPendingWork()` **survives** (submission/completion gate); add `reconcileContinuedSession()`, `pushProgress()`, `pauseAllSchedulable()` |
| `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` | line 4 `import BackgroundProcessingClient`, line 5 `import BackgroundTasks`, lines 71–75 `BackgroundProcessingClient.live.register { … }`, lines 84–103 `static func handleProcessingTask(_:)` | **KEEP** `application(_:handleEventsForBackgroundURLSession:completionHandler:)` and `DownloadBackgroundSessionEvents` |
| `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` | line 5 `import BackgroundProcessingClient`, line 64 `@Dependency(\.backgroundProcessingClient)`, lines 138–142 the `.background` `hasPendingWork()`/`schedule()` effect + its stale comment | The `.background` case keeps `pausePump`, the log line, and `readingFlushEffects` |
| `AppPackage/Sources/DownloadClient/DownloadClient.swift` | line 36 `hasPendingWork` façade endpoint, line 37 `runBackgroundProcessing`, line 78 `backgroundTaskClient: .live`, lines 173–174 wiring, line 219 `.noop` member | Add `backgroundProcessingClient: .live` wiring |
| `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` | line 300 `backgroundTaskClient` property, lines 340/343 `backgroundAssertionToken` / `isBeginningBackgroundAssertion`, line 350 + 368 init param/assignment | Add `backgroundProcessingClient: BackgroundProcessingClient = .noop` + a session-liveness flag |
| `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` | line 18 `await reconcileBackgroundAssertion()` + its comment | `await reconcileContinuedSession()` |
| `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` | line 262 `await self.reconcileBackgroundAssertion()` | repoint to `reconcileContinuedSession()` |
| `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` | line 55 `testingHasBackgroundAssertion()` | add `testingHasContinuedSession()` |
| `AppPackage/Package.swift` | `.module(.backgroundProcessingClient)` from the `appFeature` target deps (line ~280) | **add** `.module(.backgroundProcessingClient)` to the `downloadClient` target deps (line ~344); `downloadsFeatureTests` keeps its existing dep (line ~930) |
| `App/Info.plist` | `<string>app.ehpanda.downloads.processing</string>` | `<string>$(PRODUCT_BUNDLE_IDENTIFIER).continued.*</string>`; `UIBackgroundModes` — see Q6 below |

### Tests affected

| Path | Change |
|------|--------|
| `AppPackage/Tests/DownloadsFeatureTests/DownloadBackgroundAssertionTests.swift` | Entire suite rewritten. `BackgroundTaskClientSpy` (lines 195–224) replaced by a `BackgroundProcessingClient` spy; the three assertion-lifecycle tests become session-lifecycle tests. `makeBlockingCoordinator` helper (lines 134–176) is reusable as-is with the new injection. |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadBackgroundProcessingTests.swift` | `testRunQueueUntilIdleDrainsAllQueuedItems` (line 60) and the cancellation test (line 93) go with `runQueueUntilIdle`. `testHasPendingWorkReflectsQueueState` (lines 26–31) **survives** unchanged. `testBackgroundSchedulesProcessingWhenWorkPending` / `testBackgroundSkipsSchedulingWhenIdle` (lines 108–133) and `makeBackgroundStore` (lines 173–200) go with the `AppReducer` `.background` scheduling. Rename the file. |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift` | line 49 `$0.downloadClient.hasPendingWork = { false }` — remove with the façade endpoint. |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadSchedulingTests.swift` | No direct reference, but it exercises `scheduleNextIfNeeded()`. **Must stay green** — a failure there is a real regression, not flake (fixed deterministically in `557b0425`). |

### Grep gates for the planner

```bash
# Must all return zero after the phase:
grep -rn "BackgroundTaskClient\|backgroundTaskClient" App AppPackage ShareExtension
grep -rn "BGProcessingTask\|runQueueUntilIdle\|handleProcessingTask" App AppPackage
grep -rn "reconcileBackgroundAssertion\|backgroundAssertionToken\|isBeginningBackgroundAssertion" AppPackage
grep -rn "downloads.processing\|downloads.assertion" App AppPackage
# Must return exactly one hit, inside BackgroundProcessingClient:
grep -rn "BGTaskScheduler" App AppPackage
```

## Common Pitfalls

### Pitfall 1: Re-registering an identifier kills the app

**What goes wrong:** The process is terminated by the system, with no catchable error.
**Why it happens:** SDK header: *"Register each task identifier only once. The system kills
the app on the second registration of the same task identifier."* Handlers can never be
unregistered.
**How to avoid:** Mint a fresh `UUID` suffix per session. Never derive the suffix from
anything that can repeat (timestamps at second resolution have been observed to collide).
Guard `start` so a second session cannot begin while one is live (D-06/D-08 already require
this).
**Warning signs:** App death on the second download-start tap in one launch.

### Pitfall 2: Submission silently no-ops when the app is not (believed) foreground

**What goes wrong:** `submit(_:)` does not throw, the launch handler never fires, and no
session exists — while the caller believes one does.
**Why it happens:** The scheduling daemon validates foreground state independently and, per
a DTS-diagnosed report, can disagree with the app (`"Foregrounded apps … don't include
expected identifier"`). Submission is also documented as needing to happen from the
foreground in response to a user action.
**How to avoid:** Treat "session requested" and "session granted" as different states. Never
gate download work on the session existing — start the work immediately (DTS's explicit
guidance) and treat the session purely as background insurance. That is already the shape
D-05/D-07 describe.
**Warning signs:** Downloads run fine in the foreground but the card never appears.

### Pitfall 3: The task is expired for "no progress"

**What goes wrong:** SC1 fails intermittently on real devices — the session dies partway.
**Why it happens:** SDK header: tasks that appear stalled *"may be forcibly expired by the
scheduler"*, and the scheduler prioritizes terminating minimal-progress tasks. Community
reports put the tolerance near a ~20-second reporting interval, and the card may render an
indeterminate spinner until at least one unit completes.
**How to avoid:** Drive `updateProgress` from the per-page flush cadence in
`DownloadClient+PageDownload.swift` (which already throttles on page count and elapsed
time), not only from `scheduleNextIfNeeded()`. Ensure `completedUnitCount` genuinely
advances between updates. Do **not** use child `Progress` objects — reported not to drive
the card reliably.
**Warning signs:** Card shows a spinner instead of a bar; session dies on large galleries
with slow pages.

### Pitfall 4: Treating card-cancel and system-reclaim as different

**What goes wrong:** A "smart" policy that resumes after a reclaim but stays cancelled after
a user tap.
**Why it happens:** There is no such signal. Apple DTS: *"a significant oversight in the
current API"*, bug FB21890081 filed.
**How to avoid:** D-11's single policy. Document it in code so a future reader does not read
the uniform behaviour as a bug (repo convention: document deliberate designs).
**Warning signs:** Any code inspecting timing/app-state to guess the cause.

### Pitfall 5: Blocking the launch handler

**What goes wrong:** UI freezes the moment the session is granted.
**Why it happens:** Apple's own article sample runs a `sleep`-driven `while` loop inside the
handler. With `using: .main` that loop runs on the main queue.
**How to avoid:** The handler adopts the task, yields `.granted`, returns. Completion is
signalled later via `setTaskCompleted(success:)`. DTS confirms returning from the handler
does not complete the task.
**Warning signs:** Beachball / dropped frames right after tapping download.

### Pitfall 6: Forgetting `setTaskCompleted(success:)`

**What goes wrong:** The card lingers; worst case the system kills the app.
**Why it happens:** SDK header warns explicitly. `expirationHandler` is auto-cleared once
called or once `setTaskCompleted` runs, so a late completion call on an expired task is a
no-op but the state must still be reset locally.
**How to avoid:** Exactly one terminal transition per session in the `@MainActor` store,
guarded by nilling `task`/`continuation` before returning.

### Pitfall 7: Assuming Simulator parity

**What goes wrong:** SC1/SC2 "verified" on Simulator, broken on device.
**Why it happens:** SDK header for `.unavailable`: *"The app is running on Simulator which
doesn't support background processing."*
**How to avoid:** Every SC1/SC2 acceptance step is a **device** step. Unit tests exercise the
seam, never the framework. See Validation Architecture.

### Pitfall 8: `.queue` requests die in the app switcher

**What goes wrong:** A queued-but-not-started session vanishes.
**Why it happens:** SDK header on `.queue`: *"Queued `BGContinuedProcessingTaskRequest`s
will be cancelled when the user removes your app from the app switcher."* Apple's article
adds that *running* tasks are also cancelled on app-switcher removal, **without** the app
being told.
**How to avoid:** Nothing to fix — but the plan must not treat "no `.expired` event" as
"session still alive" across a force-quit. State on disk (manifests, queue) is already the
source of truth on next launch.

### Pitfall 9: System concurrent-task limit

**What goes wrong:** Submissions start failing when several apps hold sessions.
**Why it happens:** DTS confirms a system limit on concurrent continued tasks; consolidating
into fewer tasks is the recommended mitigation, along with `.queue`.
**How to avoid:** D-06's single queue-wide session is already the correct shape. Never
submit per gallery.

## Code Examples

### Info.plist edit

```xml
<!-- App/Info.plist -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER).continued.*</string>
</array>
```

`$(PRODUCT_BUNDLE_IDENTIFIER)` resolves to `app.ehpanda` (Debug and Release, app target).
Xcode's Info.plist processing substitutes build settings inside nested array string values —
the same mechanism already used for `CFBundleIdentifier` in this file, and a working
production example of this exact wildcard-with-variable form is documented on the Apple
developer forums. **Plan-level verification (cheap, worth doing):**
`plutil -p "$(xcodebuild -showBuildSettings … | …)/EhPanda.app/Info.plist" | grep -A2 BGTaskScheduler`
after a build, asserting the literal `app.ehpanda.continued.*`.

### Localized card strings

The strings belong in `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings`
(the coordinator supplies them; D-04 keeps the client domain-agnostic). That catalog already
exists, is `.process`-ed by the `downloadClient` target, and its keys are consumed through
Xcode-generated `LocalizedStringResource` symbols with **no** `.RLocalizable.` prefix — e.g.
`String(localized: .downloadStoreAssetUnreadable(sourceURL.lastPathComponent))`
(`DownloadStore+Operations.swift:13`). Shared-module keys use the `.RLocalizable.` prefix and
hand-written symbols in `AppPackage/Sources/Resources/ResourceStringSymbols.swift`; these new
keys are module-local, so **no** `ResourceStringSymbols.swift` edit is needed.

CLAUDE.md requires every *numeric* argument to be a `%#@variable@` substitution. The exact
existing shape to copy is the `downloaded` key in
`AppPackage/Sources/DownloadsFeature/Resources/Localizable.xcstrings`:

```jsonc
// Pattern to replicate, per locale, for each numeric argument.
"en": {
  "stringUnit": { "state": "translated", "value": "%#@completed@ of %#@total@ pages" },
  "substitutions": {
    "completed": {
      "argNum": 1,
      "formatSpecifier": "lld",
      "variations": { "plural": { "other": { "stringUnit": { "state": "translated", "value": "%arg" } } } }
    },
    "total": {
      "argNum": 2,
      "formatSpecifier": "lld",
      "variations": { "plural": { "other": { "stringUnit": { "state": "translated", "value": "%arg" } } } }
    }
  }
}
```

Rules the plan must honour (all from CLAUDE.md, all observable in the existing catalog):

- Locales: `en`, `de`, `ja`, `ko`, `zh-Hans`, `zh-Hant` — **all six**, every key.
- `en` and `de` substitution variables may carry `one`/`other`; `ja`/`ko`/`zh-Hans`/`zh-Hant`
  are `other`-only. A variable's `en` category set must equal its `de` set.
- Never a bare `%lld` in the outer value.
- Generated symbol becomes `func …(completed: Int, total: Int)` — labelled, as required.
- The card **title** is a plain non-numeric key (no substitution) and may be a simple
  `stringUnit` per locale.

### Coordinator-side session start (D-07)

```swift
// AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
extension DownloadCoordinator {
    /// Ensures a queue-wide continued-processing session exists (D-06/D-07). Safe to call
    /// from every queue-mobilizing user action; a no-op while a session is already live.
    func ensureContinuedSession() async {
        guard !hasLiveSession, await hasPendingWork() else { return }
        hasLiveSession = true
        let progress = await schedulableProgress()
        let stream = await backgroundProcessingClient.start(
            String(localized: .continuedSessionTitle),
            String(localized: .continuedSessionSubtitle(
                completed: progress.displayCompletedPageCount,
                total: progress.displayPageCount
            ))
        )
        sessionTask = Task { [weak self] in
            for await event in stream {
                await self?.handleSessionEvent(event)
            }
            await self?.markSessionEnded()
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `beginBackgroundTask` assertion for the post-background grace window | `BGContinuedProcessingTask` for user-initiated work | iOS 26 (WWDC25) | DTS guidance: use `beginBackgroundTask` only for work under ~30s; longer user-initiated work belongs on a continued task. |
| `BGProcessingTask` discretionary window for long work | `BGContinuedProcessingTask` for *user-initiated* long work | iOS 26 | `BGProcessingTask` remains correct for opportunistic maintenance; it is the wrong tool for "the user just tapped download". |
| All launch handlers registered before `didFinishLaunching` returns | Continued-task handlers registered dynamically at submission time | iOS 26 | The generic rule still applies to refresh/processing tasks; continued tasks are explicitly exempted in the SDK header. |
| App-owned progress UI while backgrounded | System-provided card / Live Activity driven by `Progress` | iOS 26 | No ActivityKit adoption needed; progress reporting becomes a *liveness* requirement, not a nicety. |

**Deprecated/outdated:**

- Nothing is formally deprecated. But third-party write-ups that show
  `BGTaskScheduler.shared.supportedResources` are wrong (it is a **type** property), and
  ones that show a wildcard identifier passed to `register(forTaskWithIdentifier:)` describe
  a runtime crash.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `UIBackgroundModes: processing` should be **kept** even after `BGProcessingTask` is gone. No Apple source states it is required for `BGContinuedProcessingTask`; the recommendation is risk-weighted, not evidence-positive. | Environment / Open Q6 | If it is genuinely unnecessary, the app ships a spurious background-mode declaration (App Review may ask about it). If it *is* necessary and were removed, `submit(_:)` throws `.notPermitted` and SC1 fails outright. |
| A2 | `$(PRODUCT_BUNDLE_IDENTIFIER)` expands inside a `BGTaskSchedulerPermittedIdentifiers` array entry in **this** project's build setup. | Code Examples | The permitted identifier would be the literal string `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`, `register` returns `false`, every session reports `.unavailable`. Cheap to falsify with `plutil -p` on the built Info.plist. |
| A3 | The imported Swift signature of `register(forTaskWithIdentifier:using:launchHandler:)` leaves `launchHandler` non-`@Sendable`, so a closure formed in a `@MainActor` context inherits main-actor isolation (the mechanism the existing `BGProcessingTask` code relies on). | Pattern 1 / Pattern 6 | If the closure imports as `@Sendable`, isolation is not inherited and the body needs `MainActor.assumeIsolated { … }` — sound because `using: .main` guarantees main-queue delivery, and *not* lint-banned. Compile-time discoverable in the first task. |
| A4 | The system card refreshes acceptably when `totalUnitCount` grows mid-session (fraction dips). Community reports describe card update quirks around child `Progress`; direct-count growth is untested here. | Pattern 3 | The card could look jumpy when a second gallery joins. Cosmetic only; D-06 accepts recomputation. Observable on device during SC2 verification. |
| A5 | Deleting `runQueueUntilIdle` is safe because the existing detached reschedule chain keeps the queue moving inside a live process. | Standard Stack / Blast Radius | If the chain stalls, a large queue could go idle mid-session. Directly testable: `DownloadSchedulingTests` + the existing drain-behaviour coverage repointed onto `scheduleNextIfNeeded()`. |

## Open Questions (RESOLVED)

**Shipped disposition (Q6):** `UIBackgroundModes: processing` was KEPT exactly as recommended below — implemented and verified in the executed phase.

1. **Q6 — Is `UIBackgroundModes: processing` still required?**
   - *What we know:* The SDK header documents the mode requirement explicitly for
     `BGProcessingTask` (`processing`) and `BGAppRefreshTask` (`fetch`) and says **nothing**
     for `BGContinuedProcessingTask`. Apple's adoption article ("Performing long-running
     tasks on iOS and iPadOS") and WWDC25 session 227 both cover Info.plist setup and mention
     only permitted identifiers (plus the Background GPU Access capability for `.gpu`).
     Meanwhile `BGTaskSchedulerErrorCode.notPermitted` still lists a missing `UIBackgroundModes`
     entry as one of its causes, and community guides uniformly (but non-authoritatively)
     list `processing`. The app's other background consumer — the background `URLSession`
     `app.ehpanda.downloads.pages` — is covered by Apple's "Downloading files in the
     background" article, which describes `sessionSendsLaunchEvents` and
     `handleEventsForBackgroundURLSession` and never mentions a background mode.
   - *What's unclear:* Whether the daemon's permission check for a continued-processing
     submission consults `UIBackgroundModes` at all. No Apple source states it either way.
   - **Recommendation (definitive): KEEP `<string>processing</string>`.** Absence of mention
     is not a statement of non-requirement, and the failure modes are wildly asymmetric —
     keeping it costs a stray declaration, removing it wrongly costs SC1 entirely. Removal is
     a one-line plist edit with zero code coupling, so if the owner wants it gone the plan can
     add a **late, isolated, device-verified** task: remove `processing`, run the SC1 device
     scenario, and assert `submit(_:)` does not throw `BGTaskScheduler.Error.Code.notPermitted`
     (code 3). Revert on failure. Do not make any other task depend on that outcome.

2. **Q — Should the `\.backgroundProcessingClient` `DependencyValues` accessor survive?**
   - *What we know:* After D-01/D-05 no reducer resolves it; the coordinator takes it by
     injection. `previewValue: .noop` / `testValue` unimplemented are still meaningful for
     the module's own tests.
   - *Recommendation:* Keep the `DependencyKey` + accessor (SC4 names `testValue` explicitly
     and it costs nothing), but delete `AppFeature`'s `@Dependency` declaration and its
     package dependency on the module. Note this diverges from `BackgroundTaskClient`, which
     had no `DependencyValues` entry at all.

3. **Q — Where exactly does the progress push hook into the page loop?**
   - *What we know:* `DownloadClient+PageDownload.swift:191-206` already runs an
     opportunistic, throttled cadence flush (`lastFlushDate` + page-count branch, with an
     injectable `now` clock on the coordinator for deterministic tests).
   - *Recommendation:* Piggyback the session progress push on that same cadence branch so
     one throttle governs both, and so the frozen-clock test technique (`now:` injection,
     established in Phase 11) applies unchanged. Confirm during planning that the flush site
     can reach the coordinator's session state without a new suspension hazard.

4. **Q — Should `hasPendingWork` remain on the `DownloadClient` façade?**
   - *What we know:* Its only two consumers (`AppReducer` `.background`,
     `AppDelegate.handleProcessingTask`) are both deleted. The coordinator method is still
     needed.
   - *Recommendation:* Delete the façade endpoint and its `.noop` member; keep
     `DownloadCoordinator.hasPendingWork()`. Update `DownloadAutomationTests.swift:49`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | build/test | ✓ | 26.6 (17F113) | — |
| iOS SDK with `BGContinuedProcessingTask` | the whole phase | ✓ | iPhoneOS 26.5 SDK | — |
| Deployment target ≥ iOS 26.0 | availability gating | ✓ | `IPHONEOS_DEPLOYMENT_TARGET = 26.0` (app + ShareExtension); `AppPackage` `platforms: [.iOS(.v26)]` | — |
| Physical iOS 26 device | SC1 / SC2 verification | **unknown to this agent** | — | **None.** Simulator returns `BGTaskScheduler.Error.Code.unavailable`; there is no substitute. |
| iOS Simulator | unit tests, build gate | ✓ | iOS 26 runtimes | — |
| `swiftlint` binary | lint gate | via SwiftLintPlugins 0.65.0 build plugin (standalone binary is in DerivedData, not on `PATH`) | 0.65.0 | Run the app-scheme build, which invokes the plugin |

**Availability annotation strategy: none needed.** Both the Xcode project
(`IPHONEOS_DEPLOYMENT_TARGET = 26.0`) and the package (`platforms: [.iOS(.v26)]`) already sit
at or above the API's `API_AVAILABLE(ios(26.0))` floor. **Do not add `@available` /
`#available` scaffolding** — it would be dead code. (Note: two *legacy* build-configuration
blocks in `project.pbxproj` still read `IPHONEOS_DEPLOYMENT_TARGET = 16.0`; grep-verified as
belonging to no live target used by this phase. Confirm during planning if a plan touches
project settings.)

**Missing dependencies with no fallback:**

- A physical iOS 26 device is required to observe SC1 and SC2. The SDK documents that
  Simulator does not support background processing, so `submit(_:)` fails there. Every
  acceptance step for SC1/SC2 must be an owner-run device step.

**Missing dependencies with fallback:** none.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (bundled with Xcode 26.6) |
| Config file | `AppPackage/Tests/FeatureTests.xctestplan` (22 targets, includes `DownloadsFeatureTests` and `AppFeatureTests`) |
| Quick run command | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DownloadsFeatureTests` |
| Full suite command | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone 17'` |

Two standing constraints (project memory): run **one** `xcodebuild test` invocation at a
time — overlapping or `pkill`-ing a launching test run wedges `testmanagerd`. And
`xcodebuild` buffers stdout until exit, so silence is not a hang.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SC1 | A D-07 tap starts exactly one session when work is pending | unit | `… -only-testing:DownloadsFeatureTests/DownloadContinuedSessionTests` | ❌ Wave 0 (replaces `DownloadBackgroundAssertionTests`) |
| SC1 | A second D-07 tap while a session is live does **not** start a second session (D-06/D-08, Pitfall 1) | unit | same suite | ❌ Wave 0 |
| SC1 | No session is started when `hasPendingWork()` is false | unit | same suite | ❌ Wave 0 |
| SC1 | Session is completed with `success: true` when the queue drains via `scheduleNextIfNeeded()` | unit | same suite | ❌ Wave 0 |
| SC1 | Session is **not** completed on foreground return (D-08) | unit | `… -only-testing:AppFeatureTests` (scene-phase `.active` emits no session call) | ❌ Wave 0 |
| SC1 | **A large queue outlasts the old grace window after backgrounding** | **manual (device)** | — owner runs the device scenario | n/a — device-only |
| SC2 | Card progress equals completed/total pages across schedulable galleries; totals recompute when a gallery joins (D-10/D-06) | unit | spy records `(completed, total)` pairs; frozen `now:` clock removes the throttle's time branch | ❌ Wave 0 |
| SC2 | `completedUnitCount` never regresses within a session | unit | same suite | ❌ Wave 0 |
| SC2 | `.expired` pauses **every** schedulable gallery with in-app pause semantics (D-11) | unit | spy fires `.expired`; assert each gallery's `displayStatus` and `schedulingBlockedGalleryIDs` match a per-gallery `pause(gid:)` baseline | ❌ Wave 0 |
| SC2 | **Card renders real progress and its cancel affordance stops the queue** | **manual (device)** | — | n/a — device-only |
| SC2 | Card carries **no** gallery title/tag text (D-09) | unit + manual | assert the strings passed to `start`/`updateProgress` contain only counts; device screenshot confirms | ❌ Wave 0 |
| SC3 | `.unavailable` produces no reducer action, no `AppError`, no toast | unit | `… -only-testing:DownloadsFeatureTests` — TestStore receives nothing | ❌ Wave 0 |
| SC3 | Queue state after `.unavailable` is byte-identical to the no-session path (no lost/duplicated work) | unit | run the same queue with `.noop` vs `.unavailable` client and compare manifests | ❌ Wave 0 |
| SC4 | `testValue` is unimplemented — an unexpected call fails the test loudly | unit | a test that constructs the coordinator with `BackgroundProcessingClient()` and asserts an issue is reported on call | ❌ Wave 0 |
| SC4 | No `BGTaskScheduler` reference outside the client module | static | `grep -rn "BGTaskScheduler" App AppPackage` returns exactly the client-module hits | ✅ (grep gate) |
| — | Existing scheduling behaviour unchanged | regression | `… -only-testing:DownloadsFeatureTests/DownloadSchedulingTests` | ✅ exists — **must stay green** |
| — | `hasPendingWork()` still reflects queue state | regression | `… -only-testing:DownloadsFeatureTests` (`testHasPendingWorkReflectsQueueState`) | ✅ exists — survives unchanged |

### What is unit-testable vs device-only

- **Unit-testable through the seam:** every *decision* — when a session is requested, with
  what strings, what progress numbers are pushed, what happens on each event, and that the
  session is completed exactly once. The spy replaces `BackgroundProcessingClient` wholesale,
  so `BGTaskScheduler` is never touched. The existing `makeBlockingCoordinator` helper
  (`DownloadBackgroundAssertionTests.swift`) already builds a coordinator whose single
  queued download blocks forever — exactly the fixture the session-lifecycle tests need.
- **Unit-testable through coordinator queue state:** pause-all equivalence (compare the
  post-`.expired` state against a per-gallery `pause(gid:)` baseline), progress arithmetic
  over a synthetic multi-gallery index, and the "no lost/duplicated work" property.
- **Device-only:** that iOS actually grants the session, that the card appears with the
  right strings, that its cancel affordance routes to `expirationHandler`, and that work
  genuinely survives backgrounding past the old grace window. The SDK states Simulator does
  not support background processing, so none of this is observable in CI.

### Sampling Rate

- **Per task commit:** `-only-testing:DownloadsFeatureTests` (quick command above) plus a
  clean app-scheme build (which runs SwiftLint via the plugin).
- **Per wave merge:** full `FeatureTests` plan.
- **Phase gate:** full suite green, all grep gates at zero, then the owner's device UAT for
  SC1/SC2 before `/gsd-verify-work`.

### Device Observation Script (owner-run, SC1 + SC2)

1. Queue ≥ 3 galleries totalling ≥ 300 pages on a real iOS 26 device.
2. Tap start; confirm downloads begin **immediately** (work must not wait on the session).
3. Background the app. Confirm the system card appears with the neutral title + count
   subtitle and **no gallery title**.
4. Leave backgrounded past ~60s (comfortably beyond the old `beginBackgroundTask` window).
   Confirm the card's counts advance.
5. Foreground; confirm the card persists (D-08) and in-app progress matches the card.
6. Background again, tap **cancel** on the card. Foreground; confirm every gallery is
   Paused, identical to having tapped pause on each.
7. Separately: force-quit from the app switcher mid-session and relaunch; confirm no crash
   and no duplicated pages (Pitfall 8).

### Wave 0 Gaps

- [ ] `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` — session
      lifecycle, progress, expiration → pause-all (replaces `DownloadBackgroundAssertionTests.swift`)
- [ ] `BackgroundProcessingClientSpy` — `Mutex`-backed recorder plus a controllable event
      continuation (model on `BackgroundTaskClientSpy`, which is already `Sendable` + `Mutex`)
- [ ] Repoint/prune `DownloadBackgroundProcessingTests.swift` (rename; drop the
      `runQueueUntilIdle` and `AppReducer` `.background` cases; keep `hasPendingWork`)
- [ ] `DownloadAutomationTests.swift:49` — drop the `hasPendingWork` façade override
- [ ] `testingHasContinuedSession()` in `DownloadClient+Testing.swift` (replaces
      `testingHasBackgroundAssertion()`)
- [ ] Framework install: none — Swift Testing and the test plan already exist

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | This phase touches no credential path. Session cookies are unchanged. |
| V3 Session Management | no | "Session" here is an OS task session, not an auth session. |
| V4 Access Control | no | No new authorization surface. |
| V5 Input Validation | yes (narrow) | The only untrusted input reaching the new code is gallery page counts from manifests. Clamp with `DownloadProgress`'s existing `displayPageCount`/`displayCompletedPageCount` (`max(pageCount, 1)`, `min(max(completed, 0), total)`) so a corrupt manifest cannot produce a negative or divide-by-zero `Progress`. |
| V6 Cryptography | no | None. |
| V8 Data Protection / Privacy | **yes — the load-bearing one** | D-09: the system card renders in system UI outside the app's privacy mask and outside the App Switcher snapshot protection added in Phase 7. Gallery titles, tags, categories and IDs must never reach `title`/`subtitle`. Enforce with a unit assertion on the exact strings passed to `start`/`updateProgress`, and consider a grep gate that no `DownloadedGallery` title accessor is reachable from the card-string builder. |
| V14 Configuration | yes | Info.plist change: the permitted identifier must be scoped to `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`, never a broader wildcard. Removing `app.ehpanda.downloads.processing` reduces the declared background surface. |

### Known Threat Patterns for iOS 26 / SwiftUI / TCA

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Content-identifying text leaked to a system surface outside the app's privacy controls | Information Disclosure | D-09 neutral counts; asserted in unit tests, confirmed by device screenshot |
| Over-broad background-task identifier wildcard permitting unintended task routing | Elevation of Privilege / Tampering | Prefix with `$(PRODUCT_BUNDLE_IDENTIFIER)` and one semantic segment; never a bare `*` |
| Unbounded/attacker-influenced counts driving `Progress` (corrupt manifest) | Denial of Service | Clamp via `DownloadProgress`; `Int64` conversion from a clamped `Int` |
| Stale background-task request left registered with the system after the handling code is deleted | Denial of Service (self-inflicted) | One-shot `cancel(taskRequestWithIdentifier:)` cleanup — see Runtime State Inventory |
| Retaining a `@unchecked Sendable` box over a system object → data race on `Progress` | Tampering | `@MainActor` confinement + `using: .main`; `no_unchecked_sendable` at error severity enforces it |

## Sources

### Primary (HIGH confidence)

- **iOS 26.5 SDK headers** (installed, read directly):
  `.../Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk/System/Library/Frameworks/BackgroundTasks.framework/Headers/{BGTask.h, BGTaskRequest.h, BGTaskScheduler.h, BackgroundTasks.apinotes}`
  — full API surface, availability, identifier/wildcard rule, registration-exemption and
  double-registration warning, `.queue` app-switcher caveat, error codes including the
  Simulator statement.
- `developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask` — abstract,
  discussion, availability (iOS 26.0).
- `developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest` —
  abstract, topic symbols, foreground/user-action requirement.
- `developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados`
  — the adoption article: identifier prefixing, `.queue`/`.fail`, `register` + `submit`
  sample, progress reporting, expiration handling, app-switcher note.
- `developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/register(fortaskwithidentifier:using:launchhandler:)`
  — return value and the "register once" warning.
- **Codebase** (grep/read-verified): `AppPackage/Sources/{BackgroundProcessingClient,DownloadClient,AppFeature}/**`,
  `AppPackage/Tests/DownloadsFeatureTests/**`, `AppPackage/Package.swift`, `App/Info.plist`,
  `.swiftlint.yml`, `AppPackage/Tests/FeatureTests.xctestplan`,
  `EhPanda.xcodeproj/project.pbxproj`.

### Secondary (MEDIUM confidence)

- WWDC25 session 227, "Finish tasks in the background" — wildcard identifier notation,
  dynamic registration, mandatory progress, GPU capability.
- Apple Developer Forums thread 796944 (DTS: Kevin Elliott) — per-instance registration is
  the primary pattern; handler need not do the work; single task + child progress for
  multi-job workflows; start work immediately rather than waiting on the task; handler-leak
  acknowledgement.
- Apple Developer Forums thread 799126 (DTS) — wildcard handler registration is
  intentionally rejected; register the concrete identifier immediately before submitting.
- Apple Developer Forums thread 805088 (DTS) — cancel/reclaim indistinguishability
  acknowledged (FB21890081); concurrent-task limit; `.queue` as mitigation; card UI quirks.
- Apple Developer Forums thread 807370 (DTS) — a real, working
  `$(PRODUCT_BUNDLE_IDENTIFIER).<context>.*` plist entry; silent submission failure when the
  daemon disagrees about foreground state; identifier-uniqueness collision at second
  resolution.
- `developer.apple.com/documentation/foundation/downloading-files-in-the-background` —
  background `URLSession` guidance; notably makes no `UIBackgroundModes` claim.
- `github.com/dotnet/macios/wiki/BackgroundTasks-iOS-xcode26.0-b1` — independent
  header-derived binding surface; corroborates the SDK reading.

### Tertiary (LOW confidence)

- Community "background processing" skill documents and blog write-ups listing
  `UIBackgroundModes: processing` for continued tasks — used only as weak corroboration for
  A1; none cites an Apple statement, and several contain verifiable errors (e.g.
  `BGTaskScheduler.shared.supportedResources`).

## Metadata

**Confidence breakdown:**

- Standard stack: **HIGH** — no third-party packages; the system API surface was read out of
  the installed SDK rather than inferred.
- Architecture: **HIGH** — the registration/submission/expiration model is pinned by SDK
  header text plus DTS statements; the confinement design mirrors code already compiling in
  this repo.
- Pitfalls: **HIGH** for 1, 3, 4, 5, 6, 7, 8, 9 (all SDK- or DTS-sourced); **MEDIUM** for 2
  (single DTS-diagnosed report of a daemon bug).
- Deletion blast radius: **HIGH** — every entry is grep-verified with file paths and line
  numbers.
- `UIBackgroundModes` decision: **LOW/MEDIUM** — see Assumption A1; recommendation is
  risk-weighted with a stated falsification test.
- Validation architecture: **HIGH** for the unit-testable half; the device-only half is
  inherent to the API, not a research gap.

**Research date:** 2026-07-28
**Valid until:** 2026-08-27 (30 days). `BGContinuedProcessingTask` is a first-year API under
active bug-fixing (card contrast fixed in 26.1; FB21890081 open) — re-check the forums and
the SDK headers if this phase slips past a point release.
