@testable import AppFeature
import AppModels
import Kanna
import ParserFeature
import Testing
import TestingSupport

struct GalleryMPVKeysParserTests: TestHelper {
    @Test
    func testExample() throws {
        let document = try htmlDocument(filename: .galleryMPVKeys)
        let imageList = try Parser.parseMPVKeys(doc: document)
        #expect(imageList.key == "00000000000")
        #expect(imageList.imageKeys.count == 194)
        #expect(imageList.originalSizes.count == 194)
        #expect(imageList.originalSizes[1] == PagePixelSize(width: 2048, height: 3072))
    }

    /// A page whose thumbnail URL names no original file, or that lists no thumbnail, keeps its image key and has no
    /// original size.
    @Test
    func testPagesWithoutAnOriginalFileKeepTheirKeys() throws {
        let document = try Kanna.HTML(html: #"""
        <html><body><script type='text/javascript'>
        var mpvkey = "inline-mpv-key";
        var imagelist = [
        {"n":"001.png","k":"first-image-key",
        "t":"https:\/\/ehgt.org\/9d\/71\/9d71dd93bbf5cae13e9b5f9a1086b41600c9ce7e-6430614-2048-3072-png_l.jpg"},
        {"n":"002.png","k":"second-image-key","t":"https:\/\/ehgt.org\/g\/blank.gif"},
        {"n":"003.png","k":"third-image-key"}]
        </script></body></html>
        """#, encoding: .utf8)
        let original = try #require(PagePixelSize(width: 2048, height: 3072))

        let imageList = try Parser.parseMPVKeys(doc: document)

        #expect(imageList.key == "inline-mpv-key")
        #expect(imageList.imageKeys == [1: "first-image-key", 2: "second-image-key", 3: "third-image-key"])
        #expect(imageList.originalSizes == [1: original])
    }
}
