@testable import AppModels
import Foundation
import Testing

struct GalleryListPresentationCodingTests {
    // Choices saved before the Front Page rename use this key, so it has to keep reading back.
    @Test
    func theFrontPageChoiceKeepsItsStoredKey() throws {
        var presentation = GalleryListPresentation()
        presentation.frontPage = .grid

        let data = try JSONEncoder().encode(presentation)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["frontpage"] as? Int == GalleryListDisplayMode.grid.rawValue)
        #expect(try JSONDecoder().decode(GalleryListPresentation.self, from: data) == presentation)
    }
}
