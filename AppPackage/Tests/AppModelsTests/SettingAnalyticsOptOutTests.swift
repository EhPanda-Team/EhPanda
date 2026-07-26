import AppModels
import Foundation
import Testing

// `Setting.shareAnalyticsData` is the one optional field on an otherwise strictly-decoded model, and it is
// optional for a specific reason: synthesized `Codable` throws on a missing non-optional key, so a
// blob written before the opt-out toggle shipped would fail to decode and Sharing would reset *every*
// preference to its default. These tests pin both halves of that: the field tolerates an old blob, and
// the accessor resolves the resulting `nil` to the opt-in state the build already had.
@Suite
struct SettingAnalyticsOptOutTests {
    /// A `Setting` blob as written before `shareAnalyticsData` existed: every other key present, this one
    /// absent. Encoding a current `Setting` and deleting the key reproduces an old blob faithfully,
    /// and keeps this fixture from rotting as unrelated fields are added.
    private func legacyBlob(mutate: (inout Setting) -> Void = { _ in }) throws -> Data {
        var setting = Setting()
        mutate(&setting)
        var object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(setting)
        ) as? [String: Any] ?? [:]
        object.removeValue(forKey: "shareAnalyticsData")
        return try JSONSerialization.data(withJSONObject: object)
    }

    // The regression this file exists for. If `shareAnalyticsData` were made non-optional, this throws,
    // and in the app that throw silently wipes the user's host, reading direction and every other
    // preference rather than merely losing the new flag.
    @Test
    func aBlobWrittenBeforeTheToggleExistedStillDecodes() throws {
        let decoded = try JSONDecoder().decode(Setting.self, from: legacyBlob())

        #expect(decoded.shareAnalyticsData == nil)
    }

    // Decoding an old blob must not disturb anything else in it.
    @Test
    func decodingAnOldBlobPreservesEveryOtherPreference() throws {
        let blob = try legacyBlob {
            $0.galleryHost = .exhentai
            $0.readingDirection = .rightToLeft
            $0.listDisplayMode = .thumbnail
            $0.prefetchLimit = 42
        }

        let decoded = try JSONDecoder().decode(Setting.self, from: blob)

        #expect(decoded.galleryHost == .exhentai)
        #expect(decoded.readingDirection == .rightToLeft)
        #expect(decoded.listDisplayMode == .thumbnail)
        #expect(decoded.prefetchLimit == 42)
    }

    // An existing user must not be silently opted out by the upgrade that introduces the toggle.
    @Test
    func anOldBlobResolvesToOptedIn() throws {
        let decoded = try JSONDecoder().decode(Setting.self, from: legacyBlob())

        #expect(decoded.isSharingAnalyticsData)
    }

    @Test(arguments: [true, false])
    func theAccessorRoundTripsThroughTheStoredOptional(shared: Bool) {
        var setting = Setting()
        setting.isSharingAnalyticsData = shared

        #expect(setting.isSharingAnalyticsData == shared)
        // Writing pins the optional, so a later decode reads the user's explicit choice rather than
        // falling back through `nil` to the default again.
        #expect(setting.shareAnalyticsData == shared)
    }

    @Test(arguments: [true, false])
    func anExplicitChoiceSurvivesAnEncodeDecodeRoundTrip(shared: Bool) throws {
        var setting = Setting()
        setting.isSharingAnalyticsData = shared

        let decoded = try JSONDecoder().decode(Setting.self, from: JSONEncoder().encode(setting))

        #expect(decoded.shareAnalyticsData == shared)
        #expect(decoded.isSharingAnalyticsData == shared)
    }
}
