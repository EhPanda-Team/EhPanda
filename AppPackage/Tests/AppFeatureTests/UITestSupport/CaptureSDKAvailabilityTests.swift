#if DEBUG && !(canImport(Appshot) && canImport(AppshotProtocol))
@testable import AppFeature
import Foundation
import Testing

struct CaptureSDKAvailabilityTests {
    @Test(arguments: [false, true])
    func absentSceneKeepsOrdinaryLaunch(_ isTesting: Bool) throws {
        #expect(try UITestAutomation.resolve(environment: [:], now: .distantPast, isTesting: isTesting) == nil)
    }

    @Test(arguments: ["", "not JSON", #"{"protocol":1,"coordinate":{},"inputs":{}}"#])
    func unavailableSDKSceneIsRefused(_ scene: String) {
        assertUnavailableSceneIsRefused(["APPSHOT_SCENE": scene], isTesting: false)
        assertUnavailableSceneIsRefused(["APPSHOT_SCENE": scene], isTesting: true)
    }

    @Test(arguments: [
        "EHPANDA_CAPTURE_CONFIGURATION",
        "EHPANDA_CAPTURE_FIXTURES",
        "EHPANDA_UITEST_STUB_NETWORK",
        "EHPANDA_UITEST_FIXTURE_DIR"
    ])
    func unavailableSDKSceneFailsBeforeAppOwnedKeys(_ key: String) {
        let validConfiguration = #"{"purpose":"marketingReal","scenarioID":"home","fixtureID":"nonexplicit"}"#
        var environment = [
            "APPSHOT_SCENE": #"{"protocol":1,"coordinate":{},"inputs":{}}"#,
            "EHPANDA_CAPTURE_CONFIGURATION": validConfiguration,
            "EHPANDA_CAPTURE_FIXTURES": "/tmp/fixtures"
        ]
        environment[key] = "1"
        assertUnavailableSceneIsRefused(environment, isTesting: false)
        assertUnavailableSceneIsRefused(environment, isTesting: true)
    }

    private func assertUnavailableSceneIsRefused(
        _ environment: [String: String],
        isTesting: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let failure = #expect(throws: CaptureFailure.self, sourceLocation: sourceLocation) {
            try UITestAutomation.resolve(environment: environment, now: .distantPast, isTesting: isTesting)
        }
        guard case .malformedConfiguration(let message) = failure else {
            Issue.record("Expected APPSHOT_SCENE to be rejected before fallback", sourceLocation: sourceLocation)
            return
        }
        #expect(message.contains("explicit local capture composition"), sourceLocation: sourceLocation)
    }
}
#endif
