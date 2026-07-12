import Kanna
import AppModels
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

    public func response() async throws(AppError) -> GalleriesResult {
        let request = URLRequest(url: URLUtil.searchList(keyword: keyword, filter: filter))
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> GalleriesResult {
        let url = URLUtil.moreSearchList(keyword: keyword, filter: filter, lastID: lastID)
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> GalleriesResult {
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> GalleriesResult {
        let request = URLRequest(url: URLUtil.frontpageList(filter: filter))
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> GalleriesResult {
        let url = URLUtil.moreFrontpageList(filter: filter, lastID: lastID)
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> [Gallery] {
        let request = URLRequest(url: URLUtil.popularList(filter: filter))
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseGalleries)
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> GalleriesResult {
        let request = URLRequest(url: URLUtil.watchedList(filter: filter, keyword: keyword))
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> GalleriesResult {
        let url = URLUtil.moreWatchedList(
            filter: filter,
            lastID: lastID,
            keyword: keyword
        )
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> FavoritesGalleriesResult {
        let url = URLUtil.favoritesList(
            favIndex: favIndex,
            keyword: keyword,
            sortOrder: sortOrder
        )
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                FavoritesGalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    sortOrder: Parser.parseFavoritesSortOrder(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> FavoritesGalleriesResult {
        let url = URLUtil.moreFavoritesList(
            favIndex: favIndex,
            lastID: lastID,
            lastTimestamp: lastTimestamp,
            keyword: keyword
        )
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                FavoritesGalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0),
                    sortOrder: Parser.parseFavoritesSortOrder(doc: $0),
                    galleries: try Parser.parseGalleries(doc: $0)
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> (PageNumber, [Gallery]) {
        let url = URLUtil.toplistsList(catIndex: catIndex, pageNum: pageNum)
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0))
            }
        } catch {
            throw mapAppError(error: error)
        }
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

    public func response() async throws(AppError) -> (PageNumber, [Gallery]) {
        let url = URLUtil.moreToplistsList(catIndex: catIndex, pageNum: pageNum)
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                (Parser.parsePageNum(doc: $0), try Parser.parseGalleries(doc: $0))
            }
        } catch {
            throw mapAppError(error: error)
        }
    }
}
