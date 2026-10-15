import CryptoKit
import XCTest

@MainActor
final class LibraryPresentationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFavoritesLayoutPersistsThroughLibrary() throws {
        let app = XCUIApplication()
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "favorites",
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "fixture-member",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "fixture-session"
        ])
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Favorites"].waitForExistence(timeout: 15))
        let gallery = app.staticTexts["Library Study 01"].firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 15), "Favorites must load the real parsed fixture list.")
        let presentation = app.buttons["gallery-layout-favorites"]
        presentation.tapWhenHittable("Favorites presentation")
        app.buttons["Grid"].tapWhenHittable("Favorites Grid")
        assertGrid(in: app)
        XCTAssertTrue(gallery.isHittable)
        gallery.tapWhenHittable("Open a Favorites gallery")
        XCTAssertTrue(app.descendants(matching: .any)["detail_view"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons[UITestConstants.primaryMarkerTitle].waitForExistence(timeout: 5))
        let close = app.buttons["Close"].firstMatch
        if close.exists {
            close.tapWhenHittable("Dismiss gallery detail")
        } else {
            app.navigationBars.buttons.element(boundBy: 0).tapWhenHittable("Return to Favorites")
        }
        XCTAssertTrue(presentation.waitForExistence(timeout: 10))
        assertGrid(in: app)

        app.terminate()
        app.launch()
        XCTAssertTrue(presentation.waitForExistence(timeout: 15))
        XCTAssertTrue(gallery.waitForExistence(timeout: 15))
        assertGrid(in: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Library Favorites grid"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testDownloadManagementInBothLayouts() throws {
        let originalOrientation = XCUIDevice.shared.orientation
        XCUIDevice.shared.orientation = .landscapeLeft
        let root = try makeDownloads()
        let app = XCUIApplication()
        defer {
            app.terminate()
            XCUIDevice.shared.orientation = originalOrientation
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                XCTFail("Unable to remove test-owned downloads: \(error)")
            }
        }
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "downloads",
            "EHPANDA_UITEST_DOWNLOAD_ROOT": root.path()
        ])
        let picker = app.buttons["gallery-layout-downloads"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        picker.tapWhenHittable("Downloads presentation")
        app.buttons["Row"].tapWhenHittable("Downloads Row")
        let first = app.descendants(matching: .any)["download-gallery-9101"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        first.press(forDuration: 1)
        app.buttons["Pages"].tapWhenHittable("Inspect downloaded pages from row")
        XCTAssertTrue(app.navigationBars["Download Status"].waitForExistence(timeout: 10))
        app.navigationBars["Download Status"].buttons["Close"].tapWhenHittable("Close inspector")

        picker.tapWhenHittable("Downloads presentation")
        app.buttons["Grid"].tapWhenHittable("Downloads Grid")
        let actions = app.buttons["download-actions-9101"]
        XCTAssertTrue(actions.waitForExistence(timeout: 10))
        let gridScreenshot = XCTAttachment(screenshot: app.screenshot())
        gridScreenshot.name = "Library Downloads grid"
        gridScreenshot.lifetime = .keepAlways
        add(gridScreenshot)
        actions.tapWhenHittable("Manage downloaded gallery")
        app.buttons["Move"].tapWhenHittable("Move downloaded gallery")
        try XCTUnwrap(app.buttons.matching(identifier: "Reading").allElementsBoundByIndex.last)
            .tapWhenHittable("Move to Reading folder")
        actions.tapWhenHittable("Manage moved gallery")
        app.buttons["Pages"].tapWhenHittable("Inspect downloaded pages from grid")
        XCTAssertTrue(app.navigationBars["Download Status"].waitForExistence(timeout: 10))
        app.navigationBars["Download Status"].buttons["Close"].tapWhenHittable("Close inspector")
        first.tapWhenHittable("Read a local downloaded gallery")
        let reader = app.descendants(matching: .any)["reading_view"].firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 10))
        ReaderPageProbe(app: app).showPanel()
        reader.buttons["Close"].firstMatch.tapWhenHittable("Close local reader")
        XCTAssertTrue(actions.waitForExistence(timeout: 10))
        actions.tapWhenHittable("Manage downloaded gallery")
        app.buttons["Delete"].tapWhenHittable("Request delete")
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Library Downloads anchored confirmation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Delete"].tapWhenHittable("Confirm gallery deletion")
        XCTAssertTrue(first.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["download-actions-9102"].exists, "Deleting one card must preserve its neighbor.")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["download-actions-9102"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["download-gallery-9101"].firstMatch.exists)
    }

    private func makeDownloads() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "LibraryUITest-\(UUID())")
        try FileManager.default.createDirectory(at: root.appending(path: "Reading"), withIntermediateDirectories: true)
        let coverURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LibraryCover", withExtension: "png"))
        let cover = try Data(contentsOf: coverURL)
        let hash = SHA256.hash(data: cover).map { String(format: "%02x", $0) }.joined()
        for index in 1...6 {
            let gid = String(9100 + index)
            let folder = root.appending(path: "Inbox/[\(gid)_library] Library Download \(index)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let manifest: [String: Any] = [
                "gid": gid, "host": "E-Hentai", "token": "library",
                "title": "Library Download \(index)", "category": "Image Set", "language": "English",
                "uploader": "Fixture Studio", "tags": [], "postedDate": 0, "rating": 4.5,
                "pages": ["1": hash, "2": hash]
            ]
            try JSONSerialization.data(withJSONObject: manifest).write(to: folder.appending(path: "manifest.json"))
            try cover.write(to: folder.appending(path: "\(gid)_library_cover.png"))
            for page in 1...2 {
                try cover.write(to: folder.appending(path: "\(gid)_library_\(page).png"))
            }
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: 1_000 - Double(index))],
                ofItemAtPath: folder.path(percentEncoded: false)
            )
        }
        return root
    }

    private func assertGrid(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let first = app.staticTexts["Library Study 01"].firstMatch
        let second = app.staticTexts["Library Study 02"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(second.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1, file: file, line: line)
        XCTAssertGreaterThan(second.frame.minX, first.frame.maxX, file: file, line: line)
    }

}
