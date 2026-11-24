import ComposableArchitecture
@testable import DetailFeature
import Foundation
import SwiftUI
import Testing
import UIKit

/// The Report form's centred states keep their content centred while it fits and scroll once it does not.
///
/// A centred state (sent, unavailable, loading) pinned its content to the height of its container. At accessibility
/// sizes in landscape the Sent message is taller than the container, so it was squeezed into that height and cut to
/// one line instead of scrolling (the owner's C11 item, 19-13). The content now has the visible height as a floor:
/// it fills a tall container, which keeps the message centred, and grows past a short one, which makes it scroll.
@MainActor
struct ReportFormCentredStateTests {
    private static let iPhoneLandscape = CGSize(width: 912, height: 420)
    private static let iPhonePortrait = CGSize(width: 420, height: 912)
    private static let taller = CGSize(width: 420, height: 1012)

    /// At the largest text size in landscape the Sent message is taller than the room it has, so it scrolls.
    @Test
    func theSentMessageScrollsWhenItDoesNotFit() throws {
        let page = try Self.sentForm(size: .accessibility5)
        try HostedView.withRoot(of: page, size: Self.iPhoneLandscape) { root in
            let scrollView = try #require(Self.scrollViews(in: root).first)
            let visibleHeight = Self.visibleHeight(of: scrollView)
            #expect(
                scrollView.contentSize.height > visibleHeight,
                "The content is \(scrollView.contentSize.height) pt tall in \(visibleHeight) pt of room."
            )
        }
    }

    /// Where the message fits, the content is exactly the room it has and the message stays centred in it: given
    /// more room, the message moves down by half of the extra.
    ///
    /// The check is differential because the message's accessibility frame is not its layout frame. The checkmark
    /// symbol's layout box is taller than its accessibility frame (a 144 pt block reports 138 pt, the difference
    /// missing at the top), which biases the frame's middle by a constant. Measured at two heights, the bias
    /// cancels, and a message pinned to the top or the bottom would not move by half of the extra room.
    @Test
    func theSentMessageStaysCentredWhileItFits() throws {
        let page = try Self.sentForm(size: .large)
        let short = try Self.measure(page, in: Self.iPhonePortrait)
        let tall = try Self.measure(page, in: Self.taller)
        for placement in [short, tall] {
            #expect(
                abs(placement.contentHeight - placement.visibleHeight) <= 1,
                "The content is \(placement.contentHeight) pt tall in \(placement.visibleHeight) pt of room."
            )
        }
        let extraRoom = tall.visibleHeight - short.visibleHeight
        let moved = tall.messageMiddle - short.messageMiddle
        #expect(
            abs(moved - extraRoom / 2) <= 1,
            "With \(extraRoom) pt more room the message moved \(moved) pt, not \(extraRoom / 2)."
        )
    }

    /// Where the Sent message stands in its scroll view hosted in a window of `size`.
    private struct Placement {
        let visibleHeight: CGFloat
        let contentHeight: CGFloat
        /// The middle of the message's accessibility frame, in the scroll view's content coordinates.
        let messageMiddle: CGFloat
    }

    private static func measure(_ page: some View, in size: CGSize) throws -> Placement {
        try AccessibilityElements.read(of: page, size: size) { elements in
            let root = try #require(elements.first as? UIView, "The first element is not the hosted root view.")
            let scrollView = try #require(Self.scrollViews(in: root).first)
            let message = try #require(
                elements.first(where: { Self.identifier(of: $0) == "report_sent" }),
                "The page has no element identified report_sent."
            )
            let frame = try #require(
                root.window?.screen.coordinateSpace.convert(message.accessibilityFrame, to: scrollView)
            )
            return Placement(
                visibleHeight: Self.visibleHeight(of: scrollView),
                contentHeight: scrollView.contentSize.height,
                messageMiddle: frame.midY
            )
        }
    }

    /// The Report form in its Sent phase, at a Dynamic Type size.
    private static func sentForm(size: DynamicTypeSize) throws -> some View {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/7731/abcdef0123/"))
        var state = try #require(ReportFormFeature.State(
            comment: ReportFormFeature.Comment(
                author: "Alice", date: Date(timeIntervalSince1970: 1_700_000_000), text: "Buy now"
            ),
            galleryURL: galleryURL
        ))
        state.phase = .sent
        let store = Store(initialState: state, reducer: ReportFormFeature.init)
        return ReportFormView(store: store)
            .environment(\.dynamicTypeSize, size)
            .environment(\.locale, Locale(identifier: "en_US"))
    }

    /// SwiftUI's accessibility nodes answer `accessibilityIdentifier` but do not all adopt the protocol declaring it.
    private static func identifier(of element: NSObject) -> String? {
        let key = "accessibilityIdentifier"
        guard element.responds(to: NSSelectorFromString(key)) else { return nil }
        return element.value(forKey: key) as? String
    }

    /// The room a scroll view gives its content: its bounds less the insets that keep content clear of the bars.
    private static func visibleHeight(of scrollView: UIScrollView) -> CGFloat {
        scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map({ [$0] }) ?? []) + view.subviews.flatMap(scrollViews(in:))
    }
}
