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
    private static func isWireValue(_ value: String) -> Bool {
        value.wholeMatch(of: #/(appStore|testFlight|web|other|unknown|marketplace:[A-Za-z0-9.-]{1,155})/#) != nil
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
        #expect(await InstallSourceClient.live.current() == .other)
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
