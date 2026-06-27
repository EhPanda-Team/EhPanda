import Kanna
import Combine
import Foundation

// MARK: Response Types
struct GalleryMPVImageURLResponse {
    let imageURL: URL
    let originalImageURL: URL?
    let skipServerIdentifier: String
}

// MARK: Image Requests
struct MPVKeysRequest: Request {
    let mpvURL: URL
    var urlSession: URLSession = .shared
    var allowsCellular = true

    var publisher: AnyPublisher<(String, [Int: String]), AppError> {
        urlSession.dataTaskPublisher(
            for: urlRequest(url: mpvURL, allowsCellular: allowsCellular)
        )
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseMPVKeys) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct ThumbnailURLsRequest: Request {
    let galleryURL: URL
    let pageNum: Int
    var urlSession: URLSession = .shared
    var allowsCellular = true

    var publisher: AnyPublisher<[Int: URL], AppError> {
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
}

struct GalleryNormalImageURLsRequest: Request {
    let thumbnailURLs: [Int: URL]
    var urlSession: URLSession = .shared
    var allowsCellular = true

    var publisher: AnyPublisher<([Int: URL], [Int: URL]), AppError> {
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
}

struct ImageURLRefetchResult {
    let imageURL: URL
    let anotherImageURL: URL
    let response: HTTPURLResponse?
}

struct GalleryNormalImageURLRefetchRequest: Request {
    let index: Int
    let pageNum: Int
    let galleryURL: URL
    let thumbnailURL: URL?
    let storedImageURL: URL
    var urlSession: URLSession = .shared
    var allowsCellular = true

    var publisher: AnyPublisher<([Int: URL], HTTPURLResponse?), AppError> {
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

    func storedThumbnailURL() -> AnyPublisher<URL, AppError> {
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

    func renewThumbnailURL(stored: URL)
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

    func imageURL(thumbnailURL: URL, anotherImageURL: URL)
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

struct GalleryMPVImageURLRequest: Request {
    let gid: Int
    let index: Int
    let mpvKey: String
    let mpvImageKey: String
    let skipServerIdentifier: String?
    var apiURL: URL = Defaults.URL.api
    var urlSession: URLSession = .shared
    var allowsCellular = true
    var requiresSkipServerIdentifier = true

    var publisher: AnyPublisher<GalleryMPVImageURLResponse, AppError> {
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
}

// MARK: Tool
struct DataRequest: Request {
    let url: URL

    var publisher: AnyPublisher<Data, AppError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .genericRetry()
            .map(\.data)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
