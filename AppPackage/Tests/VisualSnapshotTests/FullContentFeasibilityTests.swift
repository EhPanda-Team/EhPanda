import AppFeature
import CryptoKit
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
            let manifest = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: first.manifestURL)) as? [String: Any]
            )
            XCTAssertEqual(manifest["fixtureVersion"] as? String, PublicVisualFixtures.fixtureVersion)
            let entries = try XCTUnwrap(manifest["assets"] as? [[String: Any]])
            XCTAssertGreaterThan(entries.count, 30)
            for entry in entries {
                let path = try XCTUnwrap(entry["path"] as? String)
                let bytes = try Data(contentsOf: directory.appending(path: path))
                XCTAssertEqual(bytes.count, entry["bytes"] as? Int)
                XCTAssertEqual(SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined(),
                               entry["sha256"] as? String)
                XCTAssertFalse(path.hasPrefix("/"))
            }
            let attachment = XCTAttachment(compressedContentsOfDirectory: directory)
            attachment.name = "phase17-public-fixtures"
            attachment.lifetime = .keepAlways
            add(attachment)
        } catch {
            XCTFail("Committed fixtures must export complete repeatable bytes into empty directories: \(error)")
        }
    }

    @MainActor
    func testExportRejectsMissingFixtureAssetAndRoute() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(component: "phase17-invalid-export-\(UUID().uuidString)", directoryHint: .isDirectory)
        let catalogs: [(scenario: [String: Any], expected: PublicFixtureError)] = [
            (["fixtureID": "absent"], .unknownFixture("absent")),
            (["fixtureID": "home-finite", "assets": ["absent.png"]], .missingAsset("absent.png")),
            (["fixtureID": "home-finite", "routes": ["absent"]], .missingRoute("absent"))
        ]
        for catalog in catalogs {
            let data = try JSONSerialization.data(withJSONObject: [catalog.scenario])
            XCTAssertThrowsError(try PublicVisualFixtures.export(to: directory, scenarios: data)) { error in
                XCTAssertEqual(error as? PublicFixtureError, catalog.expected)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        }
    }
}
