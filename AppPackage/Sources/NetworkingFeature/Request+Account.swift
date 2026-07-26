import AppModels
import AppTools
import Foundation
import Kanna
import OSLogExt
import ParserFeature

private let logger = Logger(category: .init(describing: LoginRequest.self))

#if DEBUG
/// Reduces a credential-setting header to the names it sets, discarding every value.
///
/// The values are the account's credentials. The names alone settle the only question asked of this
/// header while diagnosing a failed login — whether the forum returned a session at all — so nothing
/// is gained by keeping the rest, and a dump that omits them can be read and shared freely.
///
/// Foundation's own `Set-Cookie` parser does the splitting. Doing it by hand meant cutting the
/// coalesced header on `,`, which lands inside `expires` — whose value carries one — and printing
/// the pieces as if they were cookie names; the same cut would hand back the tail of a *value* if a
/// server ever put a comma in one. A parser that either recognises a cookie or yields nothing has no
/// way to name a fragment of one.
func redactedCredentialHeader(_ headerValue: String, for url: URL?) -> String {
    var names = [String]()
    // Without the response's URL there is no domain to attach the cookies to, so nothing is parsed
    // and nothing is named: the dump gives up a detail rather than gambling with a value.
    if let url {
        names = HTTPCookie
            .cookies(withResponseHeaderFields: ["Set-Cookie": headerValue], for: url)
            .map(\.name)
    }
    return "<values redacted; names set: \(names.joined(separator: ", "))>"
}
#endif

// MARK: Account Ops
public struct LoginRequest: Request {
    public init(
        username: String,
        password: String,
        clearance: CloudflareClearance? = nil,
        urlSession: URLSession = .shared
    ) {
        self.username = username
        self.password = password
        self.clearance = clearance
        self.urlSession = urlSession
    }
    public let username: String
    public let password: String
    /// Proof a Cloudflare wall was solved, present only on a retry after a challenge.
    ///
    /// Nil is the ordinary case and leaves the request byte-identical to the pre-challenge one.
    public let clearance: CloudflareClearance?
    public let urlSession: URLSession

    public func response() async throws(AppError) -> HTTPURLResponse? {
        let params: [String: String] = [
            "b": "d",
            "bt": "1-1",
            "CookieDate": "1",
            "UserName": username,
            "PassWord": password,
            "ipb_login_submit": "Login!"
        ]

        var request = URLRequest(url: Defaults.URL.login)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().data(using: .utf8)
        request.setURLEncodedContentType()
        // The shared jar is taken out of this POST's loop on both paths. Nothing the request needs is
        // lost: login credentials arrive on the *response* as Set-Cookie (consumed downstream by
        // `setCredentials`), never as cookies sent, and the returned `HTTPURLResponse` carries them
        // regardless of this flag. What it buys is that URLSession no longer files a *rejection*
        // page's Set-Cookie tombstones on their way past — which would otherwise clobber a working
        // session the moment a re-login was mistyped, on the one path that still allowed it.
        request.httpShouldHandleCookies = false
        if let clearance {
            // The clearance must also be the authoritative outbound cookie, so it is written as the
            // header directly rather than left for the jar to inject or overwrite. Suppressing the
            // jar keeps the clearance out of `HTTPCookieStorage.shared` too, which is the point.
            request.setValue("cf_clearance=" + clearance.cookieValue, forHTTPHeaderField: "Cookie")
            // Cloudflare binds the clearance to the exact User-Agent that earned it, so the solving
            // web view's UA is replayed verbatim — on this retried login POST only, never on the
            // app's general traffic.
            request.setValue(clearance.userAgent, forHTTPHeaderField: "User-Agent")
        }

        // One attempt only. A POST the forum received but whose response was lost on the way back is
        // indistinguishable here from one it never saw, and replaying it spends another of the
        // account's login attempts — the same budget whose exhaustion this request now parses and
        // reports. A single lost response costs the user one retry; four cost them the lockout.
        let (data, response) = try await fetch(request, in: urlSession, attempts: 1)
        let httpResponse = response as? HTTPURLResponse
        // A challenged response is Cloudflare's interstitial, not a forum page. Leave it exactly as
        // it arrived for the caller's classifier rather than trying to read a login outcome out of it.
        guard !isCloudflareChallenge(httpResponse) else { return httpResponse }
        guard let content = String(data: data, encoding: .utf8) else { return httpResponse }
        // The body was previously discarded, which left every rejection indistinguishable: a wrong
        // password, a lockout after repeated failures and a missing field are all 200s that set no
        // auth cookie, so the caller saw one undifferentiated "not logged in". Reading the page is
        // the only way to tell them apart — and throwing here also stops the failure page's
        // Set-Cookie tombstones from reaching the jar, since `setCredentials` is now the only thing
        // that files anything from this exchange and it runs on success alone.
        let siteError = Parser.parseResponseError(content: content)
        // `.authenticationRequired` is the site-wide "you are not signed in" verdict, which is
        // meaningless as the *outcome of a login POST*: not being signed in is the premise here, not
        // a diagnosis. It fires readily on this path too — the parser reads `bounce_login.php` as its
        // marker, and the login form the forum hands back on a refusal is exactly the page that links
        // to it — so an ordinary wrong password surfaced as a general authentication error, wearing
        // copy written for another caller entirely.
        //
        // It does not throw here, it falls through: this branch runs *before* the login-specific
        // reading below, so throwing on it would skip the forum's own error box and the CAPTCHA
        // detection on every page carrying that link, which is most refusal pages. The verdict is
        // kept only as the fallback for a page nothing further can read.
        let refusedWithoutDiagnosis = siteError == .authenticationRequired
        if let siteError, !refusedWithoutDiagnosis {
            // A genuine site condition — a quota, a ban — keeps its own case and its tailored
            // recovery suggestion rather than collapsing into a login refusal.
            logger.warning("Login blocked by a site error: \(String(describing: siteError), privacy: .public)")
            throw siteError
        }
        if let message = Parser.parseLoginErrorMessage(content: content) {
            // A CAPTCHA-gated form gets its own case rather than collapsing into the generic
            // failure: it is the one rejection no password and no number of retries can clear,
            // because the submission is missing a field this request cannot produce. Reporting it
            // as a plain failure would send the user back to re-check a password that was never
            // the problem, so it carries its own recovery route instead.
            let captchaGated = Parser.loginFormRequiresCaptcha(content: content)
            logger.warning("""
                Login rejected by the forum: \(message, privacy: .public) \
                captchaGated=\(captchaGated, privacy: .public)
                """)
            // The message is carried rather than logged and dropped. It is the only part of the
            // response that separates a wrong password from a missing field from the attempt
            // lockout, and dropping it is what made every refusal arrive on screen as "unknown".
            throw captchaGated ? AppError.loginCaptchaRequired : AppError.loginRejected(message)
        }
        if refusedWithoutDiagnosis {
            // The page says the credential did not take but carries no readable reason. A refusal
            // with nothing to quote is exactly what `.unknown` means; throwing still keeps the
            // rejection page's Set-Cookie tombstones away from the jar.
            logger.warning("Login refused with no readable reason; reporting unknown.")
            throw AppError.unknown
        }
        // No error box and no recognised site error, yet a login can still not have happened. The
        // form's own submit control is the cheapest tell that the page came back as the login form
        // rather than as a signed-in page — a shape, never any of its content.
        let loginFormPresent = content.contains("ipb_login_submit")
        let bodyLength = content.count
        logger.notice("""
            Login response shape: bytes=\(bodyLength, privacy: .public) \
            loginFormPresent=\(loginFormPresent, privacy: .public)
            """)
        #if DEBUG
        dumpLoginExchange(response: httpResponse, body: content)
        #endif
        return httpResponse
    }

    #if DEBUG
    /// Writes the whole login exchange to a file, so one attempt answers every question at once
    /// rather than costing a new probe and a new round trip per fact.
    ///
    /// Header values for credential-setting headers are reduced to their cookie *names*. Those
    /// values are the account's credentials, and the point of this file is that it can be read and
    /// passed around freely; the names alone settle the only question being asked of them, which is
    /// whether the forum returned a session at all. Everything else — status, every other header,
    /// and the full page — is kept verbatim, because that is the part that has been invisible.
    ///
    /// DEBUG-only: this exists to diagnose a live login failure, not to ship.
    private func dumpLoginExchange(response: HTTPURLResponse?, body: String) {
        guard let directory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }

        let credentialHeaderName = "Set-Cookie"
        let headers = (response?.allHeaderFields ?? [:])
            .map { name, value -> String in
                let name = String(describing: name)
                let text = String(describing: value)
                guard name.caseInsensitiveCompare(credentialHeaderName) == .orderedSame else {
                    return "\(name): \(text)"
                }
                return "\(name): \(redactedCredentialHeader(text, for: response?.url))"
            }
            .sorted()
            .joined(separator: "\n")

        let dump = """
            status: \(response?.statusCode ?? -1)
            url: \(response?.url?.absoluteString ?? "<none>")

            --- headers ---
            \(headers)

            --- body (\(body.count) bytes) ---
            \(body)
            """
        let destination = directory.appendingPathComponent("login-response-dump.txt")
        do {
            try dump.write(to: destination, atomically: true, encoding: .utf8)
            logger.notice("Wrote login response dump to \(destination.lastPathComponent, privacy: .public)")
        } catch {
            logger.error("Could not write the login response dump. \(error, privacy: .public)")
        }
    }
    #endif
}

public struct IgneousRequest: Request {
    public init(
        urlSession: URLSession = .shared
    ) {
        self.urlSession = urlSession
    }
    public let urlSession: URLSession

    public func response() async throws(AppError) -> HTTPURLResponse {
        let (_, response) = try await fetch(
            URLRequest(url: Defaults.URL.exhentai),
            in: urlSession
        )
        guard let response = response as? HTTPURLResponse else {
            throw AppError.unknown
        }
        return response
    }
}

public struct VerifyEhProfileRequest: Request {
    public init(
        host: GalleryHost,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let urlSession: URLSession

    public func response() async throws(AppError) -> VerifyEhProfileResponse {
        let (data, _) = try await fetch(URLRequest(url: Defaults.URL.uConfig(host: host)), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseProfileIndex)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct EhProfileRequest: Request {
    public init(
        host: GalleryHost,
        action: EhProfileAction? = nil,
        name: String? = nil,
        set: Int? = nil,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.action = action
        self.name = name
        self.set = set
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public var action: EhProfileAction?
    public var name: String?
    public var set: Int?
    public let urlSession: URLSession

    public func response() async throws(AppError) -> EhSetting {
        var params = [String: String]()

        if let action = action {
            params["profile_action"] = action.rawValue
        }
        if let name = name {
            params["profile_name"] = name
        }
        if let set = set {
            params["profile_set"] = "\(set)"
        }

        var request = URLRequest(url: Defaults.URL.uConfig(host: host))
        request.httpMethod = "POST"
        request.httpBody = params.dictString().data(using: .utf8)
        request.setURLEncodedContentType()

        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseEhSetting)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct EhSettingRequest: Request {
    public init(
        host: GalleryHost,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let urlSession: URLSession

    public func response() async throws(AppError) -> EhSetting {
        let (data, _) = try await fetch(URLRequest(url: Defaults.URL.uConfig(host: host)), in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseEhSetting)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct SubmitEhSettingChangesRequest: Request {
    public init(
        host: GalleryHost,
        ehSetting: EhSetting,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.ehSetting = ehSetting
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let ehSetting: EhSetting
    public let urlSession: URLSession

    public func response() async throws(AppError) -> EhSetting {
        let url = Defaults.URL.uConfig(host: host)
        var params: [String: String] = [
            "uh": String(ehSetting.loadThroughHathSetting.rawValue),
            "co": ehSetting.hahRegion.rawValue,
            "xr": String(ehSetting.imageResolution.rawValue),
            "rx": String(Int(ehSetting.imageSizeWidth)),
            "ry": String(Int(ehSetting.imageSizeHeight)),
            "tl": String(ehSetting.galleryName.rawValue),
            "ar": String(ehSetting.archiverBehavior.rawValue),
            "dm": String(ehSetting.displayMode.rawValue),
            "pp": ehSetting.showSearchRangeIndicator ? "0" : "1",
            "fs": String(ehSetting.favoritesSortOrder.rawValue),
            "ru": ehSetting.ratingsColor,
            "ft": String(Int(ehSetting.tagFilteringThreshold)),
            "wt": String(Int(ehSetting.tagWatchingThreshold)),
            "tf": ehSetting.showFilteredRemovalCount ? "0" : "1",
            "xu": ehSetting.excludedUploaders,
            "rc": String(ehSetting.searchResultCount.rawValue),
            "lt": String(ehSetting.thumbnailLoadTiming.rawValue),
            "tr": String(ehSetting.thumbnailConfigRows.rawValue),
            "tp": String(Int(ehSetting.coverScaleFactor)),
            "vp": String(Int(ehSetting.viewportVirtualWidth)),
            "cs": String(ehSetting.commentsSortOrder.rawValue),
            "sc": String(ehSetting.commentVotesShowTiming.rawValue),
            "tb": String(ehSetting.tagsSortOrder.rawValue),
            "pn": String(ehSetting.galleryPageNumbering.rawValue),
            "apply": "Apply"
        ]

        if ehSetting.enableGalleryThumbnailSelector {
            params["xn_0"] = "on"
        }

        switch ehSetting.thumbnailConfigSize {
        case .auto: params["ts"] = "0"
        case .normal: params["ts"] = "1"
        case .small: params["ts"] = "2"
        default: break
        }

        // These three loops pair a static name/value table against an array parsed out of the
        // remote settings page. `zip` / `prefix` make the pairing bounds-safe: a settings page
        // that yields fewer entries than expected now submits the parameters it does have
        // instead of trapping.
        for (name, isDisabled) in zip(EhSetting.categoryNames, ehSetting.disabledCategories) {
            params["ct_\(name)"] = isDisabled ? "1" : "0"
        }
        for (slot, favoriteName) in ehSetting.favoriteCategories.prefix(10).enumerated() {
            params["favorite_\(slot)"] = favoriteName
        }
        for (languageValue, isExcluded) in zip(EhSetting.languageValues, ehSetting.excludedLanguages)
        where isExcluded {
            params["xl_\(languageValue)"] = "on"
        }

        if let useOriginalImages = ehSetting.useOriginalImages {
            params["oi"] = useOriginalImages ? "1" : "0"
        }
        if let useMultiplePageViewer = ehSetting.useMultiplePageViewer {
            params["qb"] = useMultiplePageViewer ? "1" : "0"
        }
        if let multiplePageViewerStyle = ehSetting.multiplePageViewerStyle {
            params["ms"] = String(multiplePageViewerStyle.rawValue)
        }
        if let multiplePageViewerShowThumbnailPane = ehSetting.multiplePageViewerShowThumbnailPane {
            params["mt"] = multiplePageViewerShowThumbnailPane ? "0" : "1"
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().data(using: .utf8)
        request.setURLEncodedContentType()

        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseEhSetting)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct FavorGalleryRequest: Request {
    public init(
        host: GalleryHost,
        gid: String,
        token: String,
        favIndex: Int,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.gid = gid
        self.token = token
        self.favIndex = favIndex
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let gid: String
    public let token: String
    public let favIndex: Int
    public let urlSession: URLSession

    public func response() async throws(AppError) {
        let url = URLUtil.addFavorite(host: host, gid: gid, token: token)
        let params: [String: String] = [
            "favcat": "\(favIndex)",
            "favnote": "",
            "apply": "Add to Favorites",
            "update": "1"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().data(using: .utf8)
        request.setURLEncodedContentType()

        _ = try await fetch(request, in: urlSession)
    }
}

public struct UnfavorGalleryRequest: Request {
    public init(
        host: GalleryHost,
        gid: String,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.gid = gid
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let gid: String
    public let urlSession: URLSession

    public func response() async throws(AppError) {
        let params: [String: String] = [
            "ddact": "delete",
            "modifygids[]": gid,
            "apply": "Apply"
        ]

        var request = URLRequest(url: Defaults.URL.favorites(host: host))
        request.httpMethod = "POST"
        request.httpBody = params.dictString().data(using: .utf8)
        request.setURLEncodedContentType()

        _ = try await fetch(request, in: urlSession)
    }
}

public struct SendDownloadCommandRequest: Request {
    public init(
        archiveURL: URL,
        resolution: String,
        urlSession: URLSession = .shared
    ) {
        self.archiveURL = archiveURL
        self.resolution = resolution
        self.urlSession = urlSession
    }
    public let archiveURL: URL
    public let resolution: String
    public let urlSession: URLSession

    public func response() async throws(AppError) -> String {
        let params: [String: String] = [
            "hathdl_xres": resolution
        ]

        var request = URLRequest(url: archiveURL)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().data(using: .utf8)
        request.setURLEncodedContentType()

        let (data, _) = try await fetch(request, in: urlSession)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseDownloadCommandResponse)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

public struct RateGalleryRequest: Request {
    public init(
        host: GalleryHost,
        apiuid: Int,
        apikey: String,
        gid: Int,
        token: String,
        rating: Int,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.apiuid = apiuid
        self.apikey = apikey
        self.gid = gid
        self.token = token
        self.rating = rating
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let apiuid: Int
    public let apikey: String
    public let gid: Int
    public let token: String
    public let rating: Int
    public let urlSession: URLSession

    public func response() async throws(AppError) {
        let params: [String: Any] = [
            "method": "rategallery",
            "apiuid": apiuid,
            "apikey": apikey,
            "gid": gid,
            "token": token,
            "rating": rating
        ]

        var request = URLRequest(url: Defaults.URL.api(host: host))
        request.httpMethod = "POST"
        request.httpBody = try encodeJSONObject(params)

        _ = try await fetch(request, in: urlSession)
    }
}

public struct CommentGalleryRequest: Request {
    public init(
        content: String,
        galleryURL: URL,
        urlSession: URLSession = .shared
    ) {
        self.content = content
        self.galleryURL = galleryURL
        self.urlSession = urlSession
    }
    public let content: String
    public let galleryURL: URL
    public let urlSession: URLSession

    public func response() async throws(AppError) {
        // Newlines need no hand-rolled `%0A` here: `dictString()` percent-encodes each value, so a
        // pre-escaped one would come out as `%250A` and the comment would carry the literal text.
        let params: [String: String] = [
            "commenttext_new": content
        ]

        var request = URLRequest(url: galleryURL)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().data(using: .utf8)
        request.setURLEncodedContentType()

        _ = try await fetch(request, in: urlSession)
    }
}

public struct EditGalleryCommentRequest: Request {
    public init(
        commentID: String,
        content: String,
        galleryURL: URL,
        urlSession: URLSession = .shared
    ) {
        self.commentID = commentID
        self.content = content
        self.galleryURL = galleryURL
        self.urlSession = urlSession
    }
    public let commentID: String
    public let content: String
    public let galleryURL: URL
    public let urlSession: URLSession

    public func response() async throws(AppError) {
        // See `CommentGalleryRequest`: `dictString()` owns the escaping, so the content goes in raw.
        let params: [String: String] = [
            "edit_comment": commentID,
            "commenttext_edit": content
        ]

        var request = URLRequest(url: galleryURL)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().data(using: .utf8)
        request.setURLEncodedContentType()

        _ = try await fetch(request, in: urlSession)
    }
}

public struct VoteGalleryCommentRequest: Request {
    public init(
        host: GalleryHost,
        apiuid: Int,
        apikey: String,
        gid: Int,
        token: String,
        commentID: Int,
        commentVote: Int,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.apiuid = apiuid
        self.apikey = apikey
        self.gid = gid
        self.token = token
        self.commentID = commentID
        self.commentVote = commentVote
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let apiuid: Int
    public let apikey: String
    public let gid: Int
    public let token: String
    public let commentID: Int
    public let commentVote: Int
    public let urlSession: URLSession

    public func response() async throws(AppError) {
        let params: [String: Any] = [
            "method": "votecomment",
            "apiuid": apiuid,
            "apikey": apikey,
            "gid": gid,
            "token": token,
            "comment_id": commentID,
            "comment_vote": commentVote
        ]

        var request = URLRequest(url: Defaults.URL.api(host: host))
        request.httpMethod = "POST"
        request.httpBody = try encodeJSONObject(params)

        _ = try await fetch(request, in: urlSession)
    }
}

public struct VoteGalleryTagRequest: Request {
    public init(
        host: GalleryHost,
        apiuid: Int,
        apikey: String,
        gid: Int,
        token: String,
        tag: String,
        vote: Int,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.apiuid = apiuid
        self.apikey = apikey
        self.gid = gid
        self.token = token
        self.tag = tag
        self.vote = vote
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let apiuid: Int
    public let apikey: String
    public let gid: Int
    public let token: String
    public let tag: String
    public let vote: Int
    public let urlSession: URLSession

    public func response() async throws(AppError) {
        let params: [String: Any] = [
            "method": "taggallery",
            "apiuid": apiuid,
            "apikey": apikey,
            "gid": gid,
            "token": token,
            "tags": tag,
            "vote": vote
        ]

        var request = URLRequest(url: Defaults.URL.api(host: host))
        request.httpMethod = "POST"
        request.httpBody = try encodeJSONObject(params)

        _ = try await fetch(request, in: urlSession)
    }
}
