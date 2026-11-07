import Foundation
import XCTest

/// The catalog against `scenarios.json` (19-02): every registered factory is an inventory scenario, registered once,
/// in the group file of the plan the inventory names. Fast; captures nothing.
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

    /// Reports, without failing, the scenarios 19-05 to 19-08 have not reached yet; 19-10 makes this a failure.
    func testReportsScenariosWithoutAFactory() throws {
        let missing = try ScenarioInventory.load().scenarios.map(\.id).filter({ ScenarioCatalog.factories[$0] == nil })
        let report = "\(missing.count) inventory scenarios have no factory yet."
        print(report)
        let attachment = XCTAttachment(string: ([report] + missing).joined(separator: "\n"))
        attachment.name = "scenarios-without-factory"
        attachment.lifetime = .keepAlways
        add(attachment)
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
