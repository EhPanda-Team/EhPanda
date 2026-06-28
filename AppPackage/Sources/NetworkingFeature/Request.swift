import Kanna
import AppModels
import Combine
import Foundation
import ComposableArchitecture
import OpenCCExt
import AppTools
import ParserFeature

public protocol Request {
    associatedtype Response: Sendable

    var publisher: AnyPublisher<Response, AppError> { get }
}

private struct ResponseParsingError: Error {
    let underlyingError: Error
    let responseError: AppError?
}

extension Request {
    public func response() async -> Result<Response, AppError> {
        await publisher.receive(on: DispatchQueue.main).async()
    }

    public func urlRequest(
        url: URL,
        allowsCellular: Bool
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.allowsCellularAccess = allowsCellular
        return request
    }

    public func htmlDocument(data: Data) throws -> HTMLDocument {
        do {
            return try Kanna.HTML(html: data, encoding: .utf8)
        } catch {
            let content = String(
                data: data.utf8InvalidCharactersRipped,
                encoding: .utf8
            )
            throw ResponseParsingError(
                underlyingError: error,
                responseError: content.flatMap(
                    Parser.parseResponseError(content:)
                )
            )
        }
    }

    public func htmlDocumentWithUTF8Fallback(data: Data) throws -> HTMLDocument {
        do {
            return try Kanna.HTML(html: data, encoding: .utf8)
        } catch {
            guard let parseError = error as? ParseError,
                  parseError == .EncodingMismatch,
                  let htmlDocument = try? Kanna.HTML(
                    html: data.utf8InvalidCharactersRipped,
                    encoding: .utf8
                  )
            else {
                let content = String(
                    data: data.utf8InvalidCharactersRipped,
                    encoding: .utf8
                )
                throw ResponseParsingError(
                    underlyingError: error,
                    responseError: content.flatMap(
                        Parser.parseResponseError(content:)
                    )
                )
            }
            return htmlDocument
        }
    }

    public func parseResponse<T>(
        doc: HTMLDocument,
        _ parser: (HTMLDocument) throws -> T
    ) throws -> T {
        do {
            return try parser(doc)
        } catch {
            throw ResponseParsingError(
                underlyingError: error,
                responseError: Parser.parseResponseError(doc: doc)
            )
        }
    }

    public func parseResponse<T>(
        data: Data,
        _ parser: (Data) throws -> T
    ) throws -> T {
        do {
            return try parser(data)
        } catch {
            let content = String(
                data: data.utf8InvalidCharactersRipped,
                encoding: .utf8
            )
            throw ResponseParsingError(
                underlyingError: error,
                responseError: content.flatMap(
                    Parser.parseResponseError(content:)
                )
            )
        }
    }

    public func mapAppError(error: Error) -> AppError {
        if let responseParsingError = error as? ResponseParsingError {
            if let responseError = parsedResponseError(
                from: responseParsingError
            ) {
                return responseError
            }
            return mapAppError(
                error: responseParsingError.underlyingError
            )
        }

        switch error {
        case is ParseError:
            return .parseFailed

        case is URLError:
            return .networkingFailed

        case is DecodingError:
            return .parseFailed

        default:
            return error as? AppError ?? .unknown
        }
    }

    private func parsedResponseError(
        from error: ResponseParsingError
    ) -> AppError? {
        error.responseError
    }
}

extension Publisher {
    public func genericRetry() -> Publishers.Retry<Self> {
        retry(3)
    }

    public func async() async -> Result<Output, AppError> where Output: Sendable, Failure == AppError {
        do {
            let output = try await asyncOutput()
            return .success(output)
        } catch {
            return .failure(error as? AppError ?? .unknown)
        }
    }

    private func asyncOutput() async throws -> Output where Output: Sendable, Failure == AppError {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var finishedWithoutValue = true
            cancellable = first()
                .sink { result in
                    switch result {
                    case .finished:
                        if finishedWithoutValue {
                            continuation.resume(throwing: AppError.unknown)
                        }
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                } receiveValue: { value in
                    finishedWithoutValue = false
                    continuation.resume(returning: value)
                }
        }
    }
}
extension URLRequest {
    public mutating func setURLEncodedContentType() {
        setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    }
}
extension Dictionary where Key == String, Value == String {
    public func dictString() -> String {
        var array = [String]()
        keys.forEach { key in
            array.append(key + "=" + self[key].forceUnwrapped)
        }
        return array.joined(separator: "&")
    }
}

private extension URL {
    var galleryToken: String? {
        let filteredComponents = pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard filteredComponents.count >= 3 else { return nil }
        return filteredComponents[2]
    }
}

// MARK: - Response Types

public struct GalleriesResult: Sendable {
    public init(
        pageNumber: PageNumber,
        dateSeekNavigation: DateSeekNavigation? = nil,
        galleries: [Gallery]
    ) {
        self.pageNumber = pageNumber
        self.dateSeekNavigation = dateSeekNavigation
        self.galleries = galleries
    }
    public let pageNumber: PageNumber
    public let dateSeekNavigation: DateSeekNavigation?
    public let galleries: [Gallery]
}

public struct FavoritesGalleriesResult: Sendable {
    public init(
        pageNumber: PageNumber,
        dateSeekNavigation: DateSeekNavigation? = nil,
        sortOrder: FavoritesSortOrder? = nil,
        galleries: [Gallery]
    ) {
        self.pageNumber = pageNumber
        self.dateSeekNavigation = dateSeekNavigation
        self.sortOrder = sortOrder
        self.galleries = galleries
    }
    public let pageNumber: PageNumber
    public let dateSeekNavigation: DateSeekNavigation?
    public let sortOrder: FavoritesSortOrder?
    public let galleries: [Gallery]
}

public struct GalleryArchiveResponse: Sendable {
    public init(
        archive: GalleryArchive,
        galleryPoints: String? = nil,
        credits: String? = nil
    ) {
        self.archive = archive
        self.galleryPoints = galleryPoints
        self.credits = credits
    }
    public let archive: GalleryArchive
    public let galleryPoints: String?
    public let credits: String?
}

// MARK: Routine
public struct GreetingRequest: Request {
    public init() {}

    public var publisher: AnyPublisher<Greeting, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.news)
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseGreeting) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct UserInfoRequest: Request {
    public init(
        uid: String
    ) {
        self.uid = uid
    }
    public let uid: String

    public var publisher: AnyPublisher<User, AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.userInfo(uid: uid))
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseUserInfo) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct FavoriteCategoriesRequest: Request {
    public init() {}

    public var publisher: AnyPublisher<[Int: String], AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry()
            .tryMap { try htmlDocument(data: $0.data) }
            .tryMap { try parseResponse(doc: $0, Parser.parseFavoriteCategories) }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

public struct TagTranslatorRequest: Request {
    public init(
        language: TranslatableLanguage,
        updatedDate: Date
    ) {
        self.language = language
        self.updatedDate = updatedDate
    }
    public let language: TranslatableLanguage
    public let updatedDate: Date

    public var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = Defaults.DateFormat.github
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    public var publisher: AnyPublisher<TagTranslator, AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.githubAPI(repoName: language.repoName))
            .genericRetry().tryMap { data, _ -> Date in
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let postedDateString = dict["published_at"] as? String,
                      let postedDate = dateFormatter.date(from: postedDateString)
                else { throw AppError.parseFailed }

                guard postedDate > updatedDate
                else { throw AppError.noUpdates }
                return postedDate
            }
            .flatMap { date in
                URLSession.shared.dataTaskPublisher(
                    for: URLUtil.githubDownload(repoName: language.repoName, fileName: language.remoteFilename)
                )
                    .tryMap { data, _ in
                        let response = try JSONDecoder().decode(
                            EhTagTranslationDatabaseResponse.self, from: data
                        )
                        var translations = response.tagTranslations
                        guard !translations.isEmpty else { throw AppError.parseFailed }
                        if language == .traditionalChinese {
                            translations = translations.chtConverted
                        }
                        return TagTranslator(
                            language: language, updatedDate: date, translations: translations
                        )
                    }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
