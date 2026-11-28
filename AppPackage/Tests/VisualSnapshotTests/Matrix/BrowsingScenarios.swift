@testable import AppFeature
import AppModels
import ComposableArchitecture
import DownloadsFeature
import FavoritesFeature
import Foundation
@testable import HomeFeature
import Resources
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

@MainActor
enum BrowsingScenarios {
    /// The fewest identical reads a first-launch picture settles on; ``HostedWindowCapture/minimumReads`` now shares
    /// this six-read floor across the matrix so starved runners never settle on two reads (runs 42533872440,
    /// 44025665174 and 44137794244).
    nonisolated static let firstLaunchMinimumReads = HostedWindowCapture.minimumReads

    // MARK: First launch

    static func ageWall(ticked: Bool) -> AnyView {
        var state = FirstLaunchReducer.State()
        state.$setting.withLock {
            $0.ageDeclarationVersion = nil
            $0.analyticsLevel = nil
        }
        state.isDeclarationTicked = ticked
        return AnyView(FirstLaunchGateView(store: Store(initialState: state, reducer: FirstLaunchReducer.init)))
    }

    /// The analytics choice after a confirmed age, with `level` selected (nil: nothing yet; Continue dimmed).
    static func analyticsChoice(_ level: AnalyticsLevel?) -> AnyView {
        var state = FirstLaunchReducer.State()
        state.$setting.withLock {
            $0.ageDeclarationVersion = AgeDeclaration.currentVersion
            $0.analyticsLevel = nil
        }
        state.selectedLevel = level
        return AnyView(FirstLaunchGateView(store: Store(initialState: state, reducer: FirstLaunchReducer.init)))
    }

    // MARK: Home

    /// Home before its sections arrive: `loading` shows the loading card, a failure shows the error view.
    static func home(loading: LoadingState) -> AnyView {
        var state = HomeReducer.State()
        state.popularLoadingState = loading
        state.frontPageLoadingState = loading
        state.toplistsLoadingState = Dictionary(
            uniqueKeysWithValues: ToplistsType.allCases.map({ ($0.categoryIndex, loading) })
        )
        return AnyView(NavigationStack {
            HomeView(store: Store(initialState: state, reducer: HomeReducer.init))
        })
    }

    // MARK: List pages

    /// A list page's content: synthetic galleries in the persisted display mode, or a loading or failed state.
    enum ListContent {
        case loaded(GalleryListDisplayMode)
        case loading
        case failed(AppError)

        var loadingState: LoadingState {
            switch self {
            case .loaded: .idle
            case .loading: .loading
            case .failed(let error): .failed(error)
            }
        }

        @MainActor func galleries(_ count: Int = 6) -> [Gallery] {
            guard case .loaded = self else { return [] }
            return Array(TracerScenarios.homeGalleries().prefix(count))
        }

        /// Stores the display mode the page reads, as `GalleryLayoutPicker` would.
        func storeDisplayMode(_ scope: GalleryListScope) {
            guard case .loaded(let mode) = self else { return }
            @Shared(.setting) var setting
            $setting.withLock({ $0.galleryListPresentation[scope] = mode })
        }
    }

    static func frontPage(_ content: ListContent) -> AnyView {
        content.storeDisplayMode(.frontPage)
        var state = FrontPageReducer.State()
        state.galleries = content.galleries()
        state.loadingState = content.loadingState
        return AnyView(NavigationStack {
            FrontPageView(store: Store(initialState: state, reducer: FrontPageReducer.init))
        })
    }

    static func popular(_ content: ListContent) -> AnyView {
        content.storeDisplayMode(.popular)
        var state = PopularReducer.State()
        state.galleries = content.galleries()
        state.loadingState = content.loadingState
        return AnyView(NavigationStack {
            PopularView(store: Store(initialState: state, reducer: PopularReducer.init))
        })
    }

    static func watched(_ content: ListContent) -> AnyView {
        content.storeDisplayMode(.watched)
        var state = WatchedReducer.State()
        state.galleries = content.galleries()
        state.loadingState = content.loadingState
        return AnyView(NavigationStack {
            WatchedView(store: Store(initialState: state, reducer: WatchedReducer.init))
        })
    }

    /// Toplists keeps three galleries per period (the six-per-period rule is dropped, owner decision).
    static func toplists(_ content: ListContent) -> AnyView {
        content.storeDisplayMode(.toplists)
        var state = ToplistsReducer.State()
        state.rawGalleries[state.type] = content.galleries(3)
        state.rawLoadingState[state.type] = content.loadingState
        return AnyView(NavigationStack {
            ToplistsView(store: Store(initialState: state, reducer: ToplistsReducer.init))
        })
    }

    /// History with the synthetic galleries viewed one hour apart, or with nothing viewed (`mode` nil).
    static func history(_ mode: GalleryListDisplayMode?) -> AnyView {
        let content: ListContent = mode.map(ListContent.loaded) ?? .failed(.notFound)
        content.storeDisplayMode(.history)
        let galleries = content.galleries()
        var state = HistoryReducer.State()
        state.$galleryHistory.withLock {
            $0 = galleries.enumerated().map { index, gallery in
                GalleryHistoryEntry(
                    gid: gallery.gid, token: gallery.token,
                    lastOpenDate: PublicVisualFixtures.fixedDate.addingTimeInterval(-3600 * Double(index + 1))
                )
            }
        }
        state.galleries = galleries
        state.fetchedCount = galleries.count
        state.loadingState = content.loadingState
        return AnyView(NavigationStack {
            HistoryView(store: Store(initialState: state, reducer: HistoryReducer.init))
        })
    }

    // MARK: Shell

    /// The Library: a sidebar beside its detail on iPad, a title menu over the selected source on iPhone.
    static func library(selection: LibraryGroup?) -> AnyView {
        var favorites = FavoritesReducer.State()
        favorites.rawGalleries[-1] = TracerScenarios.homeGalleries()
        favorites.rawLoadingState[-1] = .idle
        return AnyView(LibraryView(
            store: Store(initialState: LibraryFeature.State(selection: selection), reducer: LibraryFeature.init),
            favoritesStore: Store(initialState: favorites, reducer: FavoritesReducer.init),
            downloadsStore: Store(initialState: DownloadsReducer.State(), reducer: DownloadsReducer.init)
        ))
    }

    // MARK: User steps

    /// Activates the first element labelled `label`, as VoiceOver's double tap would (a menu opens).
    static func activate(_ label: String, in window: UIWindow) async throws {
        let root = try XCTUnwrap(window.rootViewController?.view)
        let clock = ContinuousClock()
        let budget = StepBudget(.seconds(3))
        while true {
            if let element = element(labelled: label, in: root) {
                if element.accessibilityActivate() { return }
                // A toolbar button is a UIKit bar button, whose activation VoiceOver performs as a tap.
                if let control = element as? UIControl {
                    control.performPrimaryAction()
                    return
                }
            }
            guard !budget.isSpent else { throw AccessibilityActionDriver.Failure.notFound(label) }
            try await clock.sleep(for: .milliseconds(100))
        }
    }

    /// A user step's window that never came to rest; the motion it last read, and how long the wait took
    /// (``StepFailure/init(reason:budget:)``: `still-moving:<motion> waited=… turned=… polls=…`).
    struct StillMoving: CaptureStepFailure {
        let motion: String
        var detail = ""

        var reason: String { "still-moving:\(motion)" + detail }
    }

    /// A user step that did not reach its state by its deadline, and how far it got.
    struct StepFailure: CaptureStepFailure {
        let reason: String
    }

    /// How long this process has run, from the kernel's record of its start, or `nil` when it cannot be read.
    nonisolated static var processSeconds: Double? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, u_int(name.count), &info, &size, nil, 0) == 0 else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        return Date().timeIntervalSince1970 - (Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000)
    }

    /// How long ``waitForRest(_:within:)`` waits for a window to come to rest.
    static let defaultRestWait: Duration = .seconds(10)

    /// Waits until ``HostedWindowCapture/motion(in:)`` reads nothing three times in a row, 100 ms apart, for at most
    /// `span` (``defaultRestWait``) of time the main run loop turned (``StepBudget``); a window still moving by then
    /// fails the step.
    ///
    /// The span used to be wall-clock time. An animation is timed from the commit that starts it, so one whose commit
    /// waited out a stop of the main thread began after the stop, and was read as moving at the first look after it,
    /// with the span already spent. `comments-post-filled` on iPad zh-Hans accessibility5 failed
    /// `still-moving:animation:UIDropShadowView:position` in run 43621303643, in a shard whose other steps stopped
    /// for 34 s; the reason did not say how often it had looked, and now does.
    static func waitForRest(_ window: UIWindow, within span: Duration = defaultRestWait) async throws {
        var budget = StepBudget(span)
        var quiet = 0
        while quiet < 3 {
            budget.look()
            let motion = HostedWindowCapture.motion(in: window)
            quiet = motion == nil ? quiet + 1 : 0
            if let motion, budget.isSpent {
                throw StillMoving(motion: motion, detail: budget.failure("").reason)
            }
            try await ContinuousClock().sleep(for: .milliseconds(100))
        }
    }

    /// Holds the hosted view at a fixed point: once the window is at rest, the hosted view's layer clock is stopped
    /// and every animation that repeats for as long as its view shows (an indeterminate indicator's spin, a caret's
    /// blink) is restarted at its first frame. The hosted controller is replaced for every attempt, so the clock
    /// never stays stopped.
    ///
    /// Stopping the clock alone held the indicator wherever its animation happened to be: an animation committed
    /// before the stop showed its model value, one committed after it its first frame, and an appearing loading card
    /// could be held part-way in. Which one a run got depended on the host's load (`home-loading` changed on the
    /// hosted runner in run 42475531683; locally `home-loading`, `front-page-loading` and `popular-loading` each
    /// had two byte-different states). The rest wait lets every commit and finite transition finish first.
    static func freezeIndicators(_ window: UIWindow) async throws {
        try await waitForRest(window)
        let layer = try XCTUnwrap(window.rootViewController?.view.layer)
        layer.speed = 0
        layer.timeOffset = 0
        restartRepeatingAnimations(in: layer)
    }

    /// Stops the blink of every caret in `window`, so each is drawn solid, as in the blink's shown half.
    ///
    /// Stopping the layer clock does not hold a caret: UIKit's blink adds a new animation on a timer of its own at
    /// each turn, and under a stopped clock each new one shows its first frame, so a frozen caret still turned on and
    /// off between reads. Pictures held either half and changed from run to run (`comments-post-empty`,
    /// `comments-post-filled`, `search-typing-suggestions`; run 43451019962 against the run before it).
    static func stopCaretBlink(in window: UIWindow) {
        for cursor in views(in: window).compactMap({ $0 as? any UIView & UITextCursorView }) {
            cursor.isBlinking = false
        }
    }

    private static func views(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(views(in:))
    }

    private static func restartRepeatingAnimations(in layer: CALayer) {
        let now = layer.convertTime(CACurrentMediaTime(), from: nil)
        for key in layer.animationKeys() ?? [] {
            guard let animation = layer.animation(forKey: key), HostedWindowCapture.repeatsForever(animation),
                  let restarted = animation.copy() as? CAAnimation else { continue }
            restarted.beginTime = now
            restarted.timeOffset = 0
            restarted.fillMode = .both
            layer.add(restarted, forKey: key)
        }
        for sublayer in layer.sublayers ?? [] {
            restartRepeatingAnimations(in: sublayer)
        }
    }

    private static func element(labelled label: String, in element: NSObject, depth: Int = 0) -> NSObject? {
        guard depth < 64 else { return nil }
        if element.isAccessibilityElement, element.accessibilityLabel == label { return element }
        var children: [NSObject] = []
        if let elements = element.accessibilityElements as? [NSObject] {
            children += elements
        } else {
            let count = element.accessibilityElementCount()
            if count > 0, count != NSNotFound {
                children += (0..<count).compactMap({ element.accessibilityElement(at: $0) as? NSObject })
            }
        }
        if let view = element as? UIView {
            children += view.subviews
        }
        for child in children {
            if let found = Self.element(labelled: label, in: child, depth: depth + 1) { return found }
        }
        return nil
    }
}

extension BrowsingScenarios.StepFailure {
    /// A step's failure that also says how long its attempt waited on the wall clock, how long the main run loop
    /// turned meanwhile (``StepBudget``), how many times it looked (a host that froze looks few times in a long wait),
    /// the longest stall in it (``MainThreadWatch``: `blocked`, the main thread held while the process ran, or
    /// `frozen`, the process not run) and how long the test process had run:
    /// `<reason> waited=50.3s turned=10.0s polls=99 stall=40.1s/frozen process=812s`.
    @MainActor
    init(reason: String, budget: StepBudget) {
        let stall = budget.longestStall.map({ String(format: " stall=%.1fs/%@", $0.seconds, $0.kind) }) ?? ""
        self.init(
            reason: reason, waited: budget.waited, turned: budget.turned, polls: budget.polls, stall: stall
        )
    }

    init(reason: String, waited: Duration, turned: Duration, polls: Int, stall: String = "") {
        var text = reason + String(
            format: " waited=%.1fs turned=%.1fs polls=%d", MainThreadWatch.seconds(waited),
            MainThreadWatch.seconds(turned), polls
        ) + stall
        if let process = BrowsingScenarios.processSeconds {
            text += String(format: " process=%.0fs", process)
        }
        self.init(reason: text)
    }
}
