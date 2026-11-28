import AppFeature
import SwiftUI
import UIKit
@testable import VisualSnapshotSupport
import XCTest

/// A text view's scrolling is the field's own, not the page's (owner decision in 19-26, 「整頁有拍到那 7,150 不就可以了嗎」).
///
/// A text view's content height is its text, laid out at the field's width, and a field shorter than its text
/// scrolls inside itself; the page around it is what a picture must cover. The "Excluded Uploaders" editor of site
/// settings needed the window plus 23 pt at every height, so the page was `cannot-cover:TextEditorTextView` in
/// 19-26's measuring runs, as were the report form's and the account's fields (`VerticalTextView`).
final class TextViewNeedTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    /// A field whose text runs past its frame sets no need: the page that holds it is measured at the screen height
    /// in no steps.
    @MainActor
    func testATextViewsOwnContentSetsNoNeed() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let view = VStack(spacing: 0) {
            TextEditor(text: .constant(Self.longText)).frame(height: 120)
            Color.clear
        }
        var textViews = 0
        let measured = await Self.measure(view, in: window) { window in
            textViews = Self.scrollViews(in: window).count(where: { $0 is UITextView })
        }
        let screen = Int(window.bounds.height)
        XCTAssertEqual(textViews, 1)
        XCTAssertEqual(measured, PageMeasurement(
            status: .measured, neededPoints: screen, screenPoints: screen, steps: 0, reason: nil
        ))
    }

    /// A page taller than the screen that holds a text view is measured at its own content, which the field's text
    /// neither adds to nor hides.
    @MainActor
    func testAPageThatHoldsATextViewIsMeasuredAtItsOwnContent() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let content = window.bounds.height * 1.5
        let view = ScrollView {
            VStack(spacing: 0) {
                TextEditor(text: .constant(Self.longText)).frame(height: 120)
                Color.orange.frame(height: content)
            }
        }
        let measured = await Self.measure(view, in: window)
        XCTAssertEqual(measured.status, .measured, measured.reason ?? "")
        XCTAssertGreaterThan(measured.steps, 0)
        XCTAssertGreaterThanOrEqual(measured.neededPoints ?? 0, Int(content + 120))
        XCTAssertLessThan(measured.neededPoints ?? 0, Int(content + 120 + window.bounds.height / 2))
    }

    // MARK: Helpers

    /// Forty lines of text: more than a 120 pt field shows at any text size.
    private static let longText = (1...40).map({ "Line \($0)" }).joined(separator: "\n")

    @MainActor
    private static func measure(
        _ view: some View, in window: UIWindow, interact: (@MainActor (UIWindow) async throws -> Void)? = nil
    ) async -> PageMeasurement {
        await HostedWindowCapture.measure(
            make: { AnyView(view) }, window: window, style: .light, interact: interact, freezeViewport: { _ in },
            keyboardTop: { _ in nil }, popoverSource: { _ in nil }
        )
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        view.subviews.flatMap({ subview in
            ((subview as? UIScrollView).map({ [$0] }) ?? []) + scrollViews(in: subview)
        })
    }
}
