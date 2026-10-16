import CryptoKit
import XCTest

@MainActor
final class LibraryPresentationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFavoritesLayoutPersistsThroughLibrary() throws {
        XCUIDevice.shared.orientation = .portrait
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
        app.returnFromGalleryDetail()
        XCTAssertTrue(presentation.waitForExistence(timeout: 10))
        assertGrid(in: app)

        app.terminate()
        app.launch()
        XCTAssertTrue(presentation.waitForExistence(timeout: 15))
        XCTAssertTrue(gallery.waitForExistence(timeout: 15))
        assertGrid(in: app)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Library Favorites grid"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testCategoryNavigationReturnsAndSwitchesSources() throws {
        XCUIDevice.shared.orientation = .portrait
        let root = try makeDownloads()
        let app = XCUIApplication()
        defer {
            app.terminate()
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                XCTFail("Unable to remove test-owned downloads: \(error)")
            }
        }
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "library",
            "EHPANDA_UITEST_DOWNLOAD_ROOT": root.path(),
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "fixture-member",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "fixture-session"
        ])
        let favorites = app.buttons["library-favorites--1"]
        favorites.tapWhenHittable("All Favorites category")
        let picker = app.buttons["gallery-layout-favorites"]
        picker.tapWhenHittable("Favorites presentation")
        app.buttons["Grid"].tapWhenHittable("Favorites Grid")
        if !favorites.isHittable {
            app.descendants(matching: .any)["BackButton"].firstMatch.tapWhenHittable("Return to Library")
        }
        let categories = app.descendants(matching: .any)["library-categories"].firstMatch
        let downloads = app.buttons["library-downloads-Inbox"]
        for _ in 0..<5 where !downloads.isHittable {
            categories.swipeDown(velocity: .slow)
        }
        downloads.tapWhenHittable("Inbox download folder after returning")
        XCTAssertTrue(app.buttons["gallery-layout-downloads"].waitForExistence(timeout: 10))
        if !downloads.isHittable {
            app.descendants(matching: .any)["BackButton"].firstMatch.tapWhenHittable("Return to categories")
        }
        for _ in 0..<5 where !favorites.isHittable {
            categories.swipeDown(velocity: .slow)
        }
        favorites.tapWhenHittable("Favorites category after Downloads")
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        assertGrid(in: app)
    }

    func testDownloadManagementInBothLayouts() throws {
        XCUIDevice.shared.orientation = .portrait
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
        app.descendants(matching: .any)["Close"].firstMatch.tapWhenHittable("Close inspector")

        picker.tapWhenHittable("Downloads presentation")
        app.buttons["Grid"].tapWhenHittable("Downloads Grid")
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["download-actions-9101"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["gallery-grid-rating-9101"].firstMatch.exists)
        let content = app.descendants(matching: .any)["downloads-gallery-list"].firstMatch
        reveal(first, in: content, app: app)
        let gridScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        gridScreenshot.name = "Library Downloads grid"
        gridScreenshot.lifetime = .keepAlways
        add(gridScreenshot)
        reveal(first, in: content, app: app)
        first.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Pages"].waitForExistence(timeout: 5))
        let menuScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        menuScreenshot.name = "Library Downloads grid context menu"
        menuScreenshot.lifetime = .keepAlways
        add(menuScreenshot)
        app.buttons["Move to Folder"].tapWhenHittable("Move downloaded gallery")
        // The sidebar also contains Reading; target the menu action, not query ordering.
        app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier == %@", "Reading", ""
        )).firstMatch
            .tapWhenHittable("Move to Reading folder")
        let movedManifest = root.appending(path: "Reading/[9101_library] Library Download 1/manifest.json")
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: movedManifest.path(percentEncoded: false))
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed)
        reveal(first, in: content, app: app)
        first.press(forDuration: 1)
        app.buttons["Pages"].tapWhenHittable("Inspect downloaded pages from grid")
        XCTAssertTrue(app.navigationBars["Download Status"].waitForExistence(timeout: 10))
        app.descendants(matching: .any)["Close"].firstMatch.tapWhenHittable("Close inspector")
        let readTitle = app.staticTexts["Library Download 1"].firstMatch
        reveal(readTitle, in: content, app: app)
        readTitle.doubleTap()
        let reader = app.descendants(matching: .any)["reading_view"].firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 10))
        ReaderPageProbe(app: app).showPanel()
        reader.buttons["Close"].firstMatch.tapWhenHittable("Close local reader")
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        reveal(first, in: content, app: app)
        first.press(forDuration: 1)
        app.buttons["Delete"].tapWhenHittable("Request delete")
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tapWhenHittable("Cancel gallery deletion")
        } else {
            picker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(first.exists, "Cancel must keep the downloaded gallery.")
        reveal(first, in: content, app: app)
        first.press(forDuration: 1)
        app.buttons["Delete"].tapWhenHittable("Request deletion again")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Library Downloads anchored confirmation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Delete"].tapWhenHittable("Confirm gallery deletion")
        XCTAssertTrue(first.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["download-gallery-9102"].exists, "Deleting one card must preserve its neighbor.")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["download-gallery-9102"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["download-gallery-9101"].firstMatch.exists)
    }

    func testFavoritesSingleTapDetailsAndDoubleTapReads() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "favorites",
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "fixture-member",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "fixture-session"
        ])
        defer { app.terminate() }
        try assertLibraryTapActions(in: app, source: "favorites", item: "gallery-list-item-1001")
    }

    func testDownloadsSingleTapDetailsAndDoubleTapReads() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let root = try makeDownloads()
        let app = XCUIApplication()
        defer {
            app.terminate()
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
        try assertLibraryTapActions(in: app, source: "downloads", item: "download-gallery-9101")
    }

    private func assertLibraryTapActions(in app: XCUIApplication, source: String, item: String) throws {
        let picker = app.buttons["gallery-layout-\(source)"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        for layout in ["Row", "Grid"] {
            picker.tapWhenHittable("Choose Library layout")
            app.buttons[layout].tapWhenHittable("Library \(layout)")
            let gallery = app.buttons[item].firstMatch
            XCTAssertTrue(gallery.waitForExistence(timeout: 15))
            gallery.tapWhenHittable("Single tap opens Detail")
            let detail = app.descendants(matching: .any)["detail_view"].firstMatch
            XCTAssertTrue(detail.waitForExistence(timeout: 15))
            XCTAssertFalse(app.descendants(matching: .any)["reading_view"].firstMatch.exists)
            app.returnFromGalleryDetail()
            XCTAssertTrue(gallery.waitForExistence(timeout: 10))
            gallery.doubleTap()
            let reader = app.descendants(matching: .any)["reading_view"].firstMatch
            XCTAssertTrue(reader.waitForExistence(timeout: 15), "Double tap must open reading directly.")
            ReaderPageProbe(app: app).showPanel()
            reader.buttons["Close"].firstMatch.tapWhenHittable("Return from direct reading")
            XCTAssertTrue(reader.waitForNonExistence(timeout: 10))
            XCTAssertTrue(picker.waitForExistence(timeout: 10))
            XCTAssertFalse(detail.exists, "Double tap must not leave Detail beneath the reader.")
            gallery.press(forDuration: 1)
            app.buttons["Read"].tapWhenHittable("Read remains available without a double-tap gesture")
            XCTAssertTrue(reader.waitForExistence(timeout: 15))
            ReaderPageProbe(app: app).showPanel()
            reader.buttons["Close"].firstMatch.tapWhenHittable("Close menu-initiated reading")
            XCTAssertTrue(reader.waitForNonExistence(timeout: 10))
        }
    }

    /// XCTest can report clipped cards as hittable. Use the measured visible content between native bars.
    private func reveal(_ element: XCUIElement, in content: XCUIElement, app: XCUIApplication) {
        let frame = content.frame.intersection(app.windows.firstMatch.frame)
        let navigation = app.navigationBars["Downloads"].frame
        let tabBar = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame : .zero
        let top = navigation.width > navigation.height ? max(frame.minY, navigation.maxY) : frame.minY
        let bottom = tabBar.width > tabBar.height && tabBar.minY > frame.midY
            ? min(frame.maxY, tabBar.minY) : frame.maxY
        let viewport = CGRect(x: frame.minX, y: top, width: frame.width, height: bottom - top).insetBy(dx: 8, dy: 8)
        XCTAssertGreaterThan(viewport.height, 0)
        for _ in 0..<24 {
            let target = element.frame
            if viewport.contains(CGPoint(x: target.midX, y: target.midY)), element.isHittable { return }
            let direction: CGFloat = target.midY < viewport.midY ? 1 : -1
            let start = CGPoint(x: viewport.midX, y: viewport.midY - direction * viewport.height * 0.15)
            let end = CGPoint(x: viewport.midX, y: viewport.midY + direction * viewport.height * 0.15)
            let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: start.x, dy: start.y)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)),
                withVelocity: .slow, thenHoldForDuration: 0.15
            )
        }
        XCTFail("Could not reveal \(element.identifier) within the actual content viewport.")
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
        if second.frame.minX > first.frame.maxX {
            XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1, file: file, line: line)
        } else {
            XCTAssertEqual(first.frame.minX, second.frame.minX, accuracy: 1, file: file, line: line)
            let card = app.buttons["gallery-list-item-1001"]
            XCTAssertGreaterThan(card.frame.height, card.frame.width, file: file, line: line)
        }
    }

}
