public import SwiftUI
public import UIKit

/// The height of the window one coordinate's picture is taken in, and how to hold the page's own viewport while that
/// window is taller than the screen (19-19, design section 2).
public struct CaptureHeight: Sendable {
    /// The committed page height, in points. The matrix reads it from the scenario's source and never changes it
    /// at run time.
    public let points: CGFloat
    /// Freezes (`true`) or releases (`false`) the page's viewport sampling (`VisibleViewportSampling`), so views that
    /// size themselves from their own measured viewport keep the native measurement while the window is taller.
    public let freezeViewport: @MainActor @Sendable (Bool) -> Void

    public init(points: CGFloat, freezeViewport: @escaping @MainActor @Sendable (Bool) -> Void) {
        self.points = points
        self.freezeViewport = freezeViewport
    }
}

/// The status bar companion window: it holds the status bar state measured while a window was screen-sized for as
/// long as a window taller than the screen is up.
///
/// UIKit lets only a window that covers the whole screen drive the status bar. Once the key window grows
/// past the screen it loses that role and the status bar reappears (measured 2026-10-03: hidden -> visible,
/// status bar frame 54 pt on the phone / 32 pt on the iPad, iPad safe-area top 0 -> 32), and the soft
/// scroll-edge effect renders under it. A full-screen companion window therefore owns the status bar state
/// while the capture window is tall, so that window keeps the viewport's status bar, safe area and edge
/// effect. It mirrors the state measured at viewport size rather than hard-coding hidden, which keeps
/// screens with a visible status bar unchanged.
@MainActor
final class StatusBarCompanion {
    private let window: UIWindow

    init(scene: UIWindowScene, hidesStatusBar: Bool) {
        let companion = UIWindow(windowScene: scene)
        companion.rootViewController = StatusBarAppearanceController(hidesStatusBar: hidesStatusBar)
        // At `.normal`, created after the capture window, so it is the topmost full-screen window: the host app's
        // own full-screen main window is also at `.normal` with a visible status bar, and a companion below it
        // (`.normal - 1`) never takes over the status bar (measured 2026-10-03). It is never made key; the capture
        // window stays key, and a clear, non-key companion in front of it does not affect the replicant reads,
        // which draw the captured hierarchy itself.
        companion.windowLevel = .normal
        companion.isHidden = false
        window = companion
    }

    /// Takes the companion down; at viewport size the capture window covers the screen and drives the status bar
    /// again.
    func remove() {
        window.isHidden = true
        window.rootViewController = nil
    }
}

/// Root of the status bar companion window: it exists only to state the status bar visibility measured while
/// the capture window was viewport-sized.
///
/// UIKit lets only a window covering the whole screen drive the status bar, so a capture window grown past the
/// screen cannot keep it hidden (measured 2026-10-03: the status bar reappears, 54 pt on the phone and 32 pt on
/// the iPad, and the iPad safe-area top goes 0 -> 32). A clear, full-screen, non-key window above the host app's
/// own main window, whose root prefers the measured visibility, restores the viewport's status bar state; with it
/// the tall window's top crop matched the viewport reference pixel for pixel on both devices. Placed below the
/// host app's main window, it lost to that window's visible status bar (measured 2026-10-03).
private final class StatusBarAppearanceController: UIViewController {
    let hidesStatusBar: Bool

    init(hidesStatusBar: Bool) {
        self.hidesStatusBar = hidesStatusBar
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var prefersStatusBarHidden: Bool { hidesStatusBar }

    override func loadView() {
        let view = UIView()
        view.backgroundColor = .clear
        self.view = view
    }
}

/// What a hosted page needs: the window height that covers it, and the scroll view that sets it.
struct PageNeed {
    /// The window height the page needs, in whole points.
    let points: CGFloat
    /// The visible, scrolling scroll view with the largest overflow, or `nil` when the page fits its window.
    let scrollView: UIScrollView?
}

extension HostedHierarchy {
    /// The window height the page needs, in whole points: the window's height plus the largest vertical overflow
    /// of a scroll view the user could see and scroll.
    ///
    /// A scroll view counts when it scrolls, is neither hidden nor (nearly) transparent in itself or any ancestor up
    /// to the window, and its frame in window coordinates meets the window's bounds. Its overflow is its content
    /// with the adjusted insets above and below, less its own height, and it counts only from one device pixel on.
    /// The sum is read in device pixels before it is rounded up, so that a page whose layout lands exactly on a
    /// whole point is not pushed to the next one by floating-point noise.
    static func pageNeed(in window: UIWindow) -> PageNeed {
        let scale = window.screen.scale
        var largest: CGFloat = 0
        var widest: UIScrollView?
        for view in descendants(of: window) {
            guard let scrollView = view as? UIScrollView, isVisibleAndScrolling(scrollView, in: window) else {
                continue
            }
            let insets = scrollView.adjustedContentInset
            let overflow = scrollView.contentSize.height + insets.top + insets.bottom - scrollView.bounds.height
            if overflow >= 1 / scale, overflow > largest {
                largest = overflow
                widest = scrollView
            }
        }
        return PageNeed(points: ceil(((window.bounds.height + largest) * scale).rounded() / scale), scrollView: widest)
    }

    private static func isVisibleAndScrolling(_ scrollView: UIScrollView, in window: UIWindow) -> Bool {
        guard scrollView.isScrollEnabled else { return false }
        var view: UIView? = scrollView
        while let current = view, current !== window {
            if current.isHidden || current.alpha < 0.01 { return false }
            view = current.superview
        }
        return scrollView.convert(scrollView.bounds, to: window).intersects(window.bounds)
    }
}

/// A hosted window grown past the screen: its size classes pinned to the scene's, and the status bar companion up,
/// until ``restore()``.
///
/// The window keeps the viewport's top, left and right safe area and its size classes while it is taller
/// (``holdsViewportGeometry()``). The caller holds the viewport sampling frozen for as long as the window is grown.
@MainActor
final class GrownWindow {
    private let window: UIWindow
    private let nativeFrame: CGRect
    private let pinnedInsets: UIEdgeInsets
    private let sceneClasses: UITraitCollection
    private let companion: StatusBarCompanion

    init(window: UIWindow, scene: UIWindowScene) {
        self.window = window
        nativeFrame = window.frame
        pinnedInsets = window.safeAreaInsets
        sceneClasses = scene.traitCollection
        companion = StatusBarCompanion(
            scene: scene, hidesStatusBar: scene.statusBarManager?.isStatusBarHidden ?? false
        )
        window.traitOverrides.horizontalSizeClass = sceneClasses.horizontalSizeClass
        window.traitOverrides.verticalSizeClass = sceneClasses.verticalSizeClass
    }

    /// Resizes the window to the scene's width and `points`, and lays it out.
    func resize(to points: CGFloat) {
        window.frame = CGRect(origin: nativeFrame.origin, size: CGSize(width: nativeFrame.width, height: points))
        window.rootViewController?.view.frame = window.bounds
        window.layoutIfNeeded()
    }

    /// Whether the grown window still has the viewport's top, left and right safe area and its size classes.
    func holdsViewportGeometry() -> Bool {
        let insets = window.safeAreaInsets
        return insets.top == pinnedInsets.top && insets.left == pinnedInsets.left
            && insets.right == pinnedInsets.right
            && window.traitCollection.horizontalSizeClass == sceneClasses.horizontalSizeClass
            && window.traitCollection.verticalSizeClass == sceneClasses.verticalSizeClass
    }

    /// Puts the window back at its native size, releases the size class pins and takes the companion down.
    func restore() {
        window.frame = nativeFrame
        window.rootViewController?.view.frame = window.bounds
        window.traitOverrides.remove(UITraitHorizontalSizeClass.self)
        window.traitOverrides.remove(UITraitVerticalSizeClass.self)
        companion.remove()
    }
}

/// What hosting a page at native size and freezing its viewport sampling came to.
enum FrozenRead {
    /// Native and frozen reads both settled and are byte for byte the same; carries the frozen settle.
    case matched(SettleResult)
    /// A read never settled.
    case unsettled(SettleResult)
    /// The frozen read differs from the native one, so a view sized itself from its own viewport; carries the
    /// frozen settle and picture.
    case changed(SettleResult, UIImage)
}

/// How a measuring run ended for one coordinate (19-20, design section 3).
public struct PageMeasurement: Equatable, Sendable {
    /// `measured`, `cannotCover`, `didNotConverge` or `error`.
    public let status: SnapshotHeightStatus
    /// The whole-point window height that covers the page (`measured`), or the last need seen; `nil` when the
    /// measurement ended before there was one.
    public let neededPoints: Int?
    /// The window's own height.
    public let screenPoints: Int
    /// How many times the window was grown.
    public let steps: Int
    /// A fixed code, never page text.
    public let reason: String?

    public init(status: SnapshotHeightStatus, neededPoints: Int?, screenPoints: Int, steps: Int, reason: String?) {
        self.status = status
        self.neededPoints = neededPoints
        self.screenPoints = screenPoints
        self.steps = steps
        self.reason = reason
    }
}

extension HostedWindowCapture {
    /// The most times the window is grown to its need before the measurement gives up: the full-content host's
    /// bound.
    public static let maximumGrowthSteps = 12

    /// Settles the hosted page at native size and freezes its viewport sampling, as the tall window's attempt does:
    /// the frozen read must be byte for byte the native one.
    static func freezeAtNativeSize(
        _ window: UIWindow, minimumReads: Int, freeze: @MainActor (Bool) -> Void
    ) async -> FrozenRead {
        let native = await settleRead(window, minimumReads: minimumReads)
        guard case .settled = native.result, let nativeImage = native.image else {
            return .unsettled(native.result)
        }
        freeze(true)
        let frozen = await settleRead(window, minimumReads: minimumReads)
        guard case .settled = frozen.result, let frozenImage = frozen.image else {
            return .unsettled(frozen.result)
        }
        guard let nativeBytes = comparedBytes(nativeImage), nativeBytes == comparedBytes(frozenImage) else {
            return .changed(frozen.result, frozenImage)
        }
        return .matched(frozen.result)
    }

    /// Finds the window height the hosted page needs, without taking a picture.
    ///
    /// The page is hosted at native size, settled, and its viewport sampling frozen and verified as the tall window
    /// does; the status bar companion and size class pins go up, `interact` runs and the window settles again. Then,
    /// while the page needs more than the window has (``HostedHierarchy/pageNeed(in:)``), the window is set to that
    /// need, laid out and settled again (at most ``maximumGrowthSteps`` times), and the new need is read. The result
    /// is `measured` once two consecutive reads give the same whole-point need. If the most-overflowing scroll view
    /// grew by less than the window did, less one device pixel, no window height covers it (`cannotCover`, reason
    /// `cannot-cover:<class>`); if the need still moves after the last step, `didNotConverge`. Nothing is written
    /// and the window and viewport sampling are restored on every exit.
    ///
    /// A page that fits the screen is `measured` at the screen height in no steps.
    public static func measure(
        make: () throws -> AnyView, window: UIWindow, style: UIUserInterfaceStyle,
        interact: (@MainActor (UIWindow) async throws -> Void)? = nil, minimumReads: Int = minimumReads,
        freezeViewport: @escaping @MainActor @Sendable (Bool) -> Void
    ) async -> PageMeasurement {
        let screen = Int(window.bounds.height.rounded())
        let root: AnyView
        do {
            root = try make()
        } catch {
            return PageMeasurement(status: .error, neededPoints: nil, screenPoints: screen, steps: 0, reason: "factory")
        }
        let hosted = host(root, in: window, style: style)
        let measurement = await measureHosted(
            window: window, interact: interact, minimumReads: minimumReads, freezeViewport: freezeViewport
        )
        await hosted.disposeAfterDismissal()
        return measurement
    }

    private static func measureHosted(
        window: UIWindow, interact: (@MainActor (UIWindow) async throws -> Void)?, minimumReads: Int,
        freezeViewport: @MainActor (Bool) -> Void
    ) async -> PageMeasurement {
        let nativeSize = window.bounds.size
        let screen = Int(nativeSize.height.rounded())
        func ended(_ status: SnapshotHeightStatus, need: PageNeed? = nil, steps: Int = 0, reason: String? = nil)
            -> PageMeasurement {
            PageMeasurement(
                status: status, neededPoints: need.map({ Int($0.points) }), screenPoints: screen, steps: steps,
                reason: reason
            )
        }
        guard let scene = window.windowScene else { return ended(.error, reason: tallWindowGeometryReason) }
        var grown: GrownWindow?
        defer {
            grown?.restore()
            freezeViewport(false)
            window.layoutIfNeeded()
        }
        switch await freezeAtNativeSize(window, minimumReads: minimumReads, freeze: freezeViewport) {
        case .unsettled:
            return ended(.error, reason: settleTimeoutReason)
        case .changed:
            return ended(.error, reason: freezeChangedPixelsReason)
        case .matched:
            break
        }
        let held = GrownWindow(window: window, scene: scene)
        grown = held
        if let interact {
            do {
                try await interact(window)
            } catch {
                return ended(.error, reason: "\(interactionReason):\(stepFailure(error))")
            }
        }
        do {
            guard case .settled = try await settleWindow(window, nativeSize: nativeSize, minimumReads: minimumReads)
            else { return ended(.error, reason: settleTimeoutReason) }
        } catch {
            return ended(.error, reason: "render-server:\(error)")
        }
        var previous = HostedHierarchy.pageNeed(in: window)
        guard previous.points > nativeSize.height else { return ended(.measured, need: previous) }
        let scale = window.screen.scale
        for step in 1...maximumGrowthSteps {
            let heightBefore = previous.scrollView?.bounds.height ?? 0
            let growth = previous.points - window.bounds.height
            held.resize(to: previous.points)
            do {
                guard case .settled = try await settleWindow(
                    window, nativeSize: nativeSize, minimumReads: minimumReads
                ) else { return ended(.error, need: previous, steps: step, reason: settleTimeoutReason) }
            } catch {
                return ended(.error, need: previous, steps: step, reason: "render-server:\(error)")
            }
            let need = HostedHierarchy.pageNeed(in: window)
            if need.points == previous.points { return ended(.measured, need: need, steps: step) }
            if let scrollView = previous.scrollView, scrollView.bounds.height - heightBefore < growth - 1 / scale {
                return ended(
                    .cannotCover, need: need, steps: step,
                    reason: "cannot-cover:\(String(describing: type(of: scrollView)))"
                )
            }
            previous = need
        }
        return ended(.didNotConverge, need: previous, steps: maximumGrowthSteps)
    }

    /// Settles the window as it is: on 1x reads of the window, or, above what the render server draws in one read,
    /// on the owned-row digests of reads of the native size (the rule of the tall window's attempt).
    private static func settleWindow(_ window: UIWindow, nativeSize: CGSize, minimumReads: Int) async throws
        -> SettleResult {
        guard window.bounds.height * window.screen.scale > RenderServerCapture.maximumSnapshotDimension else {
            return await settleRead(window, minimumReads: minimumReads).result
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return try await settleOwnedRows(window, viewportSize: nativeSize, format: format, minimumReads: minimumReads)
    }
}
