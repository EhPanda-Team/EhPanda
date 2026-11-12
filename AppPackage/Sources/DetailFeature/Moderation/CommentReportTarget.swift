import AppModels
import Foundation

/// Where a comment is reported (D-10, research §5.2): the gallery's own report page on E-Hentai or ExHentai.
///
/// The site has no per-comment report link (only the gallery page's "Report Gallery", `?report=select`), so a comment
/// is reported from its gallery's report page. The URL is rebuilt from the parsed gallery URL alone, never from a
/// comment's content: only an `http` or `https` URL whose host is exactly a `GalleryHost` site and whose path is a
/// gallery page (`/g/<gid>/<token>/`) has a target, and it is always `https` with exactly one query item, `report`.
/// Anything else, a look-alike host included, has none (T-18-09).
enum CommentReportTarget {
    /// The gallery's report page, or `nil` when `galleryURL` is not a gallery page on a `GalleryHost` site.
    static func reportURL(for galleryURL: URL) -> URL? {
        reportURL(for: galleryURL, report: "select")
    }

    /// The gallery's report page for one report type (`?report=<type>`), where the native Report form reads the
    /// site's form and posts the report (18.1 DD-01, DD-02), or `nil` under the same rules as `reportURL(for:)`.
    ///
    /// The report is posted here, never to the `action` the page's form names, so a page cannot send it to another
    /// site (T-18.1-01).
    static func reportURL(for galleryURL: URL, type: ReportType) -> URL? {
        reportURL(for: galleryURL, report: type.rawValue)
    }

    private static func reportURL(for galleryURL: URL, report: String) -> URL? {
        guard let gallery = GalleryPage(galleryURL) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = gallery.host
        components.path = "/g/\(gallery.gid)/\(gallery.token)/"
        components.queryItems = [URLQueryItem(name: "report", value: report)]
        return components.url
    }

    /// The site the gallery is on, or `nil` when it has no report target.
    static func site(for galleryURL: URL) -> GalleryHost? {
        GalleryPage(galleryURL)?.site
    }

    /// The `{site}` of "Report on {site}": the site's display name (`GalleryHost.rawValue`), or `nil` when the
    /// gallery has no report target.
    static func siteName(for galleryURL: URL) -> String? {
        site(for: galleryURL)?.rawValue
    }
}

/// A gallery page URL taken apart into the only parts a report URL is rebuilt from.
private struct GalleryPage {
    let site: GalleryHost
    let host: String
    let gid: String
    let token: String

    init?(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              components.user == nil, components.password == nil, components.port == nil,
              let host = components.host?.lowercased(),
              let site = GalleryHost.allCases.first(where: { $0.url.host(percentEncoded: false) == host })
        else { return nil }

        let segments = components.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard segments.count == 3,
              let kind = segments.first, kind == "g",
              let gid = segments.dropFirst().first, !gid.isEmpty, gid.allSatisfy(\.isASCIIDigit),
              let token = segments.last, !token.isEmpty, token.allSatisfy(\.isASCIIAlphanumeric)
        else { return nil }

        self.site = site
        self.host = host
        self.gid = gid
        self.token = token
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIIAlphanumeric: Bool { isASCII && (isLetter || isNumber) }
}
