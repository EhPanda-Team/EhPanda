import Kanna
import AppModels
import Foundation
import ImageIO
import AppTools
import AnimatedImageFeature
import ParserFeature

// MARK: - Response Inspection Helpers
extension DownloadCoordinator {
    public func normalizedMimeType(
        _ response: URLResponse
    ) -> String? {
        if let mimeType = response.mimeType?.lowercased(),
           !mimeType.isEmpty {
            return mimeType
        }
        if let httpResponse = response as? HTTPURLResponse,
           let contentType = httpResponse.value(
            forHTTPHeaderField: "Content-Type"
           )?.lowercased(),
           let mimeType = contentType
            .split(separator: ";").first,
           !mimeType.isEmpty {
            return String(mimeType)
        }
        return nil
    }

    public func shouldInspectTextResponse(
        mimeType: String?,
        prefixData: Data
    ) -> Bool {
        if let mimeType {
            if mimeType.hasPrefix("image/") {
                return prefixLooksLikeHTML(prefixData)
            }
            if mimeType == "text/html"
                || mimeType == "text/plain" {
                return true
            }
            return prefixLooksLikeHTML(prefixData)
        }

        guard !prefixData.isKnownBinaryImageFormat else {
            return false
        }
        return true
    }

    public func prefixLooksLikeHTML(_ prefixData: Data) -> Bool {
        let prefix = String(
            bytes: prefixData,
            encoding: .utf8
        )?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() ?? ""
        guard !prefix.isEmpty else { return false }

        let htmlMarkers = [
            "<html",
            "<!doctype",
            "your ip address has been temporarily banned",
            "access to exhentai.org is restricted"
        ]
        return htmlMarkers.contains(where: prefix.contains)
    }

    public func prefixLooksLikeJSON(_ prefixData: Data) -> Bool {
        let prefix = String(
            bytes: prefixData,
            encoding: .utf8
        )?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let firstCharacter = prefix.first else { return false }

        return firstCharacter == "{" || firstCharacter == "["
    }

    func responseLooksLikeHTML(
        mimeType: String?,
        prefixData: Data,
        expectsHTML: Bool
    ) -> Bool {
        expectsHTML
            || mimeType == "text/html"
            || prefixLooksLikeHTML(prefixData)
    }

    func detectTextualDownloadError(
        data: Data,
        looksLikeHTML: Bool
    ) -> AppError? {
        let normalizedData = data.utf8InvalidCharactersRipped
        let rawContent = String(
            data: normalizedData,
            encoding: .utf8
        ) ?? ""
        if !looksLikeHTML {
            return Parser.parseResponseError(
                content: rawContent
            )
        }

        // DOM parsing is an optional probe; malformed HTML falls back to the raw
        // short-response parser below so validation behavior stays conservative.
        if let document = probeHTMLDocument(normalizedData),
        let error = Parser.parseResponseError(
            doc: document
        ) {
            return error
        }

        guard rawContent.count <= 1024 else {
            return nil
        }
        return Parser.parseResponseError(
            content: rawContent
        )
    }

    func isQuotaExceededResponse(
        fullData: Data?,
        fileURL: URL?,
        response: URLResponse,
        requestURL: URL?
    ) -> Bool {
        let urls = [requestURL, response.url]
            .compactMap(\.self)
        let lowercasedURLs = urls
            .map { $0.absoluteString.lowercased() }
        guard lowercasedURLs.contains(where: { url in
            Self.quotaExceededImageURLSuffixes
                .contains(where: url.hasSuffix)
        }) else {
            return false
        }

        let byteCount = fullData?.count
            ?? responseContentLength(response)
            ?? fileSize(at: fileURL)
        guard byteCount == ImagePlaceholderFingerprint.quotaExceededByteCount
        else {
            return false
        }

        let data: Data?
        if let fullData {
            data = fullData
        } else if let fileURL {
            // Loading file bytes is an optional fingerprint probe; failure means this
            // response cannot be confirmed as the quota placeholder by content.
            data = probeFileData(at: fileURL)
        } else {
            data = nil
        }
        guard let data else { return false }
        return isQuotaExceededAssetData(data)
    }

    func isAuthenticationRequiredPlaceholderResponse(
        response: URLResponse,
        requestURL: URL?
    ) -> Bool {
        [requestURL, response.url].contains {
            isAuthenticationRequiredPlaceholderURL($0)
        }
    }

    func isAuthenticationRequiredPlaceholderURL(
        _ url: URL?
    ) -> Bool {
        guard let url else { return false }
        let normalizedURL = url.absoluteString.lowercased()
        if normalizedURL.contains("bounce_login.php") {
            return true
        }
        return isKokomadePlaceholderURL(url)
    }

    func isKokomadePlaceholderURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        let normalizedURL = url.absoluteString.lowercased()
        return isExHentaiURL(url)
            && Self.kokomadeImageURLSuffixes
            .contains(where: normalizedURL.hasSuffix)
    }

    func isAuthenticationRequiredResponse(
        prefixData: Data,
        fullData: Data?,
        response: URLResponse,
        requestURL: URL?
    ) -> Bool {
        guard isExHentaiURL(requestURL)
                || isExHentaiURL(response.url) else {
            return false
        }
        guard normalizedMimeType(response) == "text/html"
        else {
            return false
        }
        guard fullData?.isEmpty ?? prefixData.isEmpty else {
            return false
        }

        let cookies = responseCookies(
            response: response,
            requestURL: requestURL
        )
        let hasYay = cookies.contains {
            $0.name == Defaults.Cookie.yay
                && !$0.value.isEmpty
        }
        let hasValidIgneous = cookies.contains {
            $0.name == Defaults.Cookie.igneous
                && !$0.value.isEmpty
                && $0.value != Defaults.Cookie.mystery
        }
        return hasYay && !hasValidIgneous
    }

    func responseCookies(
        response: URLResponse,
        requestURL: URL?
    ) -> [HTTPCookie] {
        let urls = [
            response.url,
            requestURL,
            Defaults.URL.exhentai,
            Defaults.URL.sexhentai
        ]
        .compactMap(\.self)
        var uniqueURLs = [URL]()
        for url in urls where !uniqueURLs.contains(url) {
            uniqueURLs.append(url)
        }

        var cookies = [HTTPCookie]()
        if let httpResponse = response as? HTTPURLResponse,
           let responseURL = httpResponse.url {
            let headerFields = httpResponse.allHeaderFields
                .reduce(into: [String: String]()) { partial, item in
                    guard let key = item.key as? String,
                          let value = item.value as? String
                    else { return }
                    partial[key] = value
                }
            cookies += HTTPCookie.cookies(
                withResponseHeaderFields: headerFields,
                for: responseURL
            )
        }

        for url in uniqueURLs {
            cookies += storedCookiesProvider(url)
        }
        return cookies
    }

    func isExHentaiURL(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else {
            return false
        }
        return host == "exhentai.org"
            || host.hasSuffix(".exhentai.org")
    }

    func statusCode(for response: URLResponse) -> Int? {
        (response as? HTTPURLResponse)?.statusCode
    }

    func responseContentLength(
        _ response: URLResponse
    ) -> Int? {
        if response.expectedContentLength > 0 {
            return Int(response.expectedContentLength)
        }
        if let httpResponse = response as? HTTPURLResponse,
           let header = httpResponse.value(
            forHTTPHeaderField: "Content-Length"
           ),
           let contentLength = Int(header) {
            return contentLength
        }
        return nil
    }

    func fileSize(at fileURL: URL?) -> Int? {
        guard let fileURL else { return nil }
        // File size is optional response metadata; an unavailable attribute leaves
        // callers to use response headers or decline placeholder classification.
        do {
            return try fileURL.resourceValues(
                forKeys: [.fileSizeKey]
            ).fileSize
        } catch {
            return nil
        }
    }

    /// Parses response bytes as a DOM purely to ask "does this HTML carry a known site error?".
    /// Every caller treats a `nil` document exactly like a document without an error and falls
    /// through to the raw-content or status-code classifiers, so malformed markup — which is the
    /// ordinary shape of the truncated or non-HTML payloads this probe is pointed at — is the
    /// expected negative answer rather than a failure worth logging.
    func probeHTMLDocument(_ data: Data) -> HTMLDocument? {
        do {
            return try Kanna.HTML(html: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Reads a downloaded file's bytes for optional placeholder/HTML fingerprinting. Callers use
    /// the bytes only to *add* a classification they could not otherwise make, so an unreadable
    /// file simply means "cannot be confirmed by content" — response metadata still drives the
    /// verdict. Failure is silent because these probes run against files that may legitimately
    /// have been cleaned up or never staged.
    func probeFileData(at fileURL: URL) -> Data? {
        do {
            return try Data(contentsOf: fileURL, options: .mappedIfSafe)
        } catch {
            return nil
        }
    }

    func isAuthenticationRequiredPlaceholderImageData(
        _ data: Data
    ) -> Bool {
        ImagePlaceholderFingerprint.match(data) == .authenticationRequired
    }

    func isQuotaExceededAssetData(_ data: Data) -> Bool {
        ImagePlaceholderFingerprint.match(data) == .quotaExceeded
    }

    func isDecodableImageData(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            nil
        ) else {
            return false
        }
        return CGImageSourceGetCount(source) > 0
    }

    func shouldSuppressFailurePersistence(
        for gid: String
    ) -> Bool {
        schedulingBlockedGalleryIDs.contains(gid)
            || Task.isCancelled
    }

    nonisolated static func isCancellationLikeError(
        _ error: Error
    ) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == URLError.cancelled.rawValue {
            return true
        }

        let message = nsError.localizedDescription
            .lowercased()
        return message.contains("cancellation")
            || message.contains("cancelled")
            || message.contains("canceled")
    }

    func isCancellationLikeAppError(
        _ error: AppError
    ) -> Bool {
        guard case .fileOperationFailed(let reason) = error
        else { return false }
        return Self.isCancellationLikeError(NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: reason]
        ))
    }
}
