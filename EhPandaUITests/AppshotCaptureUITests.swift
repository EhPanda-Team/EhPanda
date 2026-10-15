#if DEBUG
import AppshotProtocol
import AppshotXCTest
import XCTest

/// The standalone CLI drives the actual app, using the same content checks as the reference runner.
final class AppshotCaptureUITests: XCTestCase {
    @MainActor
    func testCapture() async throws {
        continueAfterFailure = true
        try await captureAppshotScene { scene in
            let coordinate = CaptureCoordinate(
                screen: try XCTUnwrap(CaptureCoordinate.Screen(rawValue: scene.coordinate.screen)),
                set: try XCTUnwrap(scene.coordinate.custom["set"]),
                locale: try XCTUnwrap(CaptureCoordinate.Locale(rawValue: scene.coordinate.locale)),
                theme: try XCTUnwrap(CaptureCoordinate.Theme(rawValue: scene.coordinate.appearance.rawValue)),
                family: try XCTUnwrap(CaptureCoordinate.Family(rawValue: scene.coordinate.device))
            )
            let path = try XCTUnwrap(scene.inputs["fixtures"], "The capture has no fixtures input")
            let version = URL(filePath: path, directoryHint: .isDirectory)
            // AppshotXCTest owns this copy and removes it in teardown; this test only reads it.
            let fixture = try CaptureFixtureCopy.read(version: version, root: version)
            let content = try XCTUnwrap(scene.state.app, "The app reported no content diagnostics")
            let diagnostics = try JSONDecoder().decode(
                CaptureLaunchDiagnostics.self,
                from: StrictJSON.encode(content)
            )
            let verifier = CaptureContentVerifier(coordinate: coordinate, fixture: fixture)
            let liveText = coordinate.screen == .readingLiveText ? try verifier.recordedLiveText() : nil
            try verifier.verify(diagnostics, liveText: liveText)
        }
    }
}
#endif
