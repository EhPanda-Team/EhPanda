import AppModels
import Foundation
import Kanna
import Resources

extension Parser {
    public static func parseResponseError(doc: HTMLDocument) -> AppError? {
        if let banInterval = parseBanInterval(doc: doc) {
            return .ipBanned(banInterval)
        }
        // Ex login failures commonly surface as a kokomade placeholder wall when `igneous` is missing.
        // Reference: https://github.com/OpportunityLiu/E-Viewer/issues/124
        if doc.at_xpath("//img[contains(@src, 'kokomade.jpg')]") != nil {
            return .authenticationRequired
        }

        for candidate in responseErrorCandidates(doc: doc) {
            if let error = parseResponseError(content: candidate) {
                return error
            }
        }
        return nil
    }

    /// The message the forum software puts in its own error box, if the page carries one.
    ///
    /// A rejected login is an HTTP 200 carrying an ordinary forum page. A wrong password, a
    /// temporary lockout after repeated failures, and a missing field all share that status code and
    /// all leave the auth cookies unset, so the status line and the cookie jar cannot tell them
    /// apart — this box is the only thing that can. Its text is passed through verbatim rather than
    /// matched against known phrasings, because the useful part is whatever the server chose to say,
    /// including messages this app has never seen.
    ///
    /// The result is untrusted remote text on its way to a log, so it is stripped of markup and
    /// length-bounded here rather than at each call site.
    public static func parseLoginErrorMessage(content: String) -> String? {
        let marker = "the error returned was"
        let stripped = content
            .replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
        guard let markerRange = stripped.range(of: marker, options: .caseInsensitive) else { return nil }
        let message = stripped[markerRange.upperBound...]
            .split(separator: "\n")
            .lazy
            .map({ $0.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\r\n")) })
            .first(where: { !$0.isEmpty })
        guard let message else { return nil }
        return String(message.prefix(200))
    }

    public static func parseResponseError(content: String) -> AppError? {
        let normalizedContent = content.lowercased()
        guard !normalizedContent.isEmpty else { return nil }

        // Ex login failures commonly surface as a kokomade placeholder wall when `igneous` is missing.
        // Reference: https://github.com/OpportunityLiu/E-Viewer/issues/124
        if normalizedContent.contains("kokomade.jpg")
            || normalizedContent.contains("access to exhentai.org is restricted") {
            return .authenticationRequired
        }
        // JDownloader matches these image-limit texts to distinguish quota exhaustion from generic HTML failures.
        // Reference: https://github.com/mirror/jdownloader/blob/master/src/jd/plugins/hoster/EHentaiOrg.java
        if normalizedContent.contains("you have exceeded your image viewing limits")
            || normalizedContent.contains(
                "you have reached the image limit, and do not have sufficient gp to buy a download quota"
            ) {
            return .quotaExceeded
        }
        // `Gallery Not Available` is intentionally not mapped to `.expunged` in the download parser.
        // gallery-dl treats `404 + Gallery Not Available` as an authorization-like unavailable state:
        // https://github.com/mikf/gallery-dl/blob/master/gallery_dl/extractor/exhentai.py
        if normalizedContent.contains("gallery not available")
            || normalizedContent.contains(String(localized: .RConstant.responseGalleryUnavailable).lowercased()) {
            return nil
        }
        // JDownloader treats `bounce_login.php` as an account / re-login required signal for EH/EX.
        // Reference: https://github.com/mirror/jdownloader/blob/master/src/jd/plugins/hoster/EHentaiOrg.java
        if normalizedContent.contains("bounce_login.php"),
           !looksLikeGalleryDetailMarkup(normalizedContent) {
            return .authenticationRequired
        }
        // gallery-dl treats `Key missing` and `Gallery not found` as gallery-level not-found conditions.
        // Reference: https://github.com/mikf/gallery-dl/blob/master/gallery_dl/extractor/exhentai.py
        if normalizedContent.contains("gallery not found")
            || normalizedContent.contains("key missing") {
            return .notFound
        }
        // gallery-dl treats `Invalid page` and `Keep trying` as image-page not-found conditions.
        // Reference: https://github.com/mikf/gallery-dl/blob/master/gallery_dl/extractor/exhentai.py
        if normalizedContent.contains("invalid page")
            || normalizedContent.contains("keep trying") {
            return .notFound
        }
        return nil
    }
}

// MARK: Helpers
private extension Parser {
    static func responseErrorCandidates(doc: HTMLDocument) -> [String] {
        var candidates = [String]()

        let directCandidates = [
            doc.at_xpath("//title")?.text,
            doc.at_xpath("//h1")?.text,
            doc.at_xpath("//div[@class='d']//p")?.text
        ]
        for candidate in directCandidates.compactMap(\.self) {
            let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedCandidate.isEmpty, !candidates.contains(trimmedCandidate) else { continue }
            candidates.append(trimmedCandidate)
        }

        if let bodyText = doc.body?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bodyText.isEmpty,
           bodyText.count <= 1024,
           !candidates.contains(bodyText) {
            candidates.append(bodyText)
        }

        if let bodyContent = doc.body?.innerHTML?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bodyContent.isEmpty,
           bodyContent.count <= 2048,
           !candidates.contains(bodyContent) {
            candidates.append(bodyContent)
        }

        return candidates
    }

    static func looksLikeGalleryDetailMarkup(_ normalizedContent: String) -> Bool {
        normalizedContent.contains(#"id="gd1""#)
        || normalizedContent.contains(#"id='gd1'"#)
        || normalizedContent.contains(#"id="gdt""#)
        || normalizedContent.contains(#"id='gdt'"#)
        || normalizedContent.contains(#"id="taglist""#)
        || normalizedContent.contains(#"id='taglist'"#)
        || normalizedContent.contains("gallerypopups.php")
        || normalizedContent.contains("api.e-hentai.org/api.php")
        || normalizedContent.contains("api.exhentai.org/api.php")
    }
}
