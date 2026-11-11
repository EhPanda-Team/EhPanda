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
        "App.dualPageMode", "App.translateTags", "App.distributionChannel"
    ]
    /// Where the app came from is the one parameter below Full (20-12 §3, owner msg 2842).
    private static let channelKey = "App.distributionChannel"

    private static func baseSetting() -> Setting {
        var setting = Setting()
        // A level that shares the parameters; the gate itself is pinned in "The level gate" below.
        setting.analyticsLevel = .full
        setting.galleryHost = .ehentai
        setting.readingDirection = .vertical
        setting.translateTags = false
        setting.enableDualPageMode = false
        return setting
    }

    // MARK: The pure snapshot

    // The shape is fixed at six entries at Full under every input, so a parameter added or dropped fails
    // here rather than silently changing the default-parameter set the whole dataset is segmented by.
    @Test
    func snapshotAlwaysCarriesExactlyTheSixExpectedKeys() {
        let parameters = AnalyticsDefaultParameters.snapshot(setting: Self.baseSetting(), didLogin: false)

        #expect(parameters.count == 6)
        #expect(Set(parameters.keys) == Self.keys)
    }

    // The Int-raw `ReadingDirection` enum must ship its stable spelling, not
    // their persisted ordinal — a bare integer on the dashboard would re-number every history row the
    // moment a case is inserted upstream. Sweeping every combination proves no value is ever a digit
    // string, which is the failure a snapshot of the raw value would produce.
    @Test
    func noSnapshotValueIsABareInteger() {
        for host in GalleryHost.allCases {
            for direction in ReadingDirection.allCases {
                var setting = Self.baseSetting()
                setting.galleryHost = host
                setting.readingDirection = direction

                let parameters = AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: true)

                for value in parameters.values {
                    #expect(Int(value) == nil, "value \(value) rendered as a bare integer")
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

    // MARK: The level gate

    // Only Full promises "your main settings" (D-06f), so Minimal, and no level, get none. Asserting
    // emptiness rather than a smaller key set is deliberate: a future parameter added to `snapshot`
    // above the guard would leak onto a signal the user did not agree to, and this fails the moment it
    // does. Basic gets the channel and nothing else, which the next group pins.
    @Test(arguments: [nil, .minimal] as [AnalyticsLevel?])
    func snapshotIsEmptyWithoutALevelThatSharesIt(level: AnalyticsLevel?) {
        var setting = Self.baseSetting()
        setting.analyticsLevel = level

        #expect(AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: false).isEmpty)
        #expect(AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: true).isEmpty)
    }

    // The gate must not depend on any other field's value, or a particular combination of
    // preferences could leak parameters before the user chose a level that shares them.
    @Test(arguments: [nil, .minimal] as [AnalyticsLevel?])
    func aLevelBelowBasicEmptiesTheSnapshotUnderEveryOtherSetting(level: AnalyticsLevel?) {
        for host in GalleryHost.allCases {
            for direction in ReadingDirection.allCases {
                for didLogin in [true, false] {
                    var setting = Self.baseSetting()
                    setting.galleryHost = host
                    setting.readingDirection = direction
                    setting.analyticsLevel = level

                    let parameters = AnalyticsDefaultParameters.snapshot(
                        setting: setting, didLogin: didLogin
                    )

                    #expect(parameters.isEmpty, "leaked \(parameters.keys.sorted()) at \(String(describing: level))")
                }
            }
        }
    }

    // Nothing is chosen until the user chooses, so a caller that never sets a level gets nothing.
    @Test
    func aDefaultSettingHasNoLevelAndCarriesNoParameters() {
        #expect(Setting().analyticsLevel == nil)
        #expect(AnalyticsDefaultParameters.snapshot(setting: Setting(), didLogin: false).isEmpty)
    }

    @Test
    func fullCarriesAllFiveSettingsParametersAndTheChannel() {
        var setting = Self.baseSetting()
        setting.analyticsLevel = .full

        #expect(Set(AnalyticsDefaultParameters.snapshot(setting: setting, didLogin: false).keys) == Self.keys)
    }

    // MARK: The channel at Basic (20-12 §3, owner msg 2842)

    // Basic carries exactly one default parameter, and it is the channel: no `App.*` key other than
    // `App.distributionChannel`, under every other setting, so the settings stay a Full-only promise.
    @Test(arguments: DistributionChannel.allCases)
    func basicCarriesTheChannelAndNoOtherAppKey(channel: DistributionChannel) {
        for host in GalleryHost.allCases {
            for direction in ReadingDirection.allCases {
                for didLogin in [true, false] {
                    var setting = Self.baseSetting()
                    setting.galleryHost = host
                    setting.readingDirection = direction
                    setting.analyticsLevel = .basic

                    let parameters = AnalyticsDefaultParameters.snapshot(
                        setting: setting, didLogin: didLogin, distributionChannel: channel
                    )

                    #expect(parameters == [Self.channelKey: channel.rawValue])
                }
            }
        }
    }

    @Test(arguments: DistributionChannel.allCases)
    func fullCarriesTheChannelToo(channel: DistributionChannel) {
        var setting = Self.baseSetting()
        setting.analyticsLevel = .full

        let parameters = AnalyticsDefaultParameters.snapshot(
            setting: setting, didLogin: false, distributionChannel: channel
        )

        #expect(parameters[Self.channelKey] == channel.rawValue)
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
    func liveReReadsTheSharedSettingOnEveryCall() {
        let defaults = UserDefaults.inMemory
        withDependencies {
            $0.defaultAppStorage = defaults
            $0.cookieClient = .testing()
        } operation: {
            @Shared(.setting) var setting
            $setting.withLock {
                $0.analyticsLevel = .full
                $0.galleryHost = .ehentai
            }

            let first = AnalyticsDefaultParameters.live()
            #expect(first["App.host"] == GalleryHost.ehentai.rawValue)

            $setting.withLock({ $0.galleryHost = .exhentai })

            let second = AnalyticsDefaultParameters.live()
            #expect(second["App.host"] == GalleryHost.exhentai.rawValue)
        }
    }
}
