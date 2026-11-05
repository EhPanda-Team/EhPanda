import XCTest

/// Launches the stubbed app in one of the six app languages, at the default text size or the largest accessibility
/// size, and keeps a screenshot of a screen under `<screen>-<locale>-<size>`, such as `age-wall-zh-Hans-AX5`.
///
/// It serves the UI-SPEC C-3 title line-break check (18-09, 18-10): a screen's long titles are read in every
/// language at both sizes from the kept screenshots. The language, region and text size are launch arguments, so the
/// simulator's own settings are never changed and nothing needs restoring. Like `launchStubbed`, the launch answers
/// every request from the bundled fixtures.
@MainActor
struct LocalizedLaunch {
    /// The app's six languages, named as their screenshots are.
    enum Language: String, CaseIterable {
        case english = "en"
        case german = "de"
        case korean = "ko"
        case japanese = "ja"
        case simplifiedChinese = "zh-Hans"
        case traditionalChinese = "zh-Hant"

        /// The region launched with the language, so dates and numbers read as they do there.
        var appleLocale: String {
            switch self {
            case .english: "en_US"
            case .german: "de_DE"
            case .korean: "ko_KR"
            case .japanese: "ja_JP"
            case .simplifiedChinese: "zh_CN"
            case .traditionalChinese: "zh_TW"
            }
        }
    }

    /// The text sizes a screen is checked at, named as their screenshots are.
    enum TextSize: String, CaseIterable {
        /// The system's default size, Large.
        case standard = "default"
        /// The largest accessibility size, AX5.
        case accessibility5 = "AX5"

        /// The content size category the launch asks for; `nil` keeps the default.
        var contentSizeCategory: String? {
            switch self {
            case .standard: nil
            case .accessibility5: "UICTContentSizeCategoryAccessibilityXXXL"
            }
        }
    }

    let language: Language
    let textSize: TextSize

    /// Every language at every size, in the order the screenshots are listed.
    static var all: [LocalizedLaunch] {
        Language.allCases.flatMap { language in
            TextSize.allCases.map({ LocalizedLaunch(language: language, textSize: $0) })
        }
    }

    /// The launch arguments of this language, region and text size.
    var launchArguments: [String] {
        var arguments = ["-AppleLanguages", "(\(language.rawValue))", "-AppleLocale", language.appleLocale]
        if let category = textSize.contentSizeCategory {
            arguments += ["-UIPreferredContentSizeCategoryName", category]
        }
        return arguments
    }

    /// Terminates `app` and launches it stubbed in this language at this size, with `extraEnvironment` added (the
    /// phase's launch keys, such as `UITestConstants.firstLaunchEnvironmentKey`). The arguments replace any an
    /// earlier launch of the same `app` set, so a run across every language never stacks them.
    func launch(_ app: XCUIApplication, extraEnvironment: [String: String] = [:]) throws {
        let resourceURL = try XCTUnwrap(Bundle(for: LocalizedLaunchBundleToken.self).resourceURL)
        app.terminate()
        app.launchArguments = launchArguments
        app.launchEnvironment = [
            UITestConstants.stubNetworkEnvironmentKey: "1",
            UITestConstants.fixtureDirectoryEnvironmentKey: resourceURL.path()
        ].merging(extraEnvironment, uniquingKeysWith: { $1 })
        app.launch()
    }

    /// The name of `screen`'s screenshot in this language at this size.
    func screenshotName(of screen: String) -> String {
        "\(screen)-\(language.rawValue)-\(textSize.rawValue)"
    }

    /// Attaches a screenshot of `app` as it stands, named for `screen`, to `testCase`, and keeps it whether or not
    /// the test passes.
    func keepScreenshot(of screen: String, app: XCUIApplication, in testCase: XCTestCase) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = screenshotName(of: screen)
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }
}

private final class LocalizedLaunchBundleToken {}
