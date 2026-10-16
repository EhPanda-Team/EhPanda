import AppModels
import Foundation
import Testing

@Suite
struct GallerySimplifiedTitleTests {
    @Test(arguments: [
        ("[Author] Title words [tag]", "Title words"),
        ("(Event) [Circle (Artist)] A  Journey 【English】", "A  Journey"),
        ("{Author} 「Info」 Title 『Tag』", "Title"),
        ("［作者］ 標題　內容 （標籤）", "標題　內容"),
        ("〈Author〉 《Title info》 Story  Name 〔tag〕", "Story  Name"),
        ("﹝Author﹞ Story ﹙tag﹚", "Story"),
        ("︵Author︶ Story ﹁tag﹂", "Story"),
        ("❨Author❩ Story ⟦tag⟧", "Story"),
        ("＜Author＞ Story «tag»", "Story"),
        ("[Author] A [note] B", "A B"),
        ("A  [note]   B  C", "A B  C"),
        ("A[note]B", "AB"),
        (" [one] [two]  Story  ", "Story"),
        ("[Author] ﾀｲﾄﾙ ﬁancé [tag]", "ﾀｲﾄﾙ ﬁancé"),
        ("A 👩🏽‍🎨 Story [tag]", "A 👩🏽‍🎨 Story"),
        ("It's  a story", "It's  a story"),
        ("[Unclosed title", "[Unclosed title"),
        ("Story [mismatched)", "Story [mismatched)"),
        ("[Title entirely enclosed]", "[Title entirely enclosed]"),
        ("", "")
    ])
    func simplifiesOnlyBalancedGroupsAndTheirBoundaryWhitespace(input: String, expected: String) {
        var gallery = Gallery.preview
        gallery.title = input
        #expect(gallery.simplifiedTitle == expected)
        #expect(gallery.title == input)
    }

    @Test
    func oldSettingsEnableSimplificationWithoutResettingOtherPreferences() throws {
        var original = Setting()
        original.galleryHost = .exhentai
        original.galleryListPresentation.favorites = .grid
        original.prefetchLimit = 42
        let encoded = try JSONEncoder().encode(original)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "simplifiedGalleryTitles")
        let decoded = try JSONDecoder().decode(
            Setting.self, from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(decoded.simplifyGalleryTitles)
        #expect(decoded.galleryHost == original.galleryHost)
        #expect(decoded.galleryListPresentation == original.galleryListPresentation)
        #expect(decoded.prefetchLimit == 42)
    }

    @Test(arguments: [true, false])
    func explicitChoiceRoundTrips(enabled: Bool) throws {
        var setting = Setting()
        setting.simplifyGalleryTitles = enabled
        let decoded = try JSONDecoder().decode(Setting.self, from: JSONEncoder().encode(setting))
        #expect(decoded.simplifyGalleryTitles == enabled)
    }

    @Test
    func freshSettingsEnableSimplification() {
        #expect(Setting().simplifyGalleryTitles)
    }
}
