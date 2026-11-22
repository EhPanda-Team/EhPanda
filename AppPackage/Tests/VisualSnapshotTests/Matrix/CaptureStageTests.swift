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

    // MARK: The measuring mode

    /// A page that is still only because its stillness step holds it still is measured; as an operating step it runs
    /// after the taller hosting's native settle, which times out.
    @MainActor
    func testAPageOnlyItsStillnessStepHoldsStillIsMeasured() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let native = Int(window.bounds.height.rounded())
        let asStillness = await Self.measure(
            Self.changingPage(content: window.bounds.height + 400), in: window, still: Self.hideChangingViews
        )
        XCTAssertEqual(asStillness.status, .measured, asStillness.reason ?? "")
        XCTAssertGreaterThan(asStillness.neededPoints ?? 0, native)
        XCTAssertEqual(asStillness.steps, 1)
        let asOperating = await Self.measure(
            Self.changingPage(content: window.bounds.height + 400), in: window, interact: Self.hideChangingViews
        )
        XCTAssertEqual(asOperating.status, .error)
        XCTAssertTrue(asOperating.reason?.hasPrefix("settle-timeout") == true, asOperating.reason ?? "")
        XCTAssertEqual(window.bounds.height, CGFloat(native))
    }

    /// Each height is its own hosting, taken in the capture's order: the window's own height first, then the need in a
    /// fresh hosting of the tall path.
    @MainActor
    func testEachMeasuredHeightIsItsOwnHostingInTheCaptureOrder() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let native = window.frame
        var made = 0
        var stillHeights: [CGFloat] = []
        var interactHeights: [CGFloat] = []
        let measured = await HostedWindowCapture.measure(
            make: {
                made += 1
                return AnyView(Self.scrolling(native.height + 400))
            },
            window: window, style: .light,
            still: { window in stillHeights.append(window.bounds.height) },
            interact: { window in interactHeights.append(window.bounds.height) },
            freezeViewport: { _ in }, keyboardTop: { _ in nil }
        )
        XCTAssertEqual(measured.status, .measured, measured.reason ?? "")
        XCTAssertEqual(measured.steps, 1)
        let need = try XCTUnwrap(measured.neededPoints)
        XCTAssertGreaterThan(CGFloat(need), native.height)
        XCTAssertEqual(made, 2)
        XCTAssertEqual(stillHeights, [native.height, native.height])
        XCTAssertEqual(interactHeights, [native.height, CGFloat(need)])
        XCTAssertEqual(window.frame, native)
    }

    // MARK: The keyboard classification

    /// A scroll view that avoids a keyboard that is up cannot be covered by any window height, and the first hosting
    /// says so.
    @MainActor
    func testAKeyboardTheScrollViewAvoidsCannotBeCoveredAndIsFoundAtTheFirstHosting() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let keyboardTop = window.screen.bounds.maxY - Self.keyboardHeight
        var made = 0
        let measured = await HostedWindowCapture.measure(
            make: {
                made += 1
                return AnyView(Self.keyboardScrollView(bottomInset: Self.keyboardHeight, over: window))
            },
            window: window, style: .light, freezeViewport: { _ in }, keyboardTop: { _ in keyboardTop }
        )
        XCTAssertEqual(measured.status, .cannotCover, measured.reason ?? "")
        XCTAssertEqual(measured.reason, "cannot-cover:keyboard")
        XCTAssertEqual(measured.steps, 0)
        XCTAssertEqual(made, 1)
        let without = await HostedWindowCapture.measure(
            make: { AnyView(Self.keyboardScrollView(bottomInset: Self.keyboardHeight, over: window)) },
            window: window, style: .light, freezeViewport: { _ in }, keyboardTop: { _ in nil }
        )
        XCTAssertEqual(without.status, .measured, without.reason ?? "")
        XCTAssertEqual(without.steps, 1)
    }

    /// A keyboard the page ignores (as `LoginView` does up to Large) is no reason.
    @MainActor
    func testAKeyboardTheScrollViewDoesNotAvoidIsNoReason() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let keyboardTop = window.screen.bounds.maxY - Self.keyboardHeight
        let measured = await HostedWindowCapture.measure(
            make: { AnyView(Self.keyboardScrollView(bottomInset: 0, over: window)) },
            window: window, style: .light, freezeViewport: { _ in }, keyboardTop: { _ in keyboardTop }
        )
        XCTAssertEqual(measured.status, .measured, measured.reason ?? "")
        XCTAssertEqual(measured.steps, 1)
    }

    /// The check names the keyboard the need-setting scroll view avoids, and only that.
    @MainActor
    func testTheChecksReasonNamesAKeyboardTheScrollViewAvoids() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let native = window.bounds.height
        let keyboardTop = window.screen.bounds.maxY - Self.keyboardHeight
        var need = 0
        for top in [keyboardTop, nil] {
            let outcome = await HostedWindowCapture.captureAndCompare(
                make: { AnyView(Self.keyboardScrollView(bottomInset: Self.keyboardHeight, over: window)) },
                window: window, style: .light, reference: nil, mode: .candidate,
                interact: { window in
                    let scrollView = Self.descendants(of: window).compactMap({ $0 as? UIScrollView }).first
                    let insets = scrollView?.adjustedContentInset ?? .zero
                    let overflow = (scrollView?.contentSize.height ?? 0) + insets.top + insets.bottom
                        - (scrollView?.bounds.height ?? 0)
                    need = Int((window.bounds.height + overflow).rounded(.up))
                },
                height: CaptureHeight(points: native, freezeViewport: { _ in }, keyboardTop: { _ in top })
            )
            let reason = "page-height: needs \(need) pt, committed \(Int(native)) pt"
            XCTAssertEqual(outcome.status, .error)
            XCTAssertEqual(outcome.reason, top == nil ? reason : reason + ", cannot-cover:keyboard")
        }
    }

    // MARK: Helpers

    private static func height(_ points: CGFloat) -> CaptureHeight {
        CaptureHeight(points: points, freezeViewport: { _ in }, keyboardTop: { _ in nil })
    }

    /// The height of the keyboard the cases below pretend is up.
    private static let keyboardHeight: CGFloat = 300

    @MainActor
    private static func measure(
        _ view: some View, in window: UIWindow,
        still: (@MainActor (UIWindow) async throws -> Void)? = nil,
        interact: (@MainActor (UIWindow) async throws -> Void)? = nil
    ) async -> PageMeasurement {
        await HostedWindowCapture.measure(
            make: { AnyView(view) }, window: window, style: .light, still: still, interact: interact,
            freezeViewport: { _ in }, keyboardTop: { _ in nil }
        )
    }

    /// A page that is one scroll view, 400 pt of content taller than the window and with `bottomInset` of bottom
    /// inset, as the page of a keyboard it avoids has.
    @MainActor
    private static func keyboardScrollView(bottomInset: CGFloat, over window: UIWindow) -> some View {
        KeyboardScrollView(contentHeight: window.bounds.height + 400, bottomInset: bottomInset)
            .ignoresSafeArea()
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

/// A scroll view that fills the page, with the content height and bottom inset a case gives it.
private struct KeyboardScrollView: UIViewRepresentable {
    let contentHeight: CGFloat
    let bottomInset: CGFloat

    func makeUIView(context: Context) -> Container {
        let container = Container()
        container.scrollView.contentSize = CGSize(width: 10, height: contentHeight)
        container.scrollView.contentInset.bottom = bottomInset
        return container
    }

    func updateUIView(_ uiView: Container, context: Context) {}

    /// Keeps the scroll view the size of the page whenever the page's size changes, as the window grows.
    final class Container: UIView {
        let scrollView = UIScrollView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            addSubview(scrollView)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            scrollView.frame = bounds
        }
    }
}
