import AppFeature
import Foundation
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// The two step stages of the capture and of the measuring mode, on small synthetic views in the app-hosted test's
/// real key window (19-30; owner decision 2026-11-23, 「把步驟拆成兩種」, split the steps into two kinds): a stillness
/// step (`still`) runs at screen size right after hosting, an operating step (`interact`) after the window has grown.
final class CaptureStageTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    // MARK: The capture path

    /// The stillness step sees the window at its native height and the operating step the grown window; at a committed
    /// height equal to the window's own, both see the native height.
    @MainActor
    func testAStillnessStepRunsAtNativeSizeAndAnOperatingStepInTheGrownWindow() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let native = window.bounds.height
        for committed in [native + 600, native] {
            var stillHeights: [CGFloat] = []
            var interactHeights: [CGFloat] = []
            let outcome = await HostedWindowCapture.captureAndCompare(
                make: { AnyView(Self.scrolling(committed - 200)) }, window: window, style: .light, reference: nil,
                mode: .candidate,
                still: { window in stillHeights.append(window.bounds.height) },
                interact: { window in interactHeights.append(window.bounds.height) },
                height: Self.height(committed)
            )
            XCTAssertEqual(outcome.status, .recorded, outcome.reason ?? "")
            XCTAssertEqual(stillHeights, [native], "still at committed \(committed)")
            XCTAssertEqual(interactHeights, [committed], "interact at committed \(committed)")
            XCTAssertEqual(window.bounds.height, native)
        }
    }

    /// A page that is still only because its stillness step holds it still is taken taller than the screen when that
    /// step is a stillness step; as an operating step it runs after the native settle, which times out.
    @MainActor
    func testAPageOnlyItsStillnessStepHoldsStillIsTakenTallerThanTheScreen() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let committed = window.bounds.height + 600
        let asStillness = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.changingPage(content: committed - 200)) }, window: window, style: .light,
            reference: nil, mode: .candidate, still: Self.hideChangingViews, height: Self.height(committed)
        )
        XCTAssertEqual(asStillness.status, .recorded, asStillness.reason ?? "")
        XCTAssertEqual(try Self.pixelHeight(asStillness.png), Int(committed))
        let asOperating = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.changingPage(content: committed - 200)) }, window: window, style: .light,
            reference: nil, mode: .candidate, interact: Self.hideChangingViews, height: Self.height(committed)
        )
        XCTAssertEqual(asOperating.status, .timeout)
        XCTAssertTrue(asOperating.reason?.hasPrefix("settle-timeout") == true, asOperating.reason ?? "")
    }

    /// On the screen-sized path the two stages run back to back, still first: the one step of before.
    @MainActor
    func testOnTheScreenSizedPathTheTwoStagesAreTheOneStepOfBefore() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let native = window.bounds.height
        let split = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.changingPage(content: native + 600)) }, window: window, style: .light,
            reference: nil, mode: .candidate, still: Self.hideChangingViews, interact: Self.scrollDown,
            height: Self.height(native)
        )
        let whole = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(Self.changingPage(content: native + 600)) }, window: window, style: .light,
            reference: nil, mode: .candidate,
            interact: { window in
                try await Self.hideChangingViews(window)
                try await Self.scrollDown(window)
            },
            height: Self.height(native)
        )
        XCTAssertEqual(split.status, whole.status)
        XCTAssertEqual(split.reason, whole.reason)
        XCTAssertNotNil(split.png)
        XCTAssertEqual(split.png, whole.png)
    }

    // MARK: Helpers

    private static func height(_ points: CGFloat) -> CaptureHeight {
        CaptureHeight(points: points, freezeViewport: { _ in })
    }

    /// A scroll view of coloured rows, `height` points of content.
    @MainActor
    private static func scrolling(_ height: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<Int((height / 60).rounded(.up)), id: \.self) { row in
                    Text(verbatim: "Row \(row)")
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hue: Double(row % 12) / 12, saturation: 0.4, brightness: 0.95))
                }
            }
        }
    }

    /// ``scrolling(_:)`` under a 120 × 120 pt view that never stops changing, until a step hides it.
    @MainActor
    private static func changingPage(content: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            scrolling(content)
            ChangingView()
                .frame(width: 120, height: 120)
        }
    }

    /// The stillness step of the cases above: hides every `ChangingView.CountingView` in the window.
    @MainActor
    private static func hideChangingViews(_ window: UIWindow) async throws {
        for view in descendants(of: window) where view is ChangingView.CountingView {
            view.isHidden = true
        }
    }

    /// The operating step of the cases above: scrolls the page's scroll view 100 pt down.
    @MainActor
    private static func scrollDown(_ window: UIWindow) async throws {
        let scrollView = try XCTUnwrap(descendants(of: window).compactMap({ $0 as? UIScrollView }).first)
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y + 100), animated: false)
    }

    @MainActor
    private static func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap({ [$0] + descendants(of: $0) })
    }

    private static func pixelHeight(_ png: Data?) throws -> Int {
        try XCTUnwrap(png.flatMap(UIImage.init(data:))?.cgImage).height
    }
}
