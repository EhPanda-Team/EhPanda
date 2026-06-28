import Kanna
import AppModels
import Combine
import Foundation
import Utilities
import ParserFeature

// MARK: Fetch ListItems
public struct SearchGalleriesRequest: Request {
    public init(
        keyword: String,
        filter: Filter
    ) {
        self.keyword = keyword
        self.filter = filter
    }
    public let keyword: String
    public let filter: Filter

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.searchList(keyword: keyword, filter: filter)
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap {
            try parseResponse(doc: $0) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

public struct MoreSearchGalleriesRequest: Request {
    public init(
        keyword: String,
        filter: Filter,
        lastID: String
    ) {
        self.keyword = keyword
        self.filter = filter
        self.lastID = lastID
    }
    public let keyword: String
    public let filter: Filter
    public let lastID: String

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreSearchList(keyword: keyword, filter: filter, lastID: lastID)
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap {
            try parseResponse(doc: $0) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

public struct DateSeekGalleriesRequest: Request {
    public init(
        url: URL
    ) {
        self.url = url
    }
    public let url: URL

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap {
                try parseResponse(doc: $0) {
                    GalleriesResult(
                        pageNumber: Parser.parsePageNum(doc: $0),
                        dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                        galleries: try Parser.parseGalleries(doc: $0)
                    )
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct FrontpageGalleriesRequest: Request {
    public init(
        filter: Filter
    ) {
        self.filter = filter
    }
    public let filter: Filter

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.frontpageList(filter: filter))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap {
                try parseResponse(doc: $0) {
                    GalleriesResult(
                        pageNumber: Parser.parsePageNum(doc: $0),
                        dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                        galleries: try Parser.parseGalleries(doc: $0)
                    )
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct MoreFrontpageGalleriesRequest: Request {
    public init(
        filter: Filter,
        lastID: String
    ) {
        self.filter = filter
        self.lastID = lastID
    }
    public let filter: Filter
    public let lastID: String

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.moreFrontpageList(filter: filter, lastID: lastID))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap {
                try parseResponse(doc: $0) {
                    GalleriesResult(
                        pageNumber: Parser.parsePageNum(doc: $0),
                        dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                        galleries: try Parser.parseGalleries(doc: $0)
                    )
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct PopularGalleriesRequest: Request {
    public init(
        filter: Filter
    ) {
        self.filter = filter
    }
    public let filter: Filter

    public var publisher: AnyPublisher<[Gallery], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.popularList(filter: filter))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseGalleries) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct WatchedGalleriesRequest: Request {
    public init(
        filter: Filter,
        keyword: String
    ) {
        self.filter = filter
        self.keyword = keyword
    }
    public let filter: Filter
    public let keyword: String

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.watchedList(filter: filter, keyword: keyword))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap {
                try parseResponse(doc: $0) {
                    GalleriesResult(
                        pageNumber: Parser.parsePageNum(doc: $0),
                        dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                        galleries: try Parser.parseGalleries(doc: $0)
                    )
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct MoreWatchedGalleriesRequest: Request {
    public init(
        filter: Filter,
        lastID: String,
        keyword: String
    ) {
        self.filter = filter
        self.lastID = lastID
        self.keyword = keyword
    }
    public let filter: Filter
    public let lastID: String
    public let keyword: String

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreWatchedList(filter: filter, lastID: lastID, keyword: keyword)
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap {
            try parseResponse(doc: $0) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

public struct FavoritesGalleriesRequest: Request {
    public init(
        favIndex: Int,
        keyword: String,
        sortOrder: FavoritesSortOrder? = nil
    ) {
        self.favIndex = favIndex
        self.keyword = keyword
        self.sortOrder = sortOrder
    }
    public let favIndex: Int
    public let keyword: String
    public var sortOrder: FavoritesSortOrder?

    public var publisher: AnyPublisher<FavoritesGalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.favoritesList(favIndex: favIndex, keyword: keyword, sortOrder: sortOrder)
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap { doc in
            try parseResponse(doc: doc) {
                FavoritesGalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    sortOrder: Parser.parseFavoritesSortOrder(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

public struct MoreFavoritesGalleriesRequest: Request {
    public init(
        favIndex: Int,
        lastID: String,
        lastTimestamp: String,
        keyword: String
    ) {
        self.favIndex = favIndex
        self.lastID = lastID
        self.lastTimestamp = lastTimestamp
        self.keyword = keyword
    }
    public let favIndex: Int
    public let lastID: String
    public var lastTimestamp: String
    public let keyword: String

    public var publisher: AnyPublisher<FavoritesGalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreFavoritesList(
                favIndex: favIndex, lastID: lastID, lastTimestamp: lastTimestamp, keyword: keyword
            )
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap { doc in
            try parseResponse(doc: doc) {
                FavoritesGalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    sortOrder: Parser.parseFavoritesSortOrder(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

public struct ToplistsGalleriesRequest: Request {
    public init(
        catIndex: Int,
        pageNum: Int? = nil
    ) {
        self.catIndex = catIndex
        self.pageNum = pageNum
    }
    public let catIndex: Int
    public var pageNum: Int?

    public var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.toplistsList(catIndex: catIndex, pageNum: pageNum)
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap {
            try parseResponse(doc: $0) {
                (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0))
            }
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

public struct MoreToplistsGalleriesRequest: Request {
    public init(
        catIndex: Int,
        pageNum: Int
    ) {
        self.catIndex = catIndex
        self.pageNum = pageNum
    }
    public let catIndex: Int
    public let pageNum: Int

    public var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreToplistsList(
                catIndex: catIndex, pageNum: pageNum
            )
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap {
            try parseResponse(doc: $0) {
                (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0))
            }
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}
