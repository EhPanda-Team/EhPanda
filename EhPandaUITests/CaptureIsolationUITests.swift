import XCTest

/// Launches the actual app on a real marketing fixture version and proves the capture is isolated
/// and offline: Home shows exactly the selected galleries, every image arrives from the fixture,
/// no request goes unanswered, and a relaunch, which resets the capture's storage, shows the same
/// scene again.
///
/// The fixture holds real gallery content, so it never enters the repository. The runner names a
/// local fixture version directory through `TEST_RUNNER_EHPANDA_CAPTURE_SOURCE` (for example
/// `.capture/marketing/current`); the test copies it into its own temporary directory, which the
/// app then reads. Without that input the test fails rather than skip, so a missing fixture can
/// never pass as evidence.
@MainActor
final class CaptureIsolationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeCaptureShowsTheSelectionOfflineAcrossAResetRelaunch() throws {
        let fixture = try CapturedFixture.copy()
        addTeardownBlock { [root = fixture.root] in
            try FileManager.default.removeItem(at: root)
        }
        let configuration = #"{"purpose":"marketingReal","scenarioID":"home","fixtureID":"nonexplicit"}"#
        let app = XCUIApplication()
        app.launchEnvironment = [
            "EHPANDA_CAPTURE_CONFIGURATION": configuration,
            "EHPANDA_CAPTURE_FIXTURES": fixture.version.path(percentEncoded: false)
        ]

        for launch in ["first launch", "relaunch"] {
            app.launch()
            let settled = try settledDiagnostics(of: app, during: launch)
            XCTAssertEqual(
                settled.diagnostics,
                fixture.expectedHome,
                "Home differs from the selection on the \(launch)."
            )
            let attachments = [
                XCTAttachment(string: settled.json),
                XCTAttachment(screenshot: app.screenshot())
            ]
            for attachment in attachments {
                attachment.name = "capture-home-\(launch.replacingOccurrences(of: " ", with: "-"))"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            app.terminate()
        }
    }

    /// Waits until the capture reports Home finished or failed, then reads its diagnostics, both as
    /// the app wrote them and decoded.
    private func settledDiagnostics(
        of app: XCUIApplication,
        during launch: String
    ) throws -> (json: String, diagnostics: CaptureDiagnostics) {
        let element = app.descendants(matching: .any).matching(identifier: "capture_diagnostics").firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 30), "The \(launch) did not start a capture.")
        let settles = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "value CONTAINS %@ OR value CONTAINS %@",
                #""readiness":"ready""#,
                #""readiness":"failed""#
            ),
            object: element
        )
        let outcome = XCTWaiter.wait(for: [settles], timeout: 60)
        let value = try XCTUnwrap(element.value as? String, "The capture diagnostics have no value.")
        XCTAssertEqual(outcome, .completed, "Home never finished loading on the \(launch): \(value)")
        do {
            return (value, try JSONDecoder().decode(CaptureDiagnostics.self, from: Data(value.utf8)))
        } catch {
            XCTFail("The capture diagnostics are not readable on the \(launch): \(value)")
            throw error
        }
    }
}

/// The app's capture diagnostics, as the accessibility value of `capture_diagnostics` carries them.
private struct CaptureDiagnostics: Decodable, Equatable {
    let screenID: String?
    let selectionID: String
    let fixtureVersion: String
    let galleryIDs: [String]
    let page: Int?
    let readiness: String
    let pendingImages: Int
    let unknownRequests: [String]
}

/// A copy of the runner-named fixture version in the test's own temporary directory, and the Home
/// diagnostics its selection calls for.
private struct CapturedFixture {
    /// The temporary directory this test created; removed when the test ends.
    let root: URL
    let version: URL
    let expectedHome: CaptureDiagnostics

    static func copy() throws -> Self {
        let sourcePath = try XCTUnwrap(
            ProcessInfo.processInfo.environment["EHPANDA_CAPTURE_SOURCE"],
            "Run with TEST_RUNNER_EHPANDA_CAPTURE_SOURCE naming a marketing fixture version directory."
        )
        // A `current` link is resolved once, so the copy is one fixed version.
        let source = URL(filePath: sourcePath, directoryHint: .isDirectory).resolvingSymlinksInPath()
        let root = FileManager.default.temporaryDirectory
            .appending(path: "CaptureIsolation-\(UUID().uuidString)", directoryHint: .isDirectory)
        let version = root.appending(path: source.lastPathComponent, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: version)

        let manifest = try JSONDecoder().decode(
            FixtureManifest.self,
            from: Data(contentsOf: version.appending(path: "manifest.json"))
        )
        let selection = try JSONDecoder().decode(
            FixtureSelection.self,
            from: Data(contentsOf: version.appending(path: "selection.json"))
        )
        let home = try XCTUnwrap(selection.scenes["nonexplicit"], "The selection has no nonexplicit scene.").home
        let toplists = try ["yesterday", "pastMonth", "pastYear", "allTime"].flatMap { period in
            try XCTUnwrap(home.toplists[period], "The selection has no \(period) Toplists.")
        }
        return Self(
            root: root,
            version: version,
            expectedHome: CaptureDiagnostics(
                screenID: "home",
                selectionID: selection.selectionID,
                fixtureVersion: manifest.fixtureVersion,
                galleryIDs: home.hero.galleries + home.frontpage + toplists,
                page: nil,
                readiness: "ready",
                pendingImages: 0,
                unknownRequests: []
            )
        )
    }
}

private struct FixtureManifest: Decodable {
    let fixtureVersion: String
}

private struct FixtureSelection: Decodable {
    struct Scene: Decodable {
        let home: Home
    }

    struct Home: Decodable {
        let hero: Hero
        let frontpage: [String]
        let toplists: [String: [String]]
    }

    struct Hero: Decodable {
        let galleries: [String]
    }

    let selectionID: String
    let scenes: [String: Scene]
}
