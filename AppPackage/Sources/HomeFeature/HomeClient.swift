import AppModels
import ComposableArchitecture
import Foundation
import NetworkingFeature

/// Home's three gallery-list fetches, injected so a capture scene can supply selected galleries.
///
/// Each result reaches the reducer in display order. The live popular fetch therefore arranges
/// the hero carousel itself (``arrangedCarousel(_:using:)``), and a replacement value decides the
/// carousel order exactly; the reducer only assigns what it receives.
public struct HomeClient: Sendable {
    /// The hero carousel's galleries, in display order.
    public var fetchPopularGalleries: @Sendable (
        _ host: GalleryHost,
        _ filter: AppModels.Filter
    ) async throws(AppError) -> [Gallery]
    public var fetchFrontpageGalleries: @Sendable (
        _ host: GalleryHost,
        _ filter: AppModels.Filter
    ) async throws(AppError) -> (pageNumber: PageNumber, galleries: [Gallery])
    public var fetchToplistsGalleries: @Sendable (
        _ host: GalleryHost,
        _ catIndex: Int,
        _ pageNum: Int?
    ) async throws(AppError) -> (pageNumber: PageNumber, galleries: [Gallery])

    public init(
        fetchPopularGalleries: @escaping @Sendable (
            _ host: GalleryHost,
            _ filter: AppModels.Filter
        ) async throws(AppError) -> [Gallery],
        fetchFrontpageGalleries: @escaping @Sendable (
            _ host: GalleryHost,
            _ filter: AppModels.Filter
        ) async throws(AppError) -> (pageNumber: PageNumber, galleries: [Gallery]),
        fetchToplistsGalleries: @escaping @Sendable (
            _ host: GalleryHost,
            _ catIndex: Int,
            _ pageNum: Int?
        ) async throws(AppError) -> (pageNumber: PageNumber, galleries: [Gallery])
    ) {
        self.fetchPopularGalleries = fetchPopularGalleries
        self.fetchFrontpageGalleries = fetchFrontpageGalleries
        self.fetchToplistsGalleries = fetchToplistsGalleries
    }
}

extension HomeClient {
    public static let live = Self(
        fetchPopularGalleries: { (host: GalleryHost, filter: AppModels.Filter) async throws(AppError) in
            let galleries = try await PopularGalleriesRequest(host: host, filter: filter).response()
            var generator = SystemRandomNumberGenerator()
            return arrangedCarousel(galleries, using: &generator)
        },
        fetchFrontpageGalleries: { (host: GalleryHost, filter: AppModels.Filter) async throws(AppError) in
            let response = try await FrontpageGalleriesRequest(host: host, filter: filter).response()
            return (pageNumber: response.pageNumber, galleries: response.galleries)
        },
        fetchToplistsGalleries: { (host: GalleryHost, catIndex: Int, pageNum: Int?) async throws(AppError) in
            try await ToplistsGalleriesRequest(host: host, catIndex: catIndex, pageNum: pageNum).response()
        }
    )

    /// Arranges popular galleries into the hero carousel: the ten longest titles, without repeated
    /// trimmed titles, at most six of them, in random order.
    ///
    /// The order is random by design, so every launch shows a different carousel. The generator is
    /// a parameter only so tests can make that order reproducible.
    static func arrangedCarousel(
        _ galleries: [Gallery],
        using generator: inout some RandomNumberGenerator
    ) -> [Gallery] {
        let longestTitles = Array(galleries.sorted(by: { $0.title.count > $1.title.count }).prefix(10))
        var carousel = Array(longestTitles.removeDuplicates(by: \.trimmedTitle).prefix(6))
        carousel.shuffle(using: &generator)
        return carousel
    }
}

// MARK: API
public enum HomeClientKey: DependencyKey {
    public static let liveValue = HomeClient.live
    public static let previewValue = HomeClient.noop
    public static let testValue = HomeClient.unimplemented
}

extension DependencyValues {
    public var homeClient: HomeClient {
        get { self[HomeClientKey.self] }
        set { self[HomeClientKey.self] = newValue }
    }
}

// MARK: Test
extension HomeClient {
    public static let noop = Self(
        fetchPopularGalleries: { (_: GalleryHost, _: AppModels.Filter) async throws(AppError) in [] },
        fetchFrontpageGalleries: { (_: GalleryHost, _: AppModels.Filter) async throws(AppError) in
            (pageNumber: PageNumber(), galleries: [])
        },
        fetchToplistsGalleries: { (_: GalleryHost, _: Int, _: Int?) async throws(AppError) in
            (pageNumber: PageNumber(), galleries: [])
        }
    )

    /// Reports an issue and throws, so a test that reaches a fetch it did not override fails that
    /// test without ending the test process.
    public static let unimplemented = Self(
        fetchPopularGalleries: IssueReporting.unimplemented(throwing: AppError.unknown),
        fetchFrontpageGalleries: IssueReporting.unimplemented(throwing: AppError.unknown),
        fetchToplistsGalleries: IssueReporting.unimplemented(throwing: AppError.unknown)
    )
}
