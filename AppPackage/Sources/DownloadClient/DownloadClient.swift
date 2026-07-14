import Foundation
import AppModels
import ComposableArchitecture
import AppTools
import Sharing

@DependencyClient
public struct DownloadClient: Sendable {
    public var observeDownloads: @Sendable () -> AsyncStream<[DownloadedGallery]> = { AsyncStream { $0.finish() } }
    public var fetchDownloads: @Sendable () async throws -> [DownloadedGallery]
    public var fetchDownload: @Sendable (String) async -> DownloadedGallery?
    public var reconcileDownloads: @Sendable () async -> Void
    public var refreshDownloads: @Sendable () async -> Void
    public var validateImageData: @Sendable (String) async -> DownloadValidationState?
    public var fetchVersionMetadata: @Sendable (String, String) async -> DownloadVersionMetadata?
    public var updateRemoteVersion: @Sendable (String, DownloadVersionMetadata) async -> DownloadedGallery?
    public var enqueue: @Sendable (DownloadRequestPayload) async throws -> Void
    public var togglePause: @Sendable (String) async throws -> Void
    public var retry: @Sendable (String, DownloadStartMode) async throws -> Void
    public var retryPages: @Sendable (String, [Int]) async throws -> Void
    public var delete: @Sendable (String) async throws -> Void
    public var loadManifest: @Sendable (String) async throws -> (DownloadedGallery, DownloadManifest)
    public var loadLocalPageURLs: @Sendable (String) async -> [Int: URL]?
    public var rescanLocalPageURLs: @Sendable (String) async -> [Int: URL]?
    public var captureCachedPage: @Sendable (String, Int, URL?) async -> Void
    public var loadInspection: @Sendable (String) async throws -> DownloadInspection
    public var fetchFolders: @Sendable () async throws -> [String]
    public var createFolder: @Sendable (String) async throws -> Void
    public var renameFolder: @Sendable (String, String) async throws -> Void
    public var deleteFolder: @Sendable (String) async throws -> Void
    public var moveDownload: @Sendable (String, String) async throws -> Void
    public var hasPendingWork: @Sendable () async -> Bool = { false }
    public var runBackgroundProcessing: @Sendable () async -> Void
}

extension DownloadClient {
    public static func live(
        rootURL: URL = FileUtil.downloadsDirectoryURL,
        urlSession: URLSession = .shared,
        fileManager: sending FileManager = FileManager()
    ) -> Self {
        let storage = DownloadStore(rootURL: rootURL, fileManager: fileManager)
        // Reclaim any background-transfer files stranded by a prior process that died
        // between staging and consuming them. Safe here because the background session
        // does not exist yet, so the holding dir can only hold orphans.
        storage.purgeBackgroundTransferHoldingDirectory()
        let backgroundTaskStore = DownloadBackgroundTaskStore(
            fileURL: storage.backgroundTaskRegistryURL()
        )
        let completionReceiver = BackgroundPageCompletionReceiver()
        let pageDownloader = DownloadPageDownloader.background(
            identifier: DownloadBackgroundSessionEvents.pageSessionIdentifier,
            taskStore: backgroundTaskStore,
            holdingDirectory: storage.backgroundTransferHoldingDirectoryURL(),
            orphanedCompletionHandler: { taskIdentifier, fileURL, response in
                await completionReceiver.handleCompletion(
                    taskIdentifier: taskIdentifier,
                    fileURL: fileURL,
                    response: response
                )
            },
            orphanedFailureHandler: { taskIdentifier, error in
                await completionReceiver.handleFailure(
                    taskIdentifier: taskIdentifier,
                    error: error
                )
            }
        )
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
        Task {
            await completionReceiver.setCoordinator(manager)
            await manager.reconcileDownloads()
            await manager.resumeQueue()
        }
        return makeDownloadClient(manager: manager)
    }

    private static func makeObserveDownloadsStream(
        manager: DownloadCoordinator
    ) -> AsyncStream<[DownloadedGallery]> {
        AsyncStream { continuation in
            let task = Task {
                let stream = await manager.observeDownloads()
                for await downloads in stream {
                    continuation.yield(downloads)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func makeDownloadClient(
        manager: DownloadCoordinator
    ) -> Self {
        .init(
            observeDownloads: { makeObserveDownloadsStream(manager: manager) },
            fetchDownloads: { await manager.fetchDownloads() },
            fetchDownload: { gid in await manager.fetchDownload(gid: gid) },
            reconcileDownloads: { await manager.reconcileDownloads() },
            refreshDownloads: { await manager.refreshDownloads() },
            validateImageData: { gid in await manager.validateImageData(gid: gid) },
            fetchVersionMetadata: { gid, token in
                @Shared(.setting) var setting
                return try? await manager.fetchVersionMetadata(
                    host: setting.galleryHost,
                    gid: gid,
                    token: token
                )
                .get()
            },
            updateRemoteVersion: { gid, metadata in
                await manager.updateRemoteVersion(gid: gid, metadata: metadata)
            },
            enqueue: { payload in try await manager.enqueue(payload: payload).get() },
            togglePause: { gid in try await manager.togglePause(gid: gid).get() },
            retry: { gid, mode in try await manager.retry(gid: gid, mode: mode).get() },
            retryPages: { gid, pageIndices in
                try await manager.retryPages(gid: gid, pageIndices: pageIndices).get()
            },
            delete: { gid in try await manager.delete(gid: gid).get() },
            loadManifest: { gid in try await manager.loadManifest(gid: gid).get() },
            loadLocalPageURLs: { gid in try? await manager.loadLocalPageURLs(gid: gid).get() },
            rescanLocalPageURLs: { gid in await manager.rescanLocalPageURLs(gid: gid) },
            captureCachedPage: { gid, index, imageURL in
                await manager.captureCachedPage(gid: gid, index: index, imageURL: imageURL)
            },
            loadInspection: { gid in try await manager.loadInspection(gid: gid).get() },
            fetchFolders: { await manager.fetchFolders() },
            createFolder: { name in try await manager.createFolder(name: name).get() },
            renameFolder: { oldName, newName in
                try await manager.renameFolder(oldName: oldName, newName: newName).get()
            },
            deleteFolder: { name in try await manager.deleteFolder(name: name).get() },
            moveDownload: { gid, folderName in
                try await manager.moveDownload(gid: gid, toFolderName: folderName).get()
            },
            hasPendingWork: { await manager.hasPendingWork() },
            runBackgroundProcessing: { await manager.runQueueUntilIdle() }
        )
    }
}

// MARK: API
public enum DownloadClientKey: DependencyKey {
    public static let liveValue = DownloadClient.live()
    public static let previewValue = DownloadClient.noop
    public static let testValue = DownloadClient()
}

extension DependencyValues {
    public var downloadClient: DownloadClient {
        get { self[DownloadClientKey.self] }
        set { self[DownloadClientKey.self] = newValue }
    }
}

// MARK: Preview
extension DownloadClient {
    public static let noop = Self(
        observeDownloads: { AsyncStream { $0.finish() } },
        fetchDownloads: { [] },
        fetchDownload: { _ in nil },
        reconcileDownloads: {},
        refreshDownloads: {},
        validateImageData: { _ in nil },
        fetchVersionMetadata: { _, _ in nil },
        updateRemoteVersion: { _, _ in nil },
        enqueue: { _ in },
        togglePause: { _ in },
        retry: { _, _ in },
        retryPages: { _, _ in },
        delete: { _ in },
        loadManifest: { _ in throw AppError.notFound },
        loadLocalPageURLs: { _ in nil },
        rescanLocalPageURLs: { _ in nil },
        captureCachedPage: { _, _, _ in },
        loadInspection: { _ in throw AppError.notFound },
        fetchFolders: { [] },
        createFolder: { _ in },
        renameFolder: { _, _ in },
        deleteFolder: { _ in },
        moveDownload: { _, _ in },
        hasPendingWork: { false },
        runBackgroundProcessing: {}
    )
}
