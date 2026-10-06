import UIKit
@testable import VisualSnapshotSupport
import XCTest

/// Vertical scroll host selection over plain UIKit hierarchies with explicit insets, mirroring the measured iPad
/// portrait Home page at xSmall: 1192 pt of content in a 1210 pt scroll view whose adjusted insets add 86 pt above
/// and 25 pt below it.
@MainActor
final class HostedHierarchyTests: XCTestCase {
    func testAdjustedInsetsMakeContentShorterThanItsBoundsScrollable() {
        let page = Self.scrollView(height: 1210, contentHeight: 1192, insets: Self.pageInsets)
        page.addSubview(Self.carousel())
        let root = Self.root(containing: page)

        XCTAssertIdentical(HostedHierarchy.verticalScrollHost(in: root), page)
    }

    func testContentThatFitsWithItsInsetsHasNoHost() {
        let page = Self.scrollView(height: 1210, contentHeight: 1099, insets: Self.pageInsets)
        page.addSubview(Self.carousel())
        let root = Self.root(containing: page)

        XCTAssertNil(HostedHierarchy.verticalScrollHost(in: root))
    }

    func testTallestScrollableContentWinsAndZeroWidthViewsNeverQualify() {
        let page = Self.scrollView(height: 1210, contentHeight: 2000, insets: Self.pageInsets)
        let nested = Self.scrollView(height: 400, contentHeight: 900, insets: .zero)
        let collapsed = Self.scrollView(height: 1210, contentHeight: 5000, insets: .zero)
        collapsed.frame.size.width = 0
        page.addSubview(nested)
        page.addSubview(collapsed)
        let root = Self.root(containing: page)

        XCTAssertIdentical(HostedHierarchy.verticalScrollHost(in: root), page)
    }

    private static let pageInsets = UIEdgeInsets(top: 86, left: 0, bottom: 25, right: 0)

    private static func scrollView(height: CGFloat, contentHeight: CGFloat, insets: UIEdgeInsets) -> UIScrollView {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 834, height: height))
        // Without a window the system adds no safe area; `.never` makes the adjusted insets exactly these.
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = insets
        scrollView.contentSize = CGSize(width: 834, height: contentHeight)
        return scrollView
    }

    /// A full-width horizontal carousel whose content height equals its own bounds.
    private static func carousel() -> UIScrollView {
        let carousel = UIScrollView(frame: CGRect(x: 0, y: 120, width: 834, height: 300))
        carousel.contentInsetAdjustmentBehavior = .never
        carousel.contentSize = CGSize(width: 3000, height: 300)
        return carousel
    }

    private static func root(containing page: UIScrollView) -> UIView {
        let root = UIView(frame: page.frame)
        root.addSubview(page)
        return root
    }
}
