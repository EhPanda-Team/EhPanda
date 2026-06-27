import Foundation
import AppModels
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
/// modes / selections). It is one of three types the old monolith was split into by
/// invariant ownership, alongside `DownloadStore` (pure disk I/O) and
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
        case mpv(String, [Int: String])
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
    public let backgroundTaskClient: BackgroundTaskClient
    public let storedCookiesProvider: @Sendable (URL) -> [HTTPCookie]
    public let libraryClient: LibraryClient
    /// Supplies the latest runtime settings immediately before a queued download starts.
    ///
    /// Options are not stored in manifests or request payloads so settings changed while
    /// a gallery is queued apply to the eventual detail fetch and page workers.
    public let downloadOptionsProvider: @Sendable () async -> DownloadRequestOptions
    public let queueStore: DownloadQueueStore
    public let taskRunner: DownloadTaskRunner
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
    public var activeGalleryID: String?
    public var activeTask: Task<Void, Never>?
    public var activeTaskGeneration = 0
    public var schedulingBlockedGalleryIDs = Set<String>()
    public var backgroundAssertionToken: BackgroundTaskToken?
    /// Set synchronously across the `begin` MainActor hop so a concurrent reconcile
    /// cannot issue a second assertion before the first token is recorded.
    public var isBeginningBackgroundAssertion = false

    public init(
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
        observers.values.forEach { $0.yield(downloads) }
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }
}

extension DownloadCoordinator {
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
