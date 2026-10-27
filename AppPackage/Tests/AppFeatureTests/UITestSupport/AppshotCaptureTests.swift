#if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
@testable import AppFeature
import AppshotProtocol
import Foundation
import Testing

struct AppshotCaptureTests {
    private func scene(
        screen: String = "home",
        set: String = "nonexplicit",
        textSize: TextSize = .large,
        orientation: Orientation = .portrait
    ) -> AppshotProtocol.CaptureScene {
        .init(
            coordinate: .capture(.init(
                screen: screen, device: "iphone", locale: "en", appearance: .light,
                textSize: textSize, orientation: orientation, custom: ["set": set]
            )),
            inputs: ["fixtures": "/tmp/appshot-test-fixtures"]
        )
    }

    @Test func noSceneLeavesNormalLaunchAlone() throws {
        #expect(try AppshotCapture.decode(environment: [:]) == nil)
        #expect(try UITestAutomation.resolve(environment: [:], now: .distantPast, isTesting: false) == nil)
    }

    @Test(arguments: CaptureScreen.allCases)
    func marketingScreenUsesExistingContentContract(_ screen: CaptureScreen) throws {
        let request = scene(screen: screen.rawValue)
        let environment = try AppshotCapture.captureEnvironment(request, environment: ["TZ": "UTC"])
        let json = try #require(environment[CaptureScenePreparation.configurationKey])
        let configuration = try CaptureSceneConfiguration(json: Data(json.utf8))
        #expect(configuration.purpose == .marketingReal)
        #expect(configuration.scenarioID == screen.rawValue)
        #expect(configuration.fixtureID == "nonexplicit")
        #expect(environment[CaptureScenePreparation.fixturesKey] == "/tmp/appshot-test-fixtures")
        #expect(environment["TZ"] == "UTC")
    }

    @Test(arguments: ["EHPANDA_CAPTURE_CONFIGURATION", "EHPANDA_UITEST_STUB_NETWORK", "EHPANDA_VISUAL_TEST_HOST"])
    func competingAutomationIsRefused(_ key: String) {
        #expect(throws: AppFeature.CaptureFailure.conflictingLaunchKeys([key])) {
            try AppshotCapture.captureEnvironment(scene(), environment: [key: "1"])
        }
    }

    @Test func invalidMarketingAxesAreRefused() {
        for request in [scene(screen: "missing"), scene(set: "missing"), scene(textSize: .accessibilityLarge)] {
            let failure = #expect(throws: AppFeature.CaptureFailure.self) {
                try AppshotCapture.captureEnvironment(request, environment: [:])
            }
            guard case .malformedConfiguration = failure else {
                Issue.record("Expected an invalid marketing coordinate")
                continue
            }
        }
    }

    @Test func missingInputCannotFallBackToLiveData() {
        var request = scene()
        request.inputs = [:]
        #expect(throws: AppFeature.CaptureFailure.missingFixtureDirectory) {
            try AppshotCapture.captureEnvironment(request, environment: [:])
        }
    }

    @Test func probeIsIsolatedWithoutFixtures() throws {
        let request = AppshotProtocol.CaptureScene(
            coordinate: .probe(.init(device: "iphone", locale: "en", textSize: .large, orientation: .portrait)),
            inputs: [:]
        )
        let json = try StrictJSON.encodeLine(request)
        let configuration = try #require(try UITestAutomation.resolve(
            environment: [EnvironmentName.scene: json], now: .distantPast, isTesting: false
        ))
        #expect(configuration.shouldStubNetwork)
        #expect(configuration.shouldUseVisualTestHost)
        #expect(configuration.captureScene == nil)
        #expect(configuration.appshotScene == request)
        #expect(configuration.fixtureDirectory == nil)
    }

    @Test(arguments: ["not JSON", "{}", #"{"protocol":999,"coordinate":{},"inputs":{}}"#])
    func malformedProtocolIsRejected(_ json: String) {
        let failure = #expect(throws: AppFeature.CaptureFailure.self) {
            try AppshotCapture.decode(environment: [EnvironmentName.scene: json])
        }
        guard case .malformedConfiguration = failure else {
            Issue.record("Expected an invalid appshot protocol")
            return
        }
    }
}
#endif
