import Kanna
import AppModels
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
            // Greeting is optional detail enrichment; failure keeps the required detail payload.
            let greeting: Greeting?
            do {
                greeting = try Parser.parseGreeting(doc: document)
            } catch {
                greeting = nil
            }
            return GalleryDetailResponse(
                galleryDetail: detail,
                galleryState: state,
                apiKey: apiKey,
                greeting: greeting
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
    public let host: GalleryHost
    public let gid: String
    public let token: String
    public let urlSession: URLSession

    public init(
        host: GalleryHost,
        gid: String,
        token: String,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.gid = gid
        self.token = token
        self.urlSession = urlSession
    }

    public func response() async throws(AppError) -> DownloadVersionMetadata {
        guard let gid = Int(gid) else {
            throw AppError.notFound
        }
        return try await gdataResponse(host: host, gidlist: [[gid, token]], urlSession: urlSession) {
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
        if let detail = detail, let identifiers = url.galleryIdentifiers {
            return Gallery(
                gid: identifiers.gid,
                token: identifiers.token,
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
            guard let identifiers = resolvedGalleryURL.galleryIdentifiers else {
                throw AppError.parseFailed
            }
            return try parseResponse(doc: document) {
                let (detail, _) = try Parser.parseGalleryDetail(
                    doc: $0,
                    gid: identifiers.gid
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

    public func response() async throws(AppError) -> GalleryArchiveResponse {
        let (data, _) = try await fetch(URLRequest(url: archiveURL), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            let archive = try parseResponse(doc: document, Parser.parseGalleryArchive)
            // Funds are optional archive enrichment; failure keeps the required archive payload.
            do {
                let (galleryPoints, credits) = try Parser.parseCurrentFunds(doc: document)
                return GalleryArchiveResponse(
                    archive: archive,
                    galleryPoints: galleryPoints,
                    credits: credits
                )
            } catch {
                return GalleryArchiveResponse(archive: archive)
            }
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

    public func response() async throws(AppError) -> (galleryPoints: String, credits: String) {
        let (detailData, _) = try await fetch(URLRequest(url: galleryURL), in: urlSession)
        let archiveURL: URL
        do {
            let document = try htmlDocument(data: detailData)
            archiveURL = try parseResponse(doc: document) {
                guard let archiveURL = try Parser
                    .parseGalleryDetail(doc: $0, gid: gid)
                    .detail
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

}

public struct GalleryTorrentsRequest: Request {
    public init(
        host: GalleryHost,
        gid: String,
        token: String,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.gid = gid
        self.token = token
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let gid: String
    public let token: String
    public let urlSession: URLSession

    public func response() async throws(AppError) -> [GalleryTorrent] {
        let url = URLUtil.galleryTorrents(host: host, gid: gid, token: token)
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

private extension URL {
    /// Gallery identifiers read out of a `/g/<gid>/<token>` path, or `nil` when the URL is not
    /// gallery-shaped.
    ///
    /// Both call sites previously indexed path components 2 and 3 directly. The bound was
    /// never proven: `GalleryReverseRequest` accepts an arbitrary URL and, when
    /// `isGalleryImageURL` is set, a URL scraped out of remote markup, so a short path trapped
    /// rather than failing the parse. Extracting both identifiers behind one guard keeps the
    /// bounds proof at the access and routes a malformed URL into the existing error path.
    var galleryIdentifiers: (gid: String, token: String)? {
        // Skips the leading "/" and "g" components to reach <gid>/<token>.
        let identifiers = pathComponents.dropFirst(2)
        guard let gid = identifiers.first, let token = identifiers.dropFirst().first else {
            return nil
        }
        return (gid: gid, token: token)
    }
}
