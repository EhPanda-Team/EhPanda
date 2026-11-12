@testable import AppFeature
import AppModels
import AppTools
import ComposableArchitecture
import DownloadClient
import Foundation
import LibraryClient
import Testing
import UIKit

/// Pins how a gallery downloaded before the reader-cache key stopped carrying the per-request
/// `keystamp` signature behaves afterwards.
///
/// Downloaded pages are never looked up by cache key: they are files in the gallery's folder,
/// resolved by page index through the manifest. The reader cache is only a *source* a download is
/// seeded from (and evicted from). So galleries saved under the old keys must keep opening offline
/// whatever happens to the cache, and the old cache entries must stay reachable until they age out.
struct DownloadLegacyCacheKeyTests: DownloadFeatureTestCase {
    private static let signedPath = "h/9dc6713b44a7eafef9f42e831305087ca0898f05-152222-1024-1024-wbp"

    private func signedURL(host: String, keystamp: String) throws -> URL {
        try #require(URL(
            string: "https://\(host).hath.network:47800/\(Self.signedPath)/"
                + "keystamp=\(keystamp);fileindex=279444560;xres=1280/1_Copia.webp"
        ))
    }

    private func makeJPEGData(_ color: UIColor) throws -> Data {
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            color.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        return try #require(image.jpegData(compressionQuality: 1))
    }

    /// A completed gallery exactly as a 3.0 download leaves it: a manifest plus one file per page.
    private func writeLegacyDownload(
        gid: String,
        rootURL: URL,
        pages: [Int: Data]
    ) throws -> (folderURL: URL, manifest: DownloadManifest) {
        let folderURL = rootURL.appending(path: "Folder/\(gid) - Legacy", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        var hashes = [Int: String]()
        for (index, data) in pages {
            let fileURL = folderURL.appending(path: "\(gid)_token_\(index).jpg")
            try data.write(to: fileURL, options: .atomic)
            hashes[index] = try DownloadStore().fileHash(at: fileURL)
        }
        let manifest = DownloadManifest(
            gid: gid,
            host: .ehentai,
            token: "token",
            title: "Legacy",
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
            uploader: "Uploader",
            tags: [],
            postedDate: .now,
            rating: 4,
            pages: hashes
        )
        try JSONEncoder().encode(manifest).write(
            to: folderURL.appending(path: Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        return (folderURL, manifest)
    }

    @Test
    func testGalleryDownloadedUnderLegacyKeysStillOpensOfflineWithoutAnyCache() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 91)
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { removeTemporaryItem(at: rootURL) }
        let page1 = try makeJPEGData(.systemRed)
        let page2 = try makeJPEGData(.systemGreen)
        let (folderURL, _) = try writeLegacyDownload(gid: gid, rootURL: rootURL, pages: [1: page1, 2: page2])

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared, libraryClient: .noop)
        let dataCache = DataCache(
            configuration: .init(rootURL: rootURL.appending(path: "DataCache", directoryHint: .isDirectory))
        )

        try await withDependencies {
            $0.dataCache = dataCache
        } operation: {
            // The 3.0 reader cache held this page under the old key (keystamp included).
            let legacyURL = try signedURL(host: "alpha", keystamp: "1794510300-c5c7a48fa5")
            let legacyKey = try #require(legacyURL.legacyStableImageCacheKey)
            try await dataCache.store(page1, forKey: legacyKey)

            // Offline open: the cache is wiped (aged out / cleared) and the network is never touched.
            try await dataCache.removeAll()
            await manager.reloadDownloadIndex()

            let download = try #require(await manager.fetchDownload(gid: gid))
            #expect(download.displayStatus == .completed)
            let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()
            #expect(pageURLs.keys.sorted() == [1, 2])
            #expect(pageURLs[1] == folderURL.appending(path: "\(gid)_token_1.jpg"))
            #expect(try Data(contentsOf: #require(pageURLs[1])) == page1)
            #expect(try Data(contentsOf: #require(pageURLs[2])) == page2)
        }
    }

    @Test
    func testReaderCacheEntryWrittenUnderLegacyKeyIsStillServedToDownloads() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { removeTemporaryItem(at: rootURL) }
        let manager = DownloadCoordinator(
            storage: DownloadStore(rootURL: rootURL, fileManager: .default),
            urlSession: .shared,
            libraryClient: .noop
        )
        let dataCache = DataCache(
            configuration: .init(rootURL: rootURL.appending(path: "DataCache", directoryHint: .isDirectory))
        )
        let data = try makeJPEGData(.systemBlue)
        let url = try signedURL(host: "alpha", keystamp: "1794510300-c5c7a48fa5")

        try await withDependencies {
            $0.dataCache = dataCache
        } operation: {
            // Only the 3.0-style entry exists, under the old, keystamp-bearing key.
            try await dataCache.store(data, forKey: #require(url.legacyStableImageCacheKey))

            #expect(await manager.cachedImageData(for: [url]) == data)
            #expect(await manager.validatedCachedAssetData(for: [url]) == data)
        }
    }

    @Test
    func testReaderCacheEntryIsSharedAcrossKeystampRotationAndHost() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { removeTemporaryItem(at: rootURL) }
        let manager = DownloadCoordinator(
            storage: DownloadStore(rootURL: rootURL, fileManager: .default),
            urlSession: .shared,
            libraryClient: .noop
        )
        let dataCache = DataCache(
            configuration: .init(rootURL: rootURL.appending(path: "DataCache", directoryHint: .isDirectory))
        )
        let data = try makeJPEGData(.systemPurple)
        let firstVisit = try signedURL(host: "alpha", keystamp: "1794510300-c5c7a48fa5")
        let nextVisit = try signedURL(host: "beta", keystamp: "1794511500-65aa15ecef")

        try await withDependencies {
            $0.dataCache = dataCache
        } operation: {
            try await dataCache.store(data, forKey: firstVisit.imageCacheKeys[0])

            #expect(await manager.cachedImageData(for: [nextVisit]) == data)
        }
    }

    @Test
    func testRemovingCachedImagesAlsoEvictsLegacyKeyEntries() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { removeTemporaryItem(at: rootURL) }
        let manager = DownloadCoordinator(
            storage: DownloadStore(rootURL: rootURL, fileManager: .default),
            urlSession: .shared,
            libraryClient: .noop
        )
        let dataCache = DataCache(
            configuration: .init(rootURL: rootURL.appending(path: "DataCache", directoryHint: .isDirectory))
        )
        let data = try makeJPEGData(.systemYellow)
        let url = try signedURL(host: "alpha", keystamp: "1794510300-c5c7a48fa5")
        let legacyKey = try #require(url.legacyStableImageCacheKey)

        try await withDependencies {
            $0.dataCache = dataCache
        } operation: {
            try await dataCache.store(data, forKey: legacyKey)
            #expect(await dataCache.data(forKey: legacyKey) == data)

            await manager.removeCachedImages(for: [url])

            #expect(await dataCache.data(forKey: legacyKey) == nil)
        }
    }

    @Test
    func testCaptureRestoresPageFromLegacyKeyIntoLegacyDownloadFolder() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 92)
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { removeTemporaryItem(at: rootURL) }
        let page2 = try makeJPEGData(.systemGreen)
        let (folderURL, _) = try writeLegacyDownload(gid: gid, rootURL: rootURL, pages: [2: page2])
        // Re-declare the manifest with page 1 missing on disk, as after a partial loss.
        var manifest = try JSONDecoder().decode(
            DownloadManifest.self,
            from: Data(contentsOf: folderURL.appending(path: Defaults.FilePath.downloadManifest))
        )
        manifest.pages[1] = "sha256:missing"
        try JSONEncoder().encode(manifest).write(
            to: folderURL.appending(path: Defaults.FilePath.downloadManifest),
            options: .atomic
        )

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared, libraryClient: .noop)
        await manager.reloadDownloadIndex()
        let dataCache = DataCache(
            configuration: .init(rootURL: rootURL.appending(path: "DataCache", directoryHint: .isDirectory))
        )
        let page1 = try makeJPEGData(.systemOrange)
        let url = try signedURL(host: "alpha", keystamp: "1794510300-c5c7a48fa5")

        try await withDependencies {
            $0.dataCache = dataCache
        } operation: {
            try await dataCache.store(page1, forKey: #require(url.legacyStableImageCacheKey))

            await manager.captureCachedPage(gid: gid, index: 1, imageURL: url)

            let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()
            #expect(try Data(contentsOf: #require(pageURLs[1])) == page1)
            #expect(try Data(contentsOf: #require(pageURLs[2])) == page2)
        }
    }
}
