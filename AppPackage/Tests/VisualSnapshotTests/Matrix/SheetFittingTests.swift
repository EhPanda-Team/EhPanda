import AppFeature
import SwiftUI
import UIKit
@testable import VisualSnapshotSupport
import XCTest

/// A form sheet is fitted to its content before the operating step (owner decision 2026-11-27 in 19-26, 「貼合內容」).
///
/// On the iPad a form sheet keeps its own size whatever the window's height, so a sheet's content taller than the sheet
/// was `cannot-cover` at every height: 21 iPad sheet states in 19-26's measuring runs. The iPhone's sheets fill the
/// window and grow with it already, and stay as they are.
final class SheetFittingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    // MARK: The iPad's form sheet

    /// Content taller than the sheet, but within the screen less the sheet's margins, needs no taller window.
    @MainActor
    func testASheetWhoseContentFitsTheScreenIsMeasuredAtTheScreenHeight() async throws {
        let window = try Self.formSheetWindow()
        let screen = window.bounds.height
        let measured = await Self.measure(SheetPage(content: screen * 0.7), in: window)
        XCTAssertEqual(measured.status, .measured, measured.reason ?? "")
        XCTAssertEqual(measured.neededPoints, Int(screen))
        XCTAssertEqual(measured.steps, 0)
    }

    /// Content taller than the screen grows the sheet with the window, so the measurement finds a height.
    @MainActor
    func testASheetTallerThanTheScreenIsMeasuredAtItsContent() async throws {
        let window = try Self.formSheetWindow()
        let screen = window.bounds.height
        let measured = await Self.measure(SheetPage(content: screen * 1.5), in: window)
        XCTAssertEqual(measured.status, .measured, measured.reason ?? "")
        XCTAssertGreaterThan(measured.steps, 0)
        XCTAssertGreaterThan(measured.neededPoints ?? 0, Int(screen * 1.5))
        XCTAssertEqual(window.bounds.height, screen)
    }

    /// The capture fits the sheet before its check, so a sheet whose content fits the screen passes at that height.
    @MainActor
    func testTheCaptureFitsTheSheetBeforeItsCheck() async throws {
        let window = try Self.formSheetWindow()
        let screen = window.bounds.height
        let captured = await HostedWindowCapture.captureAndCompare(
            make: { AnyView(SheetPage(content: screen * 0.7)) }, window: window, style: .light, reference: nil,
            mode: .candidate,
            height: CaptureHeight(
                points: screen, freezeViewport: { _ in }, keyboardTop: { _ in nil }, popoverSource: { _ in nil }
            )
        )
        XCTAssertEqual(captured.status, .recorded, captured.reason ?? "")
    }

    /// A sheet that holds its content keeps its own size.
    @MainActor
    func testASheetThatHoldsItsContentKeepsItsSize() async throws {
        let window = try Self.formSheetWindow()
        await Self.assertFittingLeavesTheSheet(SheetPage(content: 200), in: window)
    }

    /// A sheet whose content is taller than the window lets it grow stops at the window's limit: fitting it again
    /// changes nothing. Its preferred height is set from its content, never raised again from a frame the window holds.
    @MainActor
    func testFittingASheetTheWindowCannotHoldAgainChangesNothing() async throws {
        let window = try Self.formSheetWindow()
        let hosted = HostedWindowCapture.host(SheetPage(content: window.bounds.height * 3), in: window, style: .light)
        let settled = await HostedWindowCapture.settle(window)
        let sheet = window.rootViewController?.presentedViewController
        let fitter = SheetFitter()
        let first = await fitter.fit(in: window)
        let preferred = sheet?.preferredContentSize
        let again = await fitter.fit(in: window)
        let preferredAgain = sheet?.preferredContentSize
        await hosted.disposeAfterDismissal()
        guard case .settled = settled else { return XCTFail("The page never settled") }
        XCTAssertNotNil(sheet, "No sheet was presented")
        XCTAssertEqual(first, .fitted)
        XCTAssertEqual(again, .unchanged)
        XCTAssertEqual(preferredAgain, preferred)
    }

    // MARK: Every sheet

    /// The page of a sheet state is the sheet (owner decision 2026-11-27 in 19-26, 「sheet 的狀況應當測量 sheet 內容」): a
    /// page behind it taller than the screen needs no taller window when the sheet's content fits.
    @MainActor
    func testASheetOverATallPageIsMeasuredAtTheSheet() async {
        guard let window = HostedWindowCapture.keyWindow() else { return XCTFail("No key window") }
        let screen = window.bounds.height
        let measured = await Self.measure(SheetPage(content: 200, page: screen * 3), in: window)
        XCTAssertEqual(measured.status, .measured, measured.reason ?? "")
        XCTAssertEqual(measured.neededPoints, Int(screen))
        XCTAssertEqual(measured.steps, 0)
    }

    // MARK: The iPhone's sheet

    /// A sheet that fills the window's height grows with the window already and is left as it is.
    @MainActor
    func testASheetThatFillsTheWindowIsLeftAsItIs() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        try XCTSkipIf(
            window.traitCollection.horizontalSizeClass == .regular, "The iPhone's sheets fill the window's height"
        )
        await Self.assertFittingLeavesTheSheet(SheetPage(content: window.bounds.height * 2), in: window)
    }

    // MARK: Helpers

    /// The key window, where a sheet is presented as a form sheet: the iPad's regular width.
    @MainActor
    private static func formSheetWindow() throws -> UIWindow {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        try XCTSkipUnless(
            window.traitCollection.horizontalSizeClass == .regular, "Only the iPad keeps a form sheet at its own size"
        )
        return window
    }

    @MainActor
    private static func measure(_ page: SheetPage, in window: UIWindow) async -> PageMeasurement {
        await HostedWindowCapture.measure(
            make: { AnyView(page) }, window: window, style: .light, freezeViewport: { _ in },
            keyboardTop: { _ in nil }
        )
    }

    /// Hosts `page`, lets it settle, fits its sheets, and checks the sheet's frame and preferred size did not change.
    @MainActor
    private static func assertFittingLeavesTheSheet(_ page: SheetPage, in window: UIWindow) async {
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        let settled = await HostedWindowCapture.settle(window)
        let sheet = window.rootViewController?.presentedViewController
        let frame = sheet?.view.frame
        let preferred = sheet?.preferredContentSize
        let fit = await SheetFitter().fit(in: window)
        let fittedFrame = sheet?.view.frame
        let fittedPreferred = sheet?.preferredContentSize
        await hosted.disposeAfterDismissal()
        guard case .settled = settled else { return XCTFail("The page never settled") }
        XCTAssertNotNil(sheet, "No sheet was presented")
        XCTAssertEqual(fit, .unchanged)
        XCTAssertEqual(fittedFrame, frame)
        XCTAssertEqual(fittedPreferred, preferred)
    }
}

/// A page that presents a sheet of fixed-height bands in a scroll view, over a page of `page` points in a scroll view
/// of its own, or over a plain colour.
private struct SheetPage: View {
    /// The height of the sheet's scroll content, fixed when the page is made.
    let content: CGFloat
    /// The height of the page's own scroll content, or `nil` for a page that does not scroll.
    var page: CGFloat?

    var body: some View {
        Group {
            if let page {
                ScrollView { Bands(height: page, saturation: 0.15) }
            } else {
                Color(white: 0.9)
            }
        }
        .sheet(isPresented: .constant(true)) {
            ScrollView { Bands(height: content, saturation: 0.4) }
        }
    }
}

/// Twenty bands of colour, `height` points in all.
private struct Bands: View {
    let height: CGFloat
    let saturation: Double

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<20, id: \.self) { band in
                Color(hue: Double(band) / 20, saturation: saturation, brightness: 0.9)
                    .frame(height: height / 20)
            }
        }
    }
}
