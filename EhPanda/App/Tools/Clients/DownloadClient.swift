//
//  DownloadClient.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

struct DownloadClient: Sendable {
    let observeDownloads: @Sendable () -> AsyncStream<[DownloadedGallery]>
    let fetchDownloads: @Sendable () async -> [DownloadedGallery]
    let fetchDownload: @Sendable (String) async -> DownloadedGallery?
    let reconcileDownloads: @Sendable () async -> Void
    let refreshDownloads: @Sendable () async -> Void
    let validateImageData: @Sendable (String) async -> DownloadValidationState?
    let resumeQueue: @Sendable () async -> Void
    let badges: @Sendable ([String]) async -> [String: DownloadBadge]
    let fetchVersionMetadata: @Sendable (String, String) async -> Result<DownloadVersionMetadata, AppError>
    let updateRemoteVersion: @Sendable (String, DownloadVersionMetadata) async -> DownloadBadge
    let updateRemoteSignature: @Sendable (String, String?) async -> DownloadBadge
    let enqueue: @Sendable (DownloadRequestPayload) async -> Result<Void, AppError>
    let togglePause: @Sendable (String) async -> Result<Void, AppError>
    let retry: @Sendable (String, DownloadStartMode) async -> Result<Void, AppError>
    let retryPages: @Sendable (String, [Int]) async -> Result<Void, AppError>
    let delete: @Sendable (String) async -> Result<Void, AppError>
    let loadManifest: @Sendable (String) async -> Result<(DownloadedGallery, DownloadManifest), AppError>
    let loadLocalPageURLs: @Sendable (String) async -> Result<[Int: URL], AppError>
    let captureCachedPage: @Sendable (String, Int, URL?) async -> Void
    let loadInspection: @Sendable (String) async -> Result<DownloadInspection, AppError>

    init(
        observeDownloads: @escaping @Sendable () -> AsyncStream<[DownloadedGallery]>,
        fetchDownloads: @escaping @Sendable () async -> [DownloadedGallery],
        fetchDownload: @escaping @Sendable (String) async -> DownloadedGallery?,
        reconcileDownloads: @escaping @Sendable () async -> Void = {},
        refreshDownloads: @escaping @Sendable () async -> Void,
        validateImageData: @escaping @Sendable (String) async -> DownloadValidationState? = { _ in nil },
        resumeQueue: @escaping @Sendable () async -> Void,
        badges: @escaping @Sendable ([String]) async -> [String: DownloadBadge],
        fetchVersionMetadata: @escaping @Sendable (String, String) async -> Result<DownloadVersionMetadata, AppError>
        = { _, _ in .failure(.notFound) },
        updateRemoteVersion: @escaping @Sendable (String, DownloadVersionMetadata) async -> DownloadBadge =
        { _, _ in .none },
        updateRemoteSignature: @escaping @Sendable (String, String?) async -> DownloadBadge,
        enqueue: @escaping @Sendable (DownloadRequestPayload) async -> Result<Void, AppError>,
        togglePause: @escaping @Sendable (String) async -> Result<Void, AppError>,
        retry: @escaping @Sendable (String, DownloadStartMode) async -> Result<Void, AppError>,
        retryPages: @escaping @Sendable (String, [Int]) async -> Result<Void, AppError> = { _, _ in .success(()) },
        delete: @escaping @Sendable (String) async -> Result<Void, AppError>,
        loadManifest: @escaping @Sendable (String) async -> Result<
            (DownloadedGallery, DownloadManifest), AppError
        >,
        loadLocalPageURLs: @escaping @Sendable (String) async -> Result<
            [Int: URL], AppError
        > = { _ in .failure(.notFound) },
        captureCachedPage: @escaping @Sendable (String, Int, URL?) async -> Void = { _, _, _ in },
        loadInspection: @escaping @Sendable (String) async -> Result<
            DownloadInspection, AppError
        > = { _ in .failure(.notFound) }
    ) {
        self.observeDownloads = observeDownloads
        self.fetchDownloads = fetchDownloads
        self.fetchDownload = fetchDownload
        self.reconcileDownloads = reconcileDownloads
        self.refreshDownloads = refreshDownloads
        self.validateImageData = validateImageData
        self.resumeQueue = resumeQueue
        self.badges = badges
        self.fetchVersionMetadata = fetchVersionMetadata
        self.updateRemoteVersion = updateRemoteVersion
        self.updateRemoteSignature = updateRemoteSignature
        self.enqueue = enqueue
        self.togglePause = togglePause
        self.retry = retry
        self.retryPages = retryPages
        self.delete = delete
        self.loadManifest = loadManifest
        self.loadLocalPageURLs = loadLocalPageURLs
        self.captureCachedPage = captureCachedPage
        self.loadInspection = loadInspection
    }
}

extension DownloadClient {
    static func live(
        rootURL: URL = FileUtil.downloadsDirectoryURL,
        urlSession: URLSession = .shared,
        fileManager: sending FileManager = .default
    ) -> Self {
        let manager = DownloadManager(
            storage: .init(rootURL: rootURL, fileManager: fileManager),
            urlSession: urlSession
        )
        Task {
            await manager.reconcileDownloads()
            await manager.resumeQueue()
        }
        return makeDownloadClient(manager: manager)
    }

    private static func makeObserveDownloadsStream(
        manager: DownloadManager
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
        manager: DownloadManager
    ) -> Self {
        .init(
            observeDownloads: { makeObserveDownloadsStream(manager: manager) },
            fetchDownloads: { await manager.fetchDownloads() },
            fetchDownload: { gid in await manager.fetchDownload(gid: gid) },
            reconcileDownloads: { await manager.reconcileDownloads() },
            refreshDownloads: { await manager.refreshDownloads() },
            validateImageData: { gid in await manager.validateImageData(gid: gid) },
            resumeQueue: { await manager.resumeQueue() },
            badges: { gids in await manager.badges(for: gids) },
            fetchVersionMetadata: { gid, token in
                await manager.fetchVersionMetadata(gid: gid, token: token)
            },
            updateRemoteVersion: { gid, metadata in
                await manager.updateRemoteVersion(gid: gid, metadata: metadata)
            },
            updateRemoteSignature: { gid, signature in
                await manager.updateRemoteSignature(gid: gid, latestSignature: signature)
            },
            enqueue: { payload in await manager.enqueue(payload: payload) },
            togglePause: { gid in await manager.togglePause(gid: gid) },
            retry: { gid, mode in await manager.retry(gid: gid, mode: mode) },
            retryPages: { gid, pageIndices in
                await manager.retryPages(gid: gid, pageIndices: pageIndices)
            },
            delete: { gid in await manager.delete(gid: gid) },
            loadManifest: { gid in await manager.loadManifest(gid: gid) },
            loadLocalPageURLs: { gid in await manager.loadLocalPageURLs(gid: gid) },
            captureCachedPage: { gid, index, imageURL in
                await manager.captureCachedPage(gid: gid, index: index, imageURL: imageURL)
            },
            loadInspection: { gid in await manager.loadInspection(gid: gid) }
        )
    }
}

// MARK: API
enum DownloadClientKey: DependencyKey {
    static let liveValue = DownloadClient.live()
    static let previewValue = DownloadClient.noop
    static let testValue = DownloadClient.unimplemented
}

extension DependencyValues {
    var downloadClient: DownloadClient {
        get { self[DownloadClientKey.self] }
        set { self[DownloadClientKey.self] = newValue }
    }
}

// MARK: Test
extension DownloadClient {
    static let noop: Self = .init(
        observeDownloads: {
            .init { continuation in
                continuation.yield([])
                continuation.finish()
            }
        },
        fetchDownloads: { [] },
        fetchDownload: { _ in nil },
        reconcileDownloads: {},
        refreshDownloads: {},
        validateImageData: { _ in nil },
        resumeQueue: {},
        badges: { _ in [:] },
        fetchVersionMetadata: { _, _ in .failure(.notFound) },
        updateRemoteVersion: { _, _ in .none },
        updateRemoteSignature: { _, _ in .none },
        enqueue: { _ in .success(()) },
        togglePause: { _ in .success(()) },
        retry: { _, _ in .success(()) },
        retryPages: { _, _ in .success(()) },
        delete: { _ in .success(()) },
        loadManifest: { _ in .failure(.notFound) },
        loadLocalPageURLs: { _ in .failure(.notFound) },
        captureCachedPage: { _, _, _ in },
        loadInspection: { _ in .failure(.notFound) }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        observeDownloads: IssueReporting.unimplemented(placeholder: placeholder()),
        fetchDownloads: IssueReporting.unimplemented(placeholder: placeholder()),
        fetchDownload: IssueReporting.unimplemented(placeholder: placeholder()),
        reconcileDownloads: IssueReporting.unimplemented(placeholder: placeholder()),
        refreshDownloads: IssueReporting.unimplemented(placeholder: placeholder()),
        validateImageData: IssueReporting.unimplemented(placeholder: placeholder()),
        resumeQueue: IssueReporting.unimplemented(placeholder: placeholder()),
        badges: IssueReporting.unimplemented(placeholder: placeholder()),
        fetchVersionMetadata: IssueReporting.unimplemented(placeholder: placeholder()),
        updateRemoteVersion: IssueReporting.unimplemented(placeholder: placeholder()),
        updateRemoteSignature: IssueReporting.unimplemented(placeholder: placeholder()),
        enqueue: IssueReporting.unimplemented(placeholder: placeholder()),
        togglePause: IssueReporting.unimplemented(placeholder: placeholder()),
        retry: IssueReporting.unimplemented(placeholder: placeholder()),
        retryPages: IssueReporting.unimplemented(placeholder: placeholder()),
        delete: IssueReporting.unimplemented(placeholder: placeholder()),
        loadManifest: IssueReporting.unimplemented(placeholder: placeholder()),
        loadLocalPageURLs: IssueReporting.unimplemented(placeholder: placeholder()),
        captureCachedPage: IssueReporting.unimplemented(placeholder: placeholder()),
        loadInspection: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
