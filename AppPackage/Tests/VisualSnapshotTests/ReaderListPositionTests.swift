import AppFeature
import AppTools
import CustomDump
import Observation
@testable import ReadingFeature
import SwiftUI
import UIKit
@testable import VisualSnapshotSupport
import XCTest

/// Where the vertical reader's list puts the page it positions. Resuming, the slider, tap-to-turn, autoplay and
/// the accessibility page actions all reach `AdvancedList` as a page-model write, so the tests drive that write.
///
/// The rows size as the reader's image containers do once their image URLs are known: an unloaded page fills the
/// viewport, a loaded one takes its image's aspect ratio at the full width. The test loads pages in orders it
/// chooses instead of whichever order a network happens to deliver. In the root and presented hosts the stack
/// builds no page above the positioned one, so there the orders vary when that page and the pages below it load;
/// the hosts that build a screen above, as an accessibility client makes the stack build it, also vary the order of
/// loads above it.
final class ReaderListPositionTests: XCTestCase {
    /// The list needs no app state, but it runs inside the host app, whose scene phase changes reach its download
    /// client at any time. Re-preparing the inert host clients for every test keeps such a change from resolving an
    /// unimplemented test dependency and failing whichever test happens to be running.
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testResumeKeepsItsPageAtTheTopWhateverOrderPagesLoad() async throws {
        // The default divider and the widest one the reading settings offer.
        for spacing: CGFloat in [0, 20] {
            var settledTopPixels = [[Int]: CGFloat?]()
            for order in [[3, 4, 5], [4, 5, 3], [5, 3, 4], [2, 4, 3, 5]] {
                let host = try ReaderListHost(resumePage: 4, spacing: spacing)
                defer { host.dismiss() }
                let step = "spacing \(spacing), order \(order)"
                try await expectAtTop(page: 4, in: host, "\(step), resumed")
                for page in order {
                    host.loads.loaded.insert(page)
                    settledTopPixels[order] = try await expectAtTop(page: 4, in: host, "\(step), \(page) loaded")
                        .map(host.pixel(of:))
                }
            }
            expectSameTop(settledTopPixels, "spacing \(spacing)")
        }
    }

    /// The reader is presented at less than its final height (1047 of 1210 pt on the iPad, measured 2026-10-09 in
    /// a capture of the real reader) and grows to it. Unloaded pages fill the viewport, so the growth changes the
    /// height of every page built on screen.
    @MainActor
    func testResumeKeepsItsPageAtTheTopWhenTheReaderGrows() async throws {
        let host = try ReaderListHost(resumePage: 4, heightScale: 1047 / 1210)
        defer { host.dismiss() }
        try await expectAtTop(page: 4, in: host, "resumed")
        host.growToFullHeight()
        try await expectAtTop(page: 4, in: host, "grown")
        for page in [3, 4, 5] {
            host.loads.loaded.insert(page)
            try await expectAtTop(page: 4, in: host, "\(page) loaded")
        }
    }

    /// An accessibility client, such as VoiceOver or a UI test reading the screen, makes the stack build pages
    /// around the visible ones, pages above the resume page among them (measured 2026-10-09: a capture's first
    /// accessibility query built pages 2, 3 and 6 within 87 ms). Their images then load above the resume page, so
    /// every frame drawn while a page loads is checked, not only the settled one.
    ///
    /// The host builds the pages above under a top safe-area inset off the window. The scroll view's visible region
    /// excludes that inset (measured 2026-10-10), so the list sees those pages entirely above the screen, as it sees
    /// the pages an accessibility client builds outside the scroll view's bounds.
    @MainActor
    func testResumeKeepsItsPageAtTheTopWhenBuiltPagesAboveLoad() async throws {
        var settledTopPixels = [[Int]: CGFloat?]()
        for order in [[2, 3], [3, 2]] {
            let host = try ReaderListHost(resumePage: 4, presentation: .buildingScreenAbove)
            defer { host.dismiss() }
            try await expectAtTop(page: 4, in: host, "order \(order), resumed")
            for page in order {
                settledTopPixels[order] = try await expectAtTopInEveryFrame(
                    page: 4, in: host, "order \(order), \(page) loaded"
                ) {
                    host.loads.loaded.insert(page)
                }
                .map(host.pixel(of:))
            }
        }
        expectSameTop(settledTopPixels, "pages above")
    }

    /// An accessibility client builds the pages above once the reader has settled, at its first query of the
    /// screen, so here they are built after the resume and load afterwards. Without `AboveScreenHeightLock`, pages
    /// that changed height above the screen moved the resume page in this shape in every run, in both orders
    /// (measured 2026-10-10).
    @MainActor
    func testResumeKeepsItsPageAtTheTopWhenPagesAboveAreBuiltLate() async throws {
        for order in [[2, 3], [3, 2]] {
            let host = try ReaderListHost(resumePage: 4, presentation: .buildingScreenAboveLater)
            defer { host.dismiss() }
            try await expectAtTop(page: 4, in: host, "order \(order), resumed")
            try await expectAtTopInEveryFrame(page: 4, in: host, "order \(order), screen above built") {
                host.buildScreenAbove()
            }
            for page in order {
                try await expectAtTopInEveryFrame(page: 4, in: host, "order \(order), \(page) loaded") {
                    host.loads.loaded.insert(page)
                }
            }
        }
    }

    /// Pages built above the resume page that never load leave it in place while it and the pages below it load,
    /// whatever their order and the divider.
    @MainActor
    func testResumeKeepsItsPageAtTheTopWhenPagesBelowLoadUnderBuiltPagesAbove() async throws {
        for spacing: CGFloat in [0, 20] {
            for order in [[4, 5, 6], [6, 5, 4], [5, 4, 6]] {
                let host = try ReaderListHost(resumePage: 4, spacing: spacing, presentation: .buildingScreenAbove)
                defer { host.dismiss() }
                let step = "spacing \(spacing), order \(order)"
                try await expectAtTop(page: 4, in: host, "\(step), resumed")
                for page in order {
                    try await expectAtTopInEveryFrame(page: 4, in: host, "\(step), \(page) loaded") {
                        host.loads.loaded.insert(page)
                    }
                }
            }
        }
    }

    /// The reader as it is shown: presented full screen over another view, inside a navigation stack whose bar and
    /// status bar are hidden, laid out under the safe area.
    @MainActor
    func testResumeKeepsItsPageAtTheTopInThePresentedReader() async throws {
        let host = try ReaderListHost(resumePage: 4, presentation: .fullScreenCover)
        defer { host.dismiss() }
        try await expectAtTop(page: 4, in: host, "resumed")
        for page in [3, 4, 5] {
            host.loads.loaded.insert(page)
            try await expectAtTop(page: 4, in: host, "\(page) loaded")
        }
    }

    /// A resume or jump far into a long gallery lands on the heights the stack estimates for the pages it skips,
    /// with the screen above built as an accessibility client builds it. After the jump the page above reaches a
    /// fraction of a pixel into the screen (0.071 pt, measured 2026-10-10) and must still count as above it.
    @MainActor
    func testFarPositionsKeepTheirPageAtTheTop() async throws {
        for jumps in [false, true] {
            let host = try ReaderListHost(
                resumePage: jumps ? 4 : 150, pageCount: 200, presentation: .buildingScreenAbove
            )
            defer { host.dismiss() }
            let step = jumps ? "jumped" : "resumed"
            if jumps {
                try await expectAtTop(page: 4, in: host, "resumed")
                host.model.update(.new(index: 149))
            }
            try await expectAtTop(page: 150, in: host, step)
            for page in [149, 148, 150, 151] {
                host.loads.loaded.insert(page)
                try await expectAtTop(page: 150, in: host, "\(step), \(page) loaded")
            }
        }
    }

    /// A page kept at its height above the screen keeps it while only its bottom shows, as the screen scrolls up
    /// onto it: releasing it there could shrink it back above the screen. Once its top is on screen, it takes its
    /// own height and the pages below follow it.
    ///
    /// The scrolls are `setContentOffset` calls, which the list's position does not follow (measured 2026-10-11), so
    /// the position keeps naming page 4 and page 3 releases through its zone, never by the position naming it.
    @MainActor
    func testAPageAcrossTheTopKeepsItsHeightUntilItsTopIsOnScreen() async throws {
        let host = try ReaderListHost(resumePage: 4, presentation: .buildingScreenAbove)
        defer { host.dismiss() }
        try await expectAtTop(page: 4, in: host, "resumed")
        let scrollView = try XCTUnwrap(HostedHierarchy.verticalScrollHost(in: host.window))
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y - 200), animated: true)
        let scrolledTopPixel = try await host.settle().frames[4].map({ host.pixel(of: $0.minY) })
        XCTAssertGreaterThan(try XCTUnwrap(scrolledTopPixel), 0)
        host.loads.loaded.insert(3)
        let loaded = try await host.settle()
        expectNoDifference(
            loaded.frames[4].map({ host.pixel(of: $0.minY) }), scrolledTopPixel, "3 loaded across the top"
        )
        let pageThreeTop = try XCTUnwrap(loaded.frames[3]).minY
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y + pageThreeTop - 10), animated: true)
        expectOwnSize(page: 3, in: try await host.settle(), of: host, "page 3's top on screen")
    }

    /// A jump back to a page kept at its height above the screen puts it at the top, where it takes its own height
    /// and the pages below follow it.
    @MainActor
    func testJumpBackToAPageBuiltAboveTakesItsOwnHeightAtTheTop() async throws {
        let host = try ReaderListHost(resumePage: 4, presentation: .buildingScreenAbove)
        defer { host.dismiss() }
        try await expectAtTop(page: 4, in: host, "resumed")
        host.loads.loaded.insert(3)
        try await expectAtTop(page: 4, in: host, "3 loaded")
        host.model.update(.new(index: 2))
        try await expectAtTop(page: 3, in: host, "jumped back")
        expectOwnSize(page: 3, in: try await host.settle(), of: host, "jumped back")
    }

    /// Page 1 ends half a pixel between two rows, so the jump back to page 2 targets a top the scroll view rounds past
    /// to the row below it, and the renderer, rounding the same way, draws the page from the first row (measured
    /// 2026-10-10). Page 2, kept at its placeholder's height above the screen, landed there half a pixel above the top
    /// on the iPad and a rounding error more on the iPhone, whose offsets are thirds of a point, and the zone's
    /// earlier rounding kept it locked at that height on both (measured 2026-10-10). It takes its own height at the
    /// top whichever row its edge rounds to.
    @MainActor
    func testJumpBackToAPageWhoseTopLiesHalfAPixelBetweenRowsTakesItsOwnHeight() async throws {
        let screen = try ReaderListHost.activeScene().screen
        // The first quarter-point page height that ends half a pixel between two rows at the screen's scale, short
        // enough to keep page 3 on screen below page 2.
        let pageHeight = try XCTUnwrap(
            [500.25, 500.5, 500.75].first(where: { ($0 * screen.scale).truncatingRemainder(dividingBy: 1) == 0.5 })
        )
        let host = try ReaderListHost(
            resumePage: 1, imageAspectRatio: screen.bounds.width / pageHeight, presentation: .buildingScreenAbove
        )
        defer { host.dismiss() }
        host.loads.loaded = Set(1...host.pageCount).subtracting([2])
        try await expectAtTop(page: 1, in: host, "resumed")
        host.model.update(.new(index: 3))
        try await expectAtTop(page: 4, in: host, "jumped")
        let jumped = try await host.settle()
        let placeholderHeight = try XCTUnwrap(jumped.frames[2]).height
        host.loads.loaded.insert(2)
        let loaded = try await host.settle()
        let keptHeight = try XCTUnwrap(loaded.frames[3]).minY - XCTUnwrap(loaded.frames[2]).minY
        expectNoDifference(
            host.pixel(of: keptHeight), host.pixel(of: placeholderHeight),
            "2 loaded above, kept at its placeholder's height"
        )
        host.model.update(.new(index: 1))
        let jumpedBack = try await host.settle()
        let pageOne = try XCTUnwrap(jumpedBack.frames[1])
        let pageTwo = try XCTUnwrap(jumpedBack.frames[2])
        XCTAssertLessThanOrEqual(host.pixel(of: pageOne.maxY), 0, "jumped back, page 1 above the screen")
        XCTAssertLessThanOrEqual(host.pixel(of: pageTwo.minY), 0, "jumped back, page 2 from the first row")
        expectNoDifference(jumpedBack.pageIndex + 1, 2, "jumped back, page named")
        expectOwnSize(page: 2, in: jumpedBack, of: host, "jumped back")
    }

    /// A page that leaves the screen upwards keeps the height it had there, so its image loading again from the
    /// placeholder, as every reload starts, leaves the page on screen in place.
    @MainActor
    func testAPageThatLeavesUpwardsKeepsItsHeightWhileItsImageReloads() async throws {
        let host = try ReaderListHost(resumePage: 3, presentation: .buildingScreenAbove)
        defer { host.dismiss() }
        host.loads.loaded.insert(3)
        try await expectAtTop(page: 3, in: host, "3 loaded")
        host.model.update(.new(index: 3))
        try await expectAtTop(page: 4, in: host, "jumped to 4")
        try await expectAtTopInEveryFrame(page: 4, in: host, "3 reloading") {
            host.loads.loaded.remove(3)
        }
        try await expectAtTopInEveryFrame(page: 4, in: host, "3 reloaded") {
            host.loads.loaded.insert(3)
        }
    }

    /// A window resize, as Split View and Stage Manager make, changes the width of every page, the pages above the
    /// screen among them, and with it the height of every loaded page. Pages above the screen that took their new
    /// heights moved the positioned page by once or twice the change (measured 2026-10-10), so the lock keeps the
    /// pages above it at their heights, and a single resize from rest keeps the positioned page at the top.
    ///
    /// Beyond that a resize is outside what the list keeps: SwiftUI lays the pages out against the old offset first,
    /// which released the page kept right above the positioned one until it locked again, a second resize back to the
    /// first width left the positioned page's top 464 pt above the screen in the root host started narrowed, and
    /// SwiftUI flagged geometry actions as cycling, on the iPad with the lock and without it, and on the iPhone the
    /// lock's zone observation even when it changed no height (measured 2026-10-10).
    @MainActor
    func testASingleWindowResizeKeepsThePositionedPageAtTheTop() async throws {
        for presentation in [ReaderListHost.Presentation.root, .buildingScreenAbove] {
            for widens in [true, false] {
                let host = try ReaderListHost(resumePage: 4, presentation: presentation)
                defer { host.dismiss() }
                host.loads.loaded = Set(1...host.pageCount)
                let step = "\(presentation), \(widens ? "widened" : "narrowed")"
                try await expectAtTop(page: 4, in: host, "\(step), resumed")
                host.model.update(.new(index: 6))
                try await expectAtTop(page: 7, in: host, "\(step), jumped")
                try await expectAtTopInEveryFrame(page: 7, in: host, step) {
                    host.resizeWidth(widens: widens)
                }
            }
        }
    }

    /// A page kept at its height through a window resize takes its new size once its top is on screen, and the pages
    /// below follow it.
    ///
    /// The scrolls are `setContentOffset` calls, which the list's position does not follow (measured 2026-10-11), so
    /// the position keeps naming page 7 and page 6 releases through its zone, never by the position naming it.
    @MainActor
    func testAPageKeptThroughAResizeTakesItsNewSizeOnceItsTopIsOnScreen() async throws {
        for widens in [true, false] {
            let host = try ReaderListHost(resumePage: 4)
            defer { host.dismiss() }
            host.loads.loaded = Set(1...host.pageCount)
            let step = widens ? "widened" : "narrowed"
            try await expectAtTop(page: 4, in: host, "\(step), resumed")
            host.model.update(.new(index: 6))
            try await expectAtTop(page: 7, in: host, "\(step), jumped")
            host.resizeWidth(widens: widens)
            let resized = try await host.settle()
            let scrollView = try XCTUnwrap(HostedHierarchy.verticalScrollHost(in: host.window))
            let pageSixTop = try XCTUnwrap(resized.frames[6]).minY
            scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y + pageSixTop - 10), animated: true)
            let released = try await host.settle()
            // Once released, page 6 can be taller than the screen and push page 7 past the pages the stack keeps
            // built, which leaves page 7's last frame stale, so page 7 is brought on screen before they are compared.
            let pageSixBottom = try XCTUnwrap(released.frames[6]).maxY
            scrollView.setContentOffset(
                CGPoint(x: 0, y: scrollView.contentOffset.y + pageSixBottom - 300), animated: true
            )
            expectOwnSize(page: 6, in: try await host.settle(), of: host, "\(step), page 7's top on screen")
        }
    }

    /// Loaded pages here are landscape spreads, so a later page sits under the screen center after each jump: the
    /// jump must still name its own page.
    @MainActor
    func testJumpPutsItsPageAtTheTopAndKeepsItsPageNumber() async throws {
        let host = try ReaderListHost(resumePage: 4, imageAspectRatio: 2)
        defer { host.dismiss() }
        host.loads.loaded = Set(1...host.pageCount)
        try await expectAtTop(page: 4, in: host, "resumed")
        host.model.update(.new(index: 9))
        try await expectAtTop(page: 10, in: host, "jumped forward")
        host.model.update(.new(index: 2))
        try await expectAtTop(page: 3, in: host, "jumped back")
    }

    @MainActor
    func testJumpKeepsItsPageAtTheTopWhateverOrderPagesLoad() async throws {
        var settledTopPixels = [[Int]: CGFloat?]()
        for order in [[9, 10, 11], [10, 11, 9], [11, 9, 10]] {
            let host = try ReaderListHost(resumePage: 4)
            defer { host.dismiss() }
            try await expectAtTop(page: 4, in: host, "order \(order), resumed")
            host.model.update(.new(index: 9))
            try await expectAtTop(page: 10, in: host, "order \(order), jumped")
            for page in order {
                host.loads.loaded.insert(page)
                settledTopPixels[order] = try await expectAtTop(page: 10, in: host, "order \(order), \(page) loaded")
                    .map(host.pixel(of:))
            }
        }
        expectSameTop(settledTopPixels, "jump")
    }

    /// The last page cannot reach the top, so the list stops at its end with the whole page on screen, and the page
    /// stays the one jumped to.
    @MainActor
    func testJumpToTheLastPageEndsTheListAtTheScreenBottom() async throws {
        let host = try ReaderListHost(resumePage: 4)
        defer { host.dismiss() }
        host.loads.loaded = Set(1...host.pageCount)
        try await expectAtTop(page: 4, in: host, "resumed")
        host.model.update(.new(index: host.pageCount - 1))
        let layout = try await host.settle()
        let lastPage = try XCTUnwrap(layout.frames[host.pageCount])
        expectNoDifference(layout.contentOffset.map(host.pixel(of:)), layout.endOffset.map(host.pixel(of:)))
        XCTAssertGreaterThan(host.pixel(of: lastPage.minY), 0)
        XCTAssertLessThanOrEqual(host.pixel(of: lastPage.maxY), host.pixel(of: host.window.bounds.height))
        expectNoDifference(layout.pageIndex + 1, host.pageCount)
    }

    /// Settles `host`, then expects `page` at the top of the window and named by the model, with the scroll offset
    /// on the pixel grid, and returns the page's top in points as laid out.
    @MainActor
    @discardableResult
    private func expectAtTop(
        page: Int, in host: ReaderListHost, _ step: String,
        fileID: StaticString = #fileID, filePath: StaticString = #filePath, line: UInt = #line, column: UInt = #column
    ) async throws -> CGFloat? {
        let layout = try await host.settle()
        let top = layout.frames[page]?.minY
        expectNoDifference(
            Placement(topPixel: top.map(host.pixel(of:)), page: layout.pageIndex + 1),
            Placement(topPixel: 0, page: page), step,
            fileID: fileID, filePath: filePath, line: line, column: column
        )
        if let offset = layout.contentOffset {
            let pixels = offset * host.window.traitCollection.displayScale
            expectNoDifference(
                pixels.rounded(), pixels, "\(step), scroll offset", fileID: fileID, filePath: filePath, line: line,
                column: column
            )
        }
        return top
    }

    /// Applies `change`, then expects `page` at the top as `expectAtTop` does, and also in every frame drawn from the
    /// change until the layout settles.
    @MainActor
    @discardableResult
    private func expectAtTopInEveryFrame(
        page: Int, in host: ReaderListHost, _ step: String,
        fileID: StaticString = #fileID, filePath: StaticString = #filePath, line: UInt = #line, column: UInt = #column,
        while change: () -> Void
    ) async throws -> CGFloat? {
        let frames = FrameSampler(sample: { host.loads.frames[page].map({ host.pixel(of: $0.minY) }) })
        frames.start()
        change()
        let top = try await expectAtTop(
            page: page, in: host, step, fileID: fileID, filePath: filePath, line: line, column: column
        )
        frames.stop()
        expectNoDifference(
            frames.drawnValues, [0], "\(step), drawn frames", fileID: fileID, filePath: filePath, line: line,
            column: column
        )
        return top
    }

    /// Expects loaded `page` at its own size, across the full width rather than fitted into a height the list kept,
    /// with the next page right below it. The divider is expected to be zero.
    @MainActor
    private func expectOwnSize(
        page: Int, in layout: ListLayout, of host: ReaderListHost, _ step: String,
        fileID: StaticString = #fileID, filePath: StaticString = #filePath, line: UInt = #line, column: UInt = #column
    ) {
        expectNoDifference(
            layout.frames[page].map({ host.pixel(of: $0.width) }), host.pixel(of: host.window.bounds.width),
            "\(step), page \(page) across the full width", fileID: fileID, filePath: filePath, line: line,
            column: column
        )
        expectNoDifference(
            layout.frames[page + 1].map({ host.pixel(of: $0.minY) }),
            layout.frames[page].map({ host.pixel(of: $0.maxY) }),
            "\(step), page \(page + 1) right below page \(page)", fileID: fileID, filePath: filePath, line: line,
            column: column
        )
    }

    /// Expects the same settled top, as a pixel row, after every load order.
    private func expectSameTop(
        _ settledTopPixels: [[Int]: CGFloat?], _ step: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(Set(settledTopPixels.values).count, 1, "\(step): \(settledTopPixels)", file: file, line: line)
    }
}

/// The pixel row a page's top edge is drawn on, counted from the window's top, and the page the model names,
/// one-based like the page labels.
///
/// The scroll view moves on the pixel grid while the lazy stack lays pages out at fractional points (fractional page
/// heights, averaged estimates for the pages it has not built), so a page aligned to the top lies as laid out from
/// half a pixel above it to less than half a pixel below it, give or take a rounding error where a pixel is no binary
/// fraction of a point; `expectAtTop` checks the offset's side of that.
private struct Placement: Equatable {
    let topPixel: CGFloat?
    let page: Int
}

/// Each page's last reported frame in the window, the scroll offsets and the model's page index, sampled together.
private struct ListLayout: Equatable {
    let frames: [Int: CGRect]
    let contentOffset: CGFloat?
    /// The offset at which the end of the content meets the bottom of the scroll view.
    let endOffset: CGFloat?
    let pageIndex: Int

    @MainActor
    init(frames: [Int: CGRect], scrollView: UIScrollView?, pageIndex: Int) {
        self.frames = frames
        contentOffset = scrollView?.contentOffset.y
        endOffset = scrollView.map({ $0.contentSize.height + $0.adjustedContentInset.bottom - $0.bounds.height })
        self.pageIndex = pageIndex
    }
}

@MainActor
@Observable
private final class PageLoads {
    var loaded = Set<Int>()
    /// Width over height of every loaded page's image.
    let imageAspectRatio: CGFloat
    /// The last frame each page's content reported; a page the lazy stack removed keeps its last frame.
    @ObservationIgnored var frames = [Int: CGRect]()

    init(imageAspectRatio: CGFloat) {
        self.imageAspectRatio = imageAspectRatio
    }
}

/// Sizes as the reader's image container does in the vertical reader once the page's image URL is known: the
/// placeholder fitted the way the image view fits it, or the image at its aspect ratio across the full width.
///
/// The frame it reports is its content's, inside the list's row: a page the list keeps at an older height reports
/// its top, which the row aligns its content to, and its content's own height.
private struct PageRow: View {
    let page: Int
    let loads: PageLoads

    var body: some View {
        content
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { loads.frames[page] = $0 })
    }

    @ViewBuilder private var content: some View {
        if loads.loaded.contains(page) {
            Color.gray
                .aspectRatio(loads.imageAspectRatio, contentMode: .fit)
        } else {
            Color.gray
                .containerRelativeFrame([.horizontal, .vertical])
                .aspectRatio(Defaults.ImageSize.contentAspect, contentMode: .fit)
                .scaledToFit()
        }
    }
}

@MainActor
@Observable
private final class CoverPresenter {
    var isPresented = false
}

/// Presents `reader` the way the gallery detail presents the reader.
private struct PresentedReader<Reader: View>: View {
    let presenter: CoverPresenter
    let reader: Reader

    var body: some View {
        @Bindable var presenter = presenter
        Color.clear
            .fullScreenCover(isPresented: $presenter.isPresented) {
                NavigationStack {
                    VStack {
                        reader
                    }
                    .ignoresSafeArea()
                    .toolbarVisibility(.hidden, for: .navigationBar)
                    .toolbarVisibility(.hidden, for: .statusBar)
                }
            }
    }
}

@MainActor
@Observable
private final class ScreenAbove {
    var height: CGFloat

    init(height: CGFloat) {
        self.height = height
    }
}

/// Extends `list` `screenAbove.height` above its frame, under a top safe-area inset of that height.
private struct ScreenAboveBuilder<List: View>: View {
    let screenAbove: ScreenAbove
    let list: List

    var body: some View {
        list
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: screenAbove.height) }
            .padding(.top, -screenAbove.height)
            .ignoresSafeArea()
    }
}

/// The reader's vertical list in a full-screen window of the host app's scene, laid out under the safe area as the
/// reader lays it out.
@MainActor
private final class ReaderListHost {
    enum Presentation {
        /// The list is the window's root.
        case root
        /// The list is presented full screen inside a navigation stack, as the reader is.
        case fullScreenCover
        /// The list reaches one screen above the window, under a top safe-area inset of that height, so the lazy
        /// stack builds the pages in that screen while the window shows what the root list shows.
        case buildingScreenAbove
        /// As `buildingScreenAbove`, but the list reaches above the window only once `buildScreenAbove()` is called.
        case buildingScreenAboveLater
    }

    /// A portrait page, 1280 by 1791 pixels.
    static let portraitAspectRatio: CGFloat = 1280 / 1791

    let pageCount: Int
    let loads: PageLoads
    let model: PageModel
    let window: UIWindow
    private let screenAbove: ScreenAbove
    private let previousKeyWindow: UIWindow?

    /// `heightScale` presents the window at that share of the screen's height; `growToFullHeight()` grows it.
    init(
        resumePage: Int, pageCount: Int = 20, spacing: CGFloat = 0, imageAspectRatio: CGFloat = portraitAspectRatio,
        heightScale: CGFloat = 1, presentation: Presentation = .root
    ) throws {
        let scene = try Self.activeScene()
        let loads = PageLoads(imageAspectRatio: imageAspectRatio)
        let model = PageModel(index: resumePage - 1)
        let screen = scene.screen.bounds
        let screenAbove = ScreenAbove(height: presentation == .buildingScreenAbove ? screen.height : 0)
        self.pageCount = pageCount
        self.loads = loads
        self.model = model
        self.screenAbove = screenAbove
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        let list = AdvancedList(
            page: model, data: Array(1...pageCount), id: \.self, spacing: spacing, gesture: TapGesture()
        ) { page in
            PageRow(page: page, loads: loads)
        }
        let presenter = CoverPresenter()
        window.rootViewController = switch presentation {
        case .root:
            UIHostingController(rootView: AnyView(list.ignoresSafeArea()))
        case .fullScreenCover:
            UIHostingController(rootView: AnyView(PresentedReader(presenter: presenter, reader: list)))
        case .buildingScreenAbove, .buildingScreenAboveLater:
            UIHostingController(rootView: AnyView(ScreenAboveBuilder(screenAbove: screenAbove, list: list)))
        }
        window.frame = CGRect(x: 0, y: 0, width: screen.width, height: (screen.height * heightScale).rounded())
        window.makeKeyAndVisible()
        presenter.isPresented = presentation == .fullScreenCover
    }

    /// The host app's foreground scene, which the window is shown in.
    static func activeScene() throws -> UIWindowScene {
        try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        )
    }

    /// The pixel row `points` falls on at the window's display scale, half a pixel between two rows going to the row
    /// below it as the scroll view and the renderer round it.
    func pixel(of points: CGFloat) -> CGFloat {
        (points * window.traitCollection.displayScale + 0.5).rounded(.down)
    }

    func buildScreenAbove() {
        screenAbove.height = window.windowScene?.screen.bounds.height ?? 0
    }

    func growToFullHeight() {
        window.frame = window.windowScene?.screen.bounds ?? window.frame
    }

    /// Changes the window's width by the screen's height over its width, as turning portrait to landscape changes it,
    /// or by the inverse, keeping its height.
    func resizeWidth(widens: Bool) {
        let screen = window.windowScene?.screen.bounds.size ?? window.bounds.size
        let ratio = widens ? screen.height / screen.width : screen.width / screen.height
        window.frame.size.width = (window.frame.width * ratio).rounded()
    }

    /// Samples the layout until it holds still for the settlement's stable span, so a page that moves only once
    /// a load lays out is caught rather than read before it moves.
    func settle() async throws -> ListLayout {
        try await RenderSettlement.settle(
            clock: ContinuousClock(), failure: .renderDidNotSettle, key: { $0 }, nextFrame: {}
        ) { _ in
            ListLayout(
                frames: loads.frames,
                scrollView: HostedHierarchy.verticalScrollHost(in: window),
                pageIndex: model.index
            )
        }
        .value
    }

    func dismiss() {
        window.rootViewController?.dismiss(animated: false)
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }
}

/// Samples a value once per display frame, before the frame is drawn, so each sample sees the layout the previous
/// frame drew. Passing is strong evidence that no frame showed another value; a sampler cannot prove the frames it
/// did not see.
@MainActor
private final class FrameSampler: NSObject {
    private let sample: () -> CGFloat?
    private var link: CADisplayLink?
    private var samples = [CGFloat?]()

    /// The sampled values in the order the frames showed them, each run of identical samples once.
    var drawnValues: [CGFloat?] {
        samples.reduce(into: [CGFloat?]()) { values, value in
            if values.last != value {
                values.append(value)
            }
        }
    }

    init(sample: @escaping () -> CGFloat?) {
        self.sample = sample
    }

    func start() {
        let link = CADisplayLink(target: self, selector: #selector(sampleFrame))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func sampleFrame() {
        samples.append(sample())
    }
}
