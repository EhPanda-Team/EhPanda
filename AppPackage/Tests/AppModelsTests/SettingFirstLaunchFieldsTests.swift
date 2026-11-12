import AppModels
import Foundation
import Testing

// The two first-launch answers live on the v1 `Setting`, edited in place (D-22, DD-08). Both are optional
// because `nil` means "never answered", and an absent key is exactly that: a blob written before 3.0
// decodes with both `nil`, which is what shows every upgrader the age wall and the analytics choice (D-03).
// The retired `shareAnalyticsData` key must neither reset a blob nor be written again, so no 2.x answer
// can stand in for the 3.0 choice.
struct SettingFirstLaunchFieldsTests {
    /// A current `Setting` with every other field moved off its default, so a decode that reset the
    /// blob would show up as a mismatch rather than as an accidental match with the defaults.
    private static func customizedSetting() -> Setting {
        var setting = Setting()
        setting.galleryHost = .exhentai
        setting.galleryListPresentation.favorites = .grid
        setting.readingDirection = .rightToLeft
        setting.prefetchLimit = 42
        setting.displayJapaneseTitle = false
        return setting
    }

    private static func jsonObject(_ setting: Setting) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(setting)) as? [String: Any])
    }

    private static func decode(_ object: [String: Any]) throws -> Setting {
        try JSONDecoder().decode(Setting.self, from: JSONSerialization.data(withJSONObject: object))
    }

    // MARK: Absent and present

    @Test
    func aBlobWithoutTheFieldsDecodesAsNeverAnswered() throws {
        var object = try Self.jsonObject(Self.customizedSetting())
        object.removeValue(forKey: "ageDeclarationVersion")
        object.removeValue(forKey: "analyticsLevel")

        let decoded = try Self.decode(object)

        #expect(decoded.ageDeclarationVersion == nil)
        #expect(decoded.analyticsLevel == nil)
        #expect(decoded == Self.customizedSetting())
    }

    @Test
    func aDefaultSettingHasNeitherAnswer() {
        #expect(Setting().ageDeclarationVersion == nil)
        #expect(Setting().analyticsLevel == nil)
    }

    @Test
    func aNeverAnsweredSettingWritesNeitherKey() throws {
        let object = try Self.jsonObject(Self.customizedSetting())

        #expect(object["ageDeclarationVersion"] == nil)
        #expect(object["analyticsLevel"] == nil)
    }

    @Test(arguments: AnalyticsLevel.allCases)
    func storedAnswersRoundTrip(level: AnalyticsLevel) throws {
        var setting = Self.customizedSetting()
        setting.ageDeclarationVersion = AgeDeclaration.currentVersion
        setting.analyticsLevel = level

        let decoded = try JSONDecoder().decode(Setting.self, from: JSONEncoder().encode(setting))

        #expect(decoded.ageDeclarationVersion == AgeDeclaration.currentVersion)
        #expect(decoded.analyticsLevel == level)
        #expect(decoded == setting)
    }

    // The persisted spelling is the raw value, so a later case rename would strand stored choices.
    @Test
    func theLevelIsStoredByItsRawSpelling() throws {
        var setting = Setting()
        setting.analyticsLevel = .basic

        let object = try Self.jsonObject(setting)

        #expect(object["analyticsLevel"] as? String == "basic")
    }

    // MARK: The retired toggle

    @Test(arguments: [true, false])
    func theRetiredToggleNeitherResetsSettingsNorSetsALevel(shared: Bool) throws {
        var object = try Self.jsonObject(Self.customizedSetting())
        object["shareAnalyticsData"] = shared

        let decoded = try Self.decode(object)

        #expect(decoded == Self.customizedSetting())
        #expect(decoded.analyticsLevel == nil)
        #expect(decoded.ageDeclarationVersion == nil)
        let saved = try Self.jsonObject(decoded)
        #expect(saved["shareAnalyticsData"] == nil)
    }

    // MARK: Unknown level

    // A level this build does not know (a withdrawn "none", or one from a newer build) must not fail the
    // whole decode, which would reset every other preference; it reads as "not chosen yet" instead.
    @Test(arguments: ["none", "everything", ""])
    func anUnknownLevelDecodesAsNotChosenWithoutResettingSettings(rawValue: String) throws {
        var object = try Self.jsonObject(Self.customizedSetting())
        object["ageDeclarationVersion"] = AgeDeclaration.currentVersion
        object["analyticsLevel"] = rawValue

        let decoded = try Self.decode(object)

        #expect(decoded.analyticsLevel == nil)
        #expect(decoded.ageDeclarationVersion == AgeDeclaration.currentVersion)
        var expected = Self.customizedSetting()
        expected.ageDeclarationVersion = AgeDeclaration.currentVersion
        #expect(decoded == expected)
    }

    @Test
    func aLevelOfTheWrongTypeDecodesAsNotChosenWithoutResettingSettings() throws {
        var object = try Self.jsonObject(Self.customizedSetting())
        object["analyticsLevel"] = 2

        let decoded = try Self.decode(object)

        #expect(decoded.analyticsLevel == nil)
        #expect(decoded == Self.customizedSetting())
    }

    // MARK: The levels and the wording version

    @Test
    func theLevelsAreMinimalBasicFullInThatOrder() {
        #expect(AnalyticsLevel.allCases == [.minimal, .basic, .full])
        #expect(AnalyticsLevel.allCases.map(\.rawValue) == ["minimal", "basic", "full"])
    }

    @Test
    func theCurrentWordingVersionIsOne() {
        #expect(AgeDeclaration.currentVersion == 1)
    }

    // Equality, never `>=`: a blob carrying another wording version (older, or a downgrade from a newer
    // build) asks again rather than skipping the wall (P-10).
    @Test(arguments: [
        (nil, false), (0, false), (1, true), (2, false), (-1, false)
    ] as [(Int?, Bool)])
    func onlyTheCurrentWordingVersionCountsAsConfirmed(version: Int?, confirmed: Bool) {
        #expect(AgeDeclaration.isConfirmed(version) == confirmed)
    }
}
