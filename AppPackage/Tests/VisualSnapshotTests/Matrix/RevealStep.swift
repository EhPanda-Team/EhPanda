import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// Scrolls a scenario's page to the part that makes its state, wherever that part is below the fold.
///
/// Several pages are taller than the window, and a state's own part sat below the fold: the selected analytics
/// level, the user rating under Rate Gallery, the low balances under the archives, and the row a confirmation dialog
/// belongs to. The pictures of those states were the same as their base state's (candidate run 43403534542). A
/// dialog is drawn from the row it belongs to, and a list builds no row below its fold, so a dialog whose row was
/// not built was never shown at all.
///
/// The step first moved pages at accessibility5 only, so the other sizes kept the pictures they had. The fold is
/// not a matter of text size alone: on an iPhone in landscape, Clear Image Cache's and Remove Custom Translations'
/// rows and their dialogs, and the stars under Rate Gallery, were below it at the default size too (candidate run
/// 44025665174). With no approved baseline yet there were no pictures to keep, so the step acts at every size.
///
/// The page is scrolled as a user scrolls it, a page at a time, until the part is built, and is then brought to
/// rest with the part at the top of the visible area. A dialog's tap is held back until its row is on screen
/// (``tap(_:)``). A part already in view is left where it is, so a page that shows its part keeps its picture.
@MainActor
enum RevealStep {
    /// What to bring on screen: an element whose accessibility label contains the text, or is the text
    /// (`wholeLabel`), or whose accessibility identifier is the text.
    enum Target {
        case label(String)
        case wholeLabel(String)
        case identifier(String)

        private var identifierGetter: Selector {
            #selector(getter: (any UIAccessibilityIdentification).accessibilityIdentifier)
        }

        var name: String {
            switch self {
            case .label(let text), .wholeLabel(let text), .identifier(let text): text
            }
        }

        @MainActor
        func matches(_ element: NSObject) -> Bool {
            switch self {
            case .label(let text):
                element.isAccessibilityElement && element.accessibilityLabel?.contains(text) == true
            case .wholeLabel(let text):
                element.isAccessibilityElement && element.accessibilityLabel == text
            case .identifier(let identifier):
                // SwiftUI's accessibility elements answer `accessibilityIdentifier` without declaring
                // `UIAccessibilityIdentification`, so a cast to the protocol misses them; the getter is asked by name.
                element.responds(to: identifierGetter)
                    && element.value(forKey: "accessibilityIdentifier") as? String == identifier
            }
        }
    }

    /// Whether this process renders accessibility5 text, the one size whose sheets ``showLargeTitle(then:)`` fixes.
    static var isLargestText: Bool {
        UIApplication.shared.preferredContentSizeCategory == SnapshotConfiguration.contentSizes["accessibility5"]
    }

    /// The tap a factory holds back for ``reveal(_:)``.
    private static var pendingTap: (@MainActor () -> Void)?

    /// Keeps `action`, the user's tap that presents a dialog, for the scenario's ``reveal(_:)``, which performs it
    /// once the row the dialog is drawn from is on screen.
    static func tap(_ action: @escaping @MainActor () -> Void) {
        pendingTap = action
    }

    /// Drops a tap ``tap(_:)`` held that no ``reveal(_:)`` performed (SnapshotMatrixCase, before and after each case).
    static func discardHeldTap() {
        pendingTap = nil
    }

    /// The user step of a scenario whose factory presents a dialog: returns once the dialog has finished presenting
    /// and, where it is a popover, its platter is built (``popoverPlatterReady(in:)``), or fails once it has looked
    /// for ``platterDeadline`` (``StepBudget``), and the capture tries again with a new page and a new presentation.
    ///
    /// On the hosted runner 15 of the 144 pictures of `settings-account-logout-confirmation` in run 43451019962
    /// (about 11 in the run before) drew the popover's text and button over the page without the platter: no glass,
    /// arrow or shadow, every read alike until the settle ended, with the layout of a good picture. A presentation
    /// whose platter is built returns at once, so the pictures that had it are drawn as they were.
    ///
    /// A step that fails names the check the platter last failed (``PlatterState``), as
    /// `not-found:popover-platter:<check>` with how long it waited (``BrowsingScenarios/StepFailure``): run
    /// 43575259346 failed it on the light picture only, twice in a row, with a reason that named no check.
    ///
    /// The ten seconds are counted in time the main run loop turned, not on the wall clock: in run 43621303643 the
    /// step looked twice in 15 to 50 s (`opening waited=50.3s polls=2`): the main thread did not come back, and the
    /// deadline ran out before the step could look again. (Locally a simulator render server that does not run,
    /// `backboardd` stopped, holds the main thread in a Core Animation commit in just this way.)
    nonisolated static func awaitDialogPlatter() -> ScenarioFactory.Interact {
        { window in
            var budget = StepBudget(platterDeadline)
            while true {
                budget.look()
                let state = platterState(in: window)
                if state == .ready { return }
                guard !budget.isSpent else {
                    throw budget.failure(
                        "not-found:popover-platter:\(state.rawValue) chain=\(presentationChain(in: window))"
                    )
                }
                try await ContinuousClock().sleep(for: .milliseconds(100))
            }
        }
    }

    /// The window's presentations from its root, for a failed dialog step: each controller's class, with `+` while it
    /// is being presented, `-` while it is being dismissed and `~` while a transition is under way, then `@0` when the
    /// window is not the key window. Run 43621303643's second attempts found nothing presented (`not-presented`
    /// in 85 looks) after a first attempt that failed while its popover was still opening; this says what the window
    /// held instead.
    static func presentationChain(in window: UIWindow) -> String {
        var names: [String] = []
        var controller = window.rootViewController
        while let current = controller, names.count < 8 {
            var name = String(describing: type(of: current))
            name = String(name.prefix(while: { $0 != "<" }))
            if current.isBeingPresented { name += "+" }
            if current.isBeingDismissed { name += "-" }
            if current.transitionCoordinator != nil { name += "~" }
            names.append(name)
            controller = current.presentedViewController
        }
        return names.joined(separator: ">") + (window.isKeyWindow ? "" : "@0")
    }

    /// How long ``awaitDialogPlatter()`` looks for the dialog's platter, in time the main run loop turned.
    static let platterDeadline: Duration = .seconds(10)

    /// How far a presentation is from ``popoverPlatterReady(in:)``: the first check it fails, in the order they are
    /// made.
    enum PlatterState: String {
        case ready
        /// Nothing is presented from the root or from any controller it holds.
        case notPresented = "not-presented"
        /// The presentation has not finished presenting: still opening.
        case opening
        /// The popover's glass background has no size, or it or a view above it is hidden or transparent.
        case platterHidden = "platter-hidden"
        /// The glass background has no backdrop layer of its size.
        case backdropMissing = "backdrop-missing"
        /// The glass background has no shape (SDF element) layer with drawn contents.
        case shapeMissing = "shape-missing"
    }

    /// Whether the front-most presentation in the window, from its root or from any controller it holds, has finished
    /// presenting and, if it is drawn in a popover, the popover's Liquid Glass platter has its layers: a backdrop and
    /// a shape whose contents are drawn, both the size of the platter, with nothing on the way up to the window hidden
    /// or transparent, in the model or on screen. A presentation that is not a popover (a sheet, an alert) needs only
    /// to have finished presenting.
    static func popoverPlatterReady(in window: UIWindow) -> Bool {
        platterState(in: window) == .ready
    }

    /// The first check of ``popoverPlatterReady(in:)`` the window fails, or `ready`.
    static func platterState(in window: UIWindow) -> PlatterState {
        guard let root = window.rootViewController, let front = frontPresentation(over: root) else {
            return .notPresented
        }
        guard !front.isBeingPresented, front.transitionCoordinator == nil else { return .opening }
        guard let platter = firstView(named: "_UIPopoverGlassBackground", in: window) else { return .ready }
        guard !platter.bounds.isEmpty, shows(platter, in: window) else { return .platterHidden }
        let layers = sublayers(of: platter.layer)
        guard layers.contains(where: {
            String(describing: type(of: $0)) == "CABackdropLayer" && !$0.bounds.isEmpty
        }) else { return .backdropMissing }
        guard layers.contains(where: {
            String(describing: type(of: $0)).contains("SDFElementLayer") && $0.contents != nil && !$0.bounds.isEmpty
        }) else { return .shapeMissing }
        return .ready
    }

    /// The user step of a sheet whose navigation bar draws a large title over a list with hidden overlays (Archives,
    /// Torrents): at accessibility5, once the page has settled, a bar that follows a hidden scroll view is made to
    /// follow the sheet's shown list, then `next` runs. At other sizes the step is `next` alone.
    ///
    /// Both sheets lay a loading view and an error view over their list, hidden by opacity, and at accessibility5
    /// the error view scrolls. The sheet's navigation bar can take that hidden scroll view for its content, and its
    /// large title was then laid out inside it in most launches: the title's space stayed, but nothing was drawn in
    /// it. Which way a launch went stayed for the rest of the page (`detail-pages-archives`,
    /// `-archives-insufficient-funds` and `-torrents` at accessibility5: the title in one run and not in the next,
    /// run 43451019962 against the run before it). A bar that follows the hidden scroll view also does not collapse
    /// its title when the list scrolls, so the insufficient-funds sheet, scrolled to its balances, held the large
    /// title in some launches and the collapsed bar in others. The step names the shown list as the page's top
    /// content scroll view: the title is drawn as in the launches that had it, pixel for pixel, and collapses as the
    /// list scrolls. A title that is still not drawn fails the step as `interaction:large-title-hidden`.
    nonisolated static func showLargeTitle(then next: ScenarioFactory.Interact? = nil) -> ScenarioFactory.Interact {
        { window in
            if isLargestText {
                _ = await HostedWindowCapture.settle(window)
                if followShownList(in: window) {
                    try await BrowsingScenarios.waitForRest(window)
                }
                guard largeTitleShown(in: window) else {
                    throw BrowsingScenarios.StepFailure(reason: "large-title-hidden")
                }
            }
            try await next?(window)
        }
    }

    /// Whether the front-most presentation's large title, if it has one, is drawn: nothing on the way up to the
    /// window hidden or transparent.
    static func largeTitleShown(in window: UIWindow) -> Bool {
        guard let root = window.rootViewController, let view = (frontPresentation(over: root) ?? root).view,
              let title = firstView(named: "_UINavigationBarLargeTitleView", in: view) else { return true }
        return shows(title, in: window)
    }

    /// Names the largest shown scroll view of each navigation controller's top page in the front-most presentation as
    /// that page's top content scroll view, where the one its bar follows is not shown; whether it named any.
    @discardableResult
    private static func followShownList(in window: UIWindow) -> Bool {
        guard let root = window.rootViewController else { return false }
        let front = frontPresentation(over: root) ?? root
        var named = false
        for navigation in controllers(in: front).compactMap({ $0 as? UINavigationController }) {
            guard let page = navigation.topViewController else { continue }
            if let followed = page.contentScrollView(for: .top), shows(followed, in: window) { continue }
            guard let list = scrollViews(in: page.view)
                .filter({ shows($0, in: window) })
                .max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
            else { continue }
            page.setContentScrollView(list, for: .top)
            // The bar lays its title out again only when it is itself laid out.
            navigation.navigationBar.setNeedsLayout()
            navigation.view.setNeedsLayout()
            navigation.view.layoutIfNeeded()
            named = true
        }
        return named
    }

    /// `controller` and every controller it holds.
    private static func controllers(in controller: UIViewController) -> [UIViewController] {
        [controller] + controller.children.flatMap(controllers(in:))
    }

    /// The last controller presented over `controller`, or over a controller it holds, if any; one that is being
    /// dismissed is no longer presented.
    ///
    /// An active search controller is not a presentation that covers its page: it hosts the search bar, and the
    /// suggestions the page lists stay rows of the page's own list, outside the search controller's view (the typing
    /// suggestions of the Search page, found by looking from the search controller's view: nothing was found). The
    /// walk goes through it, so a sheet, alert or popover presented over an active search is the front-most
    /// presentation; a search controller that is itself the last one is skipped, and the controller that presents it
    /// stays the answer (the sheet that holds an active search, or no presentation at all for the page).
    private static func frontPresentation(over controller: UIViewController) -> UIViewController? {
        if let presented = controller.presentedViewController, presented.presentingViewController === controller,
           !presented.isBeingDismissed {
            if let deeper = frontPresentation(over: presented) { return deeper }
            if !(presented is UISearchController) { return presented }
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

    /// The user step of a scenario whose state is `target`: the page is scrolled to it where it is below the fold,
    /// and a tap held back by ``tap(_:)`` is performed. With `settlingSteps`, the page is looked through again after
    /// each step once it has stopped changing, rather than 100 ms later (``bringIntoView(_:below:in:settlingSteps:)``).
    /// With `holdingPlacement`, a placed part is placed again once the page has stopped changing, until it stays where
    /// it was placed (``holdPlacement(_:in:)``). With `measuringPage`, a page whose part is not in view is first
    /// stepped through to its end and back, so it has built every row (``measurePage(in:)``). With `below`, the
    /// part counts as in view only with that much of the page under it: a state drawn just below the element that
    /// names it, as the stars under Rate Gallery are.
    nonisolated static func reveal(
        _ target: Target, below: CGFloat = 0, settlingSteps: Bool = false, holdingPlacement: Bool = false,
        measuringPage: Bool = false
    ) -> ScenarioFactory.Interact {
        { window in
            let tap = pendingTap
            pendingTap = nil
            _ = await HostedWindowCapture.settle(window)
            if measuringPage, !isInView(target, in: window) {
                await measurePage(in: window)
            }
            try await bringIntoView(target, below: below, in: window, settlingSteps: settlingSteps)
            if holdingPlacement {
                try await holdPlacement(target, in: window)
            }
            if let (_, view) = find(target, in: window),
               let list = scrollView(holding: view, in: window) {
                restWhereTitleSnaps(list)
            }
            tap?()
        }
    }

    /// Steps the front-most list a page at a time to its end, letting the page settle after each step, until the end
    /// it reports stays put; then returns it to the offset it started at and lets it settle.
    ///
    /// A form sizes its rows as it builds them, and the rows below the part it is brought to are built or not
    /// depending on how far a launch got: `settings-account-invalid-cookies` on iPhone large landscape ended with
    /// 714.7 points of content in some launches and 870.7 in others, and the Copy Cookies row above the part was drawn
    /// differently in the two (locally 2 of 6 launches). Stepped through first, every launch has built the same rows.
    private static func measurePage(in window: UIWindow) async {
        guard let list = frontScrollView(in: window) else { return }
        // The offset itself, not the top of the list: a large title collapsed by the steps changes the top inset.
        let start = list.contentOffset
        for _ in 0..<maximumSteps {
            let stepped = scroll(list, to: list.contentOffset.y + visibleArea(of: list).height * 0.8)
            _ = await HostedWindowCapture.settle(window)
            let bottom = list.contentSize.height - list.bounds.height + list.adjustedContentInset.bottom
            if !stepped, list.contentOffset.y >= bottom - 0.5 { break }
        }
        list.setContentOffset(start, animated: false)
        list.layoutIfNeeded()
        _ = await HostedWindowCapture.settle(window)
    }

    /// Whether `target` is on the page and inside the visible area of the list that holds it.
    private static func isInView(_ target: Target, in window: UIWindow) -> Bool {
        guard let (element, view) = find(target, in: window) else { return false }
        guard let list = scrollView(holding: view, in: window) else { return true }
        let frame = list.convert(element.accessibilityFrame, from: window.screen.coordinateSpace)
        return visibleArea(of: list).contains(frame)
    }

    /// The most times ``holdPlacement(_:in:)`` places a part again.
    private static let maximumHolds = 6

    /// Places a part brought into view at the top of the visible area again each time the page has stopped changing,
    /// until it is still there, then leaves it.
    ///
    /// A form sizes its rows as it builds them: the rows above a part placed at the top can still grow after the
    /// placement and push it down, and ``bringIntoView(_:below:in:settlingSteps:)`` leaves a part that is in view
    /// where it is. How far it was pushed depended on how many rows were built in time
    /// (`settings-pages-general-cache-confirmation` on iPhone zh-Hans accessibility5 portrait light: three placements
    /// in run 43451019962 and the runs before it; locally the form reported 1642.3 and 1676.7 points of content in two
    /// launches, and the row sat at two heights). Placed again on a page at rest, the part ends at the top, or as
    /// near it as the end of the list allows, in every launch (8 of 8 under load).
    private static func holdPlacement(_ target: Target, in window: UIWindow) async throws {
        for _ in 0..<maximumHolds {
            _ = await HostedWindowCapture.settle(window)
            guard let (element, view) = find(target, in: window),
                  let list = scrollView(holding: view, in: window)
            else { return }
            let frame = list.convert(element.accessibilityFrame, from: window.screen.coordinateSpace)
            guard scroll(list, to: frame.minY - margin - list.adjustedContentInset.top) else { return }
        }
    }

    /// The margin left above the target, so its row's top edge and separator are drawn.
    private static let margin: CGFloat = 16
    /// The most page-sized steps taken looking for a target the list has not built yet.
    private static let maximumSteps = 40
    /// The most waits at the bottom the list reported, for rows it builds as it scrolls to grow its content.
    private static let maximumStalls = 10

    private static func bringIntoView(
        _ target: Target, below: CGFloat, in window: UIWindow, settlingSteps: Bool
    ) async throws {
        var steps = 0
        var stalls = 0
        var placements = 0
        while true {
            if let (element, view) = find(target, in: window) {
                // A page that fits its screen does not scroll: the part is on screen as it is.
                guard let list = scrollView(holding: view, in: window) else { return }
                var frame = list.convert(element.accessibilityFrame, from: window.screen.coordinateSpace)
                frame.size.height += below
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
                // With `settlingSteps` the page is looked through again once it has stopped changing, not after a
                // fixed time: on a loaded host a list had not built the rows a step brought on screen 100 ms later,
                // so a step could pass the target before it was built, and ten 100 ms waits at the bottom were not
                // enough for the rows still to come. `settings-pages-general-translations-confirmation` failed
                // `interaction:not-found` on both attempts on iPad ko accessibility5 landscape light in run
                // 43451019962, and on its first on iPhone accessibility5. The other scenarios step as before: where
                // a step leaves the page decides where their part is placed, and their pictures are kept.
                if settlingSteps {
                    _ = await HostedWindowCapture.settle(window)
                    continue
                }
            }
            try await ContinuousClock().sleep(for: .milliseconds(100))
        }
    }

    /// Leaves a page the step scrolled where a user's scroll would rest it: UIKit snaps a large title to expanded or
    /// collapsed when a drag ends, never partway. A page only a little taller than its window has its bottom inside
    /// the title's collapse, and a part placed there left the title halfway over the first row (General in Korean on
    /// the phone, 47 points: `settings-pages-general-cache-confirmation` and the General pages, candidate runs
    /// 44025665174 and 44137794244). The title is collapsed by moving past the content's end, and the page then
    /// rests where it was placed or at the collapsed title's top, whichever is further down. A page without a large
    /// title returns to where it was placed, and a page the step did not scroll is left as it is.
    static func restWhereTitleSnaps(_ list: UIScrollView) {
        let placed = list.contentOffset.y
        guard placed > -list.adjustedContentInset.top + 0.5 else { return }
        // The bar is laid out by its navigation controller, outside the list: the whole window is laid out.
        let pastEnd = list.contentSize.height + list.bounds.height
        list.setContentOffset(CGPoint(x: list.contentOffset.x, y: pastEnd), animated: false)
        list.window?.layoutIfNeeded()
        let collapsedTop = -list.adjustedContentInset.top
        list.setContentOffset(CGPoint(x: list.contentOffset.x, y: max(placed, collapsedTop)), animated: false)
        list.window?.layoutIfNeeded()
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
        scrollViews(in: reachableView(in: window))
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

    /// What the step may look through: the front-most presentation's view when something is presented, else the
    /// window. A user reaches only the front-most presentation (VoiceOver does not read the page behind a sheet, and
    /// the page cannot be scrolled), so a row of the page behind that shares its label with one of the sheet's is
    /// never the step's target: the Search page lists the saved searches the Quick Search sheet over it lists too.
    private static func reachableView(in window: UIWindow) -> UIView {
        guard let root = window.rootViewController, let front = frontPresentation(over: root)?.view else {
            return window
        }
        return front
    }

    /// The first element the user can reach, depth first, that `target` names, with its view.
    private static func find(_ target: Target, in window: UIWindow) -> (element: NSObject, view: UIView)? {
        let root = reachableView(in: window)
        return element(target, in: root, view: root)
    }

    /// The first element the user can reach, depth first, that `target` names.
    static func element(_ target: Target, in window: UIWindow) -> NSObject? {
        find(target, in: window)?.element
    }

    /// The nearest view at or above the first element the user can reach that `target` names.
    static func view(of target: Target, in window: UIWindow) -> UIView? {
        find(target, in: window)?.view
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
