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

extension HostedHierarchy {
    /// The window height the page needs, in whole points: the window's height plus the largest vertical overflow
    /// of a scroll view the user could see and scroll.
    ///
    /// A scroll view counts when it scrolls, is neither hidden nor (nearly) transparent in itself or any ancestor up
    /// to the window, and its frame in window coordinates meets the window's bounds. Its overflow is its content
    /// with the adjusted insets above and below, less its own height, and it counts only from one device pixel on.
    /// The sum is read in device pixels before it is rounded up, so that a page whose layout lands exactly on a
    /// whole point is not pushed to the next one by floating-point noise.
    static func pageNeed(in window: UIWindow) -> CGFloat {
        let scale = window.screen.scale
        var largest: CGFloat = 0
        for view in descendants(of: window) {
            guard let scrollView = view as? UIScrollView, isVisibleAndScrolling(scrollView, in: window) else {
                continue
            }
            let insets = scrollView.adjustedContentInset
            let overflow = scrollView.contentSize.height + insets.top + insets.bottom - scrollView.bounds.height
            if overflow >= 1 / scale {
                largest = max(largest, overflow)
            }
        }
        return ceil(((window.bounds.height + largest) * scale).rounded() / scale)
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
