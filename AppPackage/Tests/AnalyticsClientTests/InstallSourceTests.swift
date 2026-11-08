import Foundation
import InstallSourceClient
import MarketplaceKit
import Testing

// D-06c: where the app was installed from is one value of a small fixed enum, and nothing a
// distributor reports can widen it. Every `AppDistributor` case is constructed here directly, so the
// mapping is proven without a real store install; Phase 20's ANALYTICS-02 verifies it on real
// distribution.
@Suite
struct InstallSourceTests {
    // The wire alphabet, written out here rather than read back from the source: a marketplace ID is
    // a bundle ID of 1 to 155 characters from `A-Z a-z 0-9 . -`, and every other value is one word.
    private static let wordWireValues: Set = [
        "appStore", "testFlight", "web", "other", "github", "altstore", "sidestore", "beta", "source", "unknown"
    ]

    private static func isWireValue(_ value: String) -> Bool {
        wordWireValues.contains(value) || value.wholeMatch(of: #/marketplace:[A-Za-z0-9.-]{1,155}/#) != nil
    }

    // MARK: Mapping

    @Test
    func theAppStoreMapsToAppStore() {
        #expect(InstallSourceClient.map(.appStore) == .appStore)
    }

    @Test
    func testFlightMapsToTestFlight() {
        #expect(InstallSourceClient.map(.testFlight) == .testFlight)
    }

    @Test
    func theWebMapsToWeb() {
        #expect(InstallSourceClient.map(.web) == .web)
    }

    @Test
    func otherMapsToOther() {
        #expect(InstallSourceClient.map(.other) == .other)
    }

    @Test(arguments: ["com.example.store", "a", "Store-1.example", String(repeating: "a", count: 155)])
    func aPlausibleMarketplaceIDIsKept(id: String) {
        #expect(InstallSourceClient.map(.marketplace(id)) == .marketplace(id))
    }

    // Empty, one character too long, a path separator, a space and a non-ASCII name: none is a bundle
    // ID, so none may reach the payload as a store name (T-18-21).
    @Test(arguments: ["", String(repeating: "a", count: 156), "a/b", "a b", "ストア", "com.example.store\n", "a_b"])
    func anImplausibleMarketplaceIDIsUnknown(id: String) {
        #expect(InstallSourceClient.map(.marketplace(id)) == .unknown)
    }

    // MARK: Wire values

    @Test(arguments: [
        WireCase(source: .appStore, wire: "appStore"),
        WireCase(source: .testFlight, wire: "testFlight"),
        WireCase(source: .marketplace("com.example.store"), wire: "marketplace:com.example.store"),
        WireCase(source: .web, wire: "web"),
        WireCase(source: .other, wire: "other"),
        WireCase(source: .github, wire: "github"),
        WireCase(source: .altstore, wire: "altstore"),
        WireCase(source: .sidestore, wire: "sidestore"),
        WireCase(source: .beta, wire: "beta"),
        WireCase(source: .source, wire: "source"),
        WireCase(source: .unknown, wire: "unknown")
    ])
    func everySourceHasItsPinnedWireValue(wireCase: WireCase) {
        #expect(wireCase.source.wireValue == wireCase.wire)
        #expect(Self.isWireValue(wireCase.source.wireValue))
    }

    // Whatever a distributor reports, the mapped value stays inside the wire alphabet. The
    // distributor is described by a Sendable stand-in, because `AppDistributor` is not `Sendable`.
    @Test(arguments: [
        DistributorCase.appStore, .testFlight, .web, .other,
        .marketplace("com.example.store"), .marketplace(""), .marketplace("a b"),
        .marketplace(String(repeating: "a", count: 156)), .marketplace("ストア")
    ])
    func everyMappedValueMatchesTheWireAlphabet(distributorCase: DistributorCase) {
        let wire = InstallSourceClient.map(distributorCase.distributor).wireValue

        #expect(Self.isWireValue(wire), "\(wire) is outside the wire alphabet")
    }

    // MARK: Distribution channel

    // The stamp's raw values are written out here, like the wire values: the workflows spell them
    // (`actions-tool/package-channel.sh`), so a respelled case would stop matching their copies.
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
    }

    @Test
    func theAllowListIsTheSixChannels() {
        #expect(DistributionChannel.allCases.map(\.rawValue) == [
            "github", "altstore", "sidestore", "altstorePAL", "beta", "source"
        ])
        #expect(DistributionChannel.infoPlistKey == "EhPandaDistributionChannel")
    }

    // Exact comparison: no case folding, trimming or prefixes, and no install source spelled as a stamp.
    @Test(arguments: [
        nil, "", "Beta", "GitHub", "AltStore", "SideStore", "altstorepal", "ALTSTOREPAL", " beta", "beta ",
        "beta\n", "beta.1", "other", "appStore", "testFlight", "web", "unknown", "marketplace:com.example.store"
    ])
    func anyOtherStringStampIsIgnored(value: String?) {
        #expect(DistributionChannel(stampedValue: value) == nil)
    }

    // A plist value of the wrong type is ignored too, rather than read as its description.
    @Test
    func aStampThatIsNotAStringIsIgnored() {
        #expect(DistributionChannel(stampedValue: true) == nil)
        #expect(DistributionChannel(stampedValue: 1) == nil)
        #expect(DistributionChannel(stampedValue: ["beta"]) == nil)
        #expect(DistributionChannel(stampedValue: ["EhPandaDistributionChannel": "beta"]) == nil)
        #expect(DistributionChannel(stampedValue: Data("beta".utf8)) == nil)
    }

    // MARK: Device source

    // Apple wins: a store MarketplaceKit names is the answer whatever the stamp says, including the
    // `altstorePAL` cross-check, a stamp naming another channel, and no stamp at all (owner msg 2537).
    @Test(arguments: [
        DistributorCase.appStore, .testFlight, .web, .marketplace("com.example.store")
    ], [nil, "github", "altstore", "sidestore", "altstorePAL", "beta", "source", "bogus"])
    func aStoreMarketplaceKitNamesWinsOverTheStamp(distributorCase: DistributorCase, stamp: String?) {
        let source = Self.deviceSource(distributor: .returns(distributorCase), stamp: stamp)

        #expect(source == InstallSourceClient.map(distributorCase.distributor))
        #expect(source != .other)
    }

    // A marketplace ID that is not a plausible bundle ID is still MarketplaceKit naming a marketplace:
    // the answer is `unknown`, and no stamp replaces it.
    @Test(arguments: [nil, "altstorePAL", "github"])
    func anImplausibleMarketplaceIDStaysUnknownWhateverTheStamp(stamp: String?) {
        let source = Self.deviceSource(distributor: .returns(.marketplace("a b")), stamp: stamp)

        #expect(source == .unknown)
    }

    // MarketplaceKit says `other` for a sideloaded install, or may throw; then the stamp names the build.
    @Test(arguments: [
        StampCase(stamp: "github", source: .github),
        StampCase(stamp: "altstore", source: .altstore),
        StampCase(stamp: "sidestore", source: .sidestore),
        StampCase(stamp: "beta", source: .beta),
        StampCase(stamp: "source", source: .source)
    ], [DistributorResult.returns(.other), .throws])
    func otherOrAThrowReportsTheStampedChannel(stampCase: StampCase, distributor: DistributorResult) {
        let source = Self.deviceSource(distributor: distributor, stamp: stampCase.stamp)

        #expect(source == stampCase.source)
    }

    // Only MarketplaceKit can confirm a PAL install, so a PAL stamp it does not confirm is `unknown`.
    @Test(arguments: [DistributorResult.returns(.other), .throws])
    func theAltStorePALStampWithoutAMarketplaceIsUnknown(distributor: DistributorResult) {
        let source = Self.deviceSource(distributor: distributor, stamp: "altstorePAL")

        #expect(source == .unknown)
    }

    @Test(arguments: [nil, "", "Beta", "other", "appStore", "unknown"], [
        DistributorResult.returns(.other), .throws
    ])
    func aMissingOrUnknownStampIsUnknown(stamp: String?, distributor: DistributorResult) {
        let source = Self.deviceSource(distributor: distributor, stamp: stamp)

        #expect(source == .unknown)
    }

    @Test
    func aStampThatIsNotAStringIsUnknown() {
        let source = InstallSourceClient.deviceSource(marketplaceKit: .other, infoPlistValue: { _ in true })

        #expect(source == .unknown)
    }

    // The client reads exactly one key, the stamp, and only once MarketplaceKit has not named a store.
    @Test
    func theStampIsReadFromItsKeyOnlyWhenMarketplaceKitNamesNoStore() {
        var reads: [String] = []

        _ = InstallSourceClient.deviceSource(marketplaceKit: .appStore, infoPlistValue: { key in
            reads.append(key)
            return "github"
        })
        #expect(reads.isEmpty)

        _ = InstallSourceClient.deviceSource(marketplaceKit: .other, infoPlistValue: { key in
            reads.append(key)
            return "github"
        })
        #expect(reads == ["EhPandaDistributionChannel"])
    }

    /// Calls the device source as the live client does, with what MarketplaceKit reported (mapped, or
    /// nil when it threw) and an Info.plist that holds `stamp` under the channel key, and nothing else.
    private static func deviceSource(distributor: DistributorResult, stamp: String?) -> InstallSource {
        let marketplaceKit: InstallSource? = switch distributor {
        case .returns(let distributorCase):
            InstallSourceClient.map(distributorCase.distributor)

        case .throws:
            nil
        }
        return InstallSourceClient.deviceSource(
            marketplaceKit: marketplaceKit,
            infoPlistValue: { key in key == DistributionChannel.infoPlistKey ? stamp : nil }
        )
    }

    // MARK: Client values

    @Test
    func theTestValueReportsUnknown() async {
        #expect(await InstallSourceClient.testValue.current() == .unknown)
    }

    @Test
    func thePreviewValueReportsUnknown() async {
        #expect(await InstallSourceClient.previewValue.current() == .unknown)
    }

    // The test host runs on the simulator, where the live client never asks MarketplaceKit: a
    // development install can never be counted as a store install (D-06c).
    @Test
    func theLiveClientReportsUnknownOnTheSimulator() async {
        #if targetEnvironment(simulator)
        #expect(await InstallSourceClient.live.current() == .unknown)
        #else
        #expect(await InstallSourceClient.live.current() != .other)
        #endif
    }
}

struct WireCase: Sendable {
    let source: InstallSource
    let wire: String
}

enum DistributorCase: Sendable {
    case appStore
    case testFlight
    case marketplace(String)
    case web
    case other

    var distributor: AppDistributor {
        switch self {
        case .appStore:
            .appStore

        case .testFlight:
            .testFlight

        case .marketplace(let id):
            .marketplace(id)

        case .web:
            .web

        case .other:
            .other
        }
    }
}

struct ChannelCase: Sendable {
    let stamp: String
    let channel: DistributionChannel
}

struct StampCase: Sendable {
    let stamp: String
    let source: InstallSource
}

enum DistributorResult: Sendable {
    case returns(DistributorCase)
    case `throws`
}

