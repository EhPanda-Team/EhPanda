import AppModels
import BackgroundProcessingClient
import Foundation
import LibraryClient

public typealias ScheduledDownloadOperation = @Sendable () async -> Void

public enum ScheduledDownloadRunResult: Equatable, Sendable {
    case ranOperation
    case skippedOperation
}

public struct DownloadTaskRunner: Sendable {
    public var beforeActiveTaskCheck: @Sendable () async -> Void
    public var recordScheduledGallery: @Sendable (String) async -> Void
    public var runScheduledDownload: @Sendable (
        String,
        @escaping ScheduledDownloadOperation
    ) async -> ScheduledDownloadRunResult
    public var beforeFailurePersistence: @Sendable () async -> Void

    public init(
        beforeActiveTaskCheck: @escaping @Sendable () async -> Void = {},
        recordScheduledGallery: @escaping @Sendable (String) async -> Void = { _ in },
        runScheduledDownload: @escaping @Sendable (
            String,
            @escaping ScheduledDownloadOperation
        ) async -> ScheduledDownloadRunResult = { _, operation in
            await operation()
            return .ranOperation
        },
        beforeFailurePersistence: @escaping @Sendable () async -> Void = {}
    ) {
        self.beforeActiveTaskCheck = beforeActiveTaskCheck
        self.recordScheduledGallery = recordScheduledGallery
        self.runScheduledDownload = runScheduledDownload
        self.beforeFailurePersistence = beforeFailurePersistence
    }
}

/// The brain of the download subsystem: the in-memory read model (`downloadIndex`,
/// `userFolders`) fused with scheduling (`activeGalleryID`, `activeTask`, queued
/// modes / selections). It is one of three types split by invariant ownership,
/// alongside `DownloadStore` (pure disk I/O) and
/// `DownloadObserverHub` (observer fan-out), all behind the unchanged `DownloadClient`
/// facade. Read model and scheduling stay fused on purpose: only one gallery downloads at
/// a time (E-Hentai rate-limits gallery downloads, so concurrency is unwanted), and
/// scheduling reads and writes the index on every step, so splitting them would buy nothing
/// and reintroduce the cross-actor races this single actor exists to prevent.
public actor DownloadCoordinator {
    public static let retryLimit = 3
    public static let progressFlushPageInterval = 8
    public static let progressFlushMinimumInterval: TimeInterval = 0.4
    public static let responseInspectionPrefixLength = 4096
    public static let kokomadeImageURLSuffixes = [
        "exhentai.org/img/kokomade.jpg"
    ]
    public static let quotaExceededImageURLSuffixes = [
        "exhentai.org/img/509.gif",
        "ehgt.org/g/509.gif"
    ]

    public struct PageResult: Sendable {
        public let index: Int
        public let relativePath: String
        public let imageURL: URL?

        public init(index: Int, relativePath: String, imageURL: URL?) {
            self.index = index
            self.relativePath = relativePath
            self.imageURL = imageURL
        }
    }

    public struct PageFailure: Error, Sendable {
        public let index: Int
        public let relativePath: String?
        public let error: AppError

        public init(index: Int, relativePath: String?, error: AppError) {
            self.index = index
            self.relativePath = relativePath
            self.error = error
        }
    }

    public struct DownloadBatchResult: Sendable {
        public let pages: [PageResult]
        public let failedPages: [PageFailure]
        public init(
            pages: [PageResult],
            failedPages: [PageFailure]
        ) {
            self.pages = pages
            self.failedPages = failedPages
        }
    }

    public enum PageTaskOutcome: Sendable {
        case success(PageResult)
        case failure(PageFailure)
        case cancelled
    }

    public struct RepairSeed: Sendable {
        public let folderURL: URL
        public let manifest: DownloadManifest
        public init(
            folderURL: URL,
            manifest: DownloadManifest
        ) {
            self.folderURL = folderURL
            self.manifest = manifest
        }
    }

    public struct WorkingSeed: Sendable {
        public let folderURL: URL
        public let manifest: DownloadManifest
        public let existingPages: [Int: String]
        public let coverRelativePath: String?
        public init(
            folderURL: URL,
            manifest: DownloadManifest,
            existingPages: [Int: String],
            coverRelativePath: String? = nil
        ) {
            self.folderURL = folderURL
            self.manifest = manifest
            self.existingPages = existingPages
            self.coverRelativePath = coverRelativePath
        }
    }

    public enum ResolvedSource: Sendable {
        case normal([Int: URL])
        case mpv(key: String, imageKeys: [Int: String])
    }

    public struct ResolvedImageSource: Sendable {
        public let imageURL: URL
        public var mpvSkipServerIdentifier: String?
        public init(
            imageURL: URL,
            mpvSkipServerIdentifier: String? = nil
        ) {
            self.imageURL = imageURL
            self.mpvSkipServerIdentifier = mpvSkipServerIdentifier
        }
    }

    public struct PartialDownloadError: Error, Sendable {
        public let failedPages: [PageFailure]
        public init(
            failedPages: [PageFailure]
        ) {
            self.failedPages = failedPages
        }
    }

    public struct IncompleteDownloadError: Error, Sendable {
        public let missingPageIndices: [Int]
        public init(
            missingPageIndices: [Int]
        ) {
            self.missingPageIndices = missingPageIndices
        }
    }

    public struct FailureContext: Sendable {
        public let gid: String
        public let originalDownload: DownloadedGallery
        public let mode: DownloadStartMode
        public init(
            gid: String,
            originalDownload: DownloadedGallery,
            mode: DownloadStartMode
        ) {
            self.gid = gid
            self.originalDownload = originalDownload
            self.mode = mode
        }
    }

    public struct ProgressFlushContext: Sendable {
        public let gid: String
        public let folderURL: URL

        public init(gid: String, folderURL: URL) {
            self.gid = gid
            self.folderURL = folderURL
        }
    }

    public struct PageDownloadContext: Sendable {
        public let payload: DownloadRequestPayload
        public let options: DownloadRequestOptions
        public let source: ResolvedSource?
        public let folderURL: URL
        public init(
            payload: DownloadRequestPayload,
            options: DownloadRequestOptions,
            source: ResolvedSource? = nil,
            folderURL: URL
        ) {
            self.payload = payload
            self.options = options
            self.source = source
            self.folderURL = folderURL
        }
    }

    public struct CacheRestoreSource: Sendable {
        public let gid: String
        public let token: String
        public let cacheURLs: [URL?]
        public let referenceURL: URL?
        public let imageURL: URL?
        public init(
            gid: String,
            token: String,
            cacheURLs: [URL?],
            referenceURL: URL? = nil,
            imageURL: URL? = nil
        ) {
            self.gid = gid
            self.token = token
            self.cacheURLs = cacheURLs
            self.referenceURL = referenceURL
            self.imageURL = imageURL
        }
    }

    public struct CaptureTargetResult: Sendable {
        public let folderURL: URL
        public let preferredRelativePath: String?
        public init(
            folderURL: URL,
            preferredRelativePath: String? = nil
        ) {
            self.folderURL = folderURL
            self.preferredRelativePath = preferredRelativePath
        }
    }

    public struct HTMLResponseContext {
        public let prefixData: Data
        public let fullData: Data?
        public let response: URLResponse
        public let requestURL: URL?
        public let mimeType: String?
        public init(
            prefixData: Data,
            fullData: Data? = nil,
            response: URLResponse,
            requestURL: URL? = nil,
            mimeType: String? = nil
        ) {
            self.prefixData = prefixData
            self.fullData = fullData
            self.response = response
            self.requestURL = requestURL
            self.mimeType = mimeType
        }
    }

    public struct DownloadExecutionContext: Sendable {
        public let payload: DownloadRequestPayload
        public let options: DownloadRequestOptions
        public let existingDownload: DownloadedGallery
        public init(
            payload: DownloadRequestPayload,
            options: DownloadRequestOptions,
            existingDownload: DownloadedGallery
        ) {
            self.payload = payload
            self.options = options
            self.existingDownload = existingDownload
        }
    }

    public struct FinalizeContext: Sendable {
        public let coverRelativePath: String?
        public let batchResult: DownloadBatchResult
        public let existingDownload: DownloadedGallery
        public init(
            coverRelativePath: String? = nil,
            batchResult: DownloadBatchResult,
            existingDownload: DownloadedGallery
        ) {
            self.coverRelativePath = coverRelativePath
            self.batchResult = batchResult
            self.existingDownload = existingDownload
        }
    }

    public let storage: DownloadStore
    public let urlSession: URLSession
    public let pageDownloader: DownloadPageDownloader
    public let backgroundTaskStore: DownloadBackgroundTaskStore
    /// Starts and drives the continued-processing session that keeps a backgrounded queue running.
    ///
    /// `DownloadClient.live` supplies the live value directly when it constructs this manager, and
    /// tests supply clients of their own through the same initializer. The no-argument client
    /// carries macro-generated unimplemented endpoints that report an issue when called.
    ///
    /// Direct composition here is intentional: download-start calls flow synchronously from user
    /// actions into this actor, and this is the only place that knows real queue progress.
    public let backgroundProcessingClient: BackgroundProcessingClient
    public let storedCookiesProvider: @Sendable (URL) -> [HTTPCookie]
    public let libraryClient: LibraryClient
    /// Supplies the latest runtime settings immediately before a queued download starts.
    ///
    /// Options are not stored in manifests or request payloads so settings changed while
    /// a gallery is queued apply to the eventual detail fetch and page workers.
    public let downloadOptionsProvider: @Sendable () async -> DownloadRequestOptions
    public let queueStore: DownloadQueueStore
    public let taskRunner: DownloadTaskRunner
    /// Reads the wall clock the progress-flush throttle compares against, defaulting to the
    /// real one. Injectable so a test can freeze it: with a frozen clock the throttle's
    /// elapsed-time branch is provably dead, leaving the page-count branch as the only
    /// trigger, which is what makes a coalescing assertion independent of machine load.
    public let now: @Sendable () -> Date
    public let observerHub = DownloadObserverHub()
    /// Write-through cache of the on-disk download tree and the read authority between the
    /// explicit scan boundaries (see `indexedDownload(gid:)`). The filesystem stays the
    /// source of truth, so this is rebuilt from disk only at those boundaries, never on a
    /// hot lookup.
    public var downloadIndex = [String: DownloadFolderRecord]()
    public var hasLoadedIndex = false
    public var userFolders = [String]()
    /// Transient, session-scoped status: deliberately in-memory only, never written to disk.
    /// Download-level errors, per-page failures, validation results, and the update-available
    /// set are status *about* a download, not durable properties of it; they are cheap to
    /// re-derive and re-derivation yields the *current* truth (e.g. a lifted quota simply
    /// succeeds on the next attempt). Durable facts (downloaded pages, hashes, metadata)
    /// live in the manifest. The accepted cost is that after relaunch a failed download
    /// surfaces as inactive ("Paused") until its error re-surfaces on the next manual retry.
    public var downloadErrors = [String: DownloadFailure]()
    public var validationErrors = [String: DownloadFailure]()
    public var failedPageErrors = [String: [Int: PageFailure]]()
    public var updatedGalleryIDs = Set<String>()
    public var queuedModes = [String: DownloadStartMode]()
    public var queuedPageSelections = [String: [Int]]()
    /// ACTIVE-OWNERSHIP CONVERGENCE
    ///
    /// Every path that clears `activeGalleryID` or `activeTask` must notify observers and reach
    /// `scheduleNextIfNeeded()` before returning on every exit, including failure. Once ownership
    /// is cleared, `finishActiveTaskIfOwned` rejects the cancelled task's deferred cleanup, so the
    /// clearing path owns the queue's last scheduling opportunity. Missing it leaves downloads
    /// silently stuck and a continued-processing session with no progress.
    ///
    /// Forbidden: returning after ownership is cleared, or converging while the affected gallery
    /// remains scheduling-blocked. Clearing paths release their block before convergence.
    ///
    /// Reachable by design: convergence can suspend while another user action lands; two racing
    /// failures can converge twice; and the scheduler can select the still-queued gallery whose
    /// removal failed. These are existing, idempotent scheduling windows protected by the
    /// scheduler's ownership and generation guards. A failed expiration pause also converges
    /// unconditionally: its surrounding exits already do, the unpaused gallery must not be
    /// stranded, and this schedules work without starting a new continued-processing session.
    public var activeGalleryID: String?
    public var activeTask: Task<Void, Never>?
    public var activeTaskGeneration = 0
    /// Stamps the most recent user action that wrote queue intent for each gallery.
    ///
    /// `activeTaskGeneration` is the established scheduled-task stamp; this generation instead
    /// names user intent. An expiration-owned pause needs both identities and its session id to
    /// prove that its work is still current. Missing entries are generation zero and remain
    /// comparable forever, so this dictionary needs no cleanup path.
    public var queueIntentGenerations = [String: Int]()
    public var schedulingBlockedGalleryIDs = Set<String>()
    /// Whether this coordinator currently believes a continued-processing session is live.
    ///
    /// Set together with `continuedSessionID` in the same synchronous run as the guard in
    /// `ensureContinuedSession()`, before that path's first suspension, so two callers racing the
    /// guard cannot both reach the start call. That is what it guards against: registering a
    /// second session under the same identifier terminates the app, and two live sessions would
    /// put two progress cards on screen. The client store carries an independent re-entry guard
    /// as a second line of defense behind it.
    ///
    /// It is rolled back, though — the teardown clears it — and `ensureContinuedSession()`
    /// suspends twice after setting it, so a concurrent caller can legitimately see it false
    /// while a start is still in flight. The flag alone therefore cannot say *which* session it
    /// refers to, and this actor is reentrant: that is what `continuedSessionID` is for.
    public var hasLiveContinuedSession = false
    /// Identifies the session `hasLiveContinuedSession` refers to, minted per session by
    /// `ensureContinuedSession()` and nil exactly when no session is live.
    ///
    /// Stamping the session is what makes teardown and event delivery safe against staleness: a
    /// superseded session's trailing teardown routinely lands late, and on a reentrant actor a
    /// queue-mobilizing tap can legitimately have started a successor by then. It pairs with the
    /// client-side identity in `continuedClientSessionID`.
    public var continuedSessionID: UUID?
    /// The client-side identity of the live continued-processing session.
    ///
    /// Recorded by `ensureContinuedSession()` only after its ownership re-check passes, nil while
    /// a start is still in flight and after teardown, and the only value the coordinator may pass
    /// to the client's completion verb.
    public var continuedClientSessionID: UUID?
    /// Whether the session named by `continuedSessionID` owes a reconciliation after its client
    /// identity lands.
    ///
    /// Set only when a reconcile still owns the live coordinator session but cannot name the
    /// client session it would complete. The client's start verb suspends, so a queue drain that
    /// crosses that suspension is early rather than authoritative. The debt is cleared before it
    /// is discharged and whenever the session it belongs to is torn down.
    public var continuedSessionNeedsReconciliation = false
    public var continuedSessionTask: Task<Void, Never>?
    /// The monotonic floor under the numerator this session pushes to the card.
    ///
    /// Four writers, and no others: `ensureContinuedSession`'s synchronous reset to zero, that same
    /// function's additive seed merge once the client start returns, the re-latch at the end of
    /// every accepted push, and the **D-G6-01** withdrawal inside
    /// `reconcileWorkingManifestAgainstPageFiles`, which gives back exactly the portion of a
    /// coordinator-made basis correction the numerator was actually counting. The floor's own
    /// premise (why a deliberate correction must be excused rather than masked) is written on
    /// `pushContinuedSessionProgress`, and the withdrawal's exact-portion rule on the reconciliation
    /// itself.
    ///
    /// One deliberate transient: inside the client start's main-actor hop this value can read
    /// NEGATIVE. The reset has already run, so a withdrawal landing in that window leaves "zero
    /// minus corrections the seed has not yet absorbed", and the seed's merge is what folds them
    /// into the pre-hop snapshot. Elsewhere a negative value is inert — the push compares it
    /// against a `displayCompletedPageCount` that is never negative. A reader finding a negative
    /// value must not "fix" it by clamping the withdrawal: that silently re-opens the seed
    /// overwrite, which is the second half of G-15-6.
    ///
    /// Session-scoped: cleared when a session starts and when one ends, so no floor survives into
    /// the next session.
    public var lastPushedCompletedPageCount = 0
    /// Pages this session finished for galleries that have since left the schedulable set.
    ///
    /// Added to both the numerator and the denominator of every later push, which is what stops a
    /// completed gallery from taking its own pages out of both sides of the fraction at once. The
    /// retirement rule itself (D-G2-01) is written down on
    /// `reconcileRetiredSessionPages(snapshot:)`, where it is implemented.
    ///
    /// Keyed by gallery rather than accumulated into a scalar, deliberately: a scalar could not be
    /// corrected when a paused gallery is resumed back into the queue, and would then count that
    /// gallery's finished pages twice — once in the ledger and once in the live sum.
    ///
    /// Session-scoped, like `lastPushedCompletedPageCount`: cleared when a session starts and when
    /// one ends, so no ledger survives into the next session.
    public var retiredSessionPages = [String: Int]()
    /// The schedulable galleries the last snapshot counted, and how many pages each had finished at
    /// that moment.
    ///
    /// The ledger above is derived from this by difference: a gallery recorded here and absent from
    /// the next snapshot has departed. Observing membership at the point that already reads the
    /// schedulable set covers every departure path by construction — completion settle, the
    /// incomplete-error dequeue, pause, delete, the queued-work-item cancel and the expiration
    /// pause-all — rather than only the paths someone remembered to instrument.
    public var observedSchedulablePages = [String: Int]()
    /// The galleries this session has ever observed incomplete while they were schedulable.
    ///
    /// For a gallery in here the record is authoritative twice over: its finished pages count raw
    /// even once the record reads complete again — which is exactly the completion flush, where the
    /// forced push reports a full count while the gallery is still inside its own schedulable set —
    /// and its departure retires what that record says it finished (D-G2-01).
    ///
    /// A gallery never seen incomplete counts zero and retires zero, because its record's finished
    /// pages predate the session. `shouldSchedule` returns true for any queued work item before it
    /// consults `isIncomplete`, so a complete gallery queued for an update, a redownload, a repair
    /// or a bare re-enqueue is schedulable — correctly, the redo must run — but those pages are the
    /// redo's target rather than this session's progress. The rule itself (D-G4-01) is written down
    /// on `schedulableSnapshot()` and on `reconcileRetiredSessionPages(snapshot:)`, where the two
    /// halves are implemented.
    ///
    /// Session-scoped like the two above: cleared when a session starts and when one ends, seeded
    /// from the start snapshot, and accumulated from every snapshot a push reconciles.
    public var observedIncompleteSessionGIDs = Set<String>()

    public init(
        storage: DownloadStore,
        urlSession: URLSession,
        pageDownloader: DownloadPageDownloader? = nil,
        backgroundTaskStore: DownloadBackgroundTaskStore? = nil,
        backgroundProcessingClient: BackgroundProcessingClient = .noop,
        storedCookiesProvider: @escaping @Sendable (URL) -> [HTTPCookie] = {
            HTTPCookieStorage.shared.cookies(for: $0) ?? []
        },
        libraryClient: LibraryClient = .live,
        downloadOptionsProvider: @escaping @Sendable () async -> DownloadRequestOptions = {
            DownloadRequestOptions()
        },
        queueStore: DownloadQueueStore? = nil,
        taskRunner: DownloadTaskRunner = .init(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.storage = storage
        self.urlSession = urlSession
        self.pageDownloader = pageDownloader ?? .foreground(urlSession: urlSession)
        self.backgroundTaskStore = backgroundTaskStore ?? DownloadBackgroundTaskStore(
            fileURL: storage.backgroundTaskRegistryURL()
        )
        self.backgroundProcessingClient = backgroundProcessingClient
        self.storedCookiesProvider = storedCookiesProvider
        self.libraryClient = libraryClient
        self.downloadOptionsProvider = downloadOptionsProvider
        self.queueStore = queueStore ?? DownloadQueueStore(fileURL: storage.queueURL())
        self.taskRunner = taskRunner
        self.now = now
    }

    public var fileManager: DownloadFileManager {
        storage.fileManager
    }
}

/// Owns the observer continuations and the last snapshot broadcast to them, kept apart from
/// the coordinator's state so notification can never interleave with a state mutation. The
/// coordinator computes a snapshot and hands it here to fan out; this type holds no download
/// state of its own.
public actor DownloadObserverHub {
    private var lastObservedDownloads = [DownloadedGallery]()
    private var observers = [UUID: AsyncStream<[DownloadedGallery]>.Continuation]()
    private var notifyGeneration = 0

    public init() {}

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

        let generationBeforeSnapshot = notifyGeneration
        let initialDownloads = await snapshot()
        if notifyGeneration == generationBeforeSnapshot {
            // No notify reached this observer during resolution; deliver the snapshot.
            continuation.yield(initialDownloads)
        }
        // Otherwise a fresher value already arrived via notify; skipping the now-stale
        // snapshot keeps emissions ordered newest-last.
        return stream
    }

    public func notify(_ downloads: [DownloadedGallery]) {
        guard downloads != lastObservedDownloads else { return }
        lastObservedDownloads = downloads
        notifyGeneration += 1
        observers.values.forEach({ $0.yield(downloads) })
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }
}

extension DownloadCoordinator {
    public func queueIntentGeneration(for gid: String) -> Int {
        queueIntentGenerations[gid, default: 0]
    }

    public func advanceQueueIntentGeneration(for gid: String) {
        queueIntentGenerations[gid, default: 0] += 1
    }

    public func clearDownloadFailureState(
        gid: String,
        includePageFailures: Bool = true
    ) {
        downloadErrors[gid] = nil
        validationErrors[gid] = nil
        if includePageFailures {
            failedPageErrors[gid] = nil
        }
    }

    public func clearDownloadQueueIntent(gid: String) {
        queuedModes[gid] = nil
        queuedPageSelections[gid] = nil
    }

    public func clearDownloadSessionState(
        gid: String,
        includePageFailures: Bool = true,
        includeUpdateFlag: Bool = false
    ) {
        clearDownloadFailureState(
            gid: gid,
            includePageFailures: includePageFailures
        )
        clearDownloadQueueIntent(gid: gid)
        if includeUpdateFlag {
            updatedGalleryIDs.remove(gid)
        }
    }
}
