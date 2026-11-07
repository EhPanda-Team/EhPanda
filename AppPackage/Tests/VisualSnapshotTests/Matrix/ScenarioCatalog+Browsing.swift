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

    private static var firstLaunch: [String: ScenarioFactory] {
        [
            "agewall-unticked": .init(signedIn: false, make: { BrowsingScenarios.ageWall(ticked: false) }),
            "agewall-ticked": .init(signedIn: false, make: { BrowsingScenarios.ageWall(ticked: true) }),
            "analytics-choice-none": .init(signedIn: false, make: { BrowsingScenarios.analyticsChoice(nil) }),
            "analytics-choice-minimal": .init(signedIn: false, make: { BrowsingScenarios.analyticsChoice(.minimal) }),
            "analytics-choice-basic": .init(signedIn: false, make: { BrowsingScenarios.analyticsChoice(.basic) }),
            "analytics-choice-full": .init(signedIn: false, make: { BrowsingScenarios.analyticsChoice(.full) })
        ]
    }

    private static var shell: [String: ScenarioFactory] {
        [
            "shell-library-sidebar": .init(make: { BrowsingScenarios.library(selection: nil) }),
            "shell-library-title-menu": .init(
                make: { BrowsingScenarios.library(selection: .favorites(-1)) },
                prepare: TracerScenarios.cacheHomeArtwork,
                interact: { try await BrowsingScenarios.activate(String(localized: .RLocalizable.library), in: $0) }
            )
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
            "front-page-search": .init(
                make: { Page.frontPage(.loaded(.row), keyword: Page.searchKeyword) }, prepare: artwork,
                interact: Page.focusSearchField
            )
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
    static func focusSearchField(_ window: UIWindow) async throws {
        let root = try XCTUnwrap(window.rootViewController?.view)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while true {
            if let field = firstView(of: UISearchTextField.self, in: root), field.becomeFirstResponder() {
                try await clock.sleep(for: .milliseconds(800))
                try await freezeIndicators(window)
                return
            }
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound("search field") }
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

    /// Stops the hosted view's layer clock, so an indeterminate progress indicator holds one frame and the window
    /// settles. The hosted controller is replaced for every attempt, so the clock never stays stopped.
    static func freezeIndicators(_ window: UIWindow) async throws {
        let layer = try XCTUnwrap(window.rootViewController?.view.layer)
        layer.speed = 0
        layer.timeOffset = 0
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
