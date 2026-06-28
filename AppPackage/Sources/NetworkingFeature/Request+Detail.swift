import Kanna
import AppModels
import Combine
import Foundation
import Utilities
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

        let params: [String: Any] = [
            "method": "gdata",
            "gidlist": [[gid, token]],
            "namespace": 1
        ]

        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        return urlSession.dataTaskPublisher(for: request)
            .genericRetry()
            .map(\.data)
            .tryMap { data in
                try parseResponse(data: data) {
                    let response = try JSONDecoder()
                        .decode(GalleryVersionMetadataAPIResponse.self, from: $0)
                    guard let metadata = response.gmetadata.first?.versionMetadata else {
                        throw AppError.notFound
                    }
                    return metadata
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct GalleryReverseRequest: Request {
    public init(
        url: URL,
        isGalleryImageURL: Bool
    ) {
        self.url = url
        self.isGalleryImageURL = isGalleryImageURL
    }
    public let url: URL
    public let isGalleryImageURL: Bool

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

    public func galleryURL(url: URL) -> AnyPublisher<URL, AppError> {
        switch isGalleryImageURL {
        case true:
            return URLSession.shared.dataTaskPublisher(for: url)
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
        URLSession.shared.dataTaskPublisher(for: url)
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
        archiveURL: URL
    ) {
        self.archiveURL = archiveURL
    }
    public let archiveURL: URL

    public var publisher: AnyPublisher<GalleryArchiveResponse, AppError> {
        URLSession.shared.dataTaskPublisher(for: archiveURL)
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
}

public struct GalleryArchiveFundsRequest: Request {
    public init(
        gid: String,
        galleryURL: URL
    ) {
        self.gid = gid
        self.galleryURL = galleryURL
    }
    public let gid: String
    public let galleryURL: URL

    public var publisher: AnyPublisher<(String, String), AppError> {
        archiveURL(url: galleryURL)
            .genericRetry()
            .flatMap(funds)
            .eraseToAnyPublisher()
    }

    public func archiveURL(url: URL) -> AnyPublisher<URL, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
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
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseCurrentFunds) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct GalleryTorrentsRequest: Request {
    public init(
        gid: String,
        token: String
    ) {
        self.gid = gid
        self.token = token
    }
    public let gid: String
    public let token: String

    public var publisher: AnyPublisher<[GalleryTorrent], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.galleryTorrents(gid: gid, token: token))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .map(Parser.parseGalleryTorrents)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct GalleryPreviewURLsRequest: Request {
    public init(
        galleryURL: URL,
        pageNum: Int
    ) {
        self.galleryURL = galleryURL
        self.pageNum = pageNum
    }
    public let galleryURL: URL
    public let pageNum: Int

    public var publisher: AnyPublisher<[Int: URL], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.detailPage(url: galleryURL, pageNum: pageNum))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parsePreviewURLs) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
