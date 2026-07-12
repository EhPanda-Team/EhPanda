import Kanna
import AppModels
import Combine
import Foundation
import AppTools
import ParserFeature

// MARK: Fetch ListItems
public struct SearchGalleriesRequest: Request {
    public init(
        keyword: String,
        filter: Filter,
        urlSession: URLSession = .shared
    ) {
        self.keyword = keyword
        self.filter = filter
        self.urlSession = urlSession
    }
    public let keyword: String
    public let filter: Filter
    public let urlSession: URLSession

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        urlSession.dataTaskPublisher(
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
        lastID: String,
        urlSession: URLSession = .shared
    ) {
        self.keyword = keyword
        self.filter = filter
        self.lastID = lastID
        self.urlSession = urlSession
    }
    public let keyword: String
    public let filter: Filter
    public let lastID: String
    public let urlSession: URLSession

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        urlSession.dataTaskPublisher(
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
        url: URL,
        urlSession: URLSession = .shared
    ) {
        self.url = url
        self.urlSession = urlSession
    }
    public let url: URL
    public let urlSession: URLSession

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        urlSession.dataTaskPublisher(for: url)
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
        filter: Filter,
        urlSession: URLSession = .shared
    ) {
        self.filter = filter
        self.urlSession = urlSession
    }
    public let filter: Filter
    public let urlSession: URLSession

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        urlSession.dataTaskPublisher(for: URLUtil.frontpageList(filter: filter))
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
        lastID: String,
        urlSession: URLSession = .shared
    ) {
        self.filter = filter
        self.lastID = lastID
        self.urlSession = urlSession
    }
    public let filter: Filter
    public let lastID: String
    public let urlSession: URLSession

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        urlSession.dataTaskPublisher(for: URLUtil.moreFrontpageList(filter: filter, lastID: lastID))
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
        filter: Filter,
        urlSession: URLSession = .shared
    ) {
        self.filter = filter
        self.urlSession = urlSession
    }
    public let filter: Filter
    public let urlSession: URLSession

    public var publisher: AnyPublisher<[Gallery], AppError> {
        urlSession.dataTaskPublisher(for: URLUtil.popularList(filter: filter))
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
        keyword: String,
        urlSession: URLSession = .shared
    ) {
        self.filter = filter
        self.keyword = keyword
        self.urlSession = urlSession
    }
    public let filter: Filter
    public let keyword: String
    public let urlSession: URLSession

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        urlSession.dataTaskPublisher(for: URLUtil.watchedList(filter: filter, keyword: keyword))
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
        keyword: String,
        urlSession: URLSession = .shared
    ) {
        self.filter = filter
        self.lastID = lastID
        self.keyword = keyword
        self.urlSession = urlSession
    }
    public let filter: Filter
    public let lastID: String
    public let keyword: String
    public let urlSession: URLSession

    public var publisher: AnyPublisher<GalleriesResult, AppError> {
        urlSession.dataTaskPublisher(
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
        sortOrder: FavoritesSortOrder? = nil,
        urlSession: URLSession = .shared
    ) {
        self.favIndex = favIndex
        self.keyword = keyword
        self.sortOrder = sortOrder
        self.urlSession = urlSession
    }
    public let favIndex: Int
    public let keyword: String
    public var sortOrder: FavoritesSortOrder?
    public let urlSession: URLSession

    public var publisher: AnyPublisher<FavoritesGalleriesResult, AppError> {
        urlSession.dataTaskPublisher(
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
        keyword: String,
        urlSession: URLSession = .shared
    ) {
        self.favIndex = favIndex
        self.lastID = lastID
        self.lastTimestamp = lastTimestamp
        self.keyword = keyword
        self.urlSession = urlSession
    }
    public let favIndex: Int
    public let lastID: String
    public var lastTimestamp: String
    public let keyword: String
    public let urlSession: URLSession

    public var publisher: AnyPublisher<FavoritesGalleriesResult, AppError> {
        urlSession.dataTaskPublisher(
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
        pageNum: Int? = nil,
        urlSession: URLSession = .shared
    ) {
        self.catIndex = catIndex
        self.pageNum = pageNum
        self.urlSession = urlSession
    }
    public let catIndex: Int
    public var pageNum: Int?
    public let urlSession: URLSession

    public var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        urlSession.dataTaskPublisher(
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
        pageNum: Int,
        urlSession: URLSession = .shared
    ) {
        self.catIndex = catIndex
        self.pageNum = pageNum
        self.urlSession = urlSession
    }
    public let catIndex: Int
    public let pageNum: Int
    public let urlSession: URLSession

    public var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        urlSession.dataTaskPublisher(
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
