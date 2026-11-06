import AppModels
@testable import DetailFeature
import Foundation
import Testing

/// The comment report action's target (D-10, research §5.2): the gallery's own report page on its own site.
///
/// The URL is built from the parsed gallery URL alone, never from a comment's content, and any host outside
/// `GalleryHost` yields no target, so untrusted page data cannot point the report sheet at another site (T-18-09).
/// The per-type URL the native Report form reads and posts to follows the same rules (18.1 DD-02, T-18.1-01).
struct CommentReportTargetTests {
    @Test
    func anEHentaiGalleryReportsOnItsOwnReportPage() throws {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/3103480/0000000000/"))

        let reportURL = CommentReportTarget.reportURL(for: galleryURL)

        #expect(reportURL?.absoluteString == "https://e-hentai.org/g/3103480/0000000000/?report=select")
        #expect(CommentReportTarget.site(for: galleryURL) == .ehentai)
        #expect(CommentReportTarget.siteName(for: galleryURL) == "E-Hentai")
    }

    @Test
    func anExHentaiGalleryReportsOnExHentai() throws {
        let galleryURL = try #require(URL(string: "https://exhentai.org/g/3103480/0000000000/"))

        let reportURL = CommentReportTarget.reportURL(for: galleryURL)

        #expect(reportURL?.absoluteString == "https://exhentai.org/g/3103480/0000000000/?report=select")
        #expect(CommentReportTarget.site(for: galleryURL) == .exhentai)
        #expect(CommentReportTarget.siteName(for: galleryURL) == "ExHentai")
    }

    @Test(arguments: [
        "https://e-hentai.org/g/3103480/0000000000/?p=2",
        "https://e-hentai.org/g/3103480/0000000000/?report=select&p=2",
        "https://e-hentai.org/g/3103480/0000000000/?hc=1#comments"
    ])
    func anExistingQueryOrFragmentIsReplacedNotAppendedTo(galleryURL: String) throws {
        let url = try #require(URL(string: galleryURL))

        let reportURL = try #require(CommentReportTarget.reportURL(for: url))
        let components = try #require(URLComponents(url: reportURL, resolvingAgainstBaseURL: false))

        #expect(components.queryItems == [URLQueryItem(name: "report", value: "select")])
        #expect(components.fragment == nil)
        #expect(reportURL.absoluteString == "https://e-hentai.org/g/3103480/0000000000/?report=select")
    }

    @Test
    func theHostIsMatchedWhateverItsCaseAndTheTrailingSlashIsRestored() throws {
        let url = try #require(URL(string: "https://E-Hentai.org/g/3103480/0000000000"))

        #expect(
            CommentReportTarget.reportURL(for: url)?.absoluteString
                == "https://e-hentai.org/g/3103480/0000000000/?report=select"
        )
    }

    @Test(arguments: [
        "https://example.com/g/1/x/",
        "https://e-hentai.org.example.com/g/1/x/",
        "https://evil-e-hentai.org/g/1/x/",
        "https://forums.e-hentai.org/g/1/x/",
        "https://s.exhentai.org/g/1/x/",
        "ftp://e-hentai.org/g/1/x/",
        "https://user@e-hentai.org/g/1/x/",
        "https://e-hentai.org:8443/g/1/x/"
    ])
    func anyOtherHostOrSchemeHasNoReportTarget(galleryURL: String) throws {
        let url = try #require(URL(string: galleryURL))

        #expect(CommentReportTarget.reportURL(for: url) == nil)
        #expect(CommentReportTarget.site(for: url) == nil)
        #expect(CommentReportTarget.siteName(for: url) == nil)
        for type in ReportType.allCases {
            #expect(CommentReportTarget.reportURL(for: url, type: type) == nil)
        }
    }

    @Test(arguments: [
        "https://e-hentai.org/",
        "https://e-hentai.org/g/",
        "https://e-hentai.org/g/3103480/",
        "https://e-hentai.org/g/abc/0000000000/",
        "https://e-hentai.org/s/0000000000/3103480-1",
        "https://e-hentai.org/g/3103480/0000000000/extra/",
        "https://e-hentai.org/g/3103480/../../uconfig.php"
    ])
    func aURLThatIsNotAGalleryPageHasNoReportTarget(galleryURL: String) throws {
        let url = try #require(URL(string: galleryURL))

        #expect(CommentReportTarget.reportURL(for: url) == nil)
        for type in ReportType.allCases {
            #expect(CommentReportTarget.reportURL(for: url, type: type) == nil)
        }
    }

    // MARK: Per-type report page (18.1 DD-01, DD-02)

    @Test(arguments: ["e-hentai.org", "exhentai.org"], ReportType.allCases)
    func eachTypeHasItsOwnReportPageOnTheGallerysSite(host: String, type: ReportType) throws {
        let galleryURL = try #require(URL(string: "https://\(host)/g/3103480/0000000000/?p=2#comments"))

        let reportURL = try #require(CommentReportTarget.reportURL(for: galleryURL, type: type))
        let components = try #require(URLComponents(url: reportURL, resolvingAgainstBaseURL: false))

        #expect(reportURL.absoluteString == "https://\(host)/g/3103480/0000000000/?report=\(type.rawValue)")
        #expect(components.queryItems == [URLQueryItem(name: "report", value: type.rawValue)])
        #expect(components.fragment == nil)
    }

    @Test
    func theTypesAreTheSitesChildAndOtherValues() throws {
        let galleryURL = try #require(URL(string: "http://E-Hentai.org/g/3103480/0000000000"))

        #expect(
            CommentReportTarget.reportURL(for: galleryURL, type: .child)?.absoluteString
                == "https://e-hentai.org/g/3103480/0000000000/?report=child"
        )
        #expect(
            CommentReportTarget.reportURL(for: galleryURL, type: .other)?.absoluteString
                == "https://e-hentai.org/g/3103480/0000000000/?report=other"
        )
    }

    @Test
    func anHTTPGalleryURLReportsOverHTTPS() throws {
        let url = try #require(URL(string: "http://exhentai.org/g/3103480/0000000000/"))

        #expect(
            CommentReportTarget.reportURL(for: url)?.absoluteString
                == "https://exhentai.org/g/3103480/0000000000/?report=select"
        )
    }
}
