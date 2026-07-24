@testable import AnalyticsClient
import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import Sharing
import Testing

// Two groups, split along the seam the source is split on. `snapshot` is pure, so its group is a
// plain exhaustive sweep with no shared state at all — every enum case, both states of every flag,
// and both login states, each pinned against a literal spelling written out here rather than read
// back from the source. The one `live` test is the only one that touches process-global storage,
// and it exists to prove the single thing the sweeps cannot: that `live` re-reads the shared
// setting on every call instead of snapshotting it once (D-11, research Pitfall 7).
@Suite
struct AnalyticsDefaultParametersTests {
    private static let keys: Set<String> = [
        "App.host", "App.loggedIn", "App.readingDirection",
        "App.dualPageMode", "App.translateTags", "App.listDisplayMode"
    ]

    private static func baseSetting() -> Setting {
        var setting = Setting()
        setting.galleryHost = .ehentai
        setting.readingDirection = .vertical
        setting.listDisplayMode = .detail
        setting.translateTags = false
        setting.enableDualPageMode = false
        return setting
    }

    // MARK: The pure snapshot

    // The shape is fixed at six entries under every input, so a parameter added or dropped fails
    // here rather than silently changing the default-parameter set the whole dataset is segmented by.
    @Test
    func snapshotAlwaysCarriesExactlyTheSixExpectedKeys() {
        let parameters = AnalyticsDefaultParameters.snapshot(setting: Self.baseSetting(), didLogin: false)

        #expect(parameters.count == 6)
        #expect(Set(parameters.keys) == Self.keys)
    }

    // The Int-raw enums (`ReadingDirection`, `ListDisplayMode`) must ship their stable spelling, not
    // their persisted ordinal — a bare integer on the dashboard would re-number every history row the
    // moment a case is inserted upstream. Sweeping every combination proves no value is ever a digit
    // string, which is the failure a snapshot of the raw value would produce.
    @Test
    func noSnapshotValueIsABareInteger() {
        for host in GalleryHost.allCases {
            for direction in ReadingDirection.allCases {
                for mode in ListDisplayMode.allCases {
                    var setting = Self.baseSetting()
                    setting.galleryHost = host
                    setting.readingDirection = direction
                    setting.listDisplayMode = mode

                    let parameters = AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: true)

                    for value in parameters.values {
                        #expect(Int(value) == nil, "value \(value) rendered as a bare integer")
                    }
                }
            }
        }
    }

    @Test(arguments: GalleryHost.allCases)
    func hostRendersToItsRawValue(host: GalleryHost) {
        var setting = Self.baseSetting()
        setting.galleryHost = host

        let parameters = AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: false)

        #expect(parameters["App.host"] == host.rawValue)
        #expect(Set(parameters.keys) == Self.keys)
    }

    @Test(arguments: [true, false])
    func loginStateRendersToABooleanSpelling(didLogin: Bool) {
        let parameters = AnalyticsDefaultParameters.snapshot(setting: Self.baseSetting(), didLogin: didLogin)

        #expect(parameters["App.loggedIn"] == (didLogin ? "true" : "false"))
        #expect(Set(parameters.keys) == Self.keys)
    }

    @Test(arguments: ReadingDirection.allCases)
    func readingDirectionRendersToItsStableSpelling(direction: ReadingDirection) {
        let expected: String
        switch direction {
        case .vertical:
            expected = "vertical"

        case .rightToLeft:
            expected = "rightToLeft"

        case .leftToRight:
            expected = "leftToRight"
        }

        var setting = Self.baseSetting()
        setting.readingDirection = direction

        let parameters = AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: false)

        #expect(parameters["App.readingDirection"] == expected)
    }

    @Test(arguments: ListDisplayMode.allCases)
    func listDisplayModeRendersToItsStableSpelling(mode: ListDisplayMode) {
        let expected: String
        switch mode {
        case .detail:
            expected = "detail"

        case .thumbnail:
            expected = "thumbnail"
        }

        var setting = Self.baseSetting()
        setting.listDisplayMode = mode

        let parameters = AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: false)

        #expect(parameters["App.listDisplayMode"] == expected)
    }

    @Test(arguments: [true, false])
    func dualPageModeRendersToABooleanSpelling(enabled: Bool) {
        var setting = Self.baseSetting()
        setting.enableDualPageMode = enabled

        let parameters = AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: false)

        #expect(parameters["App.dualPageMode"] == (enabled ? "true" : "false"))
    }

    @Test(arguments: [true, false])
    func translateTagsRendersToABooleanSpelling(enabled: Bool) {
        var setting = Self.baseSetting()
        setting.enableTagsExtension = true
        setting.translateTags = enabled

        let parameters = AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: false)

        #expect(parameters["App.translateTags"] == (enabled ? "true" : "false"))
    }

    // MARK: The live closure

    // The assertion that distinguishes a closure from a snapshot: read `live` once, mutate the shared
    // setting, read it again, and the second read must reflect the mutation. If `live` had captured a
    // value at configuration time this would fail on the second read — which is exactly the D-11
    // regression this test exists to catch. Exactly one `@SharedReader(.didLogin)` is alive at a time
    // (each `live` call opens and closes its own), honoring the one-live-reader constraint the
    // `DidLoginKeyTests` header documents; the shared setting is isolated to in-memory defaults so the
    // suite neither pollutes nor is polluted by the process-wide holder.
    @Test
    func liveReReadsTheSharedSettingOnEveryCall() async throws {
        let defaults = UserDefaults.inMemory
        try await withDependencies {
            $0.defaultAppStorage = defaults
            $0.cookieClient = .testing()
        } operation: {
            @Shared(.setting) var setting
            $setting.withLock({ $0.galleryHost = .ehentai })

            let first = AnalyticsDefaultParameters.live()
            #expect(first["App.host"] == GalleryHost.ehentai.rawValue)

            $setting.withLock({ $0.galleryHost = .exhentai })

            let second = AnalyticsDefaultParameters.live()
            #expect(second["App.host"] == GalleryHost.exhentai.rawValue)
        }
    }
}
