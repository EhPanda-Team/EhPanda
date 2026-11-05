import XCTest

/// Keeps a screenshot of the Blocked Users empty state in each of the six app languages, at the default text size and
/// at AX5, for the UI-SPEC C-3 line-break check (owner msg 1822) on its title (C-12): it may not end on a single word,
/// or on fewer than two characters in Chinese, Japanese and Korean.
///
/// The line check is visual, read from the kept screenshots (`blocked-users-empty-<locale>-<size>`); the test asserts
/// only that the screen is the empty list with its title in the launch language. Every launch presets an empty block
/// list, so no case depends on another's storage, and each language is its own case, so a slow launch never runs one
/// case past its time allowance.
@MainActor
final class BlockedUsersTitleLayoutUITests: XCTestCase {
    private enum Identifier {
        static let blockedUsersRow = "setting_blocked_users"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEnglishTitle() throws {
        try captureEmptyState(in: .english)
    }

    func testGermanTitle() throws {
        try captureEmptyState(in: .german)
    }

    func testKoreanTitle() throws {
        try captureEmptyState(in: .korean)
    }

    func testJapaneseTitle() throws {
        try captureEmptyState(in: .japanese)
    }

    func testSimplifiedChineseTitle() throws {
        try captureEmptyState(in: .simplifiedChinese)
    }

    func testTraditionalChineseTitle() throws {
        try captureEmptyState(in: .traditionalChinese)
    }
}

// MARK: Helpers

private extension BlockedUsersTitleLayoutUITests {
    /// How many swipes may bring a row at the end of an AX5 screen into reach.
    static let maximumSwipes = 8

    /// Opens Settings → Account → Blocked Users in `language` at both text sizes, with nobody blocked, and keeps the
    /// empty state as it first appears.
    func captureEmptyState(in language: LocalizedLaunch.Language) throws {
        let app = XCUIApplication()
        for textSize in LocalizedLaunch.TextSize.allCases {
            let localized = LocalizedLaunch(language: language, textSize: textSize)
            try localized.launch(app, extraEnvironment: [
                "EHPANDA_AUTOMATION_TAB": "setting",
                UITestConstants.blockedAuthorsEnvironmentKey: "[]"
            ])
            app.requireForeground()

            // Account is the first root row in every language; its title is localized, so the row is found by place.
            let root = app.scrollViews.firstMatch
            XCTAssertTrue(root.waitForExistence(timeout: 15), "The Settings root is missing.")
            root.buttons.firstMatch.tapWhenHittable("The Account row")

            let row = app.buttons[Identifier.blockedUsersRow]
            XCTAssertTrue(row.waitForExistence(timeout: 15), "Account has no Blocked Users row.")
            var swipes = 0
            while !row.isHittable, swipes < Self.maximumSwipes {
                app.collectionViews.firstMatch.swipeUp()
                swipes += 1
            }
            row.tapWhenHittable("The Blocked Users row")

            let title = app.staticTexts[language.emptyTitle]
            XCTAssertTrue(
                title.waitForExistence(timeout: 15),
                "The empty state is missing in \(localized.screenshotName(of: "blocked-users-empty"))."
            )
            // The push slides; the screenshot waits for it to settle.
            XCTAssertTrue(
                title.waitUntilHittable(timeout: XCUIElement.hittableTimeout),
                "The empty state never settled."
            )
            localized.keepScreenshot(of: "blocked-users-empty", app: app, in: self)
        }
        app.terminate()
    }
}

private extension LocalizedLaunch.Language {
    /// `blocked_users.empty` as each language's catalog has it, so a launch that fell back to another language fails.
    var emptyTitle: String {
        switch self {
        case .english: "You haven't blocked anyone."
        case .german: "Du hast niemanden blockiert."
        case .korean: "차단한 사용자가 없습니다."
        case .japanese: "ブロックしたユーザーはいません。"
        case .simplifiedChinese: "你还没有屏蔽任何人。"
        case .traditionalChinese: "你還沒有封鎖任何人。"
        }
    }
}
