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
        firstLaunch.merging(shell, uniquingKeysWith: { first, _ in first })
            .merging(home, uniquingKeysWith: { first, _ in first })
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
            if let element = element(labelled: label, in: root), element.accessibilityActivate() {
                return
            }
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound(label) }
            try await clock.sleep(for: .milliseconds(100))
        }
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
