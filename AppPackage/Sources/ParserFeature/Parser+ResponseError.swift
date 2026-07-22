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
    ///
    /// Only the box counts: the labels are read where the forum software writes them and nowhere
    /// else, so a page that merely quotes one in its ordinary content is not mistaken for a refusal.
    public static func parseLoginErrorMessage(content: String) -> String? {
        guard let labelEnd = loginErrorLabelEnd(content: content) else { return nil }
        let stripped = content[labelEnd...]
            .replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
        let message = stripped
            .split(separator: "\n")
            .lazy
            .map({ $0.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\r\n")) })
            .first(where: { !$0.isEmpty })
        guard let message else { return nil }
        return String(message.prefix(200))
    }

    /// Whether the login form is gated behind a Cloudflare Turnstile widget.
    ///
    /// This is distinct from the edge challenge the app already clears: Turnstile lives *inside* the
    /// forum's own login form and contributes a `cf-turnstile-response` field to the submission. A
    /// plain credential POST omits that field, so the forum refuses it whatever the password —
    /// which is not a condition more retries can resolve.
    public static func loginFormRequiresCaptcha(content: String) -> Bool {
        content.contains("cf-turnstile") || content.contains("challenges.cloudflare.com/turnstile")
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
    /// Two labels, because the forum uses a different one depending on how the login was refused: a
    /// board-level message for a malformed submission, and a form-level list when the form itself
    /// came back with errors. Reading only the first is how a CAPTCHA requirement went unreported
    /// through several rounds of diagnosis.
    static let loginErrorMarkers = ["the error returned was", "the following errors were found"]

    /// Matches the opening tag of the forum's error-box label, whatever else its class carries.
    static let loginErrorLabelPattern =
        #"<[a-zA-Z][^>]*class\s*=\s*["'][^"']*(?:pformstrip|formsubtitle)[^"']*["'][^>]*>"#

    /// The position just past the forum's own error label, if the page carries one at all.
    ///
    /// A marker phrase is only evidence of a refusal where the forum software puts it: as the text
    /// of the error box's label. Searching the whole page for it instead means any content that
    /// merely quotes one — a thread title, a quoted post, a search term echoed back — reads as a
    /// rejection. That misfire costs more than a missed message: the caller throws before
    /// `setCredentials` runs, so a login that in fact succeeded is reported as failed *and* has the
    /// session cookies it just earned dropped on the floor. Requiring the label degrades instead to
    /// an unlabelled generic failure on markup this parser does not recognise, which the caller
    /// already handles, and which leaves a real session intact.
    static func loginErrorLabelEnd(content: String) -> String.Index? {
        var searchStart = content.startIndex
        while let labelTag = content.range(
            of: loginErrorLabelPattern,
            options: [.regularExpression, .caseInsensitive],
            range: searchStart..<content.endIndex
        ) {
            searchStart = labelTag.upperBound
            // These labels hold plain text, so the label's own text is everything up to the next
            // element. Stopping there is what keeps a marker sitting further down the page — past
            // this label's close — from being adopted as though this box had carried it.
            let labelText = content[labelTag.upperBound...].prefix(while: { $0 != "<" })
            let marker = loginErrorMarkers
                .lazy
                .compactMap({ labelText.range(of: $0, options: .caseInsensitive) })
                .min(by: { $0.lowerBound < $1.lowerBound })
            if let marker {
                return marker.upperBound
            }
        }
        return nil
    }

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
