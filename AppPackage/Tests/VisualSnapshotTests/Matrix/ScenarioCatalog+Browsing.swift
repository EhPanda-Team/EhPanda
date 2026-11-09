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

// First launch, the shell, Home, Front Page, Popular, Watched, Toplists and History (19-05).
extension ScenarioCatalog {
    static var browsing: [String: ScenarioFactory] {
        [firstLaunch, shell, home, frontPage, popular, watched, toplists, history].reduce(into: [:]) { result, group in
            result.merge(group) { first, _ in first }
        }
    }

    /// The fewest identical reads a first-launch picture settles on. These pages are hosted first in a process and
    /// end in a Liquid Glass button; on run 42533872440 two candidates settled on two reads and held that button
    /// 1/255 off the reference, so the glass is given longer to finish than other pages.
    static let firstLaunchMinimumReads = 6

    private static var firstLaunch: [String: ScenarioFactory] {
        typealias Page = BrowsingScenarios
        let reads = firstLaunchMinimumReads
        return [
            "agewall-unticked": .init(signedIn: false, make: { Page.ageWall(ticked: false) }, minimumReads: reads),
            "agewall-ticked": .init(signedIn: false, make: { Page.ageWall(ticked: true) }, minimumReads: reads),
            "analytics-choice-none": .init(
                signedIn: false, make: { Page.analyticsChoice(nil) }, minimumReads: reads
            ),
            "analytics-choice-minimal": .init(
                signedIn: false, make: { Page.analyticsChoice(.minimal) }, minimumReads: reads
            ),
            "analytics-choice-basic": .init(
                signedIn: false, make: { Page.analyticsChoice(.basic) }, minimumReads: reads
            ),
            "analytics-choice-full": .init(
                signedIn: false, make: { Page.analyticsChoice(.full) }, minimumReads: reads
            )
        ]
    }

    private static var shell: [String: ScenarioFactory] {
        [
            "shell-library-sidebar": .init(make: { BrowsingScenarios.library(selection: nil) }),
            // Favorites under the menu hides its search field on scroll, so the list is brought to rest at its top
            // first, as the Favorites scenarios are: hosted early in a process it kept the field 2 points short
            // (run 42455556948, every text size but xSmall).
            "shell-library-title-menu": ScenarioFactory(
                make: { BrowsingScenarios.library(selection: .favorites(-1)) },
                prepare: TracerScenarios.cacheHomeArtwork,
                interact: { try await BrowsingScenarios.activate(String(localized: .RLocalizable.library), in: $0) }
            ).restingAtTop()
        ]
    }

    private static var home: [String: ScenarioFactory] {
        [
            "home-populated": .init(make: { TracerScenarios.home() }, prepare: TracerScenarios.cacheHomeArtwork),
            "home-loading": .init(
                make: { BrowsingScenarios.home(loading: .loading) }, interact: BrowsingScenarios.freezeIndicators
            ),
            "home-error": .init(make: { BrowsingScenarios.home(loading: .failed(.networkingFailed)) })
        ]
    }

    private static var frontPage: [String: ScenarioFactory] {
        typealias Page = BrowsingScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            "front-page-list": .init(make: { Page.frontPage(.loaded(.row)) }, prepare: artwork),
            "front-page-grid": .init(make: { Page.frontPage(.loaded(.grid)) }, prepare: artwork),
            "front-page-loading": .init(make: { Page.frontPage(.loading) }, interact: Page.freezeIndicators),
            "front-page-error": .init(make: { Page.frontPage(.failed(.networkingFailed)) }),
            "front-page-empty": .init(make: { Page.frontPage(.failed(.notFound)) }),
            "front-page-search": ScenarioFactory(
                make: { Page.frontPage(.loaded(.row), keyword: Page.searchKeyword) }, prepare: artwork,
                interact: Page.focusSearchField
            ).restingAtTop()
        ]
    }

    private static var popular: [String: ScenarioFactory] {
        typealias Page = BrowsingScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            "popular-list": .init(make: { Page.popular(.loaded(.row)) }, prepare: artwork),
            "popular-grid": .init(make: { Page.popular(.loaded(.grid)) }, prepare: artwork),
            "popular-loading": .init(make: { Page.popular(.loading) }, interact: Page.freezeIndicators),
            "popular-error": .init(make: { Page.popular(.failed(.networkingFailed)) })
        ]
    }

    private static var watched: [String: ScenarioFactory] {
        typealias Page = BrowsingScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            "watched-list": .init(make: { Page.watched(.loaded(.row)) }, prepare: artwork),
            "watched-grid": .init(make: { Page.watched(.loaded(.grid)) }, prepare: artwork),
            "watched-empty": .init(make: { Page.watched(.failed(.notFound)) }),
            "watched-error": .init(make: { Page.watched(.failed(.networkingFailed)) }),
            "watched-signed-out": .init(signedIn: false, make: { Page.watched(.loaded(.row)) }, prepare: artwork)
        ]
    }

    private static var toplists: [String: ScenarioFactory] {
        typealias Page = BrowsingScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            "toplists-list": .init(make: { Page.toplists(.loaded(.row)) }, prepare: artwork),
            "toplists-grid": .init(make: { Page.toplists(.loaded(.grid)) }, prepare: artwork),
            "toplists-error": .init(make: { Page.toplists(.failed(.networkingFailed)) }),
            "toplists-period-menu": .init(
                make: { Page.toplists(.loaded(.row)) }, prepare: artwork,
                interact: { try await Page.activate(String(localized: .timeRange), in: $0) }
            )
        ]
    }

    private static var history: [String: ScenarioFactory] {
        typealias Page = BrowsingScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            "history-list": .init(make: { Page.history(.row) }, prepare: artwork),
            "history-grid": .init(make: { Page.history(.grid) }, prepare: artwork),
            "history-empty": .init(make: { Page.history(nil) }),
            "history-clear-confirmation": .init(
                make: { Page.history(.row) }, prepare: artwork,
                interact: { try await Page.activate(String(localized: .RLocalizable.clear), in: $0) }
            )
        ]
    }
}

@MainActor
enum BrowsingScenarios {
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

    /// Typed into the Front Page filter field; it matches one synthetic gallery.
    static let searchKeyword = "Gallery 2"

    static func frontPage(_ content: ListContent, keyword: String = "") -> AnyView {
        content.storeDisplayMode(.frontPage)
        var state = FrontPageReducer.State()
        state.galleries = content.galleries()
        state.loadingState = content.loadingState
        state.keyword = keyword
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

    /// Toplists keeps three galleries per period (the six-per-period rule is dropped, owner msg 1949).
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
        let deadline = clock.now.advanced(by: .seconds(3))
        while true {
            if let element = element(labelled: label, in: root) {
                if element.accessibilityActivate() { return }
                // A toolbar button is a UIKit bar button, whose activation VoiceOver performs as a tap.
                if let control = element as? UIControl {
                    control.performPrimaryAction()
                    return
                }
            }
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound(label) }
            try await clock.sleep(for: .milliseconds(100))
        }
    }

    /// Focuses the page's search field, as a tap on it would, then holds the caret's blink still once the search
    /// bar has finished activating. The keyboard is a separate window and is not drawn.
    ///
    /// The freeze waits until the window is at rest (``HostedWindowCapture/motion(in:)``), not a fixed time: the
    /// search bar's activation moves the list and scrolls the field's text to the caret, and a freeze in the middle
    /// of either holds a different list offset or text offset on a loaded host (run 42455556948).
    ///
    /// `becomeFirstResponder()` returning true is not enough either: on the loaded hosted runner the activation took
    /// the focus back, and both attempts captured an unfocused field with its text scrolled to the start and no
    /// caret (run 42475531683). The field is focused again until it is still first responder after the window has
    /// come to rest twice in a row.
    ///
    /// On the loaded hosted runner the 15 s this step used to have ran out in 3 of 5 compare invocations of run
    /// 42533872440. The step now has ``focusDeadline``, and a window that has not come to rest within one
    /// ``waitForRest(_:)`` is waited for again until that deadline instead of failing the step at once.
    static func focusSearchField(_ window: UIWindow) async throws {
        try await focusSearchField(window, deadline: focusDeadline)
    }

    /// How long ``focusSearchField(_:)`` may take before it fails the attempt with `interaction`.
    static let focusDeadline: Duration = .seconds(40)

    static func focusSearchField(_ window: UIWindow, deadline span: Duration) async throws {
        let root = try XCTUnwrap(window.rootViewController?.view)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: span)
        var held = 0
        while held < 2 {
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound("focused search field") }
            guard let field = firstView(of: UISearchTextField.self, in: root) else {
                try await clock.sleep(for: .milliseconds(100))
                continue
            }
            if field.isFirstResponder {
                held += 1
            } else {
                held = 0
                _ = field.becomeFirstResponder()
            }
            try await clock.sleep(for: .milliseconds(held == 0 ? 800 : 300))
            do {
                try await waitForRest(window)
            } catch let moving as StillMoving {
                // Not yet at rest: the focus is not counted as held, and the loop reads again until the deadline.
                guard clock.now < deadline else { throw moving }
                held = 0
            }
        }
        try await freezeIndicators(window)
    }

    /// A user step's window that never came to rest; the motion it last read.
    struct StillMoving: Error {
        let motion: String
    }

    /// Waits until ``HostedWindowCapture/motion(in:)`` reads nothing three times in a row, 100 ms apart, for at most
    /// 10 s; a window still moving by then fails the step.
    static func waitForRest(_ window: UIWindow) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        var quiet = 0
        while quiet < 3 {
            let motion = HostedWindowCapture.motion(in: window)
            quiet = motion == nil ? quiet + 1 : 0
            if let motion, clock.now >= deadline { throw StillMoving(motion: motion) }
            try await clock.sleep(for: .milliseconds(100))
        }
    }

    private static func firstView<View: UIView>(of type: View.Type, in view: UIView) -> View? {
        if let match = view as? View { return match }
        for subview in view.subviews {
            if let match = firstView(of: type, in: subview) { return match }
        }
        return nil
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
