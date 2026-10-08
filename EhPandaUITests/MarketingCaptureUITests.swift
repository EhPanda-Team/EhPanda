import UniformTypeIdentifiers
import XCTest

/// Captures one marketing coordinate on the actual app: the runner names the coordinate and a local
/// fixture version, the app opens the coordinate's screen through its own navigation, and the test
/// passes only once that screen shows exactly the selection's content, fully loaded, in the
/// coordinate's language, appearance and device family, and holds still. It records the app's state
/// and the system's screenshot of the screen for the coordinate.
@MainActor
final class MarketingCaptureUITests: XCTestCase {
    override func setUpWithError() throws {
        // A capture that fails a check still records its state and screenshot as evidence.
        continueAfterFailure = true
    }

    func testCaptureCoordinate() throws {
        let launcher = try CaptureLauncher(coordinate: try CaptureCoordinate.fromEnvironment())
        addTeardownBlock {
            try await launcher.tearDown()
        }

        let settled = try launcher.launch(XCUIApplication())
        let screen = XCUIScreen.main.settledScreenshot()
        XCTAssertTrue(screen.isSettled, "The \(launcher.coordinate.key) screen never held still.")

        let state = XCTAttachment(string: settled.json)
        state.name = "capture-\(launcher.coordinate.key)-state"
        // The rendered PNG bytes unchanged, which the native runner compares across cold launches.
        let frame = XCTAttachment(data: screen.png, uniformTypeIdentifier: UTType.png.identifier)
        frame.name = "capture-\(launcher.coordinate.key)-screen"
        for attachment in [state, frame] {
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
