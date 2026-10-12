import AppModels
import ComposableArchitecture
import Foundation
@testable import ReadingFeature
import Testing

// What the reader records of each page's size: the size the served URL names, replaced by the size of the image
// the page decodes, which no later URL replaces.
struct ReadingReducerPageSizeTests {
    private static func servedURL(width: Int, height: Int) throws -> URL {
        try #require(URL(string: """
            https://example.hath.network/h/ea42b28bceeae68f1f6adb414da61d186b3d126b-311480-\(width)-\(height)-jpg\
            /keystamp=1694132700-fd778f8260;fileindex=132044713;xres=1280/87052610_5090394_0.jpg
            """))
    }

    @Test
    func aServedURLGivesItsPageTheSizeItNames() throws {
        var state = ReadingReducer.State(gallery: .preview)
        let servedURL = try Self.servedURL(width: 1280, height: 1791)
        let plainURL = try #require(URL(string: "https://example.com/pages/0002.jpg"))

        state.updateImageURLs([1: servedURL, 2: plainURL], originalImageURLs: [:])

        let served = try #require(PagePixelSize(width: 1280, height: 1791))
        #expect(state.pageSizes == [1: KnownPageSize(pixelSize: served, source: .servedURL)])
    }

    @Test
    func aRefetchedURLReplacesTheSizeAnEarlierURLNamed() throws {
        var state = ReadingReducer.State(gallery: .preview)
        let firstURL = try Self.servedURL(width: 1280, height: 1791)
        let refetchedURL = try Self.servedURL(width: 780, height: 1092)

        state.updateImageURLs([1: firstURL], originalImageURLs: [:])
        state.updateImageURLs([1: refetchedURL], originalImageURLs: [:])

        let refetched = try #require(PagePixelSize(width: 780, height: 1092))
        #expect(state.pageSizes[1] == KnownPageSize(pixelSize: refetched, source: .servedURL))
    }

    @Test
    func theDecodedImageReplacesTheServedSizeAndNoLaterURLReplacesIt() throws {
        var state = ReadingReducer.State(gallery: .preview)
        let servedURL = try Self.servedURL(width: 1280, height: 1791)
        let refetchedURL = try Self.servedURL(width: 780, height: 1092)
        let decoded = try #require(PagePixelSize(width: 1280, height: 1790))

        state.updateImageURLs([1: servedURL], originalImageURLs: [:])
        state.recordSize(decoded, ofPage: 1, from: .decodedImage)
        let afterDecoding = state.pageSizes[1]
        state.updateImageURLs([1: refetchedURL], originalImageURLs: [:])

        #expect(afterDecoding == KnownPageSize(pixelSize: decoded, source: .decodedImage))
        #expect(state.pageSizes[1] == KnownPageSize(pixelSize: decoded, source: .decodedImage))
    }

    @MainActor
    @Test
    func reloadingEveryImageKeepsThePagesSizes() async throws {
        var initialState = ReadingReducer.State(gallery: .preview)
        let servedURL = try Self.servedURL(width: 1280, height: 1791)
        let decoded = try #require(PagePixelSize(width: 1280, height: 1790))
        initialState.updateImageURLs([2: servedURL], originalImageURLs: [:])
        initialState.recordSize(decoded, ofPage: 1, from: .decodedImage)
        let pageSizes = initialState.pageSizes
        let store = TestStore(initialState: initialState, reducer: ReadingReducer.init)
        store.exhaustivity = .off

        await store.send(.reloadAllWebImages)

        #expect(store.state.imageURLs.isEmpty)
        #expect(store.state.pageSizes == pageSizes)
    }
}
