import Testing
import AppModels

// `AppIconType.matching(alternateIconName:)` is the shared mapping used by both the Setting tab's launch
// reconciliation and the App Icon screen's post-edit sync. This pins that every known icon round-trips
// through its filename and that anything unrecognized falls back to `.default`.
@Suite
struct AppIconTypeMatchingTests {
    @Test
    func knownAlternateIconNamesRoundTrip() {
        for iconType in AppIconType.allCases {
            #expect(AppIconType.matching(alternateIconName: iconType.filename) == iconType)
        }
    }

    @Test
    func unrecognizedNameFallsBackToDefault() {
        #expect(AppIconType.matching(alternateIconName: "SomethingElse") == .default)
    }
}
