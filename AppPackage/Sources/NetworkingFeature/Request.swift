import AppModels
import AppTools
import Foundation
import Kanna
import ParserFeature

public protocol Request {
    associatedtype Response: Sendable

    func response() async throws(AppError) -> Response
}

private struct ResponseParsingError: Error {
    let underlyingError: Error
    let responseError: AppError?
}

/// Re-parses UTF-8-repaired response bytes, or nil when the repair itself fails to parse.
///
/// Nil is the meaningful negative answer, not a swallowed error: the caller keeps the *original*
/// parse failure and its response context, which is the diagnostic the user is shown. Surfacing
/// the repair attempt's own error instead would replace that context with a strictly less useful
/// one, so it is deliberately discarded here rather than logged.
private func repairedHTMLDocument(from data: Data) -> HTMLDocument? {
    do {
        return try Kanna.HTML(html: data.utf8InvalidCharactersRipped, encoding: .utf8)
    } catch {
        return nil
    }
}

/// Reports whether a response is Cloudflare's interstitial challenge rather than the page asked for.
///
/// The contract is Cloudflare's own: a challenge page is served as `403` carrying `cf-mitigated:
/// challenge`. Nothing else is consulted — not the host, not the path, not the response body, and no
/// app setting. Page content is attacker-influenced and hosts move behind and out from behind the
/// wall over time, so classification stays purely response-driven and any `(data, response)` call
/// site can hand its response over unchanged.
///
/// A challenged `403` is a *successful* transport response, so `fetch(_:in:)` returns it on the
/// first attempt instead of burning its four-attempt retry budget; call this afterwards on the
/// returned response. This phase wires only the login flow to a UI reaction, but the helper is
/// deliberately free-standing so any request layer can adopt it when the wall spreads.
///
/// - Parameter response: The response to classify; `nil` and non-HTTP responses are not challenges.
public func isCloudflareChallenge(_ response: URLResponse?) -> Bool {
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 else {
        return false
    }
    // Header-name lookup is already case-insensitive; the value is compared the same way because
    // the header is untrusted input whose casing Cloudflare does not guarantee.
    let mitigation = httpResponse.value(forHTTPHeaderField: "cf-mitigated")
    return mitigation?.caseInsensitiveCompare("challenge") == .orderedSame
}

extension Request {

    /// Fetches a request with the four-attempt policy formerly supplied by `retry(3)`.
    ///
    /// Native async URLSession participates in structured cancellation, unlike the legacy
    /// continuation bridge. Cancellation therefore stops the HTTP request immediately; TCA still
    /// discards the cancelled effect's send, preserving user-visible behavior while saving work.
    public func fetch(
        _ request: URLRequest,
        in session: URLSession = .shared
    ) async throws(AppError) -> (data: Data, response: URLResponse) {
        var lastError: any Error = URLError(.unknown)
        for _ in 1...4 {
            do {
                return try await session.data(for: request)
            } catch {
                if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                    throw mapAppError(error: error)
                }
                lastError = error
            }
        }
        throw mapAppError(error: lastError)
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
                  let htmlDocument = repairedHTMLDocument(from: data)
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

    func encodeJSONObject(_ object: Any) throws(AppError) -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: object)
        } catch {
            throw .parseFailed
        }
    }

    func decodeJSONDictionary(_ data: Data) throws(AppError) -> [String: Any] {
        do {
            guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AppError.parseFailed
            }
            return dictionary
        } catch {
            throw .parseFailed
        }
    }

    private func parsedResponseError(
        from error: ResponseParsingError
    ) -> AppError? {
        error.responseError
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
    public init(
        urlSession: URLSession = .shared
    ) {
        self.urlSession = urlSession
    }
    public let urlSession: URLSession

    public func response() async throws(AppError) -> Greeting {
        let (data, _) = try await fetch(URLRequest(url: Defaults.URL.news), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseGreeting)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct UserInfoRequest: Request {
    public init(
        uid: String,
        urlSession: URLSession = .shared
    ) {
        self.uid = uid
        self.urlSession = urlSession
    }
    public let uid: String
    public let urlSession: URLSession

    public func response() async throws(AppError) -> User {
        let request = URLRequest(url: URLUtil.userInfo(uid: uid))
        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseUserInfo)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct FavoriteCategoriesRequest: Request {
    public init(
        host: GalleryHost,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let urlSession: URLSession

    public func response() async throws(AppError) -> [Int: String] {
        let (data, _) = try await fetch(URLRequest(url: Defaults.URL.uConfig(host: host)), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseFavoriteCategories)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct TagTranslatorRequest: Request {
    public init(
        language: TranslatableLanguage,
        updatedDate: Date,
        urlSession: URLSession = .shared
    ) {
        self.language = language
        self.updatedDate = updatedDate
        self.urlSession = urlSession
    }
    public let language: TranslatableLanguage
    public let updatedDate: Date
    public let urlSession: URLSession

    public var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = Defaults.DateFormat.github
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    // Returns the untouched DB JSON bytes plus the release date; decoding, OpenCC conversion, and
    // caching are done downstream by `FileClient` so this layer stays purely network.

    public func response() async throws(AppError) -> TagTranslatorPayload {
        let metadataRequest = urlRequest(
            url: URLUtil.githubAPI(repoName: language.repoName),
            allowsCellular: true
        )
        let (metadata, _) = try await fetch(metadataRequest, in: urlSession)
        let dictionary = try decodeJSONDictionary(metadata)
        guard let postedDateString = dictionary["published_at"] as? String,
            let postedDate = dateFormatter.date(from: postedDateString)
        else {
            throw AppError.parseFailed
        }
        guard postedDate > updatedDate else {
            throw AppError.noUpdates
        }

        do {
            let downloadRequest = urlRequest(
                url: URLUtil.githubDownload(
                    repoName: language.repoName,
                    fileName: language.remoteFilename
                ),
                allowsCellular: true
            )
            let (data, _) = try await urlSession.data(for: downloadRequest)
            return TagTranslatorPayload(data: data, updatedDate: postedDate)
        } catch {
            throw mapAppError(error: error)
        }
    }
}
