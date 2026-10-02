import AppFeature
import Foundation
import VisualSnapshotSupport
import XCTest

final class FullContentFeasibilityTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testExportPublicFixtures() throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = environment["EHPANDA_PUBLIC_FIXTURE_EXPORT_DIRECTORY"].map({
            URL(fileURLWithPath: $0, isDirectory: true)
        }) ?? FileManager.default.temporaryDirectory
            .appending(component: "phase17-public-export-\(UUID().uuidString)", directoryHint: .isDirectory)
        let secondDirectory = FileManager.default.temporaryDirectory
            .appending(component: "phase17-public-repeat-\(UUID().uuidString)", directoryHint: .isDirectory)
        let scenarios = try environment["EHPANDA_VISUAL_SCENARIOS"].map({
            try Data(contentsOf: URL(fileURLWithPath: $0))
        })
        do {
            let first = try PublicVisualFixtures.export(to: directory, scenarios: scenarios)
            let second = try PublicVisualFixtures.export(to: secondDirectory, scenarios: scenarios)
            XCTAssertEqual(first.aggregateDigest, second.aggregateDigest)
            XCTAssertEqual(try Data(contentsOf: first.manifestURL), try Data(contentsOf: second.manifestURL))
            XCTAssertFalse(first.aggregateDigest.isEmpty)
            let attachment = XCTAttachment(compressedContentsOfDirectory: directory)
            attachment.name = "phase17-public-fixtures"
            attachment.lifetime = .keepAlways
            add(attachment)
        } catch {
            XCTFail("Committed fixtures must export complete repeatable bytes into empty directories: \(error)")
        }
    }
}
