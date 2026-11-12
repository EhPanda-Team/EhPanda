import Foundation
import XCTest

/// The catalog against `scenarios.json` (19-02, closed in 19-10): every inventory scenario has a factory, and every
/// registered factory is an inventory scenario, registered once, in the group file of the plan the inventory names.
/// Fast; captures nothing.
final class ScenarioInventoryTests: XCTestCase {
    func testEveryRegisteredIDIsInTheInventory() throws {
        let known = try Set(ScenarioInventory.load().scenarios.map(\.id))
        let unknown = ScenarioCatalog.registeredIDs.subtracting(known)
        XCTAssertTrue(unknown.isEmpty, "Registered but not in scenarios.json: \(unknown.sorted())")
    }

    func testNoIDIsRegisteredInTwoGroupFiles() {
        let ids = ScenarioCatalog.groups.flatMap(\.factories.keys)
        let repeated = Dictionary(grouping: ids, by: { $0 }).filter({ $0.value.count > 1 }).keys
        XCTAssertTrue(repeated.isEmpty, "Registered in more than one group file: \(repeated.sorted())")
    }

    func testEachIDIsRegisteredInItsPlansGroupFile() throws {
        let plans = try Dictionary(
            ScenarioInventory.load().scenarios.map({ ($0.id, $0.plan ?? "") }), uniquingKeysWith: { first, _ in first }
        )
        for group in ScenarioCatalog.groups {
            for id in group.factories.keys.sorted() {
                guard let plan = plans[id] else { continue }
                XCTAssertEqual(group.plan, plan, "\(id) belongs to \(plan)'s group file.")
            }
        }
    }

    /// The inventory is closed (19-10): every scenario in `scenarios.json` has a factory, so the inventory and the
    /// catalog agree exactly. A state that cannot be captured is a not-applicable rule with its reason, never a
    /// missing factory (D-04, D-05, D-12).
    func testEveryInventoryIDHasAFactory() throws {
        let missing = try ScenarioInventory.load().scenarios.map(\.id).filter({ ScenarioCatalog.factories[$0] == nil })
        XCTAssertTrue(missing.isEmpty, "\(missing.count) inventory scenarios have no factory: \(missing.sorted())")
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
