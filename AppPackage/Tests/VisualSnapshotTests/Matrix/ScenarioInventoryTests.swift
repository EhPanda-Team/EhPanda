import Foundation
import XCTest

/// The catalog against `scenarios.json` (19-02, closed in 19-10, moved into per-view providers in 19-18): every
/// inventory scenario has a state, every declared state is an inventory scenario, and each ID is declared once. A
/// committed page height never falls below the pinned device's own. Fast; captures nothing.
final class ScenarioInventoryTests: XCTestCase {
    @MainActor
    func testEveryRegisteredIDIsInTheInventory() throws {
        let known = try Set(ScenarioInventory.load().scenarios.map(\.id))
        let unknown = ScenarioCatalog.registeredIDs.subtracting(known)
        XCTAssertTrue(unknown.isEmpty, "Registered but not in scenarios.json: \(unknown.sorted())")
    }

    @MainActor
    func testNoIDIsDeclaredTwice() {
        let repeated = Dictionary(grouping: ScenarioCatalog.states.map(\.id), by: { $0 }).filter({ $0.value.count > 1 })
        XCTAssertTrue(repeated.isEmpty, "Declared more than once: \(repeated.keys.sorted())")
    }

    /// The inventory is closed (19-10): every scenario in `scenarios.json` has a state, so the inventory and the
    /// catalog agree exactly. A state that cannot be captured is a not-applicable rule with its reason, never a
    /// missing state (D-04, D-05, D-12).
    @MainActor
    func testEveryInventoryIDHasAFactory() throws {
        let registered = ScenarioCatalog.registeredIDs
        let missing = try ScenarioInventory.load().scenarios.map(\.id).filter({ !registered.contains($0) })
        XCTAssertTrue(missing.isEmpty, "\(missing.count) inventory scenarios have no state: \(missing.sorted())")
    }

    /// A page shorter than the screen keeps the screen's height (design section 2), so no committed height may be
    /// below the pinned device height of its family and orientation.
    @MainActor
    func testEveryCommittedHeightCoversThePinnedDeviceHeight() throws {
        let pins = try SnapshotPins.load()
        for state in ScenarioCatalog.states {
            for family in ["iphone", "ipad"] {
                for orientation in ["portrait", "landscape"] {
                    let geometry = try XCTUnwrap(pins.geometry(family: family, orientation: orientation))
                    let screen = geometry.points[1]
                    for size in ["xSmall", "large", "accessibility5"] {
                        let points = state.heights.points(
                            family: family, orientation: orientation, size: size, screenHeight: screen
                        )
                        XCTAssertGreaterThanOrEqual(
                            points, screen, "\(state.id): \(family) \(orientation) \(size) is below the screen"
                        )
                    }
                }
            }
        }
    }

    /// The fixture export takes only the inventory's scenarios with a public fixture (Phase 17's reader).
    @MainActor
    func testFixtureExportTakesTheInventorysFixtureScenarios() throws {
        let bundle = Bundle(for: SnapshotMatrixCase.self)
        let url = try XCTUnwrap(bundle.url(forResource: "scenarios", withExtension: "json"))
        let rows = try XCTUnwrap(
            JSONSerialization.jsonObject(with: FixtureArtwork.fixtureScenarios(Data(contentsOf: url)))
                as? [[String: Any]]
        )
        XCTAssertEqual(rows.compactMap({ $0["id"] as? String }), ["home-populated"])
        XCTAssertEqual(rows.compactMap({ $0["fixtureID"] as? String }), ["home-finite"])
    }
}
