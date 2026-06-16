//
//  Request+Gallery.swift
//  EhPanda
//

import Kanna
import Combine
import Foundation

// MARK: Fetch ListItems
struct SearchGalleriesRequest: Request {
    let keyword: String
    let filter: Filter

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.searchList(keyword: keyword, filter: filter)
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

struct MoreSearchGalleriesRequest: Request {
    let keyword: String
    let filter: Filter
    let lastID: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreSearchList(keyword: keyword, filter: filter, lastID: lastID)
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

struct JumpGalleriesRequest: Request {
    let url: URL

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
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

struct FrontpageGalleriesRequest: Request {
    let filter: Filter

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.frontpageList(filter: filter))
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

struct MoreFrontpageGalleriesRequest: Request {
    let filter: Filter
    let lastID: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.moreFrontpageList(filter: filter, lastID: lastID))
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

struct PopularGalleriesRequest: Request {
    let filter: Filter

    var publisher: AnyPublisher<[Gallery], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.popularList(filter: filter))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseGalleries) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct WatchedGalleriesRequest: Request {
    let filter: Filter
    let keyword: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.watchedList(filter: filter, keyword: keyword))
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

struct MoreWatchedGalleriesRequest: Request {
    let filter: Filter
    let lastID: String
    let keyword: String

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.moreWatchedList(filter: filter, lastID: lastID, keyword: keyword)
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

struct FavoritesGalleriesRequest: Request {
    let favIndex: Int
    let keyword: String
    var sortOrder: FavoritesSortOrder?

    var publisher: AnyPublisher<FavoritesGalleriesResult, AppError> {
        URLSession.shared.dataTaskPublisher(
            for: URLUtil.favoritesList(favIndex: favIndex, keyword: keyword, sortOrder: sortOrder)
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap { doc in
            try parseResponse(doc: doc) {
                FavoritesGalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    sortOrder: Parser.parseFavoritesSortOrder(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

struct MoreFavoritesGalleriesRequest: Request {
    let favIndex: Int
    let lastID: String
    var lastTimestamp: String
    let keyword: String

    var publisher: AnyPublisher<FavoritesGalleriesResult, AppError> {
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
                    sortOrder: Parser.parseFavoritesSortOrder(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}

struct ToplistsGalleriesRequest: Request {
    let catIndex: Int
    var pageNum: Int?

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
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

struct MoreToplistsGalleriesRequest: Request {
    let catIndex: Int
    let pageNum: Int

    var publisher: AnyPublisher<(PageNumber, [Gallery]), AppError> {
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
