public import AppModels
public import ComposableArchitecture
public import Foundation
public import NetworkingFeature

/// Every gallery list fetch and gallery detail fetch a reducer starts, one closure per request type.
///
/// A reducer that constructs its request inside an effect leaves a test no way to choose the outcome. In a test
/// process the test network guard fails such a request offline, but at a moment set by effect scheduling, so a test
/// that did not wait for it asserted against a race. Through this dependency a test states the outcome, and the
/// unimplemented test value reports any fetch a test did not expect.
///
/// `live` builds exactly the request a reducer built before, with the same arguments and each request's own
/// defaults. Two fetch paths stay outside on purpose. `HomeClient` keeps the Home root's three fetches: the capture
/// scenes replace it, and its popular fetch arranges the carousel. The download client keeps its own detail
/// request, which carries its session and cellular policy.
public struct GalleryClient: Sendable {
    /// The first page of Search and Detail search.
    public var fetchSearchGalleries: @Sendable (
        _ host: GalleryHost,
        _ keyword: String,
        _ filter: AppModels.Filter
    ) async throws(AppError) -> GalleriesResult
    /// The next page of Search and Detail search.
    public var fetchMoreSearchGalleries: @Sendable (
        _ host: GalleryHost,
        _ keyword: String,
        _ filter: AppModels.Filter,
        _ lastID: String
    ) async throws(AppError) -> GalleriesResult
    /// The date seek of Front Page, Watched, Search and Favorites.
    public var fetchDateSeekGalleries: @Sendable (
        _ host: GalleryHost,
        _ url: URL
    ) async throws(AppError) -> GalleriesResult
    /// The first page of Front Page.
    public var fetchFrontPageGalleries: @Sendable (
        _ host: GalleryHost,
        _ filter: AppModels.Filter
    ) async throws(AppError) -> GalleriesResult
    /// The next page of Front Page.
    public var fetchMoreFrontPageGalleries: @Sendable (
        _ host: GalleryHost,
        _ filter: AppModels.Filter,
        _ lastID: String
    ) async throws(AppError) -> GalleriesResult
    /// The Popular list.
    public var fetchPopularGalleries: @Sendable (
        _ host: GalleryHost,
        _ filter: AppModels.Filter
    ) async throws(AppError) -> [Gallery]
    /// The first page of Watched.
    public var fetchWatchedGalleries: @Sendable (
        _ host: GalleryHost,
        _ filter: AppModels.Filter,
        _ keyword: String
    ) async throws(AppError) -> GalleriesResult
    /// The next page of Watched.
    public var fetchMoreWatchedGalleries: @Sendable (
        _ host: GalleryHost,
        _ filter: AppModels.Filter,
        _ lastID: String,
        _ keyword: String
    ) async throws(AppError) -> GalleriesResult
    /// The first page of Favorites.
    public var fetchFavoritesGalleries: @Sendable (
        _ host: GalleryHost,
        _ favIndex: Int,
        _ keyword: String,
        _ sortOrder: FavoritesSortOrder?
    ) async throws(AppError) -> FavoritesGalleriesResult
    /// The next page of Favorites.
    public var fetchMoreFavoritesGalleries: @Sendable (
        _ host: GalleryHost,
        _ favIndex: Int,
        _ lastID: String,
        _ lastTimestamp: String,
        _ keyword: String
    ) async throws(AppError) -> FavoritesGalleriesResult
    /// The first page of Toplists.
    public var fetchToplistsGalleries: @Sendable (
        _ host: GalleryHost,
        _ catIndex: Int,
        _ pageNum: Int?
    ) async throws(AppError) -> (pageNumber: PageNumber, galleries: [Gallery])
    /// The next page of Toplists.
    public var fetchMoreToplistsGalleries: @Sendable (
        _ host: GalleryHost,
        _ catIndex: Int,
        _ pageNum: Int
    ) async throws(AppError) -> (pageNumber: PageNumber, galleries: [Gallery])
    /// The History list and the Search root's recently seen galleries.
    public var fetchGalleriesMetadata: @Sendable (
        _ host: GalleryHost,
        _ gidList: [(gid: String, token: String)]
    ) async throws(AppError) -> [Gallery]
    /// The gallery detail of Detail and of the Favorites reading shortcut.
    public var fetchGalleryDetail: @Sendable (
        _ gid: String,
        _ galleryURL: URL
    ) async throws(AppError) -> GalleryDetailResponse
}

extension GalleryClient {
    /// Each closure forwards its arguments, in order and unchanged, to the request it is named after. The bodies are
    /// functions rather than closure literals, so the typed `throws(AppError)` is kept and the long parameter lists
    /// stay within the line limit.
    public static let live = Self(
        fetchSearchGalleries: searchGalleries,
        fetchMoreSearchGalleries: moreSearchGalleries,
        fetchDateSeekGalleries: dateSeekGalleries,
        fetchFrontPageGalleries: frontPageGalleries,
        fetchMoreFrontPageGalleries: moreFrontPageGalleries,
        fetchPopularGalleries: popularGalleries,
        fetchWatchedGalleries: watchedGalleries,
        fetchMoreWatchedGalleries: moreWatchedGalleries,
        fetchFavoritesGalleries: favoritesGalleries,
        fetchMoreFavoritesGalleries: moreFavoritesGalleries,
        fetchToplistsGalleries: toplistsGalleries,
        fetchMoreToplistsGalleries: moreToplistsGalleries,
        fetchGalleriesMetadata: galleriesMetadata,
        fetchGalleryDetail: galleryDetail
    )

    private static func searchGalleries(
        host: GalleryHost,
        keyword: String,
        filter: AppModels.Filter
    ) async throws(AppError) -> GalleriesResult {
        try await SearchGalleriesRequest(host: host, keyword: keyword, filter: filter).response()
    }

    private static func moreSearchGalleries(
        host: GalleryHost,
        keyword: String,
        filter: AppModels.Filter,
        lastID: String
    ) async throws(AppError) -> GalleriesResult {
        try await MoreSearchGalleriesRequest(host: host, keyword: keyword, filter: filter, lastID: lastID).response()
    }

    private static func dateSeekGalleries(
        host: GalleryHost,
        url: URL
    ) async throws(AppError) -> GalleriesResult {
        try await DateSeekGalleriesRequest(host: host, url: url).response()
    }

    private static func frontPageGalleries(
        host: GalleryHost,
        filter: AppModels.Filter
    ) async throws(AppError) -> GalleriesResult {
        try await FrontPageGalleriesRequest(host: host, filter: filter).response()
    }

    private static func moreFrontPageGalleries(
        host: GalleryHost,
        filter: AppModels.Filter,
        lastID: String
    ) async throws(AppError) -> GalleriesResult {
        try await MoreFrontPageGalleriesRequest(host: host, filter: filter, lastID: lastID).response()
    }

    private static func popularGalleries(
        host: GalleryHost,
        filter: AppModels.Filter
    ) async throws(AppError) -> [Gallery] {
        try await PopularGalleriesRequest(host: host, filter: filter).response()
    }

    private static func watchedGalleries(
        host: GalleryHost,
        filter: AppModels.Filter,
        keyword: String
    ) async throws(AppError) -> GalleriesResult {
        try await WatchedGalleriesRequest(host: host, filter: filter, keyword: keyword).response()
    }

    private static func moreWatchedGalleries(
        host: GalleryHost,
        filter: AppModels.Filter,
        lastID: String,
        keyword: String
    ) async throws(AppError) -> GalleriesResult {
        try await MoreWatchedGalleriesRequest(host: host, filter: filter, lastID: lastID, keyword: keyword).response()
    }

    private static func favoritesGalleries(
        host: GalleryHost,
        favIndex: Int,
        keyword: String,
        sortOrder: FavoritesSortOrder?
    ) async throws(AppError) -> FavoritesGalleriesResult {
        try await FavoritesGalleriesRequest(
            host: host, favIndex: favIndex, keyword: keyword, sortOrder: sortOrder
        )
        .response()
    }

    private static func moreFavoritesGalleries(
        host: GalleryHost,
        favIndex: Int,
        lastID: String,
        lastTimestamp: String,
        keyword: String
    ) async throws(AppError) -> FavoritesGalleriesResult {
        try await MoreFavoritesGalleriesRequest(
            host: host, favIndex: favIndex, lastID: lastID, lastTimestamp: lastTimestamp, keyword: keyword
        )
        .response()
    }

    private static func toplistsGalleries(
        host: GalleryHost,
        catIndex: Int,
        pageNum: Int?
    ) async throws(AppError) -> (pageNumber: PageNumber, galleries: [Gallery]) {
        try await ToplistsGalleriesRequest(host: host, catIndex: catIndex, pageNum: pageNum).response()
    }

    private static func moreToplistsGalleries(
        host: GalleryHost,
        catIndex: Int,
        pageNum: Int
    ) async throws(AppError) -> (pageNumber: PageNumber, galleries: [Gallery]) {
        try await MoreToplistsGalleriesRequest(host: host, catIndex: catIndex, pageNum: pageNum).response()
    }

    private static func galleriesMetadata(
        host: GalleryHost,
        gidList: [(gid: String, token: String)]
    ) async throws(AppError) -> [Gallery] {
        try await GalleriesMetadataRequest(host: host, gidList: gidList).response()
    }

    private static func galleryDetail(
        gid: String,
        galleryURL: URL
    ) async throws(AppError) -> GalleryDetailResponse {
        try await GalleryDetailRequest(gid: gid, galleryURL: galleryURL).response()
    }
}

// MARK: API
public enum GalleryClientKey: DependencyKey {
    public static let liveValue = GalleryClient.live
    public static let previewValue = GalleryClient.noop
    public static let testValue = GalleryClient.unimplemented
}

extension DependencyValues {
    public var galleryClient: GalleryClient {
        get { self[GalleryClientKey.self] }
        set { self[GalleryClientKey.self] = newValue }
    }
}

// MARK: Test
extension GalleryClient {
    /// Answers every fetch with nothing: an empty list, or a detail that is not found, since a detail has no empty
    /// value.
    public static let noop = Self(
        fetchSearchGalleries: returning(GalleriesResult(pageNumber: PageNumber(), galleries: [])),
        fetchMoreSearchGalleries: returning(GalleriesResult(pageNumber: PageNumber(), galleries: [])),
        fetchDateSeekGalleries: returning(GalleriesResult(pageNumber: PageNumber(), galleries: [])),
        fetchFrontPageGalleries: returning(GalleriesResult(pageNumber: PageNumber(), galleries: [])),
        fetchMoreFrontPageGalleries: returning(GalleriesResult(pageNumber: PageNumber(), galleries: [])),
        fetchPopularGalleries: returning([Gallery]()),
        fetchWatchedGalleries: returning(GalleriesResult(pageNumber: PageNumber(), galleries: [])),
        fetchMoreWatchedGalleries: returning(GalleriesResult(pageNumber: PageNumber(), galleries: [])),
        fetchFavoritesGalleries: returning(FavoritesGalleriesResult(pageNumber: PageNumber(), galleries: [])),
        fetchMoreFavoritesGalleries: returning(FavoritesGalleriesResult(pageNumber: PageNumber(), galleries: [])),
        fetchToplistsGalleries: returning((pageNumber: PageNumber(), galleries: [Gallery]())),
        fetchMoreToplistsGalleries: returning((pageNumber: PageNumber(), galleries: [Gallery]())),
        fetchGalleriesMetadata: returning([Gallery]()),
        fetchGalleryDetail: throwing(AppError.notFound)
    )

    /// Reports an issue that names the closure and throws, so a test that reaches a fetch it did not stub fails without
    /// ending the test process.
    public static let unimplemented = Self(
        fetchSearchGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchSearchGalleries", throwing: AppError.unknown
        ),
        fetchMoreSearchGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchMoreSearchGalleries", throwing: AppError.unknown
        ),
        fetchDateSeekGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchDateSeekGalleries", throwing: AppError.unknown
        ),
        fetchFrontPageGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchFrontPageGalleries", throwing: AppError.unknown
        ),
        fetchMoreFrontPageGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchMoreFrontPageGalleries", throwing: AppError.unknown
        ),
        fetchPopularGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchPopularGalleries", throwing: AppError.unknown
        ),
        fetchWatchedGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchWatchedGalleries", throwing: AppError.unknown
        ),
        fetchMoreWatchedGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchMoreWatchedGalleries", throwing: AppError.unknown
        ),
        fetchFavoritesGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchFavoritesGalleries", throwing: AppError.unknown
        ),
        fetchMoreFavoritesGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchMoreFavoritesGalleries", throwing: AppError.unknown
        ),
        fetchToplistsGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchToplistsGalleries", throwing: AppError.unknown
        ),
        fetchMoreToplistsGalleries: IssueReporting.unimplemented(
            "GalleryClient.fetchMoreToplistsGalleries", throwing: AppError.unknown
        ),
        fetchGalleriesMetadata: IssueReporting.unimplemented(
            "GalleryClient.fetchGalleriesMetadata", throwing: AppError.unknown
        ),
        fetchGalleryDetail: IssueReporting.unimplemented(
            "GalleryClient.fetchGalleryDetail", throwing: AppError.unknown
        )
    )

    /// Fails every fetch with `error` and reports nothing. Use it for a fetch a test starts but does not care about,
    /// failed the way an offline device would fail it.
    public static func failing(_ error: AppError) -> Self {
        Self(
            fetchSearchGalleries: throwing(error),
            fetchMoreSearchGalleries: throwing(error),
            fetchDateSeekGalleries: throwing(error),
            fetchFrontPageGalleries: throwing(error),
            fetchMoreFrontPageGalleries: throwing(error),
            fetchPopularGalleries: throwing(error),
            fetchWatchedGalleries: throwing(error),
            fetchMoreWatchedGalleries: throwing(error),
            fetchFavoritesGalleries: throwing(error),
            fetchMoreFavoritesGalleries: throwing(error),
            fetchToplistsGalleries: throwing(error),
            fetchMoreToplistsGalleries: throwing(error),
            fetchGalleriesMetadata: throwing(error),
            fetchGalleryDetail: throwing(error)
        )
    }
}

/// Builds a closure of any arity that answers with `value`.
///
/// `@concurrent` because Swift 6.4.2 crashes in SILGen on a parameter-pack closure inferred `nonisolated(nonsending)`
/// under `NonisolatedNonsendingByDefault`. The closure only returns a constant or throws, so running off the caller's
/// actor changes nothing, and IssueReporting's unimplemented closures use the same `@concurrent` shape.
private func returning<each Argument, Output: Sendable>(
    _ value: Output
) -> @concurrent @Sendable (repeat each Argument) async throws(AppError) -> Output {
    { (_: repeat each Argument) async throws(AppError) -> Output in value }
}

/// Builds a closure of any arity that fails with `error`.
///
/// `@concurrent` because Swift 6.4.2 crashes in SILGen on a parameter-pack closure inferred `nonisolated(nonsending)`
/// under `NonisolatedNonsendingByDefault`. The closure only returns a constant or throws, so running off the caller's
/// actor changes nothing, and IssueReporting's unimplemented closures use the same `@concurrent` shape.
private func throwing<each Argument, Output>(
    _ error: AppError
) -> @concurrent @Sendable (repeat each Argument) async throws(AppError) -> Output {
    { (_: repeat each Argument) async throws(AppError) -> Output in throw error }
}
