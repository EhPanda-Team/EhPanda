@testable import AnalyticsClient
import DeviceClient
import Foundation
import Synchronization
import Testing

// The enricher exists to overwrite one vendor-owned key, so these tests pin the three things that
// would make it silently stop doing that: the exact key it writes, the exact spellings it writes,
// and its refusal to write anything when it has no answer. The refresh hop is exercised from the
// main actor, which is where a signal's refresh lands.
@Suite
struct OrientationEnricherTests {
    // The key has to match the vendor's own, character for character. A typo here would not fail
    // anywhere else: the payload would simply carry an extra column alongside the "Unknown" one
    // this whole type exists to replace.
    private static let key = "TelemetryDeck.Device.orientation"

    @Test(arguments: [
        (InterfaceOrientation.portrait, "Portrait"),
        (InterfaceOrientation.landscape, "Landscape")
    ])
    @MainActor
    func eachOrientationIsReportedUnderTheVendorKey(
        orientation: InterfaceOrientation,
        expected: String
    ) {
        let enricher = OrientationEnricher(read: { orientation })
        enricher.refresh()

        let parameters = enricher.enrich(signalType: "Any.signal", for: nil, floatValue: nil)

        #expect(parameters == [Self.key: expected])
    }

    // Capitalized because the vendor's SDK writes it that way and the dashboard has been grouping
    // on those spellings from other platforms. Lowercasing them would open a second column rather
    // than fill in the existing one, so this is pinned separately from the enrich-path test above.
    @Test
    func theSpellingsMatchTheVendorsOwn() {
        #expect(OrientationEnricher.vendorName(for: .portrait) == "Portrait")
        #expect(OrientationEnricher.vendorName(for: .landscape) == "Landscape")
    }

    // The whole point of returning nothing: the SDK's built-in value stays in place, so an unknown
    // orientation is reported once rather than by two writers that happen to agree.
    @Test
    @MainActor
    func anUnknownOrientationContributesNoKeyAtAll() {
        let enricher = OrientationEnricher(read: { nil })
        enricher.refresh()

        #expect(enricher.enrich(signalType: "Any.signal", for: nil, floatValue: nil).isEmpty)
    }

    // Before the first refresh there is nothing cached, and the enricher must not invent one.
    @Test
    func nothingIsReportedBeforeTheFirstRefresh() {
        let enricher = OrientationEnricher(read: { .landscape })

        #expect(enricher.enrich(signalType: "Any.signal", for: nil, floatValue: nil).isEmpty)
    }

    // A rotation has to reach the next signal. This is the behavior the per-signal refresh buys,
    // and it is why the read is a closure rather than a value captured at init.
    @Test
    @MainActor
    func aRotationIsPickedUpByTheNextRefresh() {
        // A `Mutex` rather than a captured `var`: the read closure is `@Sendable`, so it cannot
        // close over mutable local state.
        let current = Mutex(InterfaceOrientation.portrait)
        let enricher = OrientationEnricher(read: { current.withLock({ $0 }) })

        enricher.refresh()
        #expect(enricher.enrich(signalType: "Any.signal", for: nil, floatValue: nil) == [Self.key: "Portrait"])

        current.withLock({ $0 = .landscape })
        enricher.refresh()
        #expect(enricher.enrich(signalType: "Any.signal", for: nil, floatValue: nil) == [Self.key: "Landscape"])
    }
}
