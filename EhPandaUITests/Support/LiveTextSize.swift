import UIKit
import XCTest

/// Changes the simulator's text size while the app runs, through the Settings app's Larger Text control, the way a
/// person does: Accessibility → Display & Text Size → Larger Text, the Larger Accessibility Sizes switch for the
/// accessibility sizes, then the slider. Only public means are used (D-27): no app code and no launch key.
///
/// The size is simulator-wide, so a test that sets it calls `reset()` in a teardown block. An app launched with
/// `-UIPreferredContentSizeCategoryName` ignores the system size, so a live change needs a launch without it.
@MainActor
enum LiveTextSize {
    /// The sizes the native policy checks (AGENTS.md: standard, AX1, AX3 and AX5).
    enum Size: CaseIterable {
        case large
        case accessibility1
        case accessibility3
        case accessibility5

        /// The content size category a cold launch asks for.
        var category: UIContentSizeCategory {
            switch self {
            case .large: .large
            case .accessibility1: .accessibilityMedium
            case .accessibility3: .accessibilityExtraLarge
            case .accessibility5: .accessibilityExtraExtraExtraLarge
            }
        }

        var name: String {
            switch self {
            case .large: "Large"
            case .accessibility1: "AX1"
            case .accessibility3: "AX3"
            case .accessibility5: "AX5"
            }
        }

        /// Whether the size needs Larger Accessibility Sizes on.
        var isAccessibilitySize: Bool { self != .large }

        /// The slider's step: seven steps (xS to xxxL) without the accessibility sizes, twelve (up to AX5) with them.
        var step: SliderStep {
            switch self {
            case .large: SliderStep(index: 3, count: 7)
            case .accessibility1: SliderStep(index: 7, count: 12)
            case .accessibility3: SliderStep(index: 9, count: 12)
            case .accessibility5: SliderStep(index: 11, count: 12)
            }
        }
    }

    /// One step of the Larger Text slider, out of the slider's `count` steps.
    struct SliderStep {
        let index: Int
        let count: Int
    }

    static let settingsBundleIdentifier = "com.apple.Preferences"

    private enum Identifier {
        static let accessibility = "com.apple.settings.accessibility"
        static let displayAndText = "DISPLAY_AND_TEXT"
        static let largerText = "LARGER_TEXT"
        static let largerSizesSwitch = "LARGER_DYNAMIC_TYPE_SWITCH"
        static let slider = "DYNAMIC_TYPE_SLIDER"
    }

    /// Sets the system text size to `size` in the Settings app, checks the slider reads it, and brings `app` back to
    /// the foreground.
    static func set(
        _ size: Size, returningTo app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        // On iPhone, Settings runs in portrait only. Left turned, the device would map XCUITest's taps for a landscape
        // screen onto Settings' portrait one, so the device is upright while in Settings and turned back after.
        let reported = XCUIDevice.shared.orientation
        // Before any turn the device reports no orientation; it is upright then.
        let orientation = reported.isPortrait || reported.isLandscape ? reported : .portrait
        if UIDevice.current.userInterfaceIdiom == .phone, orientation != .portrait {
            XCUIDevice.shared.orientation = .portrait
        }
        defer {
            if XCUIDevice.shared.orientation != orientation {
                XCUIDevice.shared.orientation = orientation
            }
        }
        let settings = openLargerText(file: file, line: line)
        let largerSizes = reveal(
            NSPredicate(format: "identifier == %@ AND elementType == %d", Identifier.largerSizesSwitch,
                        XCUIElement.ElementType.switch.rawValue),
            in: settings, named: "Larger Accessibility Sizes", file: file, line: line
        )
        let rangeChanged = size.isAccessibilitySize != isOn(largerSizes)
        if rangeChanged {
            // The row's own switch, not its label.
            let control = largerSizes.switches.firstMatch
            (control.exists ? control : largerSizes)
                .tapWhenHittable("Larger Accessibility Sizes", file: file, line: line)
            let flipped = NSPredicate { _, _ in isOn(largerSizes) == size.isAccessibilitySize }
            let wait = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: flipped, object: nil)], timeout: 5)
            XCTAssertEqual(wait, .completed, "Larger Accessibility Sizes did not change.", file: file, line: line)
        }
        adjustSlider(in: settings, to: size.step, requiringWrite: rangeChanged && !size.isAccessibilitySize,
                     file: file, line: line)
        if XCUIDevice.shared.orientation != orientation {
            XCUIDevice.shared.orientation = orientation
        }
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "EhPanda did not come back.",
                      file: file, line: line)
    }

    /// Returns the system text size to Large, the simulator's default, and terminates the Settings app.
    static func reset(returningTo app: XCUIApplication? = nil) {
        let settings = XCUIApplication(bundleIdentifier: settingsBundleIdentifier)
        set(.large, returningTo: app ?? settings)
        settings.terminate()
    }

    private static func openLargerText(file: StaticString, line: UInt) -> XCUIApplication {
        let settings = XCUIApplication(bundleIdentifier: settingsBundleIdentifier)
        // Settings left on Larger Text by an earlier change is used where it stands, but only in the foreground.
        let state = settings.state
        if state == .runningBackground || state == .runningBackgroundSuspended || state == .runningForeground {
            settings.activate()
            XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 15), "Settings did not open.",
                          file: file, line: line)
        }
        let largerText = settings.navigationBars["Larger Text"]
        if settings.state != .runningForeground || !largerText.waitForExistence(timeout: 2) {
            // Settings launches laid out at Large, whatever the system size. At AX5 its rows outgrow an iPhone's
            // screen, and after the swipes that bring Display & Text Size up, the row took no tap at all, on the
            // hosted iPhone (run 3) and locally alike, though it stood whole in the window. The override sets only
            // Settings' own layout; the slider still writes the system size.
            settings.launchArguments = ["-UIPreferredContentSizeCategoryName", UIContentSizeCategory.large.rawValue]
            for _ in 0..<maximumLaunches {
                // A fresh launch starts at the root, wherever an earlier run left the app.
                settings.launch()
                XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 15), "Settings did not open.",
                              file: file, line: line)
                if openRows(in: settings, file: file, line: line) { break }
            }
        }
        XCTAssertTrue(largerText.exists, "Settings never opened Larger Text.", file: file, line: line)
        reveal(NSPredicate(format: "identifier == %@", Identifier.slider), in: settings, named: "The slider",
               file: file, line: line)
        return settings
    }

    /// Goes from Settings' root to Larger Text, and tells whether every row opened its page.
    private static func openRows(in settings: XCUIApplication, file: StaticString, line: UInt) -> Bool {
        let rows = [
            // The root's rows are buttons in unnamed cells; the pages below name their cells.
            SettingsRow(name: "Accessibility", predicate: NSPredicate(format: "identifier == %@",
                                                                      Identifier.accessibility)),
            SettingsRow(name: "Display & Text Size", predicate: rowPredicate(Identifier.displayAndText)),
            SettingsRow(name: "Larger Text", predicate: rowPredicate(Identifier.largerText))
        ]
        for row in rows {
            // Each row opens a page titled with its name. A tap while the list still glides after a swipe can
            // land without opening it, so the row is tapped again until its page is up.
            let page = settings.navigationBars[row.name]
            var taps = 0
            while !page.exists, taps < maximumTaps {
                let button = reveal(row.predicate, in: settings, named: row.name, file: file, line: line)
                button.tapWhenHittable(row.name, file: file, line: line)
                _ = page.waitForExistence(timeout: 5)
                taps += 1
            }
            if !page.exists {
                attachMissedTap(on: settings.descendants(matching: .any).matching(row.predicate).firstMatch,
                                named: row.name, in: settings)
                return false
            }
        }
        return true
    }

    /// Keeps what a row that opened nothing left behind: the screen, the row's frame beside the window's, and
    /// Settings' hierarchy, so a failure shows where the taps landed.
    private static func attachMissedTap(on row: XCUIElement, named name: String, in settings: XCUIApplication) {
        let window = settings.windows.firstMatch.frame
        let frame = row.exists ? row.frame : .null
        let summary = "\(name) opened nothing: row \(frame), window \(window), visible \(frame.intersection(window))"
        XCTContext.runActivity(named: summary) { activity in
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "\(name) missed"
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)
            let hierarchy = XCTAttachment(string: summary + "\n" + settings.debugDescription)
            hierarchy.name = "\(name) missed hierarchy"
            hierarchy.lifetime = .keepAlways
            activity.add(hierarchy)
        }
    }

    /// A Settings row, by the title of the page it opens and the predicate that finds it.
    private struct SettingsRow {
        let name: String
        let predicate: NSPredicate
    }

    private static let maximumLaunches = 2

    /// Scrolls the list holding the row `predicate` matches until the row can be tapped. At accessibility sizes
    /// Settings' own rows grow, and in landscape they start below the fold; a row far below is not in the
    /// hierarchy at all until the list reaches it.
    @discardableResult
    private static func reveal(
        _ predicate: NSPredicate, in settings: XCUIApplication, named name: String, file: StaticString, line: UInt
    ) -> XCUIElement {
        let element = settings.descendants(matching: .any).matching(predicate).firstMatch
        _ = element.waitForExistence(timeout: 5)
        var swipes = 0
        while !(element.exists && element.isHittable), swipes < maximumSwipes {
            let lists = settings.descendants(matching: .any).matching(Self.listPredicate)
            let holder = lists.containing(predicate).firstMatch
            let list = holder.exists ? holder : lists.firstMatch
            // A row above the visible part is brought down; one below, or not built yet, is brought up.
            if element.exists, element.frame.midY < list.frame.midY {
                list.swipeDown(velocity: .slow)
            } else {
                list.swipeUp(velocity: .slow)
            }
            swipes += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "Settings never showed \(name).", file: file, line: line)
        waitUntilStill(element)
        return element
    }

    private static let maximumSwipes = 12

    /// Waits until `element` stops moving: a list still gliding after a swipe takes the next tap as a stop, not
    /// as a tap on the row.
    private static func waitUntilStill(_ element: XCUIElement) {
        var previous = element.frame
        for _ in 0..<maximumStillChecks {
            Thread.sleep(forTimeInterval: 0.3)
            let current = element.frame
            if current == previous { return }
            previous = current
        }
    }

    private static let maximumStillChecks = 10
    private static let maximumTaps = 3

    /// A Settings row: its cell, which takes a tap anywhere on the row at every text size.
    private static func rowPredicate(_ identifier: String) -> NSPredicate {
        NSPredicate(format: "elementType == %d AND identifier == %@", XCUIElement.ElementType.cell.rawValue, identifier)
    }

    /// Settings lays its pages out as collection views and tables.
    private static let listPredicate = NSPredicate(
        format: "elementType IN %@",
        [XCUIElement.ElementType.collectionView, .table, .scrollView].map(\.rawValue)
    )

    private static func adjustSlider(
        in settings: XCUIApplication, to step: SliderStep, requiringWrite: Bool, file: StaticString, line: UInt
    ) {
        let slider = settings.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 10), "Larger Text has no slider.", file: file, line: line)
        reveal(NSPredicate(format: "elementType == %d", XCUIElement.ElementType.slider.rawValue), in: settings,
               named: "The slider", file: file, line: line)
        let expected = "\(Int((CGFloat(step.index) / CGFloat(step.count - 1) * 100).rounded()))%"
        // The slider moves only when a drag starts on its thumb, and snaps to the nearest step when the finger
        // lifts; a tap on a step does not move it. `adjust(toNormalizedSliderPosition:)` presses where the thumb
        // would be if the track spanned the whole element, but the small and large glyphs at the ends shorten it,
        // so from some values that press lands on the thumb's edge and the drag misses or overshoots. Each attempt
        // therefore presses the thumb's middle, from the step the slider reads, and drags it to the target step.
        let track = slider.frame.width - sliderLeadingInset - sliderTrailingInset
        let position = { (index: Int) in sliderLeadingInset + CGFloat(index) / CGFloat(step.count - 1) * track }
        var needsWrite = requiringWrite
        for _ in 0..<maximumSliderAttempts {
            guard let reached = readStep(of: slider, count: step.count) else {
                XCTFail("The slider's current step is unknown.", file: file, line: line)
                return
            }
            if reached == step.index {
                guard needsWrite else { break }
                // After switching to the standard range, a displayed Large can precede a system size write.
                // Move its known thumb one standard step away, then return within this same attempt budget.
                let adjacent = step.index + 1
                drag(slider, from: position(reached), to: position(adjacent))
                guard readStep(of: slider, count: step.count) == adjacent else {
                    XCTFail("The slider did not reach the adjacent standard step.", file: file, line: line)
                    return
                }
            } else {
                drag(slider, from: position(reached), to: position(step.index))
                needsWrite = false
            }
        }
        let reads = NSPredicate { _, _ in (slider.value as? String) == expected }
        let wait = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: reads, object: nil)], timeout: 5)
        XCTAssertEqual(
            wait, .completed, "The slider reads \(slider.value ?? "nothing"), not \(expected).", file: file, line: line
        )
    }

    private static let maximumSliderAttempts = 4
    /// Where the thumb's middle sits at the first and last step, from the slider's left and right edges: the
    /// glyphs take the rest. Measured on iPhone Air at iOS 27.0, where the ticks of the twelve steps run from 45 to
    /// 291 points across the 340-point slider.
    private static let sliderLeadingInset: CGFloat = 45
    private static let sliderTrailingInset: CGFloat = 49

    /// Drags across `slider` at its middle height, between two points measured from its left edge.
    private static func drag(_ slider: XCUIElement, from start: CGFloat, to end: CGFloat) {
        let origin = slider.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        origin.withOffset(CGVector(dx: start, dy: 0)).press(
            forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: end, dy: 0)),
            withVelocity: .slow, thenHoldForDuration: 0.2
        )
    }

    /// The step a slider of `count` steps reads, from its percentage value.
    private static func readStep(of slider: XCUIElement, count: Int) -> Int? {
        guard let text = slider.value as? String, let percent = Double(text.filter(\.isNumber)) else { return nil }
        return Int((percent / 100 * Double(count - 1)).rounded())
    }

    private static func isOn(_ toggle: XCUIElement) -> Bool {
        switch toggle.value {
        case let text as String: text == "1"
        case let number as NSNumber: number.boolValue
        default: false
        }
    }
}
