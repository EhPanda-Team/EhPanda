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
        // Once the screen holds still, so the covers are where the screenshot shows them.
        let covers = try XCUIApplication().visibleCovers()
        let repeated = Dictionary(grouping: covers.map(\.gid), by: \.self).filter({ $0.value.count > 1 }).keys
        XCTAssertEqual(repeated.sorted(), [], "The \(launcher.coordinate.key) screen shows a cover twice.")

        let state = XCTAttachment(string: settled.json)
        state.name = "capture-\(launcher.coordinate.key)-state"
        // The covers in sight, which a set's cross-screen check compares with its other screens'.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let visible = XCTAttachment(data: try encoder.encode(covers), uniformTypeIdentifier: UTType.json.identifier)
        visible.name = "capture-\(launcher.coordinate.key)-covers"
        // The PNG exactly as the system rendered it: the native runner compares these bytes across cold launches.
        let frame = XCTAttachment(data: screen.png, uniformTypeIdentifier: UTType.png.identifier)
        frame.name = "capture-\(launcher.coordinate.key)-screen"
        for attachment in [state, visible, frame] {
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    /// Records the Live Text the app's own recognizer finds on the coordinate's reading-live-text page,
    /// which `record-live-text.py` saves into the fixture for every capture of that screen to replay.
    func testRecordLiveText() throws {
        let launcher = try CaptureLauncher(coordinate: try CaptureCoordinate.fromEnvironment())
        addTeardownBlock {
            try await launcher.tearDown()
        }

        let settled = try launcher.recordLiveText(XCUIApplication())

        let state = XCTAttachment(string: settled.json)
        state.name = "live-text-recording-\(launcher.coordinate.key)-state"
        state.lifetime = .keepAlways
        add(state)
    }
}
