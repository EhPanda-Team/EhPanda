import XCTest

@MainActor
extension XCUIApplication {
    func launchStubbed(
        extraEnvironment: [String: String] = [:]
    ) throws {
        try configureStubbedLaunch(extraEnvironment: extraEnvironment)
        launch()
    }

    func openWarm(_ url: URL) {
        XCUIDevice.shared.system.open(url)
    }

    /// Opens a terminated app with `XCUIApplication.open(_:)`.
    ///
    /// The Xcode 26.6 / iOS 26.5 delivery probe verified both legs: the URL
    /// opened the detail route, and the launch environment loaded the bundled
    /// fixture whose title is `EhPanda UITest Fixture`. This pins cold delivery
    /// to the closest D-05 system-open mechanism that also preserves D-06's
    /// hermetic launch environment; warm delivery uses the literal D-05 API.
    func openCold(_ url: URL) throws {
        terminate()
        try configureStubbedLaunch()
        open(url)
    }

    func requireForeground(
        timeout: TimeInterval = 15,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            wait(for: .runningForeground, timeout: timeout),
            "EhPanda did not reach the foreground.",
            file: file,
            line: line
        )
    }

    @discardableResult
    func requireElement(
        _ accessibilityIdentifier: String,
        matching elementType: XCUIElement.ElementType = .any,
        timeout: TimeInterval = 15,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let element = descendants(matching: elementType)
            .matching(identifier: accessibilityIdentifier)
            .firstMatch
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "EhPanda did not present \(accessibilityIdentifier).",
            file: file,
            line: line
        )
        return element
    }

    private func configureStubbedLaunch(
        extraEnvironment: [String: String] = [:]
    ) throws {
        let resourceURL = try XCTUnwrap(
            Bundle(for: DeepLinkLauncherBundleToken.self).resourceURL
        )
        launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        launchEnvironment[UITestConstants.stubNetworkEnvironmentKey] = "1"
        launchEnvironment[UITestConstants.fixtureDirectoryEnvironmentKey] = resourceURL.path()
        for (key, value) in extraEnvironment {
            launchEnvironment[key] = value
        }
    }
}

private final class DeepLinkLauncherBundleToken {}
