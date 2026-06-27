import Kanna
import Testing
import Parser
@testable import AppFeature

struct GalleryMPVKeysParserTests: TestHelper {
    @Test
    func testExample() throws {
        let document = try htmlDocument(filename: .galleryMPVKeys)
        let (mpvKey, mpvImageKeys) = try Parser.parseMPVKeys(doc: document)
        #expect(mpvKey == "00000000000")
        #expect(mpvImageKeys.count == 194)
    }
}
