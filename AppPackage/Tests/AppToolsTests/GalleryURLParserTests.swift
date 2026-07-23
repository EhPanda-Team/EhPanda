import AppTools
import CustomDump
import Foundation
import Testing

struct GalleryURLParserTests {
    @Test(arguments: [
        GalleryRouteFixture(
            url: "https://e-hentai.org/g/3103480/0000000000/",
            expectedURL: "https://e-hentai.org/g/3103480/0000000000/",
            gid: "3103480"
        ),
        GalleryRouteFixture(
            url: "https://exhentai.org/g/3103480/0000000000/",
            expectedURL: "https://exhentai.org/g/3103480/0000000000/",
            gid: "3103480"
        ),
        GalleryRouteFixture(
            url: "https://www.e-hentai.org/g/3103480/0000000000/",
            expectedURL: "https://www.e-hentai.org/g/3103480/0000000000/",
            gid: "3103480"
        ),
        GalleryRouteFixture(
            url: "https://www.exhentai.org/g/3103480/0000000000/",
            expectedURL: "https://www.exhentai.org/g/3103480/0000000000/",
            gid: "3103480"
        ),
        GalleryRouteFixture(
            url: "https://E-HENTAI.ORG/g/3103480/0000000000/",
            expectedURL: "https://E-HENTAI.ORG/g/3103480/0000000000/",
            gid: "3103480"
        ),
        GalleryRouteFixture(
            url: "ehpanda://e-hentai.org/g/3103480/0000000000/",
            expectedURL: "https://e-hentai.org/g/3103480/0000000000/",
            gid: "3103480"
        ),
        GalleryRouteFixture(
            url: "https://e-hentai.org/s/abc123/3103480-2",
            expectedURL: "https://e-hentai.org/s/abc123/3103480-2",
            gid: "3103480",
            pageIndex: 2,
            isGalleryImageURL: true
        ),
        GalleryRouteFixture(
            url: "https://e-hentai.org/g/3103480/0000000000/#c5143504",
            expectedURL: "https://e-hentai.org/g/3103480/0000000000/#c5143504",
            gid: "3103480",
            commentID: "5143504"
        ),
        GalleryRouteFixture(
            url: "https://e-hentai.org/s/abc123/3103480-2#c99",
            expectedURL: "https://e-hentai.org/s/abc123/3103480-2#c99",
            gid: "3103480",
            pageIndex: 2,
            commentID: "99"
        ),
        GalleryRouteFixture(
            url: "https://e-hentai.org/s/abc123/3103480-not-a-page",
            expectedURL: "https://e-hentai.org/s/abc123/3103480-not-a-page",
            gid: "3103480",
            isGalleryImageURL: true
        )
    ])
    private func parsesGalleryRoute(fixture: GalleryRouteFixture) throws {
        let url = try #require(URL(string: fixture.url))
        let expectedURL = try #require(URL(string: fixture.expectedURL))
        let route = try #require(GalleryURLParser.parse(url))

        expectNoDifference(
            route,
            GalleryURLParser.Route(
                url: expectedURL,
                gid: fixture.gid,
                pageIndex: fixture.pageIndex,
                commentID: fixture.commentID,
                isGalleryImageURL: fixture.isGalleryImageURL
            )
        )
    }

    @Test(arguments: [
        "https://evil.com/g/123/token?ref=https://e-hentai.org/",
        "https://s.exhentai.org/g/1/t",
        "https://e-hentai.org/mpv/3103480/0000000000/",
        "https://e-hentai.org/g/3103480",
        "https://e-hentai.org/g//token",
        "https://e-hentai.org/g/abc/token",
        "https://e-hentai.org/",
        "/g/3103480/0000000000/"
    ])
    func rejectsInvalidGalleryRoute(urlString: String) throws {
        let url = try #require(URL(string: urlString))

        #expect(GalleryURLParser.parse(url) == nil)
    }

    @Test(arguments: [
        MPVFixture(url: "https://e-hentai.org/mpv/3103480/0000000000/", expected: true),
        MPVFixture(url: "https://e-hentai.org/g/3103480/0000000000/", expected: false),
        MPVFixture(url: nil, expected: false)
    ])
    private func identifiesMPVPath(fixture: MPVFixture) throws {
        let url = try fixture.url.map({ try #require(URL(string: $0)) })

        #expect(GalleryURLParser.isMPVURL(url) == fixture.expected)
    }
}

private struct GalleryRouteFixture: CustomTestStringConvertible, Sendable {
    let url: String
    let expectedURL: String
    let gid: String
    let pageIndex: Int?
    let commentID: String?
    let isGalleryImageURL: Bool

    init(
        url: String,
        expectedURL: String,
        gid: String,
        pageIndex: Int? = nil,
        commentID: String? = nil,
        isGalleryImageURL: Bool = false
    ) {
        self.url = url
        self.expectedURL = expectedURL
        self.gid = gid
        self.pageIndex = pageIndex
        self.commentID = commentID
        self.isGalleryImageURL = isGalleryImageURL
    }

    var testDescription: String { url }
}

private struct MPVFixture: CustomTestStringConvertible, Sendable {
    let url: String?
    let expected: Bool

    var testDescription: String { url ?? "nil" }
}
