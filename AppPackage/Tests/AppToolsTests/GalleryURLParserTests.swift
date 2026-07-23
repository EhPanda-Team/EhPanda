import AppTools
import CustomDump
import Foundation
import Testing

struct GalleryURLParserTests {
    @Test
    func parsesGalleryURL() throws {
        let url = try #require(URL(string: "https://e-hentai.org/g/3103480/0000000000/"))
        let route = try #require(GalleryURLParser.parse(url))

        expectNoDifference(
            route,
            GalleryURLParser.Route(
                url: url,
                gid: "3103480",
                pageIndex: nil,
                commentID: nil,
                isGalleryImageURL: false
            )
        )
    }
}
