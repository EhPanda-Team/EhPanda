import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// Scrolls a scenario's page to the part that makes its state, at accessibility5 only.
///
/// At accessibility5 text several pages are taller than the screen, and a state's own part sat below the fold:
/// the selected analytics level, the user rating under Rate Gallery, the low balances under the archives, and the
/// row a confirmation dialog belongs to. The pictures of those states were the same as their base state's
/// (candidate run 43403534542). A dialog is drawn from the row it belongs to, and a list builds no row below its
/// fold, so a dialog whose row was not built was never shown at all.
///
/// At accessibility5 the page is scrolled as a user scrolls it, a page at a time, until the part is built, and is
/// then brought to rest with the part at the top of the visible area. A dialog's tap is held back until its row is
/// on screen (``tap(_:)``). Every other text size keeps its page and its pictures as they were.
@MainActor
enum RevealStep {
    /// What to bring on screen: an element whose accessibility label contains the text, or whose accessibility
    /// identifier is the text.
    enum Target {
        case label(String)
        case identifier(String)

        private var identifierGetter: Selector {
            #selector(getter: UIAccessibilityIdentification.accessibilityIdentifier)
        }

        var name: String {
            switch self {
            case .label(let text), .identifier(let text): text
            }
        }

        @MainActor
        func matches(_ element: NSObject) -> Bool {
            switch self {
            case .label(let text):
                element.isAccessibilityElement && element.accessibilityLabel?.contains(text) == true
            case .identifier(let identifier):
                // SwiftUI's accessibility elements answer `accessibilityIdentifier` without declaring
                // `UIAccessibilityIdentification`, so a cast to the protocol misses them; the getter is asked by name.
                element.responds(to: identifierGetter)
                    && element.value(forKey: "accessibilityIdentifier") as? String == identifier
            }
        }
    }

    /// Whether this process renders accessibility5 text, the one size whose pages this step moves.
    static var isLargestText: Bool {
        UIApplication.shared.preferredContentSizeCategory == SnapshotConfiguration.contentSizes["accessibility5"]
    }

    /// The tap a factory holds back for ``reveal(_:)``, at accessibility5 only.
    private static var pendingTap: (@MainActor () -> Void)?

    /// Performs `action`, the user's tap that presents a dialog, now; at accessibility5 it is kept and performed
    /// by the scenario's ``reveal(_:)`` once the row it is drawn from is on screen.
    static func tap(_ action: @escaping @MainActor () -> Void) {
        if isLargestText {
            pendingTap = action
        } else {
            action()
        }
    }

    /// Drops a tap ``tap(_:)`` held that no ``reveal(_:)`` performed (SnapshotMatrixCase, before and after each case).
    static func discardHeldTap() {
        pendingTap = nil
    }

    /// The user step of a scenario whose factory presents a dialog: returns once the dialog has finished presenting
    /// and, where it is a popover, its platter is built (``popoverPlatterReady(in:)``), or fails at
    /// ``platterDeadline``, and the capture tries again with a new page and a new presentation.
    ///
    /// On the hosted runner 15 of the 144 pictures of `settings-account-logout-confirmation` in run 43451019962
    /// (about 11 in the run before) drew the popover's text and button over the page without the platter: no glass,
    /// arrow or shadow, every read alike until the settle ended, with the layout of a good picture. A presentation
    /// whose platter is built returns at once, so the pictures that had it are drawn as they were.
    nonisolated static func awaitDialogPlatter() -> ScenarioFactory.Interact {
        { window in
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: platterDeadline)
            while !popoverPlatterReady(in: window) {
                guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound("popover platter") }
                try await clock.sleep(for: .milliseconds(100))
            }
        }
    }

    /// How long ``awaitDialogPlatter()`` waits for the dialog's platter.
    static let platterDeadline: Duration = .seconds(10)

    /// Whether the front-most presentation in the window, from its root or from any controller it holds, has finished
    /// presenting and, if it is drawn in a popover, the popover's Liquid Glass platter has its layers: a backdrop and
    /// a shape whose contents are drawn, both the size of the platter, with nothing on the way up to the window hidden
    /// or transparent, in the model or on screen. A presentation that is not a popover (a sheet, an alert) needs only
    /// to have finished presenting.
    static func popoverPlatterReady(in window: UIWindow) -> Bool {
        guard let root = window.rootViewController, let front = frontPresentation(over: root), !front.isBeingPresented,
              front.transitionCoordinator == nil else { return false }
        guard let platter = firstView(named: "_UIPopoverGlassBackground", in: window) else { return true }
        guard !platter.bounds.isEmpty, shows(platter, in: window) else { return false }
        let layers = sublayers(of: platter.layer)
        let backdrop = layers.first(where: {
            String(describing: type(of: $0)) == "CABackdropLayer" && !$0.bounds.isEmpty
        })
        let shape = layers.first(where: {
            String(describing: type(of: $0)).contains("SDFElementLayer") && $0.contents != nil && !$0.bounds.isEmpty
        })
        return backdrop != nil && shape != nil
    }

    /// The last controller presented over `controller`, or over a controller it holds, if any.
    private static func frontPresentation(over controller: UIViewController) -> UIViewController? {
        if let presented = controller.presentedViewController, presented.presentingViewController === controller {
            return frontPresentation(over: presented) ?? presented
        }
        for child in controller.children {
            if let found = frontPresentation(over: child) { return found }
        }
        return nil
    }

    private static func shows(_ view: UIView, in window: UIWindow) -> Bool {
        var current: UIView? = view
        while let view = current, view !== window {
            let shown = view.layer.presentation()?.opacity ?? view.layer.opacity
            if view.isHidden || view.alpha < 0.01 || view.layer.opacity < 0.01 || shown < 0.01 { return false }
            current = view.superview
        }
        return current === window
    }

    private static func firstView(named name: String, in view: UIView) -> UIView? {
        if String(describing: type(of: view)) == name { return view }
        for subview in view.subviews {
            if let found = firstView(named: name, in: subview) { return found }
        }
        return nil
    }

    private static func sublayers(of layer: CALayer) -> [CALayer] {
        (layer.sublayers ?? []).flatMap({ [$0] + sublayers(of: $0) })
    }

    /// The user step of a scenario whose state is `target`: at accessibility5 the page is scrolled to it and a
    /// tap held back by ``tap(_:)`` is performed. At other sizes it does nothing, unless `atEverySize`: a scenario
    /// new to the matrix, with no pictures to keep, has its target brought on screen at any size it is below the fold.
    nonisolated static func reveal(_ target: Target, atEverySize: Bool = false) -> ScenarioFactory.Interact {
        { window in
            let tap = pendingTap
            pendingTap = nil
            guard atEverySize || isLargestText else { return }
            _ = await HostedWindowCapture.settle(window)
            try await bringIntoView(target, in: window)
            tap?()
        }
    }

    /// The margin left above the target, so its row's top edge and separator are drawn.
    private static let margin: CGFloat = 16
    /// The most page-sized steps taken looking for a target the list has not built yet.
    private static let maximumSteps = 40
    /// The most waits at the bottom the list reported, for rows it builds as it scrolls to grow its content.
    private static let maximumStalls = 10

    private static func bringIntoView(_ target: Target, in window: UIWindow) async throws {
        var steps = 0
        var stalls = 0
        var placements = 0
        while true {
            if let (element, view) = element(target, in: window, view: window) {
                // A page that fits its screen does not scroll: the part is on screen as it is.
                guard let list = scrollView(holding: view, in: window) else { return }
                let frame = list.convert(element.accessibilityFrame, from: window.screen.coordinateSpace)
                let visible = visibleArea(of: list)
                // Placed again while the page lays itself out under the new offset; a part taller than the visible
                // area stays where its top is placed. Once the page has been stepped through, the part is placed at
                // the top even when a step left it in view: where a step leaves it depends on how many rows the list
                // had built in time (`settings-account-invalid-cookies` at accessibility5 stopped mid-page in one run
                // of three), and the top does not.
                guard (steps > 0 && placements == 0) || !visible.contains(frame), placements < 3,
                      scroll(list, to: frame.minY - margin - list.adjustedContentInset.top)
                else { return }
                placements += 1
            } else {
                // A page at a time, as a user's flick moves it, keeping a fifth of the last page in view. A form
                // sizes its rows as it builds them, so the bottom it reports first can still move: there it waits.
                guard steps < maximumSteps, let list = frontScrollView(in: window)
                else { throw AccessibilityActionDriver.Failure.notFound(target.name) }
                if scroll(list, to: list.contentOffset.y + visibleArea(of: list).height * 0.8) {
                    steps += 1
                } else {
                    guard stalls < maximumStalls else { throw AccessibilityActionDriver.Failure.notFound(target.name) }
                    stalls += 1
                }
            }
            try await ContinuousClock().sleep(for: .milliseconds(100))
        }
    }

    /// The part of `list`'s content shown between its bars, in the list's own coordinates.
    private static func visibleArea(of list: UIScrollView) -> CGRect {
        list.bounds.inset(by: list.adjustedContentInset)
    }

    /// Sets `list`'s vertical offset to `offset`, kept inside the list's content; whether the offset changed.
    @discardableResult
    private static func scroll(_ list: UIScrollView, to offset: CGFloat) -> Bool {
        let top = -list.adjustedContentInset.top
        let bottom = max(top, list.contentSize.height - list.bounds.height + list.adjustedContentInset.bottom)
        let clamped = min(max(offset, top), bottom)
        guard abs(clamped - list.contentOffset.y) >= 0.5 else { return false }
        list.setContentOffset(CGPoint(x: list.contentOffset.x, y: clamped), animated: false)
        list.layoutIfNeeded()
        return true
    }

    /// The scroll view that moves an element of `view`: the nearest one at or above it.
    private static func scrollView(holding view: UIView, in window: UIWindow) -> UIScrollView? {
        var view: UIView? = view
        while let current = view {
            if let list = current as? UIScrollView, scrollsVertically(list) { return list }
            view = current.superview
        }
        return frontScrollView(in: window)
    }

    /// The largest vertically scrolling list of the front-most presentation (a sheet over the page, or the page).
    private static func frontScrollView(in window: UIWindow) -> UIScrollView? {
        var front = window.rootViewController
        while let next = front?.presentedViewController, !next.isBeingDismissed {
            front = next
        }
        guard let view = front?.view else { return nil }
        return scrollViews(in: view)
            .filter(scrollsVertically)
            .max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
    }

    private static func scrollsVertically(_ list: UIScrollView) -> Bool {
        list.window != nil && list.isScrollEnabled
            && list.contentSize.height > visibleArea(of: list).height
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        guard !view.isHidden else { return [] }
        return ((view as? UIScrollView).map({ [$0] }) ?? []) + view.subviews.flatMap(scrollViews(in:))
    }

    /// The first element in `window`, depth first, that `target` names.
    static func element(_ target: Target, in window: UIWindow) -> NSObject? {
        element(target, in: window, view: window)?.element
    }

    /// The first element below `root`, depth first, that `target` names, with the view it belongs to: `root`'s
    /// view, the nearest view at or above `root` (`view`).
    private static func element(
        _ target: Target, in root: NSObject, view: UIView, depth: Int = 0
    ) -> (element: NSObject, view: UIView)? {
        guard depth < 64 else { return nil }
        if let view = root as? UIView, view.isHidden { return nil }
        let view = root as? UIView ?? view
        if target.matches(root) { return (root, view) }
        var children: [NSObject] = []
        if let elements = root.accessibilityElements as? [NSObject] {
            children += elements
        } else {
            let count = root.accessibilityElementCount()
            if count > 0, count != NSNotFound {
                children += (0..<count).compactMap({ root.accessibilityElement(at: $0) as? NSObject })
            }
        }
        if let view = root as? UIView {
            children += view.subviews
        }
        for child in children {
            if let found = element(target, in: child, view: view, depth: depth + 1) { return found }
        }
        return nil
    }
}
