# Phase 15: Continued Background Downloads - Pattern Map

**Mapped:** 2026-07-28
**Files analyzed:** 14 created/rewritten/modified (2 deleted outright — see RESEARCH.md
`## Deletion Blast Radius`, not repeated here)
**Analogs found:** 12 / 12 needing one (2 deletions need none)

> Scope note: RESEARCH.md already owns the deletion inventory (paths + line numbers). This
> document is the *analog* half: for each file that is created or rewritten, the closest
> existing code to copy from, with concrete excerpts.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` (rewritten) | client seam (`@DependencyClient`) | event-driven (stream out) + request-response | itself, pre-rewrite (same file) + `CookieClient.cookiesDidChange` | exact |
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` (new) | service (`@MainActor` store over a system object) | event-driven / pub-sub | `BackgroundProcessingClient.live.register` (`using: .main`) + `DownloadObserverHub` (continuation ownership) | role-match (composite) |
| `AppPackage/Sources/BackgroundProcessingClient/.swiftlint.yml` | config | — | itself (unchanged, must survive) | exact |
| `AppPackage/Sources/BackgroundProcessingClient/Logger+.swift` | config/utility | — | itself (unchanged) | exact |
| `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` (rewrite of `…+BackgroundAssertion.swift`) | service (actor extension) | event-driven consumer + CRUD over queue state | `DownloadClient+BackgroundAssertion.swift` (same file, pre-rewrite) | exact |
| `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` (modified) | model/state (actor storage + init) | — | its own `pageDownloader` / `backgroundTaskClient` stored-dependency pattern | exact |
| `AppPackage/Sources/DownloadClient/DownloadClient.swift` (modified) | façade + composition root | request-response | its own `backgroundTaskClient: .live` wiring + `.noop` member | exact |
| `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` (modified) | service | convergence point | its own `scheduleNextIfNeeded()` tail | exact |
| `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` (modified) | service | — | same call-site shape as Scheduling | exact |
| `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift` (modified — progress push) | service | streaming/batch cadence | its own throttled cadence-flush branch | exact |
| `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` (modified) | test hook | — | `testingHasBackgroundAssertion()` | exact |
| `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings` (modified) | resource/config | — | `DownloadsFeature/Resources/Localizable.xcstrings` key `downloaded` (numeric substitution) + this catalog's `download_store.manifest_missing` (plain 6-locale key) | exact |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` (new) | test | — | `DownloadBackgroundAssertionTests.swift` (whole file, incl. `makeBlockingCoordinator`) | exact |
| `BackgroundProcessingClientSpy` (new, in the test file) | test double | event-driven (controllable continuation) | `BackgroundTaskClientSpy` (`Mutex`-backed, `Sendable`) | role-match (needs a continuation on top) |
| `App/Info.plist` (modified) | config | — | its own existing `BGTaskSchedulerPermittedIdentifiers` array | exact |
| `AppPackage/Package.swift` (modified) | config | — | its own `.module(...)` target-dep lists | exact |

## Pattern Assignments

### `BackgroundProcessingClient.swift` (client seam, rewritten)

**Analog:** the same file as it exists today —
`AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift`.

**Imports + file-local logger** (lines 1–6) — copy verbatim; `logger` placement convention:

```swift
import AppModels
import BackgroundTasks
import ComposableArchitecture
import OSLogExt

private let logger = Logger(category: .init(describing: BackgroundProcessingClient.self))
```

(`sorted_imports` is at **error**; drop `AppModels` only if the rewrite stops using it.)

**`@DependencyClient` struct shape** (lines 19–30) — keep the shape, replace the members.
Note every endpoint is documented; the phase must keep that (deliberate-design doc rule):

```swift
@DependencyClient
public struct BackgroundProcessingClient: Sendable {
    /// Registers the launch handler for the download processing task. ...
    public var register: @MainActor @Sendable (@escaping @MainActor @Sendable (BGProcessingTask) -> Void) -> Void
    /// Submits a processing-task request. Best-effort and fire-and-forget...
    public var schedule: @Sendable () -> Void
    /// Cancels any pending download processing-task request.
    public var cancel: @Sendable () -> Void
}
```

**`DependencyKey` + accessor + `.noop`** (lines 69–89) — copy structurally unchanged; this is
literally SC4's `testValue`-unimplemented requirement (`BackgroundProcessingClient()` with
`@DependencyClient` synthesises the unimplemented value):

```swift
// MARK: API
public enum BackgroundProcessingClientKey: DependencyKey {
    public static let liveValue = BackgroundProcessingClient.live
    public static let previewValue = BackgroundProcessingClient.noop
    public static let testValue = BackgroundProcessingClient()
}

extension DependencyValues {
    public var backgroundProcessingClient: BackgroundProcessingClient {
        get { self[BackgroundProcessingClientKey.self] }
        set { self[BackgroundProcessingClientKey.self] = newValue }
    }
}

// MARK: Test
extension BackgroundProcessingClient {
    public static let noop = Self(
        register: { _ in },
        schedule: {},
        cancel: {}
    )
}
```

**`@MainActor` confinement of the non-Sendable system object** — the load-bearing excerpt
(lines 33–45). `using: .main` + a `@MainActor` closure is exactly what lets this phase avoid
`@unchecked Sendable` (banned at **error** by `no_unchecked_sendable`). The rewrite keeps
this registration shape and only changes the identifier (per-session UUID) and the task cast:

```swift
extension BackgroundProcessingClient {
    public static let live = Self(
        register: { handler in
            _ = BGTaskScheduler.shared.register(
                forTaskWithIdentifier: BackgroundProcessing.downloadTaskIdentifier,
                using: .main
            ) { task in
                guard let processingTask = task as? BGProcessingTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                handler(processingTask)
            }
        },
        ...
```

**Error handling on submit** (lines 53–58) — the silent-tolerate pattern SC3/Pattern 5 needs;
copy the log-and-continue shape, swapping the success log for an event yield:

```swift
do {
    try BGTaskScheduler.shared.submit(request)
    logger.notice("Scheduled background processing task.")
} catch {
    logger.error("\(error, privacy: .public)")
}
```

(`optional_try` is at **error** — never `try?` here.)

---

### `ContinuedProcessingSession.swift` (new `@MainActor` store, event-driven)

**Analog A (stream construction + continuation ownership + termination):**
`AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — `DownloadObserverHub`
(lines 386–419). This is the repo's canonical "store a continuation, hand back the stream,
clean up on termination" shape:

```swift
public actor DownloadObserverHub {
    private var observers = [UUID: AsyncStream<[DownloadedGallery]>.Continuation]()

    public func observe(
        snapshot: @Sendable () async -> [DownloadedGallery]
    ) async -> AsyncStream<[DownloadedGallery]> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: [DownloadedGallery].self
        )
        // Register before the snapshot resolves so a `notify` landing while the
        // snapshot is in flight reaches this observer instead of being missed.
        observers[identifier] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task {
                await self.removeObserver(id: identifier)
            }
        }
        ...
        return stream
    }
```

Copy: `AsyncStream.makeStream(of:)` (not the trailing-closure `AsyncStream { }` initialiser)
for a stored continuation; store-before-you-can-yield ordering; `onTermination` cleanup.
Differences the session needs: exactly **one** continuation (not a dictionary), and the
store *finishes* the stream itself on `.expired` / `.unavailable` / `finish(success:)` — the
consumer never cancels (D-04).

**Analog B (self-terminating bridge stream):**
`AppPackage/Sources/CookieClient/CookieClient.swift` lines 37–48 — the closure-initialiser
form with an inner `Task` and `continuation.onTermination = { _ in task.cancel() }`. Use
this shape **only** if the session ends up bridging another sequence; otherwise prefer
Analog A. It is also the repo's example of a client endpoint typed
`@Sendable () -> AsyncStream<…>` (line 14: `public var cookiesDidChange`), i.e. exactly the
D-04 endpoint typing:

```swift
public var cookiesDidChange: @Sendable () -> AsyncStream<Void>
```

**Analog C (module scaffolding to leave untouched):**

`AppPackage/Sources/BackgroundProcessingClient/.swiftlint.yml` — one line, must survive the
rebuild (CLAUDE.md per-module rule):

```yaml
parent_config: ../../../.swiftlint.yml
```

`AppPackage/Sources/BackgroundProcessingClient/Logger+.swift` — unchanged; any new file in
the module gets its own `private let logger = Logger(category: .init(describing: …))`:

```swift
import OSLogExt

extension Logger {
    init(category: String) {
        self.init(moduleName: "BackgroundProcessingClient", category: category)
    }
}
```

---

### `DownloadClient+ContinuedSession.swift` (actor extension, rewrite of `…+BackgroundAssertion.swift`)

**Analog:** `AppPackage/Sources/DownloadClient/DownloadClient+BackgroundAssertion.swift`
(the file being rewritten — same role, same call sites).

**Survives verbatim** (lines 4–19) — `hasPendingWork()` becomes the session
submission/completion gate; only its doc comment needs repointing off `BGProcessingTask`:

```swift
extension DownloadCoordinator {
    /// Whether any download still needs the in-process orchestration to run.
    public func hasPendingWork() async -> Bool {
        // A running task is unambiguous work; skip the disk-backed index read.
        if activeTask != nil { return true }
        let queuedGIDs = queueStore.gids
        let downloads = queuedGIDs.isEmpty
            ? await indexedDownloads()
            : await indexedDownloads(gids: queuedGIDs)
        return downloads.contains {
            !schedulingBlockedGalleryIDs.contains($0.gid) && shouldSchedule(download: $0)
        }
    }
```

**Reconcile pattern to copy structurally** (lines 21–47) — `reconcileContinuedSession()`
replaces this. Two things to carry over: (a) the doc comment explaining *why* it hangs off
`scheduleNextIfNeeded()`, and (b) the **re-validate-after-the-hop** discipline, since the
client call is an `await` across which the queue can drain:

```swift
    /// Begins or ends the OS background-task assertion to match the current queue
    /// state. Invoked from the tail of `scheduleNextIfNeeded()`, the single point every
    /// queue mutation converges on, so the assertion can never be leaked when the last
    /// active download is paused or deleted...
    public func reconcileBackgroundAssertion() async {
        guard await hasPendingWork() else {
            await endBackgroundAssertion()
            return
        }
        guard backgroundAssertionToken == nil, !isBeginningBackgroundAssertion else {
            return
        }
        isBeginningBackgroundAssertion = true
        let token = await backgroundTaskClient.begin { [weak self] in
            Task { await self?.endBackgroundAssertion() }
        }
        // `begin` hops to the main actor, a suspension point across which the queue may
        // have drained; re-validate before committing to holding the assertion.
        if await hasPendingWork() {
            backgroundAssertionToken = token
            isBeginningBackgroundAssertion = false
        } else {
            isBeginningBackgroundAssertion = false
            await backgroundTaskClient.end(token)
        }
    }
```

The `isBeginningBackgroundAssertion` in-flight flag is the direct precedent for the
"session already being started" guard that Pitfall 1 (double registration kills the app)
makes mandatory — a single `hasLiveSession` bool is *not* enough on its own; copy the
two-state (in-flight + established) discipline.

**Pause-all primitive to build on** —
`AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:137` `pause(gid:)`, and
the schedulability predicate at lines 99–105 that selects which galleries to pause (D-11):

```swift
    private func isSchedulableDownload(
        _ download: DownloadedGallery
    ) -> Bool {
        !schedulingBlockedGalleryIDs.contains(download.gid)
            && shouldSchedule(download: download)
    }
```

`pause(gid:)`'s own insert/`defer`-remove of `schedulingBlockedGalleryIDs` (lines 137–145)
is the invariant a bulk path would have to re-implement — iterate the existing primitive
instead.

**Progress transport value** — `AppPackage/Sources/AppModels/Download/DownloadProgress.swift`
is `Sendable` and already clamps (V5 input-validation control); use it rather than a tuple
(`labeled_tuple_elements` is at **error**):

```swift
    public var displayPageCount: Int {
        max(pageCount, 1)
    }
    public var displayCompletedPageCount: Int {
        min(max(completedPageCount, 0), displayPageCount)
    }
```

---

### `DownloadClient+Manager.swift` (stored-dependency injection — D-05)

**Analog:** the `backgroundTaskClient` member it replaces, in the same file.

**Property declaration** (lines 296–300) — the new client sits in this same block:

```swift
    public let storage: DownloadStore
    public let urlSession: URLSession
    public let pageDownloader: DownloadPageDownloader
    public let backgroundTaskStore: DownloadBackgroundTaskStore
    public let backgroundTaskClient: BackgroundTaskClient
```

**Init parameter with a `.noop` default + assignment** (lines 345–375) — copy exactly; the
`= .noop` default is what keeps every existing test-constructed coordinator compiling:

```swift
    public init(
        storage: DownloadStore,
        urlSession: URLSession,
        pageDownloader: DownloadPageDownloader? = nil,
        backgroundTaskStore: DownloadBackgroundTaskStore? = nil,
        backgroundTaskClient: BackgroundTaskClient = .noop,
        ...
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        ...
        self.backgroundTaskClient = backgroundTaskClient
```

**Session-liveness state** — model on the mutable-state block at lines 336–343, and copy the
comment style that explains a non-obvious concurrency guard:

```swift
    public var activeTask: Task<Void, Never>?
    public var schedulingBlockedGalleryIDs = Set<String>()
    public var backgroundAssertionToken: BackgroundTaskToken?
    /// Set synchronously across the `begin` MainActor hop so a concurrent reconcile
    /// cannot issue a second assertion before the first token is recorded.
    public var isBeginningBackgroundAssertion = false
```

**Injectable clock already present** (lines 310–314) — reuse `now` for the progress-push
throttle rather than adding a second clock; its doc comment states the test technique:

```swift
    /// Reads the wall clock the progress-flush throttle compares against, defaulting to the
    /// real one. Injectable so a test can freeze it...
    public let now: @Sendable () -> Date
```

---

### `DownloadClient.swift` (composition root wiring)

**Analog:** its own `backgroundTaskClient: .live` line.

**Live wiring** (`DownloadClient.swift` lines 73–82) — add
`backgroundProcessingClient: .live` in the same argument list:

```swift
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: urlSession,
            pageDownloader: pageDownloader,
            backgroundTaskStore: backgroundTaskStore,
            backgroundTaskClient: .live,
            downloadOptionsProvider: {
                @Shared(.setting) var setting
                return setting.downloadRequestOptions
            }
        )
```

**Façade `.noop` member** (lines ~193–219) — the two trailing members go with the façade
endpoints being deleted:

```swift
        moveDownload: { _, _ in },
        hasPendingWork: { false },
        runBackgroundProcessing: {}
    )
```

---

### `DownloadClient+Scheduling.swift` / `+Execution.swift` (call-site repoint)

**Analog:** the existing tail call itself (`+Scheduling.swift` lines 14–19). Keep a comment
that explains the every-exit-path guarantee, updated for sessions:

```swift
    public func scheduleNextIfNeeded() async {
        await scheduleNextIfNeededCore()
        // Reconcile on every exit path of the core (both early-return guards and the
        // happy path), so the background-task assertion always matches queue state.
        await reconcileBackgroundAssertion()
    }
```

`DownloadClient+Execution.swift:262` carries the same one-line call and is repointed the
same way.

---

### `DownloadClient+PageDownload.swift` (progress push on the existing cadence)

**Analog:** the throttled cadence-flush branch in the same file (lines ~191–206). The
session progress push piggybacks here so one throttle governs both (Pitfall 3 / Open Q3),
and — critically — copy the *non-fatal* error posture: a failed push must never abort page
scheduling:

```swift
                // This cadence flush is opportunistic; a later forced flush persists
                // accumulated progress, so failure here must not abort page scheduling.
                do {
                    try await flushDownloadProgress(
                        context: .init(
                            gid: payload.gallery.gid,
                            folderURL: context.folderURL
                        ),
                        pendingResolvedPages: &progress.pendingResolvedPages,
                        lastFlushDate: &progress.lastFlushDate,
                        force: false
                    )
                } catch {
                    logger.error("Download progress cadence flush failed: \(error, privacy: .public)")
                }
```

---

### `DownloadClient+Testing.swift` (test hook)

**Analog:** the hook it replaces (lines 55–57), inside the same `#if DEBUG`-style block:

```swift
    public func testingHasBackgroundAssertion() -> Bool {
        backgroundAssertionToken != nil
    }
```

`testingHasContinuedSession()` mirrors it one-for-one against the new liveness flag.

---

### `DownloadContinuedSessionTests.swift` + `BackgroundProcessingClientSpy` (tests)

**Analog:** `AppPackage/Tests/DownloadsFeatureTests/DownloadBackgroundAssertionTests.swift`
— the entire file is the template; it is being replaced, not extended.

**Imports + suite declaration** (lines 1–9) — `DownloadFeatureTestCase` conformance carries
the shared helpers (`sampleManifest`, `removeTemporaryItem`, `sleepIgnoringCancellation`):

```swift
@testable import AppFeature
import DownloadClient
import Foundation
import Synchronization
import Testing
import UIKit

@Suite
struct DownloadBackgroundAssertionTests: DownloadFeatureTestCase {
```

(`import UIKit` goes away with the assertion client; keep `Synchronization` for `Mutex` —
`no_nslock` is at **error**.)

**Fixture helper — reusable as-is** (lines 124–175), only the injected client changes:

```swift
    struct BlockingCoordinatorContext {
        let manager: DownloadCoordinator
        let storage: DownloadStore
        let spy: BackgroundTaskClientSpy
        let rootURL: URL
    }

    /// Builds a coordinator whose single queued download blocks forever once scheduled,
    /// so `activeTask` stays installed and the assertion lifecycle can be observed.
    func makeBlockingCoordinator(gid: String, title: String) async throws -> BlockingCoordinatorContext {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let spy = BackgroundTaskClientSpy()
        let taskRunner = DownloadTaskRunner(
            runScheduledDownload: { _, _ in
                while !Task.isCancelled {
                    await sleepIgnoringCancellation(for: .milliseconds(10))
                }
                return .skippedOperation
            }
        )
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundTaskClient: spy.client,      // ← becomes backgroundProcessingClient: spy.client
            taskRunner: taskRunner
        )
        try storage.ensureRootDirectory()
        ...
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])
        return BlockingCoordinatorContext(manager: manager, storage: storage, spy: spy, rootURL: rootURL)
    }
```

**Spy shape to extend** (lines 195–225) — `final class … : Sendable` with a private `State`
struct behind a single `Mutex`, counters exposed as computed properties, a `fire…()` method
to drive the callback, and a computed `client` that vends the struct literal:

```swift
final class BackgroundTaskClientSpy: Sendable {
    private struct State {
        var beginCount = 0
        var endCount = 0
        var expirationHandler: (@Sendable () -> Void)?
    }
    private let state = Mutex(State())

    var beginCount: Int { state.withLock({ $0.beginCount }) }
    var endCount: Int { state.withLock({ $0.endCount }) }

    func fireExpiration() {
        let handler = state.withLock({ $0.expirationHandler })
        handler?()
    }

    var client: BackgroundTaskClient {
        BackgroundTaskClient(
            begin: { handler in
                self.state.withLock {
                    $0.beginCount += 1
                    $0.expirationHandler = handler
                }
                return UIBackgroundTaskIdentifier(rawValue: 1)
            },
            end: { _ in
                self.state.withLock({ $0.endCount += 1 })
            }
        )
    }
}
```

**Delta for `BackgroundProcessingClientSpy`:** store an
`AsyncStream<BackgroundProcessingEvent>.Continuation?` in `State` instead of an expiration
closure; `start` creates the stream via `AsyncStream.makeStream`, records
`(title, subtitle)`, and stashes the continuation; `fireExpiration()` becomes
`yield(.expired)` + `finish()`. Record `updateProgress` arguments as an array of
`DownloadProgress`-like values (not tuples) so SC2's progress assertions can read them.

**Async-condition helper — copy verbatim** (lines 180–190), including the comment explaining
the 10s deadline (it did not survive CI at 1s):

```swift
    func waitUntil(
        timeout: Duration = .seconds(10),
        _ condition: @Sendable () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while await !condition(), clock.now < deadline {
            await sleepIgnoringCancellation(for: .milliseconds(10))
        }
        try #require(await condition(), "Timed out waiting for condition.")
    }
```

---

### `DownloadClient/Resources/Localizable.xcstrings` (card strings)

**Which catalog:** `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings`
(version `1.0`, `sourceLanguage: en`, currently 6 keys, all `download_store.*`). It is
module-local, so symbols are consumed **without** the `.RLocalizable.` prefix and **no**
`AppPackage/Sources/Resources/ResourceStringSymbols.swift` edit is needed.

**Call-site pattern** — `DownloadClient/DownloadStore+Operations.swift:13`:

```swift
throw AppError.fileOperationFailed(
    String(localized: .downloadStoreAssetUnreadable(sourceURL.lastPathComponent))
)
```

Note `import Resources` at the top of that file (line 5) is what brings the generated
symbols into scope.

**Analog for the non-numeric card title** — this catalog's own
`download_store.manifest_missing`: a flat `stringUnit` per locale, all six locales present
(`en`, `de`, `ja`, `ko`, `zh-Hans`, `zh-Hant`), `extractionState: "manual"`:

```jsonc
"download_store.manifest_missing": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Manifest file is missing." } },
    "de": { "stringUnit": { "state": "translated", "value": "Manifest-Datei fehlt." } },
    "ja": { "stringUnit": { "state": "translated", "value": "マニフェストファイルが見つかりません。" } },
    "ko": { "stringUnit": { "state": "translated", "value": "매니페스트 파일이 없습니다." } },
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "Manifest 文件缺失。" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "Manifest 檔案缺失。" } }
  }
}
```

**Analog for the numeric count subtitle** — the `downloaded` key in
`AppPackage/Sources/DownloadsFeature/Resources/Localizable.xcstrings`. This is a known-good,
already-shipping example of the CLAUDE.md `%#@variable@` rule; copy its exact JSON shape per
locale (this is the real `en` and `de` content, verbatim):

```jsonc
"downloaded": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": { "state": "translated", "value": "Downloaded (%#@count@)" },
      "substitutions": {
        "count": {
          "argNum": 1,
          "formatSpecifier": "lld",
          "variations": {
            "plural": {
              "other": { "stringUnit": { "state": "translated", "value": "%arg" } }
            }
          }
        }
      }
    },
    "de": {
      "stringUnit": { "state": "translated", "value": "Heruntergeladen (%#@count@)" },
      "substitutions": {
        "count": {
          "argNum": 1, "formatSpecifier": "lld",
          "variations": { "plural": { "other": { "stringUnit": { "state": "translated", "value": "%arg" } } } }
        }
      }
    }
    // ja / ko / zh-Hans / zh-Hant follow identically, `other`-only
  }
}
```

Its generated symbol is called with a **labelled** argument —
`DownloadsFeature/DownloadsView+Subviews.swift:231`:

```swift
return .downloaded(count: count)
```

Rules this pins for the new keys (all observable above): the numeric argument never appears
as a bare `%lld` in the outer value; `en` and `de` substitution category sets must match
(here both are `other`-only, which is the simplest compliant choice); `ja`/`ko`/`zh-Hans`/
`zh-Hant` are `other`-only; all six locales present on every key. A two-number subtitle
(completed / total) uses two substitutions with `argNum` 1 and 2, yielding
`func …(completed: Int, total: Int)`.

## Shared Patterns

### `@Dependency` client idiom (liveValue / previewValue: .noop / testValue unimplemented)
**Source:** `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:69-89`
**Apply to:** the rebuilt client module (SC4 names `testValue` explicitly).
Excerpted above. `DownloadClient.swift` and `CookieClient.swift` follow the same
`…Key: DependencyKey` + `extension DependencyValues` pair; the naming convention is
`<Client>Key`, and `.noop` lives under a `// MARK: Test` (or `// MARK: Preview`) banner.

### Directly-injected client (not `DependencyValues`-resolved)
**Source:** `AppPackage/Sources/DownloadClient/BackgroundTaskClient.swift:1-31` and its
injection at `DownloadClient+Manager.swift:300/350/368`, wired at `DownloadClient.swift:78`.
**Apply to:** the D-05 injection of `BackgroundProcessingClient` into `DownloadCoordinator`.
The precedent's own doc comment states the rationale — carry the equivalent forward:

```swift
/// This is a plain `Sendable` struct of `@MainActor` closures rather than a
/// `@DependencyClient`. It is injected straight into `DownloadCoordinator`
/// (like `pageDownloader`) rather than being resolved through `DependencyValues`, so it
/// has no place for the macro's auto-generated unimplemented `testValue` to live.
```

Divergence for this phase (deliberate, per RESEARCH Open Q2): the new client **keeps** its
`@DependencyClient` macro and `DependencyValues` accessor (so `testValue` exists for SC4)
*while* being injected directly — so this comment must be rewritten, not copied verbatim.

### `@MainActor` confinement instead of `@unchecked Sendable`
**Source:** `BackgroundProcessingClient.swift:34-45` (`using: .main` + `@MainActor` closure
typing on the endpoint at line 23) and `BackgroundTaskClient.swift:18-20` (`@MainActor
@Sendable` closure members).
**Apply to:** every touch of `BGContinuedProcessingTask` and its `Progress`.
`no_unchecked_sendable` is **error** severity; `nonisolated(unsafe)` is the same escape with
a different spelling and is equally unwelcome.

### `Mutex`-backed `Sendable` test spy
**Source:** `AppPackage/Tests/DownloadsFeatureTests/DownloadBackgroundAssertionTests.swift:195-225`
**Apply to:** `BackgroundProcessingClientSpy`. Excerpted above. `no_nslock` (**error**)
means `Mutex` from `Synchronization`, never `NSLock`.

### File-local logger placement
**Source:** every file in `DownloadClient` — e.g. `DownloadClient+Scheduling.swift:5`,
`DownloadClient+PublicAPI.swift:6`, `BackgroundProcessingClient.swift:6`.
**Apply to:** every new `.swift` file that logs.

```swift
private let logger = Logger(category: .init(describing: DownloadCoordinator.self))
```

### Document deliberate designs
**Source:** `DownloadClient+Manager.swift:341-343`, `DownloadClient+BackgroundAssertion.swift:21-25`,
`DownloadClient+PageDownload.swift:191-192`, `DownloadObserverHub.observe` (lines 400–401).
**Apply to:** all new code. Every non-obvious guard in the analogs carries a comment stating
the race it closes. D-11's uniform expiration policy and D-08's no-complete-on-foreground
rule both *look* like bugs without such a comment — Pitfall 4 says so explicitly.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `ContinuedProcessingSession.swift` — the terminal-transition guard (`setTaskCompleted` exactly once, `expirationHandler` auto-cleared) | service | event-driven | No existing code owns a system task object with a one-shot completion contract. Composite of Analog A (continuation ownership) + the `isBeginningBackgroundAssertion` two-state guard; the completion semantics come from RESEARCH.md Pitfall 6, not from the codebase. |
| Per-session dynamic identifier minting (`UUID`-suffixed, register-then-submit in one hop) | service | request-response | The current module registers a single fixed identifier at launch; there is no in-repo precedent for register-at-submit. Follow RESEARCH.md Pattern 1. |
| `App/Info.plist` wildcard entry with `$(PRODUCT_BUNDLE_IDENTIFIER)` expansion | config | — | The existing `BGTaskSchedulerPermittedIdentifiers` entry is a literal string; the variable-expansion form is unproven in this file (RESEARCH Assumption A2 — verify with `plutil -p` on the built app). |

## Metadata

**Analog search scope:** `AppPackage/Sources/{BackgroundProcessingClient,DownloadClient,CookieClient,AppModels,DownloadsFeature}`,
`AppPackage/Tests/DownloadsFeatureTests`, `App/Info.plist`, both module string catalogs.
**Files scanned:** 16 read, ~40 grep-matched.
**Pattern extraction date:** 2026-07-28
