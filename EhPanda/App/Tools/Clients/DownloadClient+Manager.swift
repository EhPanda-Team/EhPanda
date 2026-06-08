//
//  DownloadClient+Manager.swift
//  EhPanda
//

import CoreData
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
        let failedPages: [DownloadFailedPagesSnapshot.Page]
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

    struct CachedGalleryImageState: Sendable {
        let previewURLs: [Int: URL]
        let imageURLs: [Int: URL]
    }

    struct PartialDownloadError: Error, Sendable {
        let failedPages: [DownloadFailedPagesSnapshot.Page]
    }

    struct FailureContext: Sendable {
        let gid: String
        let originalDownload: DownloadedGallery
        let mode: DownloadStartMode
        let hadReadableFiles: Bool
        let latestSignature: String?
    }

    struct PageDownloadContext: Sendable {
        let payload: DownloadRequestPayload
        let source: ResolvedSource?
        let temporaryFolderURL: URL
        let storedGalleryImageState: CachedGalleryImageState?
    }

    struct CacheRestoreSource: Sendable {
        let cacheURLs: [URL?]
        let referenceURL: URL?
        let imageURL: URL?
    }

    struct CaptureTargetResult: Sendable {
        let folderURL: URL
        let preferredRelativePath: String?
        let isTemporary: Bool
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
        let versionSignature: String
        let folderRelativePath: String
    }

    struct FinalizeContext: Sendable {
        let versionSignature: String
        let coverRelativePath: String?
        let batchResult: DownloadBatchResult
        let storedGalleryImageState: CachedGalleryImageState?
        let existingDownload: DownloadedGallery
    }

    let storage: DownloadFileStorage
    let urlSession: URLSession
    let persistenceContainer: NSPersistentContainer
    var observers = [UUID: AsyncStream<[DownloadedGallery]>.Continuation]()
    var lastObservedDownloads = [DownloadedGallery]()
    var activeGalleryID: String?
    var activeTask: Task<Void, Never>?
    var schedulingBlockedGalleryIDs = Set<String>()
#if DEBUG
    var testingFetchDownloadsFromStoreHook: (@Sendable () async -> Void)?
    var testingPersistFailureHook: (@Sendable () async -> Void)?
    var testingScheduledGalleryIDHistory = [String]()
#endif

    init(
        storage: DownloadFileStorage,
        urlSession: URLSession,
        persistenceContainer: NSPersistentContainer = PersistenceController.shared.container
    ) {
        self.storage = storage
        self.urlSession = urlSession
        self.persistenceContainer = persistenceContainer
    }

    func fileManager() -> DownloadFileManager {
        storage.fileManager
    }
}
