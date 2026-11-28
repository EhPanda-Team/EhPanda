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
    /// The top, in screen coordinates, of a keyboard that is up by the steps' own rule, else `nil` (the matrix supplies
    /// it, as it supplies ``freezeViewport``). A classification, never an adjustment: the check and the measuring mode
    /// use it only to name a page whose scroll view avoids that keyboard (`cannot-cover:keyboard`, 19-30).
    public let keyboardTop: @MainActor @Sendable (UIWindow) -> CGFloat?
    /// The source rect, in window coordinates, of a popover that is presented as a popover and not adapted, else
    /// `nil` (the matrix supplies it: ``HostedWindowCapture/presentedPopoverSource(in:)``). A classification, never an
    /// adjustment: the check and the measuring mode use it only to name a page whose popover's source lies outside
    /// the scene (`cannot-cover:popover`, 19-30).
    public let popoverSource: @MainActor @Sendable (UIWindow) -> CGRect?

    public init(
        points: CGFloat, freezeViewport: @escaping @MainActor @Sendable (Bool) -> Void,
        keyboardTop: @escaping @MainActor @Sendable (UIWindow) -> CGFloat?,
        popoverSource: @escaping @MainActor @Sendable (UIWindow) -> CGRect?
    ) {
        self.points = points
        self.freezeViewport = freezeViewport
        self.keyboardTop = keyboardTop
        self.popoverSource = popoverSource
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

/// What a hosted page needs: the window height that covers it, and the scroll view that sets it. Main-actor
/// isolated: it holds a scroll view and reads it, its window and its screen.
@MainActor
struct PageNeed {
    /// The window height the page needs, in whole points.
    let points: CGFloat
    /// The visible, scrolling scroll view with the largest overflow, or `nil` when the page fits its window.
    let scrollView: UIScrollView?

    /// Whether the scroll view that sets the need avoids a keyboard whose top is at `keyboardTop`, in screen
    /// coordinates: the keyboard's top lies at least one device pixel above the scroll view's bottom edge, and the
    /// scroll view's `adjustedContentInset.bottom` covers that overlap within one device pixel.
    ///
    /// This is the second condition of the keyboard rule (19-30); the first, that a keyboard is up, is the caller's
    /// (`keyboardTop` is `nil` without one). A keyboard stays at the screen's bottom while the window grows below it,
    /// and the inset that follows it grows by exactly the window's growth, so the need of such a page never holds still
    /// (19-20's experiment). A page with a keyboard up that its scroll view ignores (`LoginView` does, up to the Large
    /// text size) does not avoid it.
    func avoidsKeyboard(topAt keyboardTop: CGFloat, in window: UIWindow) -> Bool {
        guard let scrollView else { return false }
        let pixel = 1 / window.screen.scale
        let bottom = scrollView.convert(scrollView.bounds, to: window.screen.coordinateSpace).maxY
        let overlap = bottom - keyboardTop
        return overlap >= pixel && scrollView.adjustedContentInset.bottom >= overlap - pixel
    }
}

extension HostedHierarchy {
    /// The window height the page needs, in whole points: the window's height plus the largest vertical overflow
    /// of a scroll view in the page (``pageRoots(in:)``: the window, or the front-most sheet) that scrolls the page.
    ///
    /// A scroll view counts when it scrolls the page (``scrollsThePage(_:in:)``). Its overflow is its content
    /// with the adjusted insets above and below, less its own height, and it counts only from one device pixel on.
    /// The sum is read in device pixels before it is rounded up, so that a page whose layout lands exactly on a
    /// whole point is not pushed to the next one by floating-point noise.
    static func pageNeed(in window: UIWindow) -> PageNeed {
        let scale = window.screen.scale
        var largest: CGFloat = 0
        var widest: UIScrollView?
        for view in pageRoots(in: window).flatMap({ [$0] + descendants(of: $0) }) {
            guard let scrollView = view as? UIScrollView, scrollsThePage(scrollView, in: window) else { continue }
            let insets = scrollView.adjustedContentInset
            let overflow = scrollView.contentSize.height + insets.top + insets.bottom - scrollView.bounds.height
            if overflow >= 1 / scale, overflow > largest {
                largest = overflow
                widest = scrollView
            }
        }
        return PageNeed(points: ceil(((window.bounds.height + largest) * scale).rounded() / scale), scrollView: widest)
    }

    /// The views that hold the page: the window, or, while a sheet is presented, the front-most sheet and what is
    /// presented over it (owner decision 2026-11-27 in 19-26, 「sheet 的狀況應當測量 sheet 內容」).
    ///
    /// The page of a sheet state is its sheet: the page behind it is only its backdrop, so its scroll views set no
    /// need (a reader of 9,257 pt behind the reader's settings sheet set the iPad's need at every text size, 19-26).
    /// A sheet is a presented controller whose presentation style is `.formSheet` or `.pageSheet`, whether it floats,
    /// as on the iPad, or fills the window's height, as on the iPhone. A dialog, popover or alert presented over the
    /// sheet belongs to the sheet's page; one presented over a page with no sheet belongs to that page, as before.
    static func pageRoots(in window: UIWindow) -> [UIView] {
        var chain: [UIViewController] = []
        var presented = HostedWindowCapture.controllers(from: window.rootViewController)
            .first(where: { $0.presentedViewController != nil })?.presentedViewController
        while let current = presented {
            chain.append(current)
            presented = current.presentedViewController
        }
        guard let sheet = chain.lastIndex(where: { controller in
            guard let style = controller.presentationController?.presentationStyle else { return false }
            return style == .formSheet || style == .pageSheet
        }) else { return [window] }
        return chain[sheet...].map({ $0.presentationController?.presentedView ?? $0.view })
    }

    /// Whether `scrollView` scrolls the page: it scrolls, is neither hidden nor (nearly) transparent in itself or any
    /// ancestor up to the window, its frame in window coordinates meets the window's bounds, and it is no text view.
    ///
    /// A text view (`UITextView` and its subclasses, which SwiftUI's `TextEditor` and vertical `TextField` are hosted
    /// in) scrolls its own text inside the field, and its content height follows its text and the field's width, not
    /// the page: the page around it is what a picture must cover (owner decision in 19-26, 「整頁有拍到那 7,150 不就可以了
    /// 嗎」). Counting one held site settings' empty "Excluded Uploaders" editor at the window plus 23 pt at every
    /// height, `cannot-cover:TextEditorTextView` (19-26).
    static func scrollsThePage(_ scrollView: UIScrollView, in window: UIWindow) -> Bool {
        !(scrollView is UITextView) && isVisibleAndScrolling(scrollView, in: window)
    }

    static func isVisibleAndScrolling(_ scrollView: UIScrollView, in window: UIWindow) -> Bool {
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
    /// Native and frozen reads both settled and show the same still window (``HostedWindowCapture/readsMatch(_:_:)``);
    /// carries the frozen settle.
    case matched(SettleResult)
    /// A read never settled.
    case unsettled(SettleResult)
    /// The frozen read differs from the native one, so a view sized itself from its own viewport; carries the
    /// frozen settle and picture.
    case changed(SettleResult, UIImage)
}

/// What preparing a window grown past the screen came to
/// (``HostedWindowCapture/prepareGrownWindow(_:to:minimumReads:freeze:)``).
struct GrownPreparation {
    /// How the preparation ended.
    enum Outcome {
        /// The window is grown to the requested height and holds the viewport's geometry.
        case ready
        /// The native settle never settled.
        case unsettled(SettleResult)
        /// The frozen read differs from the native one; carries the frozen settle and picture.
        case changed(SettleResult, UIImage)
        /// The task was cancelled while the grown layout was waited for; carries the native settle.
        case cancelled(SettleResult)
        /// The window has no scene, or the grown window lost the viewport's top, left or right safe area, or its
        /// size classes.
        case geometry
    }

    /// The grown window whenever one was made, so the caller restores everything in its `defer`.
    let grown: GrownWindow?
    let outcome: Outcome
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
    /// the frozen read must show the same still window as the native one, by the settle's own rule
    /// (``readsMatch(_:_:)``). Byte-identical reads failed on rendering rounding alone, one step on a 1 pt border, at
    /// coordinates that moved from run to run, while a view that reflows from its viewport moves far more (19-26,
    /// owner decision 2026-11-27, 「改用靜止判斷的規則」).
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
        guard let nativeBytes = comparedBytes(nativeImage), let frozenBytes = comparedBytes(frozenImage),
              readsMatch(nativeBytes, frozenBytes) else {
            return .changed(frozen.result, frozenImage)
        }
        return .matched(frozen.result)
    }

    /// Everything the tall path does between hosting at native size and the operating step, in the capture and in the
    /// measuring mode alike (19-30): the page is settled at native size and its viewport sampling frozen and verified
    /// (``freezeAtNativeSize(_:minimumReads:freeze:)``), then the status bar companion and the size class pins go up,
    /// the window is resized to `points`, one sample is waited for, and the viewport's geometry is checked. The caller
    /// restores the grown window and releases the freeze on every exit.
    static func prepareGrownWindow(
        _ window: UIWindow, to points: CGFloat, minimumReads: Int, freeze: @MainActor (Bool) -> Void
    ) async -> GrownPreparation {
        guard let scene = window.windowScene else { return GrownPreparation(grown: nil, outcome: .geometry) }
        let frozen: SettleResult
        switch await freezeAtNativeSize(window, minimumReads: minimumReads, freeze: freeze) {
        case .unsettled(let settled):
            return GrownPreparation(grown: nil, outcome: .unsettled(settled))
        case .changed(let settled, let image):
            return GrownPreparation(grown: nil, outcome: .changed(settled, image))
        case .matched(let settled):
            frozen = settled
        }
        let held = GrownWindow(window: window, scene: scene)
        held.resize(to: points)
        guard await nextSample() else { return GrownPreparation(grown: held, outcome: .cancelled(frozen)) }
        guard held.holdsViewportGeometry() else { return GrownPreparation(grown: held, outcome: .geometry) }
        return GrownPreparation(grown: held, outcome: .ready)
    }

    /// Finds the window height the hosted page needs, without taking a picture.
    ///
    /// Every height is its own hosting, taken in the capture's order (19-30, owner decision 2026-11-23, 「把步驟拆成
    /// 兩種」): the window's own height first, in a screen-sized hosting (`make`, host, `still`, `interact`, settle),
    /// then each taller height in a fresh hosting of the tall path (`make`, host, `still` at native size, then
    /// ``prepareGrownWindow(_:to:minimumReads:freeze:)`` as the capture does, `interact`, settle). A taller height
    /// needs a fresh hosting because an operating step cannot be undone, and the owner's order grows the window
    /// before it. The floating form sheets are fitted as the capture fits them (``SheetFitter``).
    /// After each settle the need is read (``HostedHierarchy/pageNeed(in:)``), together with the class and height of
    /// the scroll view that sets it and whether that scroll view avoids a keyboard that is up (`keyboardTop`,
    /// ``PageNeed/avoidsKeyboard(topAt:in:)``). Then:
    /// - a hosting above the window's own height whose popover source lies outside the scene
    ///   (``popoverSourceLiesOutsideScene(_:in:)``, read through `popoverSource`) is `cannotCover`, reason
    ///   `cannot-cover:popover`, at once, whatever its need;
    /// - a need at most the hosting's height is `measured` at that height, `steps` the number of hostings above the
    ///   window's own height;
    /// - a need above it with an avoided keyboard is `cannotCover`, reason `cannot-cover:keyboard`, at once: no height
    ///   covers a page whose scroll view follows a keyboard that stays at the screen's bottom;
    /// - a need above it whose most-overflowing scroll view keeps its class and its height (within one device pixel)
    ///   from the previous hosting while the window grew is `cannotCover`, reason `cannot-cover:<class>`;
    /// - after the ``maximumGrowthSteps``th hosting above the window's own height the measurement ends as
    ///   `didNotConverge`; otherwise the next height is the need.
    ///
    /// The classification is never an adjustment. Nothing is written, and the window, the pins and the viewport
    /// sampling are restored after every hosting. A page that fits the screen is `measured` at the screen height in no
    /// steps.
    public static func measure(
        make: () throws -> AnyView, window: UIWindow, style: UIUserInterfaceStyle,
        still: (@MainActor (UIWindow) async throws -> Void)? = nil,
        interact: (@MainActor (UIWindow) async throws -> Void)? = nil, minimumReads: Int = minimumReads,
        freezeViewport: @escaping @MainActor @Sendable (Bool) -> Void,
        keyboardTop: @escaping @MainActor (UIWindow) -> CGFloat?,
        popoverSource: @escaping @MainActor (UIWindow) -> CGRect? = { _ in nil }
    ) async -> PageMeasurement {
        let screen = window.bounds.height
        let pixel = 1 / window.screen.scale
        func ended(_ status: SnapshotHeightStatus, last: HostingRead?, steps: Int, reason: String? = nil)
            -> PageMeasurement {
            PageMeasurement(
                status: status, neededPoints: last.map({ Int($0.points) }), screenPoints: Int(screen.rounded()),
                steps: steps, reason: reason
            )
        }
        var height = screen
        var previous: HostingRead?
        for step in 0...maximumGrowthSteps {
            let root: AnyView
            do {
                root = try make()
            } catch {
                return ended(.error, last: previous, steps: step, reason: "factory")
            }
            let hosted = host(root, in: window, style: style)
            let hosting = await measureHosted(
                window: window, height: height,
                stages: .init(still: still, interact: interact, minimumReads: minimumReads),
                freezeViewport: freezeViewport,
                classifiers: .init(keyboardTop: keyboardTop, popoverSource: popoverSource)
            )
            await hosted.disposeAfterDismissal()
            let read: HostingRead
            switch hosting {
            case .failed(let reason): return ended(.error, last: previous, steps: step, reason: reason)
            case .read(let value): read = value
            }
            if read.popoverOutsideScene {
                return ended(.cannotCover, last: read, steps: step, reason: popoverReason)
            }
            if read.points <= height { return ended(.measured, last: read, steps: step) }
            if read.avoidsKeyboard {
                return ended(.cannotCover, last: read, steps: step, reason: keyboardReason)
            }
            if let previous, let name = read.scrollViewClass, name == previous.scrollViewClass,
               abs(read.scrollViewHeight - previous.scrollViewHeight) <= pixel {
                return ended(.cannotCover, last: read, steps: step, reason: "cannot-cover:\(name)")
            }
            previous = read
            height = read.points
        }
        return ended(.didNotConverge, last: previous, steps: maximumGrowthSteps)
    }

    /// The reason of a page whose need-setting scroll view avoids a keyboard that is up (the keyboard rule, 19-30).
    static let keyboardReason = "cannot-cover:keyboard"

    /// The reason of a page whose popover's source lies outside the scene (19-30, owner decision 2026-11-23, 「標出來，
    /// 19-26 逐頁決定」): in a window taller than the screen the scene's bounds stay at the screen's size, and UIKit draws
    /// an arrowed popover only within them.
    static let popoverReason = "cannot-cover:popover"

    /// The source rect, in window coordinates, of the front-most popover presented from the window's root or from a
    /// controller it holds, else `nil`. A popover here is a presentation whose `popoverPresentationController` is set
    /// and whose presentation controller's `presentationStyle`, the style in use, is `.popover`; an alert, a sheet or a
    /// popover UIKit adapted to another style is not (their `adaptivePresentationStyle`, the style an adaptation would
    /// take, reads otherwise even for a popover that stays one). An empty source rect is the source view's bounds.
    public static func presentedPopoverSource(in window: UIWindow) -> CGRect? {
        let popovers = controllers(from: window.rootViewController)
            .compactMap(\.presentedViewController)
            .compactMap(\.popoverPresentationController)
            .filter({ $0.presentationStyle == .popover && $0.sourceView != nil })
        guard let popover = popovers.last, let source = popover.sourceView else { return nil }
        let rect = popover.sourceRect.isNull || popover.sourceRect == .zero ? source.bounds : popover.sourceRect
        return source.convert(rect, to: window)
    }

    /// `controller`, the controllers it holds and what it presents, each followed by its own.
    static func controllers(from controller: UIViewController?) -> [UIViewController] {
        guard let controller else { return [] }
        return [controller] + (controller.children + [controller.presentedViewController].compactMap({ $0 }))
            .flatMap(controllers(from:))
    }

    /// Whether `source`, a rect in `window`'s coordinates, is not inside the bounds of the window's scene's coordinate
    /// space. The scene's bounds stay at the screen's size while the window is taller (19-30), and UIKit draws an
    /// arrowed popover only within them: a source below them gets no arrow and a popover that is not on its control.
    static func popoverSourceLiesOutsideScene(_ source: CGRect, in window: UIWindow) -> Bool {
        guard let space = window.windowScene?.effectiveGeometry.coordinateSpace else { return false }
        return !space.bounds.contains(window.coordinateSpace.convert(source, to: space))
    }

    /// The two kinds of step of one hosting, and the fewest identical reads its settles need.
    private struct Stages {
        let still: (@MainActor (UIWindow) async throws -> Void)?
        let interact: (@MainActor (UIWindow) async throws -> Void)?
        let minimumReads: Int
    }

    /// The readings that classify a page nothing can cover, taken from the matrix.
    private struct Classifiers {
        let keyboardTop: @MainActor (UIWindow) -> CGFloat?
        let popoverSource: @MainActor (UIWindow) -> CGRect?
    }

    /// What one hosting of the measuring mode read, while its page was still hosted.
    private struct HostingRead {
        /// The window height the page needs, in whole points.
        let points: CGFloat
        /// The class and height of the scroll view that sets the need; `nil` and 0 when the page fits.
        let scrollViewClass: String?
        let scrollViewHeight: CGFloat
        /// Whether that scroll view avoids a keyboard that is up.
        let avoidsKeyboard: Bool
        /// Whether, in a hosting above the window's own height, a popover's source lies outside the scene.
        let popoverOutsideScene: Bool
    }

    private enum Hosting {
        case read(HostingRead)
        /// A fixed reason code, never page text.
        case failed(String)
    }

    /// One hosting at `height`: the stillness step at native size, the window grown (above its own height), the
    /// operating step between two fittings of the form sheets, the settle (taken again when the fitting after it
    /// changed anything), and the read.
    private static func measureHosted(
        window: UIWindow, height: CGFloat, stages: Stages, freezeViewport: @MainActor (Bool) -> Void,
        classifiers: Classifiers
    ) async -> Hosting {
        let nativeSize = window.bounds.size
        let minimumReads = stages.minimumReads
        var grown: GrownWindow?
        defer {
            grown?.restore()
            freezeViewport(false)
            window.layoutIfNeeded()
        }
        if let still = stages.still {
            do {
                try await still(window)
            } catch {
                return .failed("\(interactionReason):\(stepFailure(error))")
            }
        }
        if height > nativeSize.height {
            let prepared = await prepareGrownWindow(
                window, to: height, minimumReads: minimumReads, freeze: freezeViewport
            )
            grown = prepared.grown
            switch prepared.outcome {
            case .ready: break
            case .unsettled, .cancelled: return .failed(settleTimeoutReason)
            case .changed: return .failed(freezeChangedPixelsReason)
            case .geometry: return .failed(tallWindowGeometryReason)
            }
        }
        let fitter = SheetFitter()
        if let failed = failure(of: await fitter.fit(in: window)) { return failed }
        if let interact = stages.interact {
            do {
                try await interact(window)
            } catch {
                return .failed("\(interactionReason):\(stepFailure(error))")
            }
            if let failed = failure(of: await fitter.fit(in: window)) { return failed }
        }
        do {
            guard case .settled = try await settleWindow(window, nativeSize: nativeSize, minimumReads: minimumReads)
            else { return .failed(settleTimeoutReason) }
            // The fitting after the settle, as the capture's (``SheetFitter``).
            let fit = await fitter.fit(in: window)
            if let failed = failure(of: fit) { return failed }
            if fit == .fitted {
                guard case .settled = try await settleWindow(
                    window, nativeSize: nativeSize, minimumReads: minimumReads
                ) else { return .failed(settleTimeoutReason) }
            }
        } catch {
            return .failed("render-server:\(error)")
        }
        let need = HostedHierarchy.pageNeed(in: window)
        let avoids = classifiers.keyboardTop(window).map({ need.avoidsKeyboard(topAt: $0, in: window) }) ?? false
        let outside = height > nativeSize.height
            && classifiers.popoverSource(window).map({ popoverSourceLiesOutsideScene($0, in: window) }) == true
        return .read(HostingRead(
            points: need.points, scrollViewClass: need.scrollView.map({ String(describing: type(of: $0)) }),
            scrollViewHeight: need.scrollView?.bounds.height ?? 0, avoidsKeyboard: avoids, popoverOutsideScene: outside
        ))
    }

    /// The hosting a fitting of the form sheets ends: failed when a presentation never finished or the wait for one
    /// was cancelled, else `nil`.
    private static func failure(of fit: SheetFit) -> Hosting? {
        switch fit {
        case .unchanged, .fitted: nil
        case .presenting, .cancelled: .failed(presentingReason)
        }
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
