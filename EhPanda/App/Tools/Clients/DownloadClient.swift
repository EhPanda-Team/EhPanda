//
//  DownloadClient.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

@DependencyClient
struct DownloadClient: Sendable {
    var observeDownloads: @Sendable () -> AsyncStream<[DownloadedGallery]> = { AsyncStream { $0.finish() } }
    var fetchDownloads: @Sendable () async throws -> [DownloadedGallery]
    var fetchDownload: @Sendable (String) async -> DownloadedGallery?
    var reconcileDownloads: @Sendable () async -> Void
    var refreshDownloads: @Sendable () async -> Void
    var validateImageData: @Sendable (String) async -> DownloadValidationState?
    var fetchVersionMetadata: @Sendable (String, String) async -> DownloadVersionMetadata?
    var updateRemoteVersion: @Sendable (String, DownloadVersionMetadata) async -> DownloadedGallery?
    var enqueue: @Sendable (DownloadRequestPayload) async throws -> Void
    var togglePause: @Sendable (String) async throws -> Void
    var retry: @Sendable (String, DownloadStartMode) async throws -> Void
    var retryPages: @Sendable (String, [Int]) async throws -> Void
    var delete: @Sendable (String) async throws -> Void
    var loadManifest: @Sendable (String) async throws -> (DownloadedGallery, DownloadManifest)
    var loadLocalPageURLs: @Sendable (String) async -> [Int: URL]?
    var rescanLocalPageURLs: @Sendable (String) async -> [Int: URL]?
    var captureCachedPage: @Sendable (String, Int, URL?) async -> Void
    var loadInspection: @Sendable (String) async throws -> DownloadInspection
    var fetchFolders: @Sendable () async throws -> [String]
    var createFolder: @Sendable (String) async throws -> Void
    var renameFolder: @Sendable (String, String) async throws -> Void
    var deleteFolder: @Sendable (String) async throws -> Void
    var moveDownload: @Sendable (String, String) async throws -> Void
}

extension DownloadClient {
    static func live(
        rootURL: URL = FileUtil.downloadsDirectoryURL,
        urlSession: URLSession = .shared,
        fileManager: sending FileManager = .default
    ) -> Self {
        let storage = DownloadStore(rootURL: rootURL, fileManager: fileManager)
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
            }
        )
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: urlSession,
            pageDownloader: pageDownloader,
            backgroundTaskStore: backgroundTaskStore,
            downloadOptionsProvider: {
                await DatabaseClient.live.fetchAppEnv().setting.downloadRequestOptions
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
                try? await manager.fetchVersionMetadata(gid: gid, token: token).get()
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
            }
        )
    }
}

// MARK: API
enum DownloadClientKey: DependencyKey {
    static let liveValue = DownloadClient.live()
    static let previewValue = DownloadClient.noop
    static let testValue = DownloadClient()
}

extension DependencyValues {
    var downloadClient: DownloadClient {
        get { self[DownloadClientKey.self] }
        set { self[DownloadClientKey.self] = newValue }
    }
}

// MARK: Preview
extension DownloadClient {
    static let noop = Self(
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
        moveDownload: { _, _ in }
    )
}
