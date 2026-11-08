import AppModels
import Foundation
import Testing

// D-06c as amended by Phase 20 D-12 (owner msg 2552): the install signal reports the distribution
// channel stamped into the app's Info.plist, as is, from a closed allow-list. Anything else is
// `source`, so no stamped value can widen what reaches an analytics payload (T-18-21).
@Suite
struct DistributionChannelTests {
    // MARK: The allow-list

    // The raw values are written out here rather than read back from the source: the workflows spell
    // them (`actions-tool/package-channel.sh`) and the dashboard keys on them, so a respelled case
    // would stop matching both.
    @Test(arguments: [
        ChannelCase(stamp: "github", channel: .github),
        ChannelCase(stamp: "altstore", channel: .altstore),
        ChannelCase(stamp: "sidestore", channel: .sidestore),
        ChannelCase(stamp: "altstorePAL", channel: .altstorePAL),
        ChannelCase(stamp: "beta", channel: .beta),
        ChannelCase(stamp: "source", channel: .source)
    ])
    func everyAllowedStampIsItsChannel(channelCase: ChannelCase) {
        #expect(DistributionChannel(stampedValue: channelCase.stamp) == channelCase.channel)
        #expect(channelCase.channel.rawValue == channelCase.stamp)
    }

    @Test
    func theAllowListIsTheSixChannels() {
        #expect(DistributionChannel.allCases.map(\.rawValue) == [
            "github", "altstore", "sidestore", "altstorePAL", "beta", "source"
        ])
    }

    @Test
    func theStampIsReadFromItsKey() {
        #expect(DistributionChannel.infoPlistKey == "EhPandaDistributionChannel")

        var reads: [String] = []
        let channel = DistributionChannel(infoPlistValue: { key in
            reads.append(key)
            return "github"
        })

        #expect(channel == .github)
        #expect(reads == ["EhPandaDistributionChannel"])
    }

    // MARK: Anything else is `source`

    // Exact comparison: no case folding, trimming or prefixes, and none of the values MarketplaceKit
    // used to report (owner msg 2552).
    @Test(arguments: [
        "", "Beta", "GitHub", "AltStore", "SideStore", "altstorepal", "ALTSTOREPAL", " beta", "beta ", "beta\n",
        "beta.1", "Source", "other", "appStore", "testFlight", "web", "unknown", "marketplace:com.example.store"
    ])
    func anyOtherStringStampIsSource(value: String) {
        #expect(DistributionChannel(stampedValue: value) == .source)
    }

    @Test
    func aMissingStampIsSource() {
        #expect(DistributionChannel(stampedValue: nil) == .source)
        #expect(DistributionChannel(infoPlistValue: { _ in nil }) == .source)
    }

    // A plist value of the wrong type counts as no stamp, rather than being read as its description.
    @Test
    func aStampThatIsNotAStringIsSource() {
        #expect(DistributionChannel(stampedValue: true) == .source)
        #expect(DistributionChannel(stampedValue: 1) == .source)
        #expect(DistributionChannel(stampedValue: ["beta"]) == .source)
        #expect(DistributionChannel(stampedValue: ["EhPandaDistributionChannel": "beta"]) == .source)
        #expect(DistributionChannel(stampedValue: Data("beta".utf8)) == .source)
    }

    // MARK: The running app

    // The test host is built from the committed `App/Info.plist`, which says `source`; the package
    // test runner has no stamp at all. Either way no release channel is reported from a test run.
    @Test
    func theTestRunReportsSource() {
        #expect(DistributionChannel.current == .source)
    }
}

struct ChannelCase: Sendable {
    let stamp: String
    let channel: DistributionChannel
}
