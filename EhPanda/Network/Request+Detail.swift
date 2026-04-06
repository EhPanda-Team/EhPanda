//
//  Request+Detail.swift
//  EhPanda
//

import Kanna
import Combine
import Foundation

// MARK: Response Types
struct GalleryDetailResponse {
    let galleryDetail: GalleryDetail
    let galleryState: GalleryState
    let apiKey: String
    let greeting: Greeting?
}

// MARK: Fetch others
struct GalleryDetailRequest: Request {
    let gid: String
    let galleryURL: URL

    var publisher: AnyPublisher<GalleryDetailResponse, AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.galleryDetail(url: galleryURL))
            .genericRetry()
            .tryMap { resp -> HTMLDocument in
                do {
                    return try Kanna.HTML(html: resp.data, encoding: .utf8)
                } catch {
                    guard let parseError = error as? ParseError, parseError == .EncodingMismatch
                    else { throw error }

                    guard let htmlDocument = try? Kanna.HTML(
                        html: resp.data.utf8InvalidCharactersRipped,
                        encoding: .utf8
                    ) else {
                        throw error
                    }
                    return htmlDocument
                }
            }
            .tryMap { doc in
                let (detail, state) = try Parser.parseGalleryDetail(doc: doc, gid: gid)
                return (doc, detail, state, try Parser.parseAPIKey(doc: doc))
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

struct GalleryVersionMetadataRequest: Request {
    let gid: String
    let token: String
    let urlSession: URLSession

    init(gid: String, token: String, urlSession: URLSession = .shared) {
        self.gid = gid
        self.token = token
        self.urlSession = urlSession
    }

    var publisher: AnyPublisher<DownloadVersionMetadata, AppError> {
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
                let response = try JSONDecoder().decode(GalleryVersionMetadataAPIResponse.self, from: data)
                guard let metadata = response.gmetadata.first?.versionMetadata else {
                    throw AppError.notFound
                }
                return metadata
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryReverseRequest: Request {
    let url: URL
    let isGalleryImageURL: Bool

    func getGallery(from detail: GalleryDetail?, and url: URL) -> Gallery? {
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

    var publisher: AnyPublisher<Gallery, AppError> {
        galleryURL(url: url)
            .genericRetry()
            .flatMap(gallery)
            .eraseToAnyPublisher()
    }

    func galleryURL(url: URL) -> AnyPublisher<URL, AppError> {
        switch isGalleryImageURL {
        case true:
            return URLSession.shared.dataTaskPublisher(for: url)
                .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
                .tryMap(Parser.parseGalleryURL)
                .mapError(mapAppError)
                .eraseToAnyPublisher()

        case false:
            return Just(url)
                .setFailureType(to: AppError.self)
                .eraseToAnyPublisher()
        }
    }

    func gallery(url: URL) -> AnyPublisher<Gallery, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap {
                guard let (detail, _) = try? Parser.parseGalleryDetail(doc: $0, gid: url.pathComponents[2])
                else { return nil }

                return getGallery(from: detail, and: url)
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryArchiveRequest: Request {
    let archiveURL: URL

    var publisher: AnyPublisher<GalleryArchiveResponse, AppError> {
        URLSession.shared.dataTaskPublisher(for: archiveURL)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap { (html: HTMLDocument) -> (HTMLDocument, GalleryArchive) in
                let archive = try Parser.parseGalleryArchive(doc: html)
                return (html, archive)
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

struct GalleryArchiveFundsRequest: Request {
    let gid: String
    let galleryURL: URL

    var publisher: AnyPublisher<(String, String), AppError> {
        archiveURL(url: galleryURL)
            .genericRetry()
            .flatMap(funds)
            .eraseToAnyPublisher()
    }

    func archiveURL(url: URL) -> AnyPublisher<URL, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .compactMap { try? Parser.parseGalleryDetail(doc: $0, gid: gid).0.archiveURL }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    func funds(url: URL) -> AnyPublisher<(String, String), AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseCurrentFunds)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryTorrentsRequest: Request {
    let gid: String
    let token: String

    var publisher: AnyPublisher<[GalleryTorrent], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.galleryTorrents(gid: gid, token: token))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map(Parser.parseGalleryTorrents)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct GalleryPreviewURLsRequest: Request {
    let galleryURL: URL
    let pageNum: Int

    var publisher: AnyPublisher<[Int: URL], AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.detailPage(url: galleryURL, pageNum: pageNum))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parsePreviewURLs)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
