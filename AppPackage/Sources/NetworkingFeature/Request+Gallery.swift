import Kanna
import AppModels
import Foundation
import AppTools
import ParserFeature

// MARK: Fetch ListItems
public struct SearchGalleriesRequest: Request {
    public init(
        host: GalleryHost,
        keyword: String,
        filter: Filter,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.keyword = keyword
        self.filter = filter
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let keyword: String
    public let filter: Filter
    public let urlSession: URLSession

    public func response() async throws(AppError) -> GalleriesResult {
        let request = URLRequest(url: URLUtil.searchList(host: host, keyword: keyword, filter: filter))
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0, host: host.url),
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
        host: GalleryHost,
        keyword: String,
        filter: Filter,
        lastID: String,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.keyword = keyword
        self.filter = filter
        self.lastID = lastID
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let keyword: String
    public let filter: Filter
    public let lastID: String
    public let urlSession: URLSession

    public func response() async throws(AppError) -> GalleriesResult {
        let url = URLUtil.moreSearchList(host: host, keyword: keyword, filter: filter, lastID: lastID)
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0, host: host.url),
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
        host: GalleryHost,
        url: URL,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.url = url
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let url: URL
    public let urlSession: URLSession

    public func response() async throws(AppError) -> GalleriesResult {
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0, host: host.url),
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
        host: GalleryHost,
        filter: Filter,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.filter = filter
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let filter: Filter
    public let urlSession: URLSession

    public func response() async throws(AppError) -> GalleriesResult {
        let request = URLRequest(url: URLUtil.frontpageList(host: host, filter: filter))
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0, host: host.url),
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
        host: GalleryHost,
        filter: Filter,
        lastID: String,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.filter = filter
        self.lastID = lastID
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let filter: Filter
    public let lastID: String
    public let urlSession: URLSession

    public func response() async throws(AppError) -> GalleriesResult {
        let url = URLUtil.moreFrontpageList(host: host, filter: filter, lastID: lastID)
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0, host: host.url),
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
        host: GalleryHost,
        filter: Filter,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.filter = filter
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let filter: Filter
    public let urlSession: URLSession

    public func response() async throws(AppError) -> [Gallery] {
        let request = URLRequest(url: URLUtil.popularList(host: host, filter: filter))
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
        host: GalleryHost,
        filter: Filter,
        keyword: String,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.filter = filter
        self.keyword = keyword
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let filter: Filter
    public let keyword: String
    public let urlSession: URLSession

    public func response() async throws(AppError) -> GalleriesResult {
        let request = URLRequest(url: URLUtil.watchedList(host: host, filter: filter, keyword: keyword))
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                GalleriesResult(
                    pageNumber: Parser.parsePageNum(doc: $0),
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0, host: host.url),
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
        host: GalleryHost,
        filter: Filter,
        lastID: String,
        keyword: String,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.filter = filter
        self.lastID = lastID
        self.keyword = keyword
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let filter: Filter
    public let lastID: String
    public let keyword: String
    public let urlSession: URLSession

    public func response() async throws(AppError) -> GalleriesResult {
        let url = URLUtil.moreWatchedList(
            host: host,
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
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0, host: host.url),
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
        host: GalleryHost,
        favIndex: Int,
        keyword: String,
        sortOrder: FavoritesSortOrder? = nil,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.favIndex = favIndex
        self.keyword = keyword
        self.sortOrder = sortOrder
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let favIndex: Int
    public let keyword: String
    public var sortOrder: FavoritesSortOrder?
    public let urlSession: URLSession

    public func response() async throws(AppError) -> FavoritesGalleriesResult {
        let url = URLUtil.favoritesList(
            host: host,
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
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0, host: host.url),
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
        host: GalleryHost,
        favIndex: Int,
        lastID: String,
        lastTimestamp: String,
        keyword: String,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.favIndex = favIndex
        self.lastID = lastID
        self.lastTimestamp = lastTimestamp
        self.keyword = keyword
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let favIndex: Int
    public let lastID: String
    public var lastTimestamp: String
    public let keyword: String
    public let urlSession: URLSession

    public func response() async throws(AppError) -> FavoritesGalleriesResult {
        let url = URLUtil.moreFavoritesList(
            host: host,
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
                    dateSeekNavigation: Parser.parseDateSeekNavigation(doc: $0, host: host.url),
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
        host: GalleryHost,
        catIndex: Int,
        pageNum: Int? = nil,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.catIndex = catIndex
        self.pageNum = pageNum
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let catIndex: Int
    public var pageNum: Int?
    public let urlSession: URLSession

    public func response() async throws(AppError) -> (PageNumber, [Gallery]) {
        let url = URLUtil.toplistsList(host: host, catIndex: catIndex, pageNum: pageNum)
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
        host: GalleryHost,
        catIndex: Int,
        pageNum: Int,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.catIndex = catIndex
        self.pageNum = pageNum
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let catIndex: Int
    public let pageNum: Int
    public let urlSession: URLSession

    public func response() async throws(AppError) -> (PageNumber, [Gallery]) {
        let url = URLUtil.moreToplistsList(host: host, catIndex: catIndex, pageNum: pageNum)
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
