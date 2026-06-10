//
//  DownloadClient+Manager.swift
//  EhPanda
//

import Foundation

actor DownloadManager {
    static let retryLimit = 3
    static let progressFlushPageInterval = 8
    static let progressFlushMinimumInterval: TimeInterval = 0.4
    static let responseInspectionPrefixLength = 4096
    static let kokomadeImageByteCount = 144844
    static let kokomadeImageSHA1 = "e48ed350e902a51581246d2a764fa7827e8e6988"
    static let kokomadeImageURLSuffixes = [
        "exhentai.org/img/kokomade.jpg"
    ]
    static let quotaExceededImageByteCount = 28658
    static let quotaExceededImageSHA1 = "f54b887b017694dc25eb1a1404f71981885f8ed9"
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
        let manifest: DownloadManifest?
        let existingPages: [Int: String]
        let coverRelativePath: String?
    }

    enum ResolvedSource: Sendable {
        case normal([Int: URL])
        case mpv(String, [Int: String])
    }

    struct ResolvedImageSource: Sendable {
        let imageURL: URL
    }

    struct PartialDownloadError: Error, Sendable {
        let failedPages: [PageFailure]
    }

    struct FailureContext: Sendable {
        let gid: String
        let originalDownload: DownloadedGallery
        let mode: DownloadStartMode
        let hadReadableFiles: Bool
    }

    struct ProgressFlushContext: Sendable {
        let gid: String
        let folderURL: URL
    }

    struct PageDownloadContext: Sendable {
        let payload: DownloadRequestPayload
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

    struct PrepareWorkingSeedResult: Sendable {
        let folderURL: URL
        let manifest: DownloadManifest?
        let existingPages: [Int: String]
        let coverRelativePath: String?
    }

    struct HTMLResponseContext {
        let prefixData: Data
        let fullData: Data?
        let response: URLResponse
        let requestURL: URL?
        let mimeType: String?
    }

    struct DownloadExecutionContext: Sendable {
        let existingDownload: DownloadedGallery
    }

    struct FinalizeContext: Sendable {
        let coverRelativePath: String?
        let batchResult: DownloadBatchResult
        let existingDownload: DownloadedGallery
    }

    let storage: DownloadFileStorage
    let urlSession: URLSession
    let libraryClient: LibraryClient
    let downloadOptionsProvider: @Sendable () async -> DownloadRequestOptions
    let queueStore: DownloadQueueStore
    var downloadIndex = [String: DownloadFolderRecord]()
    var downloadErrors = [String: DownloadFailure]()
    var validationErrors = [String: DownloadFailure]()
    var failedPageErrors = [String: [Int: PageFailure]]()
    var updatedGalleryIDs = Set<String>()
    var queuedModes = [String: DownloadStartMode]()
    var queuedPageSelections = [String: [Int]]()
    var observers = [UUID: AsyncStream<[DownloadedGallery]>.Continuation]()
    var lastObservedDownloads = [DownloadedGallery]()
    var activeGalleryID: String?
    var activeTask: Task<Void, Never>?
    var schedulingBlockedGalleryIDs = Set<String>()
#if DEBUG
    var testingFetchDownloadsFromStoreHook: (@Sendable () async -> Void)?
    var testingPersistFailureHook: (@Sendable () async -> Void)?
    var testingScheduledProcessHook: (@Sendable (String) async -> Void)?
    var testingScheduledGalleryIDHistory = [String]()
#endif

    init(
        storage: DownloadFileStorage,
        urlSession: URLSession,
        libraryClient: LibraryClient = .live,
        downloadOptionsProvider: @escaping @Sendable () async -> DownloadRequestOptions = {
            DownloadRequestOptions()
        },
        queueStore: DownloadQueueStore? = nil
    ) {
        self.storage = storage
        self.urlSession = urlSession
        self.libraryClient = libraryClient
        self.downloadOptionsProvider = downloadOptionsProvider
        self.queueStore = queueStore ?? DownloadQueueStore(fileURL: storage.queueURL())
    }

    var fileManager: DownloadFileManager {
        storage.fileManager
    }
}

extension DownloadManager {
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
