//
//  DownloadFeatureTestFactories.swift
//  EhPandaTests
//

import CoreData
import Foundation
import Testing
@testable import EhPanda

// MARK: - Sample Data Factories & CoreData Helpers

enum DownloadFixtureStatus {
    case queued
    case downloading
    case paused
    case partial
    case completed
    case failed
    case updateAvailable
    case missingFiles

    var displayStatus: DownloadDisplayStatus {
        switch self {
        case .queued:
            return .queued
        case .downloading:
            return .active
        case .paused:
            return .inactive
        case .partial:
            return .error
        case .completed:
            return .completed
        case .failed, .missingFiles:
            return .error
        case .updateAvailable:
            return .updateAvailable
        }
    }

    var defaultLastError: DownloadFailure? {
        switch self {
        case .failed:
            return .init(code: .networkingFailed, message: "Network Error")
        case .missingFiles:
            return .init(code: .fileOperationFailed, message: "Page 2 is missing.")
        case .queued, .downloading, .paused, .partial, .completed, .updateAvailable:
            return nil
        }
    }

    func defaultCompletedPageCount(pageCount: Int) -> Int {
        switch self {
        case .completed, .updateAvailable:
            return pageCount
        case .queued, .downloading, .paused, .partial, .failed, .missingFiles:
            return 0
        }
    }
}

extension DownloadedGallery {
    init(
        gid: String,
        host: GalleryHost,
        token: String,
        title: String,
        jpnTitle: String?,
        uploader: String?,
        category: EhPanda.Category,
        tags: [GalleryTag],
        pageCount: Int,
        postedDate: Date,
        rating: Float,
        onlineCoverURL: URL?,
        folderURL: URL,
        folderName: String = "Folder",
        localCoverURL: URL? = nil,
        localPageURLs: [Int: URL] = [:],
        displayStatus: DownloadDisplayStatus,
        completedPageCount: Int,
        lastDownloadedDate: Date?,
        lastError: DownloadFailure?
    ) {
        let clampedCompletedPageCount = min(max(completedPageCount, 0), pageCount)
        let manifest = DownloadManifest(
            gid: gid,
            host: host,
            token: token,
            title: title,
            jpnTitle: jpnTitle,
            category: category,
            language: .japanese,
            remoteCoverURL: onlineCoverURL,
            uploader: uploader,
            tags: tags,
            postedDate: postedDate,
            rating: rating,
            pages: pageCount > 0
                ? Dictionary(
                    uniqueKeysWithValues: (1...pageCount).map {
                        ($0, $0 <= clampedCompletedPageCount ? "sha256:fixture-\($0)" : "")
                    }
                )
                : [:]
        )
        self.init(
            manifest: manifest,
            folderURL: folderURL,
            folderName: folderName,
            localCoverURL: localCoverURL,
            localPageURLs: localPageURLs,
            modificationDate: lastDownloadedDate,
            displayStatus: displayStatus,
            lastError: lastError
        )
    }
}

extension DownloadFeatureTestCase {
    func appLaunchAutomationClient(
        _ automation: AppLaunchAutomation?
    ) -> AppLaunchAutomationClient {
        .init(current: { automation })
    }

    func appLaunchAutomationClient(
        autoDownloadGID: String
    ) -> AppLaunchAutomationClient {
        appLaunchAutomationClient(
            AppLaunchAutomation(
                initialTab: nil,
                autoDownloadGID: autoDownloadGID,
                downloadFolderName: nil,
                loginCookies: nil,
                galleryURL: nil
            )
        )
    }

    func sampleManifest(
        gid: String,
        title: String,
        pageCount: Int = 2
    ) throws -> DownloadManifest {
        DownloadManifest(
            gid: gid,
            host: .ehentai,
            token: "token",
            title: title,
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
            uploader: "Uploader",
            tags: [],
            postedDate: .now,
            rating: 4,
            pages: pageCount > 0
                ? Dictionary(uniqueKeysWithValues: (1...pageCount).map { ($0, "") })
                : [:]
        )
    }

    func sampleInspection(
        download: DownloadedGallery
    ) -> DownloadInspection {
        .init(
            download: download,
            coverURL: download.coverURL,
            pages: [
                .init(
                    index: 1,
                    status: .downloaded,
                    relativePath: "\(download.gid)_\(download.token)_1.jpg",
                    fileURL: URL(fileURLWithPath: "/tmp/0001.jpg"),
                    failure: nil
                ),
                .init(
                    index: 2,
                    status: .failed,
                    relativePath: "\(download.gid)_\(download.token)_2.jpg",
                    fileURL: nil,
                    failure: .init(code: .networkingFailed, message: "Network Error")
                )
            ]
        )
    }

    func sampleDownload(
        gid: String,
        title: String,
        status: DownloadFixtureStatus,
        category: EhPanda.Category = .doujinshi,
        pageCount: Int = 12,
        completedPageCount: Int? = nil,
        lastDownloadedDate: Date? = .now,
        lastError: DownloadFailure? = nil,
        folderURL: URL? = nil,
        folderName: String = "Folder",
        localCoverURL: URL? = nil,
        localPageURLs: [Int: URL] = [:]
    ) -> DownloadedGallery {
        let resolvedFolderURL = folderURL ?? FileUtil.downloadsDirectoryURL
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("[\(gid)_token] \(title)", isDirectory: true)
        return DownloadedGallery(
            gid: gid,
            host: .ehentai,
            token: "token",
            title: title,
            jpnTitle: nil,
            uploader: "Uploader",
            category: category,
            tags: [],
            pageCount: pageCount,
            postedDate: .now,
            rating: 4,
            onlineCoverURL: URL(string: "https://example.com/cover.jpg"),
            folderURL: resolvedFolderURL,
            folderName: folderName,
            localCoverURL: localCoverURL,
            localPageURLs: localPageURLs,
            displayStatus: status.displayStatus,
            completedPageCount: completedPageCount
                ?? status.defaultCompletedPageCount(pageCount: pageCount),
            lastDownloadedDate: lastDownloadedDate,
            lastError: lastError ?? status.defaultLastError
        )
    }

    func prepareLocalDownloadFiles(
        download: DownloadedGallery,
        manifest: DownloadManifest
    ) throws -> URL {
        let folderURL = download.folderURL
        try? FileManager.default.removeItem(at: folderURL)
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(manifest).write(
            to: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent(
                "\(manifest.gid)_\(manifest.token)_1.jpg"
            ),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent(
                "\(manifest.gid)_\(manifest.token)_2.jpg"
            ),
            options: .atomic
        )
        return folderURL
    }

    func makeInMemoryContainer() throws -> NSPersistentContainer {
        let container = NSPersistentContainer(
            name: UUID().uuidString,
            managedObjectModel: PersistenceController.shared.container.managedObjectModel
        )
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        let waitResult = semaphore.wait(timeout: .now() + 5)
        if waitResult == .timedOut {
            Issue.record("Timed out loading in-memory persistent store.")
        }
        if let loadError {
            Issue.record(
                "Failed to load in-memory persistent store: \(loadError)"
            )
        }
        return container
    }

    func insertPersistedGalleryState(
        in container: NSPersistentContainer,
        gid: String,
        previewURLs: [Int: URL] = [:],
        imageURLs: [Int: URL],
        originalImageURLs: [Int: URL] = [:]
    ) throws {
        let context = container.viewContext
        try performAndWait(in: context) {
            let object = GalleryStateMO(context: context)
            object.gid = gid
            object.previewURLs = previewURLs.toData()
            object.imageURLs = imageURLs.toData()
            object.originalImageURLs = originalImageURLs.toData()
            try context.save()
        }
    }

    private func performAndWait(
        in context: NSManagedObjectContext,
        operation: @Sendable () throws -> Void
    ) throws {
        try context.performAndWait(operation)
    }
}

// MARK: - Stub Handler Content

struct StubHandlerContent: Sendable {
    let detailHTML: Data
    let mpvHTML: Data
    let metadataResponse: Data
}

// MARK: - Stub Route Context

struct StubRouteContext: Sendable {
    let gid: String
    let pageIndex: Int
    let content: StubHandlerContent
    let recorder: RequestRecorder?
}

// MARK: - Stub Manager & Handler Helpers

extension DownloadFeatureTestCase {
    func makeStubbedDownloadCoordinator(
        rootURL: URL,
        sessionID: String,
        downloadOptionsProvider: @escaping @Sendable () async -> DownloadRequestOptions = {
            DownloadRequestOptions()
        },
        taskRunner: DownloadTaskRunner = .init()
    ) -> (DownloadStore, DownloadCoordinator) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            SharedSessionStubURLProtocol.headerKey: sessionID
        ]
        let storage = DownloadStore(
            rootURL: rootURL, fileManager: .default
        )
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: URLSession(configuration: configuration),
            downloadOptionsProvider: downloadOptionsProvider,
            taskRunner: taskRunner
        )
        return (storage, manager)
    }

    func makeMetadataResponseData(
        gid: String,
        token: String = "token"
    ) throws -> Data {
        let gidInt = try #require(Int(gid))
        return try JSONSerialization.data(withJSONObject: [
            "gmetadata": [[
                "gid": gidInt, "token": token,
                "current_gid": gidInt, "current_key": "updated-key",
                "parent_gid": gidInt, "parent_key": token,
                "first_gid": gidInt, "first_key": token
            ]]
        ])
    }

    func installDownloadStubHandler(
        sessionID: String, gid: String, pageIndex: Int,
        content: StubHandlerContent,
        recorder: RequestRecorder? = nil,
        allowedImageURLs: Set<String> = []
    ) {
        let context = StubRouteContext(
            gid: gid, pageIndex: pageIndex, content: content, recorder: recorder
        )
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            guard let url = request.url else { throw URLError(.badURL) }
            if url.host == "example.com" || allowedImageURLs.contains(url.absoluteString) {
                recorder?.recordImageDownload()
                return (
                    try DownloadFeatureTestStubRouter.stubResponse(
                        url: url,
                        contentType: "image/jpeg"
                    ),
                    Data([0xFF, 0xD8, 0xFF, 0xD9])
                )
            }
            return try DownloadFeatureTestStubRouter.routeStubRequest(
                url: url,
                request: request,
                context: context
            )
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
    }
}

private enum DownloadFeatureTestStubRouter {
    static func routeStubRequest(
        url: URL, request: URLRequest,
        context: StubRouteContext
    ) throws -> (HTTPURLResponse, Data) {
        let gid = context.gid
        let pageIndex = context.pageIndex
        let detailHTML = context.content.detailHTML
        let mpvHTML = context.content.mpvHTML
        let metadataResponse = context.content.metadataResponse
        let recorder = context.recorder
        if url.host == "api.e-hentai.org" {
            recorder?.recordMetadata()
            return (try stubResponse(url: url, contentType: "application/json"), metadataResponse)
        }
        if url.path.contains("/g/\(gid)/token") {
            let pageNum = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "p" }?.value.flatMap(Int.init)
            if let pageNum { recorder?.recordPreview(pageNum) } else { recorder?.recordDetail() }
            return (try stubResponse(url: url, contentType: "text/html; charset=utf-8"), detailHTML)
        }
        if url.path.contains("/mpv/") {
            recorder?.recordMPV()
            return (try stubResponse(url: url, contentType: "text/html; charset=utf-8"), mpvHTML)
        }
        if url.path == "/api.php" {
            let body = requestBodyData(from: request)
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            if body?["method"] as? String == "gdata" {
                recorder?.recordMetadata()
                return (try stubResponse(url: url, contentType: "application/json"), metadataResponse)
            }
            recorder?.recordImageDispatch()
            let data = try JSONSerialization.data(withJSONObject: [
                "i": "https://example.com/image-\(pageIndex).jpg"
            ])
            return (try stubResponse(url: url, contentType: "application/json"), data)
        }
        throw URLError(.unsupportedURL)
    }

    static func stubResponse(
        url: URL, contentType: String
    ) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": contentType]
        ))
    }
}
