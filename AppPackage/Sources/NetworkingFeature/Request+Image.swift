import Kanna
import AppModels
import Combine
import Foundation
import AppTools
import ParserFeature

// MARK: Response Types
public struct GalleryMPVImageURLResponse: Sendable {
    public init(
        imageURL: URL,
        originalImageURL: URL? = nil,
        skipServerIdentifier: String
    ) {
        self.imageURL = imageURL
        self.originalImageURL = originalImageURL
        self.skipServerIdentifier = skipServerIdentifier
    }
    public let imageURL: URL
    public let originalImageURL: URL?
    public let skipServerIdentifier: String
}

// MARK: Image Requests
public struct MPVKeysRequest: Request {
    public init(
        mpvURL: URL,
        urlSession: URLSession = .shared,
        allowsCellular: Bool = true
    ) {
        self.mpvURL = mpvURL
        self.urlSession = urlSession
        self.allowsCellular = allowsCellular
    }
    public let mpvURL: URL
    public var urlSession: URLSession = .shared
    public var allowsCellular = true

    public var publisher: AnyPublisher<(String, [Int: String]), AppError> {
        urlSession.dataTaskPublisher(
            for: urlRequest(url: mpvURL, allowsCellular: allowsCellular)
        )
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseMPVKeys) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> (String, [Int: String]) {
        let request = urlRequest(url: mpvURL, allowsCellular: allowsCellular)
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseMPVKeys)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct ThumbnailURLsRequest: Request {
    public init(
        galleryURL: URL,
        pageNum: Int,
        urlSession: URLSession = .shared,
        allowsCellular: Bool = true
    ) {
        self.galleryURL = galleryURL
        self.pageNum = pageNum
        self.urlSession = urlSession
        self.allowsCellular = allowsCellular
    }
    public let galleryURL: URL
    public let pageNum: Int
    public var urlSession: URLSession = .shared
    public var allowsCellular = true

    public var publisher: AnyPublisher<[Int: URL], AppError> {
        urlSession.dataTaskPublisher(
            for: urlRequest(
                url: URLUtil.detailPage(url: galleryURL, pageNum: pageNum),
                allowsCellular: allowsCellular
            )
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap { try parseResponse(doc: $0, Parser.parseThumbnailURLs) }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> [Int: URL] {
        let request = urlRequest(
            url: URLUtil.detailPage(url: galleryURL, pageNum: pageNum),
            allowsCellular: allowsCellular
        )
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseThumbnailURLs)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct GalleryNormalImageURLsRequest: Request, Sendable {
    public init(
        thumbnailURLs: [Int: URL],
        urlSession: URLSession = .shared,
        allowsCellular: Bool = true
    ) {
        self.thumbnailURLs = thumbnailURLs
        self.urlSession = urlSession
        self.allowsCellular = allowsCellular
    }
    public let thumbnailURLs: [Int: URL]
    public var urlSession: URLSession = .shared
    public var allowsCellular = true

    public var publisher: AnyPublisher<([Int: URL], [Int: URL]), AppError> {
        thumbnailURLs.publisher
            .flatMap { index, url in
                urlSession.dataTaskPublisher(
                    for: urlRequest(
                        url: url,
                        allowsCellular: allowsCellular
                    )
                )
                    .genericRetry()
                    .tryMap { try htmlDocument(data: $0.data) }
                    .tryMap { doc in
                        try parseResponse(doc: doc) {
                            try Parser.parseGalleryNormalImageURL(
                                doc: $0,
                                index: index
                            )
                        }
                    }
            }
            .collect()
            .map { infos in
                var imageURLs = [Int: URL]()
                var originalImageURLs = [Int: URL]()
                for info in infos {
                    imageURLs[info.index] = info.imageURL
                    originalImageURLs[info.index] = info.originalImageURL
                }
                return (imageURLs, originalImageURLs)
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> ([Int: URL], [Int: URL]) {
        do {
            return try await fanOutResponse()
        } catch {
            throw mapAppError(error: error)
        }
    }

    private func fanOutResponse() async throws -> ([Int: URL], [Int: URL]) {
        try await withThrowingTaskGroup(of: NormalImageInfo.self) { group in
            for (index, url) in thumbnailURLs {
                group.addTask { [self] in
                    try await normalImageInfo(index: index, url: url)
                }
            }

            var imageURLs = [Int: URL]()
            var originalImageURLs = [Int: URL]()
            for try await info in group {
                imageURLs[info.index] = info.imageURL
                originalImageURLs[info.index] = info.originalImageURL
            }
            return (imageURLs, originalImageURLs)
        }
    }

    private func normalImageInfo(index: Int, url: URL) async throws -> NormalImageInfo {
        let request = urlRequest(url: url, allowsCellular: allowsCellular)
        let (data, _) = try await fetch(request, in: urlSession)
        let document = try htmlDocument(data: data)
        let info = try parseResponse(doc: document) {
            try Parser.parseGalleryNormalImageURL(doc: $0, index: index)
        }
        return NormalImageInfo(
            index: info.index,
            imageURL: info.imageURL,
            originalImageURL: info.originalImageURL
        )
    }
}

private struct NormalImageInfo: Sendable {
    let index: Int
    let imageURL: URL
    let originalImageURL: URL?
}

public struct ImageURLRefetchResult: Sendable {
    public init(
        imageURL: URL,
        anotherImageURL: URL,
        response: HTTPURLResponse? = nil
    ) {
        self.imageURL = imageURL
        self.anotherImageURL = anotherImageURL
        self.response = response
    }
    public let imageURL: URL
    public let anotherImageURL: URL
    public let response: HTTPURLResponse?
}

public struct GalleryNormalImageURLRefetchRequest: Request {
    public init(
        index: Int,
        pageNum: Int,
        galleryURL: URL,
        thumbnailURL: URL? = nil,
        storedImageURL: URL,
        urlSession: URLSession = .shared,
        allowsCellular: Bool = true
    ) {
        self.index = index
        self.pageNum = pageNum
        self.galleryURL = galleryURL
        self.thumbnailURL = thumbnailURL
        self.storedImageURL = storedImageURL
        self.urlSession = urlSession
        self.allowsCellular = allowsCellular
    }
    public let index: Int
    public let pageNum: Int
    public let galleryURL: URL
    public let thumbnailURL: URL?
    public let storedImageURL: URL
    public var urlSession: URLSession = .shared
    public var allowsCellular = true

    public var publisher: AnyPublisher<([Int: URL], HTTPURLResponse?), AppError> {
        storedThumbnailURL()
            .flatMap(renewThumbnailURL)
            .flatMap(imageURL)
            .genericRetry()
            .map { result in
                (
                    [index: result.imageURL != storedImageURL
                        ? result.imageURL : result.anotherImageURL],
                    result.response
                )
            }
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> ([Int: URL], HTTPURLResponse?) {
        var lastError: any Error = URLError(.unknown)
        for _ in 1...4 {
            do {
                let result = try await refetchAttempt()
                return (
                    [index: result.imageURL != storedImageURL
                        ? result.imageURL : result.anotherImageURL],
                    result.response
                )
            } catch {
                if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                    throw mapAppError(error: error)
                }
                lastError = error
            }
        }
        throw mapAppError(error: lastError)
    }

    private func refetchAttempt() async throws -> ImageURLRefetchResult {
        let storedThumbnail: URL
        if let thumbnailURL {
            storedThumbnail = thumbnailURL
        } else {
            let request = urlRequest(
                url: URLUtil.detailPage(url: galleryURL, pageNum: pageNum),
                allowsCellular: allowsCellular
            )
            let (data, _) = try await urlSession.data(for: request)
            let document = try htmlDocument(data: data)
            let thumbnails = try parseResponse(doc: document, Parser.parseThumbnailURLs)
            guard let thumbnail = thumbnails[index] else {
                throw AppError.unknown
            }
            storedThumbnail = thumbnail
        }

        let renewalRequest = urlRequest(url: storedThumbnail, allowsCellular: allowsCellular)
        let (renewalData, _) = try await urlSession.data(for: renewalRequest)
        let renewalDocument = try htmlDocument(data: renewalData)
        let (renewedThumbnail, anotherImageURL) = try parseResponse(doc: renewalDocument) {
            let identifier = try Parser.parseSkipServerIdentifier(doc: $0)
            let imageURL = try Parser.parseGalleryNormalImageURL(
                doc: $0,
                index: index
            ).imageURL
            return (
                storedThumbnail.appending(queryItems: [.skipServerIdentifier: identifier]),
                imageURL
            )
        }

        let imageRequest = urlRequest(url: renewedThumbnail, allowsCellular: allowsCellular)
        let (imageData, response) = try await urlSession.data(for: imageRequest)
        let imageDocument = try htmlDocument(data: imageData)
        let info = try parseResponse(doc: imageDocument) {
            try Parser.parseGalleryNormalImageURL(doc: $0, index: index)
        }
        return ImageURLRefetchResult(
            imageURL: anotherImageURL,
            anotherImageURL: info.imageURL,
            response: response as? HTTPURLResponse
        )
    }

    public func storedThumbnailURL() -> AnyPublisher<URL, AppError> {
        if let thumbnailURL = thumbnailURL {
            return Just(thumbnailURL)
                .setFailureType(to: AppError.self)
                .eraseToAnyPublisher()
        } else {
            return urlSession.dataTaskPublisher(
                for: urlRequest(
                    url: URLUtil.detailPage(url: galleryURL, pageNum: pageNum),
                    allowsCellular: allowsCellular
                )
            )
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseThumbnailURLs) }
            .compactMap({ thumbnailURLs in thumbnailURLs[index] })
            .mapError(mapAppError)
            .eraseToAnyPublisher()
        }
    }

    public func renewThumbnailURL(stored: URL)
    -> AnyPublisher<(URL, URL), AppError> {
        urlSession.dataTaskPublisher(
            for: urlRequest(url: stored, allowsCellular: allowsCellular)
        )
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { doc in
                try parseResponse(doc: doc) {
                    let identifier = try Parser.parseSkipServerIdentifier(doc: $0)
                    let imageURL = try Parser.parseGalleryNormalImageURL(
                        doc: $0, index: index
                    ).imageURL
                    return (
                        stored.appending(
                            queryItems: [.skipServerIdentifier: identifier]
                        ),
                        imageURL
                    )
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    public func imageURL(thumbnailURL: URL, anotherImageURL: URL)
    -> AnyPublisher<ImageURLRefetchResult, AppError> {
        urlSession.dataTaskPublisher(
            for: urlRequest(url: thumbnailURL, allowsCellular: allowsCellular)
        )
            .tryMap {
                (
                    try htmlDocument(data: $0.data),
                    $0.response as? HTTPURLResponse
                )
            }
            .tryMap { html, response in
                try parseResponse(doc: html) {
                    (
                        try Parser.parseGalleryNormalImageURL(
                            doc: $0,
                            index: index
                        ),
                        response
                    )
                }
            }
            .map { info, response in
                ImageURLRefetchResult(
                    imageURL: anotherImageURL,
                    anotherImageURL: info.imageURL,
                    response: response
                )
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct GalleryMPVImageURLRequest: Request {
    public init(
        gid: Int,
        index: Int,
        mpvKey: String,
        mpvImageKey: String,
        skipServerIdentifier: String? = nil,
        apiURL: URL = Defaults.URL.api,
        urlSession: URLSession = .shared,
        allowsCellular: Bool = true,
        requiresSkipServerIdentifier: Bool = true
    ) {
        self.gid = gid
        self.index = index
        self.mpvKey = mpvKey
        self.mpvImageKey = mpvImageKey
        self.skipServerIdentifier = skipServerIdentifier
        self.apiURL = apiURL
        self.urlSession = urlSession
        self.allowsCellular = allowsCellular
        self.requiresSkipServerIdentifier = requiresSkipServerIdentifier
    }
    public let gid: Int
    public let index: Int
    public let mpvKey: String
    public let mpvImageKey: String
    public let skipServerIdentifier: String?
    public var apiURL: URL = Defaults.URL.api
    public var urlSession: URLSession = .shared
    public var allowsCellular = true
    public var requiresSkipServerIdentifier = true

    public var publisher: AnyPublisher<GalleryMPVImageURLResponse, AppError> {
        var params: [String: Any] = [
            "method": "imagedispatch",
            "gid": gid,
            "page": index,
            "imgkey": mpvImageKey,
            "mpvkey": mpvKey
        ]
        if let skipServerIdentifier = skipServerIdentifier {
            params["nl"] = skipServerIdentifier
        }

        var request = urlRequest(
            url: apiURL,
            allowsCellular: allowsCellular
        )
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: params, options: []
        )

        return urlSession.dataTaskPublisher(for: request)
            .genericRetry()
            .map(\.data)
            .tryMap { data in
                try parseResponse(data: data) {
                    guard let dict = try JSONSerialization
                            .jsonObject(with: $0) as? [String: Any],
                          let imageURLString = dict["i"] as? String,
                          let imageURL = URL(string: imageURLString)
                    else { throw AppError.parseFailed }

                    var skipServerIdentifier: String?

                    if let integerIdentifier = dict["s"] as? Int {
                        skipServerIdentifier = integerIdentifier.description
                    } else if let stringIdentifier = dict["s"] as? String {
                        skipServerIdentifier = stringIdentifier
                    }

                    if skipServerIdentifier == nil,
                       requiresSkipServerIdentifier {
                        throw AppError.parseFailed
                    }

                    if let originalSlice = dict["lf"] as? String {
                        let originalImageURL = Defaults.URL.host
                            .appendingPathComponent(originalSlice)
                        return GalleryMPVImageURLResponse(
                            imageURL: imageURL,
                            originalImageURL: originalImageURL,
                            skipServerIdentifier: skipServerIdentifier ?? ""
                        )
                    } else {
                        return GalleryMPVImageURLResponse(
                            imageURL: imageURL,
                            originalImageURL: nil,
                            skipServerIdentifier: skipServerIdentifier ?? ""
                        )
                    }
                }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> GalleryMPVImageURLResponse {
        var params: [String: Any] = [
            "method": "imagedispatch",
            "gid": gid,
            "page": index,
            "imgkey": mpvImageKey,
            "mpvkey": mpvKey
        ]
        if let skipServerIdentifier = skipServerIdentifier {
            params["nl"] = skipServerIdentifier
        }

        var request = urlRequest(url: apiURL, allowsCellular: allowsCellular)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        let (data, _) = try await fetch(request, in: urlSession)
        do {
            return try parseResponse(data: data) {
                guard
                    let dictionary = try JSONSerialization.jsonObject(with: $0) as? [String: Any],
                    let imageURLString = dictionary["i"] as? String,
                    let imageURL = URL(string: imageURLString)
                else {
                    throw AppError.parseFailed
                }

                let identifier: String?
                if let integerIdentifier = dictionary["s"] as? Int {
                    identifier = integerIdentifier.description
                } else {
                    identifier = dictionary["s"] as? String
                }

                if identifier == nil, requiresSkipServerIdentifier {
                    throw AppError.parseFailed
                }

                let originalImageURL = (dictionary["lf"] as? String).map {
                    Defaults.URL.host.appendingPathComponent($0)
                }
                return GalleryMPVImageURLResponse(
                    imageURL: imageURL,
                    originalImageURL: originalImageURL,
                    skipServerIdentifier: identifier ?? ""
                )
            }
        } catch {
            throw mapAppError(error: error)
        }
    }
}

// MARK: Tool
public struct DataRequest: Request {
    public init(
        url: URL,
        urlSession: URLSession = .shared
    ) {
        self.url = url
        self.urlSession = urlSession
    }
    public let url: URL
    public let urlSession: URLSession

    public var publisher: AnyPublisher<Data, AppError> {
        urlSession.dataTaskPublisher(for: url)
            .genericRetry()
            .map(\.data)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    public func response() async throws(AppError) -> Data {
        try await fetch(URLRequest(url: url), in: urlSession).data
    }
}
