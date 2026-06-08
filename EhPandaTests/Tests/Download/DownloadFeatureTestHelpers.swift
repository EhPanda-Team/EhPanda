//
//  DownloadFeatureTestHelpers.swift
//  EhPandaTests
//

import Foundation
import CoreData
import ComposableArchitecture
import Kingfisher
import UIKit
import Testing
@testable import EhPanda

// MARK: - Shared Test Helper Protocol

protocol DownloadFeatureTestCase: TestHelper {
    func waitUntilCacheReady<Keys: Sequence>(
        for keys: Keys,
        timeout: Duration
    ) async where Keys.Element == String

    func waitForTaskValue<T>(
        _ task: Task<T, Never>,
        timeout: Duration,
        description: String
    ) async throws -> T

    func sampleGalleryState(gid: String) throws -> GalleryState
    func sampleVersionMetadata(gid: String, token: String) -> DownloadVersionMetadata
    func makeTestingDownloadManager() -> DownloadManager
    func makeResponse(
        url: URL,
        statusCode: Int,
        contentType: String,
        contentLength: Int?,
        headers: [String: String]
    ) throws -> HTTPURLResponse
    func writeFixtureToTemporaryFile(filename: HTMLFilename) throws -> URL
    func writeFixtureToTemporaryFile(resource: String, pathExtension: String) throws -> URL
    func fixtureData(resource: String, pathExtension: String) throws -> Data
    func installGalleryVersionMetadataStub(for gallery: Gallery, sessionID: String) throws
    func uninstallSharedSessionStub(sessionID: String)
    func sampleGallery() -> Gallery
    func sampleGalleryDetail(gid: String, title: String) -> GalleryDetail
    func sampleManifest(
        gid: String,
        title: String,
        pageCount: Int,
        versionSignature: String
    ) throws -> DownloadManifest
    func sampleInspection(download: DownloadedGallery) -> DownloadInspection
    func prepareLocalDownloadFiles(
        download: DownloadedGallery,
        manifest: DownloadManifest
    ) throws -> URL
    func makeInMemoryContainer() throws -> NSPersistentContainer
    func clearPersistedDownloads(in container: NSPersistentContainer) throws
    func insertPersistedGalleryState(
        in container: NSPersistentContainer,
        gid: String,
        previewURLs: [Int: URL],
        imageURLs: [Int: URL],
        originalImageURLs: [Int: URL]
    ) throws
}

// MARK: - Default Implementations

extension DownloadFeatureTestCase {
    func chainVersionSignature(gid: String, token: String) -> String {
        "chain:\(gid):\(token)"
    }

    func waitUntilCacheReady<Keys: Sequence>(
        for keys: Keys,
        timeout: Duration = .seconds(1)
    ) async where Keys.Element == String {
        let cacheKeys = Array(keys)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !cacheKeys.allSatisfy(LibraryClient.live.isCached),
              clock.now < deadline {
            try? await clock.sleep(until: clock.now.advanced(by: .milliseconds(10)), tolerance: .zero)
        }

        let missingKeys = cacheKeys.filter { !LibraryClient.live.isCached($0) }
        #expect(
            missingKeys.isEmpty,
            "Timed out waiting for cache visibility for keys: \(missingKeys)"
        )
    }

    func waitForTaskValue<T>(
        _ task: Task<T, Never>,
        timeout: Duration = .seconds(1),
        description: String
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                await task.value
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                task.cancel()
                throw NSError(
                    domain: "DownloadFeatureReducerTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(description)"]
                )
            }

            let value = try await group.next()
            group.cancelAll()
            return try #require(value, "Expected one task group result for \(description).")
        }
    }

    @MainActor
    func drainDetailMetadataEffects(
        _ store: TestStoreOf<DetailReducer>,
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() && clock.now < deadline {
            await store.skipReceivedActions(strict: false)
            try? await Task.sleep(for: .milliseconds(10))
        }
        await store.skipReceivedActions(strict: false)
    }

    func sampleGalleryState(gid: String) throws -> GalleryState {
        var galleryState = GalleryState(gid: gid)
        galleryState.previewURLs = [1: try #require(URL(string: "https://example.com/1t.jpg"))]
        galleryState.previewConfig = .normal(rows: 4)
        return galleryState
    }

    func sampleVersionMetadata(
        gid: String,
        token: String
    ) -> DownloadVersionMetadata {
        DownloadVersionMetadata(
            gid: gid,
            token: token,
            currentGID: gid,
            currentKey: "updated-key",
            parentGID: gid,
            parentKey: token,
            firstGID: gid,
            firstKey: token
        )
    }

    func makeTestingDownloadManager() -> DownloadManager {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared,
            persistenceContainer: PersistenceController.shared.container
        )
    }

    func makeResponse(
        url: URL,
        statusCode: Int = 200,
        contentType: String,
        contentLength: Int? = nil,
        headers: [String: String] = [:]
    ) throws -> HTTPURLResponse {
        var headerFields = headers
        headerFields["Content-Type"] = contentType
        if let contentLength {
            headerFields["Content-Length"] = "\(contentLength)"
        }
        return try #require(HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        ))
    }

    func writeFixtureToTemporaryFile(
        filename: HTMLFilename
    ) throws -> URL {
        try writeFixtureToTemporaryFile(resource: filename.rawValue, pathExtension: "html")
    }

    func writeFixtureToTemporaryFile(
        resource: String,
        pathExtension: String
    ) throws -> URL {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try fixtureData(resource: resource, pathExtension: pathExtension)
            .write(to: temporaryURL, options: .atomic)
        return temporaryURL
    }

    func fixtureData(
        resource: String,
        pathExtension: String
    ) throws -> Data {
        let fixtureURL = try #require(
            Bundle(for: TestBundleLocator.self).url(forResource: resource, withExtension: pathExtension)
        )
        return try Data(contentsOf: fixtureURL)
    }

    func installGalleryVersionMetadataStub(
        for gallery: Gallery,
        sessionID: String
    ) throws {
        let gid = try #require(Int(gallery.gid))
        let payload: [String: Any] = [
            "gmetadata": [[
                "gid": gid,
                "token": gallery.token,
                "current_gid": gid,
                "current_key": "updated-key",
                "parent_gid": gid,
                "parent_key": gallery.token,
                "first_gid": gid,
                "first_key": gallery.token
            ]]
        ]
        let responseData = try JSONSerialization.data(withJSONObject: payload, options: [])
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            let response = try #require(HTTPURLResponse(
                url: request.url ?? Defaults.URL.api,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, responseData)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
    }

    func uninstallSharedSessionStub(sessionID: String) {
        SharedSessionStubURLProtocol.removeHandler(for: sessionID)
    }

    func sampleGallery() -> Gallery {
        Gallery(
            gid: "123456",
            token: "token",
            title: "Sample Gallery",
            rating: 4,
            tags: [],
            category: .doujinshi,
            uploader: "Uploader",
            pageCount: 12,
            postedDate: .now,
            coverURL: URL(string: "https://example.com/cover.jpg"),
            galleryURL: URL(string: "https://e-hentai.org/g/123456/token")
        )
    }

    func sampleGalleryDetail(
        gid: String,
        title: String
    ) -> GalleryDetail {
        GalleryDetail(
            gid: gid,
            title: title,
            jpnTitle: nil,
            isFavorited: false,
            visibility: .yes,
            rating: 4,
            userRating: 0,
            ratingCount: 10,
            category: .doujinshi,
            language: .japanese,
            uploader: "Uploader",
            postedDate: .now,
            coverURL: URL(string: "https://example.com/cover.jpg"),
            favoritedCount: 2,
            pageCount: 12,
            sizeCount: 120,
            sizeType: "MB",
            torrentCount: 0
        )
    }

}
