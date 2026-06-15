//
//  DownloadImageParsingTests.swift
//  EhPandaTests
//

import CoreData
import Kingfisher
import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadImageParsingTests: DownloadFeatureTestCase {
    @Test
    func testFileBasedQuotaImageMapsToQuotaExceeded() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadCoordinator()
        let quotaImageURL = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let response = try makeResponse(
            url: quotaImageURL,
            contentType: "image/gif",
            contentLength: 28658
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: quotaImageURL
        )

        #expect(error == .quotaExceeded)
    }

    @Test
    func testFileBasedQuotaImageRequiresKnown509Signature() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadCoordinator()
        var data = try Data(contentsOf: fileURL)
        data[0] = 0
        try data.write(to: fileURL, options: .atomic)
        let quotaImageURL = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let response = try makeResponse(
            url: quotaImageURL,
            contentType: "image/gif",
            contentLength: data.count
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: quotaImageURL
        )

        #expect(error == nil)
    }

    @Test
    func testFileBasedBinaryKokomadeImageMapsToAuthenticationRequired() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("gif")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let imageData = try #require(Data(base64Encoded: "R0lGODlhAQABAIABAP///wAAACwAAAAAAQABAAACAkQBADs="))
        try imageData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadCoordinator()
        let kokomadeURL = try #require(URL(string: "https://exhentai.org/img/kokomade.jpg"))
        let response = try makeResponse(
            url: kokomadeURL,
            contentType: "image/gif",
            contentLength: imageData.count
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/fullimg.php?gid=1&page=1")
        )

        #expect(error == .authenticationRequired)
    }

    @Test
    func testFileBasedQuotaImageFingerprintMapsToQuotaExceededEvenWhenURLLooksNormal() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadCoordinator()
        let normalImageURL = try #require(URL(string: "https://ehgt.org/h/normal-image-cache-key/1"))
        let response = try makeResponse(
            url: normalImageURL,
            contentType: "image/gif",
            contentLength: 28658
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: normalImageURL
        )

        #expect(error == .quotaExceeded)
    }

    @Test
    func testFileBasedKokomadeImageFingerprintMapsToAuthenticationRequiredEvenWhenURLLooksNormal() async throws {
        let fileURL = try writeFixtureToTemporaryFile(resource: "Kokomade", pathExtension: "jpg")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadCoordinator()
        let normalImageURL = try #require(
            URL(string: "https://exhentai.org/fullimg.php?gid=1&page=1&key=normal-cache-key")
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: try makeResponse(
                url: normalImageURL,
                contentType: "image/jpeg",
                contentLength: 144844
            ),
            requestURL: normalImageURL
        )

        #expect(error == .authenticationRequired)
    }

    @Test
    func testFileBasedTextImageLimitMapsToQuotaExceeded() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let htmlData = Data("""
        <html><body>You have exceeded your image viewing limits</body></html>
        """.utf8)
        try htmlData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadCoordinator()
        let quotaURL = try #require(URL(string: "https://e-hentai.org/s/1/1-1"))
        let response = try makeResponse(
            url: quotaURL,
            contentType: "text/html"
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: quotaURL
        )

        #expect(error == .quotaExceeded)
    }

    @Test
    func testFatalAccountPageFailureStopsSchedulingRemainingPages() async throws {
        let sessionID = UUID().uuidString
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            SharedSessionStubURLProtocol.headerKey: sessionID
        ]
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )
        let recorder = RequestRecorder()
        let quotaHTML = Data("""
        <html><body>You have exceeded your image viewing limits</body></html>
        """.utf8)
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            recorder.recordImageDownload()
            return (
                try #require(HTTPURLResponse(
                    url: request.url ?? Defaults.URL.ehentai,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/html"]
                )),
                quotaHTML
            )
        }
        defer {
            SharedSessionStubURLProtocol.removeHandler(for: sessionID)
        }

        var gallery = sampleGallery()
        gallery.pageCount = 3
        var detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        detail.pageCount = 3
        var options = DownloadRequestOptions()
        options.threadLimit = 1
        options.autoRetryFailedPages = false
        let payload = DownloadRequestPayload(
            gallery: gallery,
            galleryDetail: detail,
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            folderName: "Folder",
            mode: .initial
        )
        let galleryFolderName = storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detail.trimmedTitle
        )
        let folderURL = storage.folderURL(
            relativePath: "Folder/\(galleryFolderName)"
        )
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        let manifest = try sampleManifest(
            gid: gallery.gid,
            title: gallery.title,
            pageCount: detail.pageCount
        )
        let batchResult = try await manager.downloadPages(
            context: .init(
                payload: payload,
                options: options,
                source: .normal([
                    1: try #require(URL(string: "https://example.com/1.html")),
                    2: try #require(URL(string: "https://example.com/2.html")),
                    3: try #require(URL(string: "https://example.com/3.html"))
                ]),
                folderURL: folderURL
            ),
            pendingPageIndices: [1, 2, 3],
            existingManifest: manifest,
            existingPageRelativePaths: [:]
        )

        #expect(batchResult.failedPages.map(\.index) == [1])
        #expect(batchResult.failedPages.first?.error == .quotaExceeded)
        #expect(recorder.snapshot().imageDownloads == 1)
    }

    @MainActor
    @Test
    func testCachedQuotaPlaceholderStoredUnderNormalImageURLIsRejected() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1_000_000) + 32)
        let manager = makeTestingDownloadCoordinator()
        let normalImageURL = try #require(
            URL(string: "https://ehgt.org/h/quota-placeholder-cache-\(gid)/1")
        )

        let placeholderURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: placeholderURL) }
        let placeholderData = try Data(contentsOf: placeholderURL)
        let cacheKeys = normalImageURL.imageCacheKeys(includeStableAlias: true)
        for cacheKey in cacheKeys {
            try await KingfisherManager.shared.cache.storeToDisk(placeholderData, forKey: cacheKey)
        }
        defer { cacheKeys.forEach { KingfisherManager.shared.cache.removeImage(forKey: $0) } }
        await waitUntilCacheReady(for: cacheKeys)

        let cachedData = await manager.validatedCachedAssetData(
            for: [normalImageURL]
        )

        #expect(cachedData == nil)
    }

    @Test
    func testMPVImageResolutionFailsOverWithSkipServerTokenOnRetry() async throws {
        let sessionID = UUID().uuidString
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            SharedSessionStubURLProtocol.headerKey: sessionID
        ]
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )

        let receivedSkipServerTokens = UncheckedBox([String?]())
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            let body = requestBodyData(from: request)
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let skipServer = body?["nl"] as? String
            receivedSkipServerTokens.value.append(skipServer)
            let imageURL = skipServer == nil
                ? "https://example.com/server-a.jpg"
                : "https://example.com/server-b.jpg"
            let data = try JSONSerialization.data(withJSONObject: ["i": imageURL, "s": "42"])
            return (
                try #require(HTTPURLResponse(
                    url: request.url ?? Defaults.URL.api,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )),
                data
            )
        }
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let payload = DownloadRequestPayload(
            gallery: sampleGallery(),
            galleryDetail: sampleGalleryDetail(gid: "123456", title: "Sample Gallery"),
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            folderName: "Folder",
            mode: .initial
        )
        let source = DownloadCoordinator.ResolvedSource.mpv("mpvkey", [1: "imgkey1"])

        let first = try await manager.resolvedImageSource(
            index: 1, payload: payload, options: .init(), source: source, failover: nil
        )
        let second = try await manager.resolvedImageSource(
            index: 1, payload: payload, options: .init(), source: source, failover: first
        )

        #expect(receivedSkipServerTokens.value == [nil, "42"])
        #expect(first.imageURL.absoluteString == "https://example.com/server-a.jpg")
        #expect(first.mpvSkipServerIdentifier == "42")
        #expect(second.imageURL.absoluteString == "https://example.com/server-b.jpg")
    }

}
