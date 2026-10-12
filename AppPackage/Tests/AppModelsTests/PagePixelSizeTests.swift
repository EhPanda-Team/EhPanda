import AppModels
import Foundation
import Testing

// A page's pixel size, as an E-Hentai URL's file identifier names it.
struct PagePixelSizeTests {
    @Test
    func anImageURLNamesTheFileItServes() throws {
        let url = try #require(URL(string: """
            https://akrtazd.spuqplybaxmf.hath.network:65000/h/\
            ea42b28bceeae68f1f6adb414da61d186b3d126b-311480-1280-1920-jpg\
            /keystamp=1694132700-fd778f8260;fileindex=132044713;xres=1280/87052610_5090394_0.jpg
            """))

        #expect(PagePixelSize(fileIdentifierIn: url) == PagePixelSize(width: 1280, height: 1920))
    }

    @Test
    func aWebPImageURLNamesTheFileItServes() throws {
        let url = try #require(URL(string: """
            https://example.hath.network/h/0123456789abcdef0123456789abcdef01234567-206476-1280-1791-wbp\
            /keystamp=1-2;fileindex=3;xres=1280/0004.webp
            """))

        #expect(PagePixelSize(fileIdentifierIn: url) == PagePixelSize(width: 1280, height: 1791))
    }

    @Test
    func aThumbnailURLNamesItsFile() throws {
        let url = try #require(URL(string: """
            https://ehgt.org/9d/71/9d71dd93bbf5cae13e9b5f9a1086b41600c9ce7e-6430614-2048-3072-png_l.jpg
            """))

        #expect(PagePixelSize(fileIdentifierIn: url) == PagePixelSize(width: 2048, height: 3072))
    }

    @Test(arguments: [
        "https://images.example.com/mpv.jpg",
        "https://example.com/pages/0001.jpg",
        // An identifier with a short hash, or with a side missing.
        "https://example.hath.network/h/ea42b28b-311480-1280-1920-jpg/0001.jpg",
        "https://example.hath.network/h/ea42b28bceeae68f1f6adb414da61d186b3d126b-311480-1280-jpg/0001.jpg",
        // An identifier inside a longer path component.
        "https://example.hath.network/h/x-ea42b28bceeae68f1f6adb414da61d186b3d126b-311480-1280-1920-jpg/0001.jpg"
    ])
    func aURLWithoutAnIdentifierNamesNoSize(urlString: String) throws {
        let url = try #require(URL(string: urlString))

        #expect(PagePixelSize(fileIdentifierIn: url) == nil)
    }

    @Test
    func anIdentifierWithAnEmptySideNamesNoSize() throws {
        let url = try #require(URL(string: """
            https://example.hath.network/h/ea42b28bceeae68f1f6adb414da61d186b3d126b-311480-0-1920-jpg/0001.jpg
            """))

        #expect(PagePixelSize(fileIdentifierIn: url) == nil)
        #expect(PagePixelSize(width: 1280, height: 0) == nil)
    }
}
