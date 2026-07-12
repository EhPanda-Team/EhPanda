import Kanna
import AppModels
import Combine
import Foundation
import AppTools
import ParserFeature

// MARK: Response Types
public struct GalleryDetailResponse: Sendable {
    public init(
        galleryDetail: GalleryDetail,
        galleryState: GalleryState,
        apiKey: String,
        greeting: Greeting? = nil
    ) {
        self.galleryDetail = galleryDetail
        self.galleryState = galleryState
        self.apiKey = apiKey
        self.greeting = greeting
    }
    public let galleryDetail: GalleryDetail
    public let galleryState: GalleryState
    public let apiKey: String
    public let greeting: Greeting?
}

// MARK: Fetch others
public struct GalleryDetailRequest: Request {
    public init(
        gid: String,
        galleryURL: URL,
        urlSession: URLSession = .shared,
        allowsCellular: Bool = true
    ) {
        self.gid = gid
        self.galleryURL = galleryURL
        self.urlSession = urlSession
        self.allowsCellular = allowsCellular
    }
    public let gid: String
    public let galleryURL: URL
    public var urlSession: URLSession = .shared
    public var allowsCellular = true

    public var publisher: AnyPublisher<GalleryDetailResponse, AppError> {
        urlSession.dataTaskPublisher(
            for: urlRequest(
                url: URLUtil.galleryDetail(url: galleryURL),
                allowsCellular: allowsCellular
            )
        )
            .genericRetry()
            .tryMap { try htmlDocumentWithUTF8Fallback(data: $0.data) }
            .tryMap { doc in
                try parseResponse(doc: doc) {
                    let (detail, state) = try Parser.parseGalleryDetail(
                        doc: $0,
                        gid: gid
                    )
                    return (doc, detail, state, try Parser.parseAPIKey(doc: $0))
                }
            }
            .mapError(mapAppError)
            .map { doc, detail, state, apiKey in
                GalleryDetailResponse(
                    galleryDetail: detail,
                    galleryState: state,
                    apiKey: apiKey,
                    greeting: try? Parser.parseGreeting(doc: doc)
                )
            }
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> GalleryDetailResponse {
        let request = urlRequest(
            url: URLUtil.galleryDetail(url: galleryURL),
            allowsCellular: allowsCellular
        )
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocumentWithUTF8Fallback(data: data)
            let (detail, state, apiKey) = try parseResponse(doc: document) {
                let (detail, state) = try Parser.parseGalleryDetail(doc: $0, gid: gid)
                return (detail, state, try Parser.parseAPIKey(doc: $0))
            }
            return GalleryDetailResponse(
                galleryDetail: detail,
                galleryState: state,
                apiKey: apiKey,
                greeting: try? Parser.parseGreeting(doc: document)
            )
        } catch {
            throw mapAppError(error: error)
        }
    }
}

private struct GalleryVersionMetadata: Decodable {
    let gid: Int
    let token: String
    let currentGID: Int?
    let currentKey: String?
    let parentGID: Int?
    let parentKey: String?
    let firstGID: Int?
    let firstKey: String?

    enum CodingKeys: String, CodingKey {
        case gid
        case token
        case currentGID = "current_gid"
        case currentKey = "current_key"
        case parentGID = "parent_gid"
        case parentKey = "parent_key"
        case firstGID = "first_gid"
        case firstKey = "first_key"
    }

    var versionMetadata: DownloadVersionMetadata {
        DownloadVersionMetadata(
            gid: String(gid),
            token: token,
            currentGID: currentGID.map(String.init),
            currentKey: currentKey,
            parentGID: parentGID.map(String.init),
            parentKey: parentKey,
            firstGID: firstGID.map(String.init),
            firstKey: firstKey
        )
    }
}

private struct GalleryVersionMetadataAPIResponse: Decodable {
    let gmetadata: [GalleryVersionMetadata]
}

public struct GalleryVersionMetadataRequest: Request {
    public let gid: String
    public let token: String
    public let urlSession: URLSession

    public init(gid: String, token: String, urlSession: URLSession = .shared) {
        self.gid = gid
        self.token = token
        self.urlSession = urlSession
    }

    public var publisher: AnyPublisher<DownloadVersionMetadata, AppError> {
        guard let gid = Int(gid) else {
            return Fail(error: AppError.notFound)
                .eraseToAnyPublisher()
        }
        return gdataPublisher(gidlist: [[gid, token]], urlSession: urlSession) {
            let response = try JSONDecoder()
                .decode(GalleryVersionMetadataAPIResponse.self, from: $0)
            guard let metadata = response.gmetadata.first?.versionMetadata else {
                throw AppError.notFound
            }
            return metadata
        }
    }

    public func response() async throws(AppError) -> DownloadVersionMetadata {
        guard let gid = Int(gid) else {
            throw AppError.notFound
        }
        return try await gdataResponse(gidlist: [[gid, token]], urlSession: urlSession) {
            let response = try JSONDecoder()
                .decode(GalleryVersionMetadataAPIResponse.self, from: $0)
            guard let metadata = response.gmetadata.first?.versionMetadata else {
                throw AppError.notFound
            }
            return metadata
        }
    }
}

public struct GalleryReverseRequest: Request {
    public init(
        url: URL,
        isGalleryImageURL: Bool,
        urlSession: URLSession = .shared
    ) {
        self.url = url
        self.isGalleryImageURL = isGalleryImageURL
        self.urlSession = urlSession
    }
    public let url: URL
    public let isGalleryImageURL: Bool
    public let urlSession: URLSession

    public func getGallery(from detail: GalleryDetail?, and url: URL) -> Gallery? {
        if let detail = detail {
            return Gallery(
                gid: url.pathComponents[2],
                token: url.pathComponents[3],
                title: detail.title,
                rating: detail.rating,
                tags: [],
                category: detail.category,
                uploader: detail.uploader,
                pageCount: detail.pageCount,
                postedDate: detail.postedDate,
                coverURL: detail.coverURL,
                galleryURL: url
            )
        } else {
            return nil
        }
    }

    public var publisher: AnyPublisher<Gallery, AppError> {
        galleryURL(url: url)
            .genericRetry()
            .flatMap(gallery)
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> Gallery {
        let resolvedGalleryURL: URL
        if isGalleryImageURL {
            let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
            do {
                let document = try htmlDocument(data: data)
                resolvedGalleryURL = try parseResponse(doc: document, Parser.parseGalleryURL)
            } catch {
                throw mapAppError(error: error)
            }
        } else {
            resolvedGalleryURL = url
        }

        do {
            let (data, _) = try await urlSession.data(for: URLRequest(url: resolvedGalleryURL))
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document) {
                let (detail, _) = try Parser.parseGalleryDetail(
                    doc: $0,
                    gid: resolvedGalleryURL.pathComponents[2]
                )
                guard let gallery = getGallery(from: detail, and: resolvedGalleryURL) else {
                    throw AppError.parseFailed
                }
                return gallery
            }
        } catch {
            throw mapAppError(error: error)
        }
    }

    public func galleryURL(url: URL) -> AnyPublisher<URL, AppError> {
        switch isGalleryImageURL {
        case true:
            return urlSession.dataTaskPublisher(for: url)
                .tryMap { try htmlDocument(data: $0.data) }
                .tryMap { try parseResponse(doc: $0, Parser.parseGalleryURL) }
                .mapError(mapAppError)
                .eraseToAnyPublisher()

        case false:
            return Just(url)
                .setFailureType(to: AppError.self)
                .eraseToAnyPublisher()
        }
    }

    public func gallery(url: URL) -> AnyPublisher<Gallery, AppError> {
        urlSession.dataTaskPublisher(for: url)
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { doc in
                try parseResponse(doc: doc) {
                    let (detail, _) = try Parser.parseGalleryDetail(
                        doc: $0,
                        gid: url.pathComponents[2]
                    )
                    guard let gallery = getGallery(from: detail, and: url)
                    else { throw AppError.parseFailed }
                    return gallery
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct GalleryArchiveRequest: Request {
    public init(
        archiveURL: URL,
        urlSession: URLSession = .shared
    ) {
        self.archiveURL = archiveURL
        self.urlSession = urlSession
    }
    public let archiveURL: URL
    public let urlSession: URLSession

    public var publisher: AnyPublisher<GalleryArchiveResponse, AppError> {
        urlSession.dataTaskPublisher(for: archiveURL)
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { (html: HTMLDocument) -> (HTMLDocument, GalleryArchive) in
                try parseResponse(doc: html) {
                    let archive = try Parser.parseGalleryArchive(doc: $0)
                    return (html, archive)
                }
            }
            .map { html, archive in
                guard let (currentGP, currentCredits) = try? Parser.parseCurrentFunds(doc: html)
                else { return GalleryArchiveResponse(archive: archive, galleryPoints: nil, credits: nil) }
                return GalleryArchiveResponse(archive: archive, galleryPoints: currentGP, credits: currentCredits)
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> GalleryArchiveResponse {
        let (data, _) = try await fetch(URLRequest(url: archiveURL), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            let archive = try parseResponse(doc: document, Parser.parseGalleryArchive)
            guard let (galleryPoints, credits) = try? Parser.parseCurrentFunds(doc: document) else {
                return GalleryArchiveResponse(archive: archive)
            }
            return GalleryArchiveResponse(
                archive: archive,
                galleryPoints: galleryPoints,
                credits: credits
            )
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct GalleryArchiveFundsRequest: Request {
    public init(
        gid: String,
        galleryURL: URL,
        urlSession: URLSession = .shared
    ) {
        self.gid = gid
        self.galleryURL = galleryURL
        self.urlSession = urlSession
    }
    public let gid: String
    public let galleryURL: URL
    public let urlSession: URLSession

    public var publisher: AnyPublisher<(String, String), AppError> {
        archiveURL(url: galleryURL)
            .genericRetry()
            .flatMap(funds)
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> (String, String) {
        let (detailData, _) = try await fetch(URLRequest(url: galleryURL), in: urlSession)
        let archiveURL: URL
        do {
            let document = try htmlDocument(data: detailData)
            archiveURL = try parseResponse(doc: document) {
                guard let archiveURL = try Parser
                    .parseGalleryDetail(doc: $0, gid: gid)
                    .0
                    .archiveURL
                else {
                    throw AppError.parseFailed
                }
                return archiveURL
            }
        } catch {
            throw mapAppError(error: error)
        }

        do {
            let (fundsData, _) = try await urlSession.data(for: URLRequest(url: archiveURL))
            let document = try htmlDocument(data: fundsData)
            return try parseResponse(doc: document, Parser.parseCurrentFunds)
        } catch {
            throw mapAppError(error: error)
        }
    }

    public func archiveURL(url: URL) -> AnyPublisher<URL, AppError> {
        urlSession.dataTaskPublisher(for: url)
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { doc in
                try parseResponse(doc: doc) {
                    guard let archiveURL = try Parser
                        .parseGalleryDetail(doc: $0, gid: gid)
                        .0
                        .archiveURL
                    else { throw AppError.parseFailed }
                    return archiveURL
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    public func funds(url: URL) -> AnyPublisher<(String, String), AppError> {
        urlSession.dataTaskPublisher(for: url)
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseCurrentFunds) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct GalleryTorrentsRequest: Request {
    public init(
        gid: String,
        token: String,
        urlSession: URLSession = .shared
    ) {
        self.gid = gid
        self.token = token
        self.urlSession = urlSession
    }
    public let gid: String
    public let token: String
    public let urlSession: URLSession

    public var publisher: AnyPublisher<[GalleryTorrent], AppError> {
        urlSession.dataTaskPublisher(for: URLUtil.galleryTorrents(gid: gid, token: token))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .map(Parser.parseGalleryTorrents)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> [GalleryTorrent] {
        let url = URLUtil.galleryTorrents(gid: gid, token: token)
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            return Parser.parseGalleryTorrents(doc: try htmlDocument(data: data))
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct GalleryPreviewURLsRequest: Request {
    public init(
        galleryURL: URL,
        pageNum: Int,
        urlSession: URLSession = .shared
    ) {
        self.galleryURL = galleryURL
        self.pageNum = pageNum
        self.urlSession = urlSession
    }
    public let galleryURL: URL
    public let pageNum: Int
    public let urlSession: URLSession

    public var publisher: AnyPublisher<[Int: URL], AppError> {
        urlSession.dataTaskPublisher(for: URLUtil.detailPage(url: galleryURL, pageNum: pageNum))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parsePreviewURLs) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> [Int: URL] {
        let url = URLUtil.detailPage(url: galleryURL, pageNum: pageNum)
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parsePreviewURLs)
        } catch {
            throw mapAppError(error: error)
        }
    }
}
