import Foundation
import Testing
@testable import EhPanda

struct DatabaseClientUpdateTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testURLUpdatesMergePageBatches() async throws {
        let container = try makeInMemoryContainer()
        let databaseClient = DatabaseClient.live(persistenceContainer: container)
        let gid = "123456"

        let imageURLs = try urlBatches(path: "image")
        let originalImageURLs = try urlBatches(path: "original")
        let thumbnailURLs = try urlBatches(path: "thumbnail")
        let previewURLs = try urlBatches(path: "preview")

        databaseClient.updateImageURLs(
            gid: gid,
            imageURLs: imageURLs.first,
            originalImageURLs: originalImageURLs.first
        )
        databaseClient.updateThumbnailURLs(gid: gid, thumbnailURLs: thumbnailURLs.first)
        databaseClient.updatePreviewURLs(gid: gid, previewURLs: previewURLs.first)

        databaseClient.updateImageURLs(
            gid: gid,
            imageURLs: imageURLs.second,
            originalImageURLs: originalImageURLs.second
        )
        databaseClient.updateThumbnailURLs(gid: gid, thumbnailURLs: thumbnailURLs.second)
        databaseClient.updatePreviewURLs(gid: gid, previewURLs: previewURLs.second)

        let galleryState = try #require(await databaseClient.fetchGalleryState(gid: gid))

        #expect(galleryState.imageURLs == imageURLs.merged)
        #expect(galleryState.originalImageURLs == originalImageURLs.merged)
        #expect(galleryState.thumbnailURLs == thumbnailURLs.merged)
        #expect(galleryState.previewURLs == previewURLs.merged)
    }

    private func urlBatches(
        path: String
    ) throws -> URLBatches {
        let first = [
            1: try #require(URL(string: "https://example.com/\(path)-1.jpg")),
            2: try #require(URL(string: "https://example.com/\(path)-2.jpg"))
        ]
        let second = [
            3: try #require(URL(string: "https://example.com/\(path)-3.jpg")),
            4: try #require(URL(string: "https://example.com/\(path)-4.jpg"))
        ]

        return .init(
            first: first,
            second: second,
            merged: first.merging(second, uniquingKeysWith: { _, new in new })
        )
    }
}

private struct URLBatches {
    let first: [Int: URL]
    let second: [Int: URL]
    let merged: [Int: URL]
}
