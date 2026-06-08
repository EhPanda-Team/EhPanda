//
//  DownloadProcessCacheTests.swift
//  EhPandaTests
//

import CoreData
import Kingfisher
import SDWebImage
import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadProcessCacheTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testProcessDownloadClearsRemoteAssetCacheAfterSuccessfulDownload() async throws {
        let container = try makeInMemoryContainer()
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 402)
        let pageIndex = 42
        let oldVersionSignature = chainVersionSignature(gid: gid, token: "token")
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let cacheTestManager = try makeCacheTestManager(
            rootURL: rootURL, sessionID: sessionID, gid: gid, pageIndex: pageIndex,
            persistenceContainer: container
        )
        let storage = cacheTestManager.storage
        let manager = cacheTestManager.manager
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let (cachedKeys, _) = try await prepareCacheTestAssets(
            manager: manager, gid: gid,
            pageIndex: pageIndex, oldVersionSignature: oldVersionSignature
        )
        defer {
            cachedKeys.forEach {
                KingfisherManager.shared.cache.removeImage(forKey: $0)
                SDImageCache.shared.removeImage(forKey: $0) {}
            }
        }

        await waitUntilCacheReady(for: cachedKeys)

        let updatedPageCount = try await setupCacheTestDownload(
            .init(
                container: container,
                storage: storage,
                manager: manager,
                gid: gid,
                pageIndex: pageIndex,
                oldVersionSignature: oldVersionSignature
            )
        )

        await manager.testingProcessDownload(gid: gid)

        let completedDownload = await manager.testingFetchDownload(gid: gid)
        #expect(completedDownload?.status == .completed)

        try await waitUntilCacheCleared(cachedKeys: cachedKeys)

        for cacheKey in cachedKeys {
            #expect(
                LibraryClient.live.isCached(cacheKey) == false,
                "Expected cache key to be removed after successful download: \(cacheKey)"
            )
        }
        _ = updatedPageCount
    }

}

// MARK: - Cache Test Manager Result

struct CacheTestManagerResult {
    let storage: DownloadFileStorage
    let manager: DownloadManager
    let metadataResponse: Data
}

private struct CacheTestDownloadSetup {
    let container: NSPersistentContainer
    let storage: DownloadFileStorage
    let manager: DownloadManager
    let gid: String
    let pageIndex: Int
    let oldVersionSignature: String
}

// MARK: - Cache Test Helpers

private extension DownloadProcessCacheTests {
    func makeCacheTestManager(
        rootURL: URL, sessionID: String, gid: String, pageIndex: Int,
        persistenceContainer: NSPersistentContainer = PersistenceController.shared.container
    ) throws -> CacheTestManagerResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [SharedSessionStubURLProtocol.headerKey: sessionID]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration),
            persistenceContainer: persistenceContainer
        )
        let content = StubHandlerContent(
            detailHTML: try makeUniqueDetailHTML(gid: gid),
            mpvHTML: try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html"),
            metadataResponse: try makeMetadataResponseData(gid: gid)
        )
        installCacheTestStubHandler(
            sessionID: sessionID, gid: gid, pageIndex: pageIndex,
            content: content, allowedImageURLs: []
        )
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
        return CacheTestManagerResult(storage: storage, manager: manager, metadataResponse: content.metadataResponse)
    }

    func installCacheTestStubHandler(
        sessionID: String, gid: String, pageIndex: Int,
        content: StubHandlerContent,
        allowedImageURLs: Set<String>
    ) {
        let detailHTML = content.detailHTML
        let mpvHTML = content.mpvHTML
        let metadataResponse = content.metadataResponse
        let currentPageImageURL = Self.currentPageImageURL(gid: gid, pageIndex: pageIndex)
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            guard let url = request.url else { throw URLError(.badURL) }
            if url.path.contains("/g/\(gid)/token") {
                return (try Self.makeCacheHTMLResponse(url: url), detailHTML)
            }
            if url.path.contains("/mpv/") {
                return (try Self.makeCacheHTMLResponse(url: url), mpvHTML)
            }
            if url.path == "/api.php" {
                return try Self.makeCacheAPIResponse(
                    url: url, request: request,
                    metadataResponse: metadataResponse,
                    imageURLString: currentPageImageURL?.absoluteString ?? ""
                )
            }
            if url.host == "example.com" || allowedImageURLs.contains(url.absoluteString) {
                return (try Self.makeCacheImageResponse(url: url), Data([0xFF, 0xD8, 0xFF, 0xD9]))
            }
            throw URLError(.unsupportedURL)
        }
    }

    func makeUniqueDetailHTML(gid: String) throws -> Data {
        let fixtureCoverURL =
            "https://ehgt.org/03/08/0308268821e99628b05a19fa54e2fc0fa9ad8f4b-1705560-1012-1470-png_250.jpg"
        let uniqueCoverURL = "https://example.com/download-cache/\(gid)/cover.jpg"
        let fixtureHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        let detailHTML = try #require(String(bytes: fixtureHTML, encoding: .utf8))
            .replacingOccurrences(of: fixtureCoverURL, with: uniqueCoverURL)
        return Data(detailHTML.utf8)
    }

    static func currentPageImageURL(gid: String, pageIndex: Int) -> URL? {
        URL(string: "https://example.com/download-cache/\(gid)/image-\(pageIndex).jpg")
    }

    static func makeCacheHTMLResponse(url: URL) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "text/html; charset=utf-8"]
        ))
    }

    static func makeCacheImageResponse(url: URL) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "image/jpeg"]
        ))
    }

    static func makeCacheJSONResponse(url: URL) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
    }

    static func makeCacheAPIResponse(
        url: URL, request: URLRequest,
        metadataResponse: Data, imageURLString: String
    ) throws -> (HTTPURLResponse, Data) {
        let body = requestBodyData(from: request)
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        if body?["method"] as? String == "gdata" {
            return (try makeCacheJSONResponse(url: url), metadataResponse)
        }
        let responseData = try JSONSerialization.data(withJSONObject: ["i": imageURLString])
        return (try makeCacheJSONResponse(url: url), responseData)
    }

    @MainActor
    func prepareCacheTestAssets(
        manager: DownloadManager, gid: String,
        pageIndex: Int, oldVersionSignature: String
    ) async throws -> (Set<String>, URL) {
        let currentPageImageURL = try #require(
            Self.currentPageImageURL(gid: gid, pageIndex: pageIndex)
        )
        let scaffoldDownload = sampleDownload(
            gid: gid, title: "Pause Race", status: .partial,
            pageCount: 156, completedPageCount: 155,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: oldVersionSignature
        )
        let latestPayload = try await manager.testingFetchLatestPayload(
            for: scaffoldDownload, mode: .redownload, pageSelection: [pageIndex]
        ).payload
        let coverURL = try #require(
            latestPayload.galleryDetail.coverURL ?? latestPayload.gallery.coverURL
        )
        let previewCleanupURLs = latestPayload.previewURLs.values
            .flatMap { $0.previewCacheCleanupURLs() }

        let cachedImage = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let cachedImageData = try #require(cachedImage.jpegData(compressionQuality: 1))
        let cachedURLs = previewCleanupURLs
            + [currentPageImageURL, coverURL]
        let cachedKeys = Set(cachedURLs.flatMap { $0.imageCacheKeys(includeStableAlias: true) })
        for cacheKey in cachedKeys {
            try await KingfisherManager.shared.cache.storeToDisk(cachedImageData, forKey: cacheKey)
            await storeSDWebImageData(cachedImageData, forKey: cacheKey)
        }
        return (cachedKeys, coverURL)
    }

    func setupCacheTestDownload(_ setup: CacheTestDownloadSetup) async throws -> Int {
        let scaffoldDownload = sampleDownload(
            gid: setup.gid, title: "Pause Race", status: .partial,
            pageCount: 156, completedPageCount: 155,
            remoteVersionSignature: setup.oldVersionSignature,
            latestRemoteVersionSignature: setup.oldVersionSignature
        )
        let latestPayload = try await setup.manager.testingFetchLatestPayload(
            for: scaffoldDownload, mode: .redownload,
            pageSelection: [setup.pageIndex]
        ).payload
        let updatedPageCount = latestPayload.galleryDetail.pageCount
        let oldPageCount = updatedPageCount - 5
        #expect(updatedPageCount > setup.pageIndex)
        #expect(oldPageCount > 0)

        try await MainActor.run {
            try insertPersistedDownload(
                in: setup.container, gid: setup.gid, status: .partial,
                completedPageCount: oldPageCount - 1, pageCount: oldPageCount,
                remoteVersionSignature: setup.oldVersionSignature,
                latestRemoteVersionSignature: setup.oldVersionSignature
            )
        }
        try setupCacheTestTemporaryFolder(
            storage: setup.storage, gid: setup.gid,
            pageIndex: setup.pageIndex, oldPageCount: oldPageCount,
            oldVersionSignature: setup.oldVersionSignature
        )
        return updatedPageCount
    }

    func setupCacheTestTemporaryFolder(
        storage: DownloadFileStorage, gid: String,
        pageIndex: Int, oldPageCount: Int, oldVersionSignature: String
    ) throws {
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(
                Defaults.FilePath.downloadPages, isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        let staleManifest = try sampleManifest(
            gid: gid, title: "Pause Race",
            pageCount: oldPageCount, versionSignature: oldVersionSignature
        )
        try JSONEncoder().encode(staleManifest).write(
            to: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: temporaryFolderURL.appendingPathComponent("cover.jpg"), options: .atomic
        )
        try Data([UInt8(pageIndex % 255)]).write(
            to: temporaryFolderURL.appendingPathComponent(
                "pages/\(String(format: "%04d", pageIndex)).jpg"
            ),
            options: .atomic
        )
        try storage.writeResumeState(
            .init(
                mode: .redownload, versionSignature: oldVersionSignature,
                pageCount: oldPageCount, downloadOptions: .init(), pageSelection: [pageIndex]
            ),
            folderURL: temporaryFolderURL
        )
    }

    func waitUntilCacheCleared(cachedKeys: Set<String>) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while cachedKeys.contains(where: LibraryClient.live.isCached),
              clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func storeSDWebImageData(_ data: Data, forKey key: String) async {
        await withCheckedContinuation { continuation in
            SDImageCache.shared.storeImageData(data, forKey: key) {
                continuation.resume()
            }
        }
    }
}
