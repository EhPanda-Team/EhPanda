import AppModels
import Foundation
import Testing

// D-01, D-07: the webtoon option lives on `Setting` and the verdict on the history entry, each as optional storage,
// so blobs written before either existed decode unchanged and read as "off" and "not checked yet".
struct WebtoonReadingPersistenceTests {
    private static func jsonObject(_ value: some Encodable) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }

    @Test
    func aSettingsBlobWithoutTheOptionKeepsItsValuesWithTheOptionOff() throws {
        let setting = Setting(
            galleryHost: .exhentai, readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true
        )
        var object = try Self.jsonObject(setting)
        let removed = object.removeValue(forKey: "webtoonVerticalReadingPreference") as? Bool
        #expect(removed == true)
        let decoded = try JSONDecoder().decode(Setting.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.galleryHost == .exhentai)
        #expect(decoded.readingDirection == .rightToLeft)
        #expect(!decoded.alwaysReadsWebtoonsVertically)
    }

    @Test(arguments: [true, false])
    func theOptionSurvivesPersistence(isOn: Bool) throws {
        var setting = Setting()
        setting.alwaysReadsWebtoonsVertically = isOn
        let decoded = try JSONDecoder().decode(Setting.self, from: JSONEncoder().encode(setting))
        #expect(decoded.alwaysReadsWebtoonsVertically == isOn)
        #expect(decoded == setting)
    }

    @Test(arguments: [true, false], [true, false])
    func onlyAWebtoonWithTheOptionOnIsForcedVertical(isOn: Bool, galleryIsWebtoon: Bool) {
        let setting = Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: isOn)
        #expect(setting.forcesVerticalReading(galleryIsWebtoon: galleryIsWebtoon) == (isOn && galleryIsWebtoon))
    }

    @Test
    func aHistoryEntryWrittenBeforeTheVerdictDecodesAsNotChecked() throws {
        let json = #"{"schemaVersion": 1, "gid": "1", "token": "a", "lastOpenDate": 0, "readingProgress": 3}"#
        let entry = try JSONDecoder().decode(GalleryHistoryEntry.self, from: Data(json.utf8))
        #expect(entry.isWebtoon == nil)
        #expect(entry.readingProgress == 3)
    }

    @Test(arguments: [true, false])
    func aVerdictSurvivesPersistence(isWebtoon: Bool) throws {
        let entry = GalleryHistoryEntry(
            gid: "1", token: "a", lastOpenDate: Date(timeIntervalSince1970: 1), isWebtoon: isWebtoon
        )
        let decoded = try JSONDecoder().decode(GalleryHistoryEntry.self, from: JSONEncoder().encode(entry))
        #expect(decoded == entry)
        #expect(try Self.jsonObject(entry)["isWebtoon"] as? Bool == isWebtoon)
    }
}
