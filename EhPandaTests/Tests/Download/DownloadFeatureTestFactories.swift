//
//  DownloadFeatureTestFactories.swift
//  EhPandaTests
//

import CoreData
import Foundation
import Testing
@testable import EhPanda

// MARK: - Sample Data Factories & CoreData Helpers

extension DownloadFeatureTestCase {
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
                    relativePath: "pages/0001.jpg",
                    fileURL: URL(fileURLWithPath: "/tmp/0001.jpg"),
                    failure: nil
                ),
                .init(
                    index: 2,
                    status: .failed,
                    relativePath: "pages/0002.jpg",
                    fileURL: nil,
                    failure: .init(code: .networkingFailed, message: "Network Error")
                )
            ]
        )
    }

    func sampleDownload(
        gid: String,
        title: String,
        status: DownloadStatus,
        category: EhPanda.Category = .doujinshi,
        pageCount: Int = 12,
        completedPageCount: Int? = nil,
        lastDownloadedAt: Date? = .now,
        lastError: DownloadFailure? = nil
    ) -> DownloadedGallery {
        DownloadedGallery(
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
            folderRelativePath: "\(gid) - \(title)",
            coverRelativePath: "cover.jpg",
            status: status,
            completedPageCount: completedPageCount ?? (status == .completed ? pageCount : 0),
            lastDownloadedAt: lastDownloadedAt,
            lastError: lastError,
            downloadOptionsSnapshot: DownloadOptionsSnapshot()
        )
    }

    func prepareLocalDownloadFiles(
        download: DownloadedGallery,
        manifest: DownloadManifest
    ) throws -> URL {
        let folderURL = download.folderURL
        try? FileManager.default.removeItem(at: folderURL)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(
                Defaults.FilePath.downloadPages, isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(manifest).write(
            to: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent("pages/0002.jpg"),
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
    func makeStubbedDownloadManager(
        rootURL: URL,
        sessionID: String
    ) -> (DownloadFileStorage, DownloadManager) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            SharedSessionStubURLProtocol.headerKey: sessionID
        ]
        let storage = DownloadFileStorage(
            rootURL: rootURL, fileManager: .default
        )
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
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
