//
//  DownloadProcessCacheTests.swift
//  EhPandaTests
//

import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadProcessCacheTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testProcessDownloadClearsRemoteAssetCacheAfterSuccessfulDownload() async throws {
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 402)
        let pageIndex = 42
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cachedKeysBox = UncheckedBox(Set<String>())
        let libraryClient = try makeCacheLibraryClient(
            cachedKeys: cachedKeysBox
        )

        let cacheTestManager = try makeCacheTestManager(
            rootURL: rootURL,
            sessionID: sessionID,
            gid: gid,
            pageIndex: pageIndex,
            libraryClient: libraryClient
        )
        let storage = cacheTestManager.storage
        let manager = cacheTestManager.manager
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let cachedKeys = try await prepareCacheTestAssets(
            manager: manager, gid: gid,
            pageIndex: pageIndex,
            cachedKeysBox: cachedKeysBox
        )

        #expect(cachedKeys.allSatisfy(libraryClient.isCached))

        let updatedPageCount = try await setupCacheTestDownload(
            .init(
                storage: storage,
                manager: manager,
                gid: gid,
                pageIndex: pageIndex
            )
        )
        await manager.reloadDownloadIndex()

        await manager.processDownload(gid: gid)

        let completedDownload = await manager.fetchDownload(gid: gid)
        #expect(completedDownload?.displayStatus == .completed)

        try await waitUntilCacheCleared(
            cachedKeys: cachedKeys,
            isCached: libraryClient.isCached
        )

        for cacheKey in cachedKeys {
            #expect(
                libraryClient.isCached(cacheKey) == false,
                "Expected cache key to be removed after successful download: \(cacheKey)"
            )
        }
        _ = updatedPageCount
    }

}

// MARK: - Cache Test Manager Result

struct CacheTestManagerResult {
    let storage: DownloadStore
    let manager: DownloadCoordinator
    let metadataResponse: Data
}

private struct CacheTestDownloadSetup {
    let storage: DownloadStore
    let manager: DownloadCoordinator
    let gid: String
    let pageIndex: Int
}

// MARK: - Cache Test Helpers

private extension DownloadProcessCacheTests {
    func makeCacheTestManager(
        rootURL: URL,
        sessionID: String,
        gid: String,
        pageIndex: Int,
        libraryClient: LibraryClient
    ) throws -> CacheTestManagerResult {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [SharedSessionStubURLProtocol.headerKey: sessionID]
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: URLSession(configuration: configuration),
            libraryClient: libraryClient
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
        manager: DownloadCoordinator, gid: String,
        pageIndex: Int,
        cachedKeysBox: UncheckedBox<Set<String>>
    ) async throws -> Set<String> {
        let currentPageImageURL = try #require(
            Self.currentPageImageURL(gid: gid, pageIndex: pageIndex)
        )
        let scaffoldDownload = sampleDownload(
            gid: gid, title: "Pause Race", status: .partial,
            pageCount: 156, completedPageCount: 155
        )
        let latestPayload = try await manager.fetchLatestPayload(
            for: scaffoldDownload, mode: .redownload, options: .init(), pageSelection: [pageIndex]
        )
        let coverURL = try #require(
            latestPayload.galleryDetail.coverURL ?? latestPayload.gallery.coverURL
        )
        let cachedURLs = [currentPageImageURL, coverURL]
        let cachedKeys = Set(cachedURLs.flatMap { $0.imageCacheKeys(includeStableAlias: true) })
        cachedKeysBox.value = cachedKeys
        return cachedKeys
    }

    func setupCacheTestDownload(_ setup: CacheTestDownloadSetup) async throws -> Int {
        let scaffoldDownload = sampleDownload(
            gid: setup.gid, title: "Pause Race", status: .partial,
            pageCount: 156, completedPageCount: 155
        )
        let latestPayload = try await setup.manager.fetchLatestPayload(
            for: scaffoldDownload, mode: .redownload,
            options: .init(), pageSelection: [setup.pageIndex]
        )
        let updatedPageCount = latestPayload.galleryDetail.pageCount
        #expect(updatedPageCount > setup.pageIndex)

        try setupCacheTestFinalFolder(
            storage: setup.storage, gid: setup.gid,
            pageCount: updatedPageCount,
            missingPageIndex: setup.pageIndex
        )
        return updatedPageCount
    }

    func setupCacheTestFinalFolder(
        storage: DownloadStore, gid: String,
        pageCount: Int,
        missingPageIndex: Int
    ) throws {
        let completedFolderURL = storage.folderURL(relativePath: "Folder/\(gid) - Pause Race")
        try FileManager.default.createDirectory(
            at: completedFolderURL,
            withIntermediateDirectories: true
        )
        let staleManifest = try sampleManifest(
            gid: gid, title: "Pause Race",
            pageCount: pageCount
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("\(gid)_token_cover.jpg"),
            options: .atomic
        )
        for index in staleManifest.pages.keys where index != missingPageIndex {
            try Data([UInt8(index % 255)]).write(
                to: completedFolderURL.appendingPathComponent("\(gid)_token_\(index).jpg"),
                options: .atomic
            )
        }
        try storage.writeManifest(staleManifest, folderURL: completedFolderURL)
    }

    func waitUntilCacheCleared(
        cachedKeys: Set<String>,
        isCached: @Sendable (String) -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while cachedKeys.contains(where: isCached),
              clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @MainActor
    func makeCacheLibraryClient(
        cachedKeys: UncheckedBox<Set<String>>
    ) throws -> LibraryClient {
        let cachedImage = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let cachedImageData = try #require(cachedImage.jpegData(compressionQuality: 1))
        return .init(
            initializeLogger: {},
            initializeWebImage: {},
            removeAllCachedImages: {
                cachedKeys.value = []
            },
            cachedImage: { _ in nil },
            cachedImageData: { key in
                cachedKeys.value.contains(key) ? cachedImageData : nil
            },
            removeCachedImage: { key in
                var keys = cachedKeys.value
                keys.remove(key)
                cachedKeys.value = keys
            },
            isCached: { key in
                cachedKeys.value.contains(key)
            },
            analyzeImageColors: { _ in nil },
            calculateWebImageDiskCacheSize: { 0 }
        )
    }
}
