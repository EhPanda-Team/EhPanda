#if DEBUG
import Appshot
import AppshotProtocol
import Foundation
import Synchronization

/// Adapts the tool's generic scene to the app's existing validated, offline content contract.
enum AppshotCapture {
    private static let launch = Mutex<AppshotProtocol.CaptureScene?>(nil)

    /// Published during dependency preparation, before any app state exists.
    static var launchedScene: AppshotProtocol.CaptureScene? {
        get { launch.withLock({ $0 }) }
        set { launch.withLock({ $0 = newValue }) }
    }

    static func decode(environment: [String: String]) throws(CaptureFailure) -> AppshotProtocol.CaptureScene? {
        guard let json = environment[EnvironmentName.scene] else {
            return nil
        }
        do {
            return try StrictJSON.decode(AppshotProtocol.CaptureScene.self, from: Data(json.utf8))
        } catch {
            throw .malformedConfiguration("Invalid appshot scene: \(error)")
        }
    }

    /// Rejects competing automation rather than mixing a real-data launch with a capture.
    /// A probe has no inputs and uses the isolated visual host, without a content route.
    static func captureEnvironment(
        _ scene: AppshotProtocol.CaptureScene,
        environment: [String: String]
    ) throws(CaptureFailure) -> [String: String] {
        let conflicts = environment.keys.filter({ $0.hasPrefix("EHPANDA_") }).sorted()
        guard conflicts.isEmpty else {
            throw .conflictingLaunchKeys(conflicts)
        }
        guard case .capture(let coordinate) = scene.coordinate else {
            return environment
        }
        guard CaptureScreen(rawValue: coordinate.screen) != nil,
              coordinate.orientation == .portrait,
              coordinate.textSize == .large,
              Set(coordinate.custom.keys) == ["set"],
              let selection = coordinate.custom["set"],
              ["nonexplicit", "explicit"].contains(selection)
        else {
            throw .malformedConfiguration("Appshot marketing requires a supported screen, set, portrait and large")
        }
        guard Set(scene.inputs.keys) == ["fixtures"], let fixtures = scene.inputs["fixtures"] else {
            throw .missingFixtureDirectory
        }
        var prepared = environment
        do {
            prepared[CaptureScenePreparation.configurationKey] = try StrictJSON.encodeLine(JSONValue.object([
                "purpose": .string("marketingReal"),
                "scenarioID": .string(coordinate.screen),
                "fixtureID": .string(selection)
            ]))
        } catch {
            throw .malformedConfiguration("Cannot encode the appshot content request: \(error)")
        }
        prepared[CaptureScenePreparation.fixturesKey] = fixtures
        return prepared
    }
}

extension CaptureDiagnostics {
    /// The SDK owns geometry and rendering verification; the app owns readiness and content.
    var appshotState: ScreenState {
        do {
            let content = try StrictJSON.decode(JSONValue.self, from: JSONEncoder().encode(self))
            let pending = readiness == .loading ? blockers : []
            let failures = readiness == .failed
                ? blockers + unknownRequests + ["The app reported a failed capture"]
                : []
            return ScreenState(
                screen: screenID?.rawValue ?? "unknown", pending: pending, failures: failures, app: content
            )
        } catch {
            return ScreenState(screen: "unknown", failures: ["Cannot encode app diagnostics: \(error)"])
        }
    }
}
#endif
