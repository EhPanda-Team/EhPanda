import AppModels
import Foundation
import Testing

struct ReadingOrientationPreferencesTests {
    @Test
    func anOldSettingsBlobKeepsItsValuesAndEnablesTheNewDefaults() throws {
        let setting = Setting(galleryHost: .exhentai, readingDirection: .leftToRight, prefetchLimit: 18)
        var object = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(setting)
        ) as? [String: Any])
        object.removeValue(forKey: "orientationReadingPreferences")
        let decoded = try JSONDecoder().decode(
            Setting.self, from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(decoded.galleryHost == .exhentai)
        #expect(decoded.readingDirection == .leftToRight)
        #expect(decoded.prefetchLimit == 18)
        #expect(decoded.orientationReadingPreferences == nil)
        #expect(decoded.readingOrientation == .init())
    }

    @Test(arguments: [true, false], HorizontalReadingDirection.allCases)
    func chosenPreferencesSurvivePersistence(enabled: Bool, landscape: HorizontalReadingDirection) throws {
        var setting = Setting()
        setting.readingOrientation.isEnabled = enabled
        setting.readingOrientation.landscapeDirection = landscape
        setting.readingOrientation.portraitDirection = .leftToRight
        let decoded = try JSONDecoder().decode(Setting.self, from: JSONEncoder().encode(setting))
        #expect(decoded.readingOrientation == setting.readingOrientation)
    }

    @Test(arguments: HorizontalReadingDirection.allCases)
    func theManualTwoPageControlCanEnableHorizontalReadingFromVertical(direction: HorizontalReadingDirection) {
        var setting = Setting(readingOrientation: .init(landscapeDirection: direction))
        #expect(setting.usesHorizontalDualPages == false)
        setting.usesHorizontalDualPages = true
        #expect(setting.enableDualPageMode)
        #expect(setting.readingDirection == direction.readingDirection)
        setting.usesHorizontalDualPages = false
        #expect(setting.enableDualPageMode == false)
        #expect(setting.readingDirection == direction.readingDirection)
    }

    @Test
    func theManualTwoPageControlKeepsAnAlreadyHorizontalDirection() {
        var setting = Setting(readingDirection: .leftToRight)
        setting.usesHorizontalDualPages = true
        #expect(setting.readingDirection == .leftToRight)
        #expect(setting.usesHorizontalDualPages)
    }
}
