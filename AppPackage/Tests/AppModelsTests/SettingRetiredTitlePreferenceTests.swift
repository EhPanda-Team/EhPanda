import AppModels
import Foundation
import Testing

struct SettingRetiredTitlePreferenceTests {
    @Test(arguments: [nil, true, false] as [Bool?])
    func oldTitlePreferenceDoesNotResetSettingsOrGetWrittenAgain(enabled: Bool?) throws {
        var original = Setting()
        original.galleryHost = .exhentai
        original.galleryListPresentation.favorites = .grid
        original.galleryListPresentation.search = .row
        original.displayJapaneseTitle = false
        original.readingDirection = .rightToLeft
        original.prefetchLimit = 42
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any]
        )
        if let enabled { object["simplifiedGalleryTitles"] = enabled }
        let decoded = try JSONDecoder().decode(
            Setting.self, from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(decoded == original)
        let saved = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any]
        )
        #expect(saved["simplifiedGalleryTitles"] == nil)
    }
}
