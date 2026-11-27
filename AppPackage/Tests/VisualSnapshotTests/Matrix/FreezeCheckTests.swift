import AppFeature
import Observation
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// The freeze check before a window grows past the screen: freezing the viewport sampling must not change the page,
/// by the same still-window rule the settle applies (``HostedWindowCapture/readsMatch(_:_:)``).
///
/// The check demanded byte-identical reads, and rendering rounding failed it: one colour step on a card's 1 pt border
/// in dark pages, one byte on the iPad, at coordinates that moved from run to run (19-26, owner decision 2026-11-27,
/// 「改用靜止判斷的規則」). What it guards against, a view that sizes itself from its own viewport and reflows when the
/// sampling is frozen, moves far more than one step.
final class FreezeCheckTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    /// One pixel one colour step off once frozen is rendering noise: the page is measured.
    @MainActor
    func testOneStepOfNoiseWhenFrozenIsTheSamePage() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let freeze = FreezeState()
        let page = TallPage(freeze: freeze, change: .oneStep, contentHeight: window.bounds.height * 2)
        let measurement = await Self.measure(page, freeze: freeze, in: window)
        XCTAssertEqual(measurement.status, .measured, measurement.reason ?? "")
        XCTAssertGreaterThan(measurement.steps, 0, "The page fitted the screen, so nothing was frozen")
    }

    /// A page that moves when frozen still fails the freeze check.
    @MainActor
    func testAPageThatReflowsWhenFrozenFails() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let freeze = FreezeState()
        let page = TallPage(freeze: freeze, change: .reflow, contentHeight: window.bounds.height * 2)
        let measurement = await Self.measure(page, freeze: freeze, in: window)
        XCTAssertEqual(measurement.status, .error)
        XCTAssertEqual(measurement.reason, "freeze-changed-pixels")
    }

    @MainActor
    private static func measure(_ page: TallPage, freeze: FreezeState, in window: UIWindow) async -> PageMeasurement {
        await HostedWindowCapture.measure(
            make: { AnyView(page) }, window: window, style: .light,
            freezeViewport: { freeze.isFrozen = $0 }, keyboardTop: { _ in nil }
        )
    }
}

/// Whether the viewport sampling is frozen, as the page under test reads it.
@MainActor
@Observable
private final class FreezeState {
    var isFrozen = false
}

/// A scrolling page of a fixed height, taller than the screen, with a change that shows once the sampling is frozen.
private struct TallPage: View {
    enum Change {
        /// The top-left pixel's red channel moves from 128 to 129.
        case oneStep
        /// The content moves 40 pt down.
        case reflow
    }

    let freeze: FreezeState
    let change: Change
    /// Fixed when the page is made, so the need does not follow a growing window.
    let contentHeight: CGFloat

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<20, id: \.self) { row in
                    Color(hue: Double(row) / 20, saturation: 0.4, brightness: 0.9)
                        .frame(height: contentHeight / 20)
                }
            }
            .padding(.top, change == .reflow && freeze.isFrozen ? 40 : 0)
            .overlay(alignment: .topLeading) {
                Color(.sRGB, red: change == .oneStep && freeze.isFrozen ? 129 / 255 : 128 / 255, green: 0, blue: 0)
                    .frame(width: 1, height: 1)
            }
        }
        .scrollIndicators(.hidden)
    }
}
