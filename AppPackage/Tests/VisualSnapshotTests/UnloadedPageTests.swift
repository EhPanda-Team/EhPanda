import AppFeature
import AppModels
import AppTools
import Observation
@testable import ReadingFeature
import SwiftUI
import UIKit
@testable import VisualSnapshotSupport
import XCTest

/// A reader page until its image loads (`UnloadedPage`): the frame it takes, as the image container shows it, and
/// where it shows its number and progress.
final class UnloadedPageTests: XCTestCase {
    /// The tests need no app state, but they run inside the host app, whose scene phase changes reach its download
    /// client at any time; re-preparing the inert host clients keeps such a change from failing a test.
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    /// The placeholder, the box shown while the page's image URL loads and the box shown after a load failed take one
    /// frame in the strip: its width by the pixel-aligned height of a 7:10 page. The placeholder alone off the
    /// screen's height, with the box still on it, moved the resume page under VoiceOver in 15 of 15 resumes (measured
    /// 2026-10-11).
    @MainActor
    func testEveryUnloadedStateTakesOneFrameInTheStrip() async throws {
        var sizes = [LoadingState: CGSize]()
        for state in [LoadingState.idle, .loading, .failed(.webImageFailed)] {
            let host = try PageFrameHost { recorder in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        page(state, slot: .strip)
                            .onGeometryChange(for: CGSize.self, of: \.size, action: { recorder.size = $0 })
                    }
                }
            }
            defer { host.dismiss() }
            sizes[state] = try await host.settled(\.size)
            expectStripFrame(sizes[state], in: host, "\(state)")
        }
        XCTAssertEqual(Set(sizes.values).count, 1, "\(sizes)")
    }

    /// A page the list keeps at an older height (`AboveScreenHeightLock`) offers the page that height, and a probe of
    /// its ideal height offers the strip's width alone; the page keeps its frame under both, and the kept height clips
    /// it. A probe that offers no width, which the strip never makes (see `StripPageLayout`), has no page size to
    /// answer with.
    @MainActor
    func testAnUnloadedPageKeepsItsFrameUnderAKeptHeightAndAProbe() async throws {
        let kept = try PageFrameHost { recorder in
            ScrollView {
                LazyVStack(spacing: 0) {
                    page(.idle, slot: .strip)
                        .onGeometryChange(for: CGSize.self, of: \.size, action: { recorder.size = $0 })
                        .frame(height: 300, alignment: .top)
                        .clipped()
                }
            }
        }
        defer { kept.dismiss() }
        expectStripFrame(try await kept.settled(\.size), in: kept, "under a kept height")
        let probed = try PageFrameHost { recorder in
            ScrollView {
                LazyVStack(spacing: 0) {
                    page(.idle, slot: .strip)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGSize.self, of: \.size, action: { recorder.size = $0 })
                }
            }
        }
        defer { probed.dismiss() }
        expectStripFrame(try await probed.settled(\.size), in: probed, "probed for its ideal height")
    }

    /// In the pager an unloaded page takes its whole cell, the frame its container gives, half of it in a dual-page
    /// spread.
    @MainActor
    func testAnUnloadedPageTakesItsCellInThePager() async throws {
        for isDualPage in [false, true] {
            let host = try PageFrameHost { recorder in
                ZStack {
                    Color.clear
                        .containerRelativeFrame([.horizontal, .vertical])
                        .onGeometryChange(for: CGSize.self, of: \.size, action: { recorder.cell = $0 })
                    page(.idle, slot: .pager(isDualPage: isDualPage))
                        .onGeometryChange(for: CGSize.self, of: \.size, action: { recorder.size = $0 })
                }
            }
            defer { host.dismiss() }
            let size = try await host.settled(\.size)
            let cell = try XCTUnwrap(host.recorder.cell)
            XCTAssertEqual(
                size, CGSize(width: cell.width / (isDualPage ? 2 : 1), height: cell.height),
                isDualPage ? "dual-page" : "single page"
            )
        }
    }

    /// A strip page centers its content in its first screen: the part of the page from its top as tall as the screen
    /// while the screen is shorter than the page, as a landscape screen is, and the whole page once the screen is
    /// taller. The screen's height moves the content alone: the reader grows while it is presented, and the page keeps
    /// its frame through the growth, which the resume position depends on (`UnloadedPageFrame`).
    @MainActor
    func testAStripPageCentersItsContentInItsFirstScreen() async throws {
        let scene = try PageFrameHost.activeScene()
        // A window as tall as it is wide is shorter than any 7:10 page across its width.
        let host = try PageFrameHost(height: scene.screen.bounds.width) { recorder in
            ScrollView {
                LazyVStack(spacing: 0) {
                    UnloadedPage(slot: .strip, backgroundColor: .gray) {
                        contentMarker(recorder)
                    }
                    .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { recorder.page = $0 })
                }
            }
        }
        defer { host.dismiss() }
        let short = try await host.settled(\.placement)
        let shortScreen = host.window.bounds.height
        XCTAssertLessThan(shortScreen, short.page.height, "the short window is shorter than the page")
        expectContent(of: short, centeredAt: shortScreen / 2, in: host, "under a screen shorter than the page")

        host.growToFullHeight()
        let full = try await host.settled(\.placement)
        XCTAssertGreaterThan(host.window.bounds.height, full.page.height, "the full window is taller than the page")
        expectContent(of: full, centeredAt: full.page.height / 2, in: host, "under a screen taller than the page")
        XCTAssertEqual(full.page.size, short.page.size, "the page keeps its frame as the screen grows")
    }

    /// In the pager a page is its cell, so its content is centered on the page, on its own and in a dual-page spread.
    @MainActor
    func testAPagerPageCentersItsContent() async throws {
        for isDualPage in [false, true] {
            let host = try PageFrameHost { recorder in
                UnloadedPage(slot: .pager(isDualPage: isDualPage), backgroundColor: .gray) {
                    contentMarker(recorder)
                }
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { recorder.page = $0 })
            }
            defer { host.dismiss() }
            let placement = try await host.settled(\.placement)
            expectContent(
                of: placement, centeredAt: placement.page.height / 2, in: host,
                isDualPage ? "dual-page" : "single page"
            )
            XCTAssertEqual(
                placement.content.midX - placement.page.minX, placement.page.width / 2,
                accuracy: halfPixel(in: host), isDualPage ? "dual-page, across" : "single page, across"
            )
        }
    }

    @MainActor
    private func page(_ loadingState: LoadingState, slot: PageSlot) -> ImageContainer {
        ImageContainer(
            index: 1, imageURL: nil, loadingState: loadingState, slot: slot, isActive: true, backgroundColor: .gray,
            enablesLiveText: false, liveTextGroups: [], focusedLiveTextGroup: nil, liveTextTapAction: { _ in },
            refetchAction: { _ in }, loadRetryAction: { _ in }, loadSucceededAction: { _ in },
            loadFailedAction: { _ in }
        )
    }

    /// Content of a fixed size that reports where the page draws it.
    @MainActor
    private func contentMarker(_ recorder: FrameRecorder) -> some View {
        Color.black
            .frame(width: 10, height: 10)
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { recorder.content = $0 })
    }

    /// Expects `size` to be the strip's width by the height of a 7:10 page at that width, on the pixel grid: a whole
    /// number of pixels within half a pixel of the exact height. A thousandth of a pixel covers the binary
    /// representation of a third of a point.
    @MainActor
    private func expectStripFrame(
        _ size: CGSize?, in host: PageFrameHost, _ step: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let width = host.window.bounds.width
        let scale = host.window.traitCollection.displayScale
        XCTAssertEqual(size?.width, width, "\(step), width", file: file, line: line)
        let pixels = (size?.height ?? 0) * scale
        let exactPixels = width / Defaults.ImageSize.contentAspect * scale
        XCTAssertLessThan(
            abs(pixels - pixels.rounded()), 0.001, "\(step), height on the pixel grid", file: file, line: line
        )
        XCTAssertLessThanOrEqual(
            abs(pixels - exactPixels), 0.5, "\(step), height of a 7:10 page", file: file, line: line
        )
    }

    /// Expects the content's center to lie `offset` below the page's top. SwiftUI draws a view's edges on the pixel
    /// grid, so the center lies within half a pixel of the exact one.
    @MainActor
    private func expectContent(
        of placement: Placement, centeredAt offset: CGFloat, in host: PageFrameHost, _ step: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(
            placement.content.midY - placement.page.minY, offset, accuracy: halfPixel(in: host), step,
            file: file, line: line
        )
    }

    @MainActor
    private func halfPixel(in host: PageFrameHost) -> CGFloat {
        0.5 / host.window.traitCollection.displayScale
    }
}

/// Where a page lies, and where it draws its content, in the window.
private struct Placement: Equatable {
    let page: CGRect
    let content: CGRect
}

@MainActor
@Observable
private final class FrameRecorder {
    var size: CGSize?
    /// The frame a container-relative view takes beside the page, for the pager's cell.
    var cell: CGSize?
    var page: CGRect?
    var content: CGRect?

    var placement: Placement? {
        guard let page, let content else { return nil }
        return Placement(page: page, content: content)
    }
}

/// A view in a full-screen window of the host app's scene, laid out under the safe area as the reader lays out.
@MainActor
private final class PageFrameHost {
    let window: UIWindow
    let recorder = FrameRecorder()
    private let previousKeyWindow: UIWindow?

    /// Shows `content` in a window as wide as the screen and `height` tall, the screen's height by default.
    init<Content: View>(height: CGFloat? = nil, @ContentBuilder content: (FrameRecorder) -> Content) throws {
        let scene = try Self.activeScene()
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: content(recorder).ignoresSafeArea())
        window.frame = CGRect(
            origin: .zero,
            size: CGSize(width: scene.screen.bounds.width, height: height ?? scene.screen.bounds.height)
        )
        window.makeKeyAndVisible()
    }

    /// The host app's foreground scene, which the window is shown in.
    static func activeScene() throws -> UIWindowScene {
        try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        )
    }

    /// The value the recorder last holds at `keyPath` once it holds still.
    func settled<Value: Equatable>(_ keyPath: KeyPath<FrameRecorder, Value?>) async throws -> Value {
        try await RenderSettlement.settle(
            clock: ContinuousClock(), failure: .renderDidNotSettle, key: { $0 }, nextFrame: {}
        ) { _ in
            recorder[keyPath: keyPath]
        }
        .value
    }

    /// Grows the window to the screen's height, as the reader grows while it is presented.
    func growToFullHeight() {
        window.frame = window.windowScene?.screen.bounds ?? window.frame
    }

    func dismiss() {
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }
}
