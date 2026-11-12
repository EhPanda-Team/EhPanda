import AppModels
import Foundation
import Testing

struct GalleryTitleTests {
    @Test(arguments: [nil, "", "  \n", "日本語の題名"] as [String?])
    func resolvesPreferenceWithoutDiscardingEitherTitle(japanese: String?) throws {
        var gallery = Gallery.preview
        gallery.title = "Original Title"
        gallery.jpnTitle = japanese
        #expect(gallery.displayTitle(prefersJapanese: false) == "Original Title")
        #expect(gallery.displayTitle(prefersJapanese: true) == (
            japanese == "日本語の題名" ? "日本語の題名" : "Original Title"
        ))
        let restored = try JSONDecoder().decode(Gallery.self, from: JSONEncoder().encode(gallery))
        #expect(restored.jpnTitle == japanese)
        #expect(restored.title == "Original Title")
    }

    @Test
    func legacyGalleryWithoutJapaneseTitleStillDecodes() throws {
        let encoded = try JSONEncoder().encode(Gallery.preview)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "jpnTitle")
        let gallery = try JSONDecoder().decode(Gallery.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(gallery.jpnTitle == nil)
        #expect(gallery.displayTitle(prefersJapanese: true) == gallery.title)
    }

    @Test
    func listFilterMatchesTheJapaneseTitle() {
        var gallery = Gallery.preview
        gallery.title = "Original Title"
        gallery.jpnTitle = "日本語の題名"
        #expect(gallery.titleMatches("題名"))
        #expect(gallery.titleMatches("original"))
        #expect(!gallery.titleMatches("missing"))
    }
}
