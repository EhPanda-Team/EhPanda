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
        let fixture = try CaptureFixtureCopy.make()
        addTeardownBlock {
            try fixture.remove()
        }
        let expectedHome = try CaptureDiagnostics(home: fixture)
        let configuration = #"{"purpose":"marketingReal","scenarioID":"home","fixtureID":"nonexplicit"}"#
        let app = XCUIApplication()
        app.launchEnvironment = [
            "EHPANDA_CAPTURE_CONFIGURATION": configuration,
            "EHPANDA_CAPTURE_FIXTURES": fixture.version.path(percentEncoded: false)
        ]

        for launch in ["first launch", "relaunch"] {
            app.launch()
            let settled = try app.settledCaptureDiagnostics(as: CaptureDiagnostics.self, during: launch)
            XCTAssertEqual(
                settled.diagnostics,
                expectedHome,
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

extension CaptureDiagnostics {
    /// The diagnostics of Home showing `fixture`'s nonexplicit selection, fully loaded.
    init(home fixture: CaptureFixtureCopy) throws {
        self.init(
            screenID: "home",
            selectionID: fixture.selection.selectionID,
            fixtureVersion: fixture.fixtureVersion,
            galleryIDs: try fixture.selection.scene("nonexplicit").home.galleryIDs(),
            page: nil,
            readiness: "ready",
            pendingImages: 0,
            unknownRequests: []
        )
    }
}
