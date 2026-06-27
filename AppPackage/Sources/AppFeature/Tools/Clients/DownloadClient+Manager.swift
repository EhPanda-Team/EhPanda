import Foundation
import AppModels

typealias ScheduledDownloadOperation = @Sendable () async -> Void

enum ScheduledDownloadRunResult: Equatable, Sendable {
    case ranOperation
    case skippedOperation
}

struct DownloadTaskRunner: Sendable {
    var beforeActiveTaskCheck: @Sendable () async -> Void
    var recordScheduledGallery: @Sendable (String) async -> Void
    var runScheduledDownload: @Sendable (
        String,
        @escaping ScheduledDownloadOperation
    ) async -> ScheduledDownloadRunResult
    var beforeFailurePersistence: @Sendable () async -> Void

    init(
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
/// modes / selections). It is one of three types the old monolith was split into by
/// invariant ownership, alongside `DownloadStore` (pure disk I/O) and
/// `DownloadObserverHub` (observer fan-out), all behind the unchanged `DownloadClient`
/// facade. Read model and scheduling stay fused on purpose: only one gallery downloads at
/// a time (E-Hentai rate-limits gallery downloads, so concurrency is unwanted), and
/// scheduling reads and writes the index on every step, so splitting them would buy nothing
/// and reintroduce the cross-actor races this single actor exists to prevent.
actor DownloadCoordinator {
    static let retryLimit = 3
    static let progressFlushPageInterval = 8
    static let progressFlushMinimumInterval: TimeInterval = 0.4
    static let responseInspectionPrefixLength = 4096
    static let kokomadeImageURLSuffixes = [
        "exhentai.org/img/kokomade.jpg"
    ]
    static let quotaExceededImageURLSuffixes = [
        "exhentai.org/img/509.gif",
        "ehgt.org/g/509.gif"
    ]

    struct PageResult: Sendable {
        let index: Int
        let relativePath: String
        let imageURL: URL?
    }

    struct PageFailure: Error, Sendable {
        let index: Int
        let relativePath: String?
        let error: AppError
    }

    struct DownloadBatchResult: Sendable {
        let pages: [PageResult]
        let failedPages: [PageFailure]
    }

    enum PageTaskOutcome: Sendable {
        case success(PageResult)
        case failure(PageFailure)
        case cancelled
    }

    struct RepairSeed: Sendable {
        let folderURL: URL
        let manifest: DownloadManifest
    }

    struct WorkingSeed: Sendable {
        let folderURL: URL
        let manifest: DownloadManifest
        let existingPages: [Int: String]
        let coverRelativePath: String?
    }

    enum ResolvedSource: Sendable {
        case normal([Int: URL])
        case mpv(String, [Int: String])
    }

    struct ResolvedImageSource: Sendable {
        let imageURL: URL
        var mpvSkipServerIdentifier: String?
    }

    struct PartialDownloadError: Error, Sendable {
        let failedPages: [PageFailure]
    }

    struct IncompleteDownloadError: Error, Sendable {
        let missingPageIndices: [Int]
    }

    struct FailureContext: Sendable {
        let gid: String
        let originalDownload: DownloadedGallery
        let mode: DownloadStartMode
    }

    struct ProgressFlushContext: Sendable {
        let gid: String
        let folderURL: URL
    }

    struct PageDownloadContext: Sendable {
        let payload: DownloadRequestPayload
        let options: DownloadRequestOptions
        let source: ResolvedSource?
        let folderURL: URL
    }

    struct CacheRestoreSource: Sendable {
        let gid: String
        let token: String
        let cacheURLs: [URL?]
        let referenceURL: URL?
        let imageURL: URL?
    }

    struct CaptureTargetResult: Sendable {
        let folderURL: URL
        let preferredRelativePath: String?
    }

    struct HTMLResponseContext {
        let prefixData: Data
        let fullData: Data?
        let response: URLResponse
        let requestURL: URL?
        let mimeType: String?
    }

    struct DownloadExecutionContext: Sendable {
        let payload: DownloadRequestPayload
        let options: DownloadRequestOptions
        let existingDownload: DownloadedGallery
    }

    struct FinalizeContext: Sendable {
        let coverRelativePath: String?
        let batchResult: DownloadBatchResult
        let existingDownload: DownloadedGallery
    }

    let storage: DownloadStore
    let urlSession: URLSession
    let pageDownloader: DownloadPageDownloader
    let backgroundTaskStore: DownloadBackgroundTaskStore
    let backgroundTaskClient: BackgroundTaskClient
    let storedCookiesProvider: @Sendable (URL) -> [HTTPCookie]
    let libraryClient: LibraryClient
    /// Supplies the latest runtime settings immediately before a queued download starts.
    ///
    /// Options are not stored in manifests or request payloads so settings changed while
    /// a gallery is queued apply to the eventual detail fetch and page workers.
    let downloadOptionsProvider: @Sendable () async -> DownloadRequestOptions
    let queueStore: DownloadQueueStore
    let taskRunner: DownloadTaskRunner
    let observerHub = DownloadObserverHub()
    /// Write-through cache of the on-disk download tree and the read authority between the
    /// explicit scan boundaries (see `indexedDownload(gid:)`). The filesystem stays the
    /// source of truth, so this is rebuilt from disk only at those boundaries, never on a
    /// hot lookup.
    var downloadIndex = [String: DownloadFolderRecord]()
    var hasLoadedIndex = false
    var userFolders = [String]()
    /// Transient, session-scoped status: deliberately in-memory only, never written to disk.
    /// Download-level errors, per-page failures, validation results, and the update-available
    /// set are status *about* a download, not durable properties of it; they are cheap to
    /// re-derive and re-derivation yields the *current* truth (e.g. a lifted quota simply
    /// succeeds on the next attempt). Durable facts (downloaded pages, hashes, metadata)
    /// live in the manifest. The accepted cost is that after relaunch a failed download
    /// surfaces as inactive ("Paused") until its error re-surfaces on the next manual retry.
    var downloadErrors = [String: DownloadFailure]()
    var validationErrors = [String: DownloadFailure]()
    var failedPageErrors = [String: [Int: PageFailure]]()
    var updatedGalleryIDs = Set<String>()
    var queuedModes = [String: DownloadStartMode]()
    var queuedPageSelections = [String: [Int]]()
    var activeGalleryID: String?
    var activeTask: Task<Void, Never>?
    var activeTaskGeneration = 0
    var schedulingBlockedGalleryIDs = Set<String>()
    var backgroundAssertionToken: BackgroundTaskToken?
    /// Set synchronously across the `begin` MainActor hop so a concurrent reconcile
    /// cannot issue a second assertion before the first token is recorded.
    var isBeginningBackgroundAssertion = false

    init(
        storage: DownloadStore,
        urlSession: URLSession,
        pageDownloader: DownloadPageDownloader? = nil,
        backgroundTaskStore: DownloadBackgroundTaskStore? = nil,
        backgroundTaskClient: BackgroundTaskClient = .noop,
        storedCookiesProvider: @escaping @Sendable (URL) -> [HTTPCookie] = {
            HTTPCookieStorage.shared.cookies(for: $0) ?? []
        },
        libraryClient: LibraryClient = .live,
        downloadOptionsProvider: @escaping @Sendable () async -> DownloadRequestOptions = {
            DownloadRequestOptions()
        },
        queueStore: DownloadQueueStore? = nil,
        taskRunner: DownloadTaskRunner = .init()
    ) {
        self.storage = storage
        self.urlSession = urlSession
        self.pageDownloader = pageDownloader ?? .foreground(urlSession: urlSession)
        self.backgroundTaskStore = backgroundTaskStore ?? DownloadBackgroundTaskStore(
            fileURL: storage.backgroundTaskRegistryURL()
        )
        self.backgroundTaskClient = backgroundTaskClient
        self.storedCookiesProvider = storedCookiesProvider
        self.libraryClient = libraryClient
        self.downloadOptionsProvider = downloadOptionsProvider
        self.queueStore = queueStore ?? DownloadQueueStore(fileURL: storage.queueURL())
        self.taskRunner = taskRunner
    }

    var fileManager: DownloadFileManager {
        storage.fileManager
    }
}

/// Owns the observer continuations and the last snapshot broadcast to them, kept apart from
/// the coordinator's state so notification can never interleave with a state mutation. The
/// coordinator computes a snapshot and hands it here to fan out; this type holds no download
/// state of its own.
actor DownloadObserverHub {
    private var lastObservedDownloads = [DownloadedGallery]()
    private var observers = [UUID: AsyncStream<[DownloadedGallery]>.Continuation]()
    private var notifyGeneration = 0

    func observe(
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

    func notify(_ downloads: [DownloadedGallery]) {
        guard downloads != lastObservedDownloads else { return }
        lastObservedDownloads = downloads
        notifyGeneration += 1
        observers.values.forEach { $0.yield(downloads) }
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }
}

extension DownloadCoordinator {
    func clearDownloadFailureState(
        gid: String,
        includePageFailures: Bool = true
    ) {
        downloadErrors[gid] = nil
        validationErrors[gid] = nil
        if includePageFailures {
            failedPageErrors[gid] = nil
        }
    }

    func clearDownloadQueueIntent(gid: String) {
        queuedModes[gid] = nil
        queuedPageSelections[gid] = nil
    }

    func clearDownloadSessionState(
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
