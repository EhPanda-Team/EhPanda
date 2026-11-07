@testable import AppFeature
import AppModels
import ComposableArchitecture
import DateSeekFeature
import DownloadsFeature
import FavoritesFeature
import FiltersFeature
import Foundation
import QuickSearchFeature
import Resources
@testable import SearchFeature
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

// Search, Quick Search, Filters, Date Seek, Favorites, Downloads and Gallery detail (19-06).
extension ScenarioCatalog {
    static var library: [String: ScenarioFactory] {
        [search, quickSearch, favorites].reduce(into: [:]) { result, group in
            result.merge(group) { first, _ in first }
        }
    }

    private static var search: [String: ScenarioFactory] {
        typealias Page = LibraryScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            "search-root-empty": .init(make: { Page.searchRoot(history: false) }),
            "search-root-history": .init(make: { Page.searchRoot(history: true) }, prepare: artwork),
            "search-clear-confirmation": .init(
                make: { Page.searchRoot(history: true) }, prepare: artwork,
                interact: { try await BrowsingScenarios.activate(Page.removeAllLabel, in: $0) }
            ),
            "search-typing-suggestions": .init(
                make: { Page.searchRoot(history: true, suggestions: true) }, prepare: artwork,
                interact: { try await Page.type(LibraryFixtures.typedTag, in: $0) }
            ),
            "search-results-list": .init(make: { Page.searchResults(.loaded(.row)) }, prepare: artwork),
            "search-results-grid": .init(make: { Page.searchResults(.loaded(.grid)) }, prepare: artwork),
            "search-results-empty": .init(make: { Page.searchResults(.failed(.notFound)) }),
            "search-results-error": .init(make: { Page.searchResults(.failed(.networkingFailed)) })
        ]
    }

    private static var quickSearch: [String: ScenarioFactory] {
        typealias Page = LibraryScenarios
        return [
            "quick-search-list": .init(make: { Page.quickSearch(.list) }),
            "quick-search-empty": .init(make: { Page.quickSearch(.empty) }),
            "quick-search-delete-confirmation": .init(make: { Page.quickSearch(.deleteConfirmation) }),
            "quick-search-word-editor": .init(
                make: { Page.quickSearch(.wordEditor) }, interact: Page.holdCaret
            ),
            "quick-search-filters": .init(make: { Page.filters(confirmingReset: false) }),
            "quick-search-filters-reset-confirmation": .init(make: { Page.filters(confirmingReset: true) }),
            "quick-search-date-seek": .init(make: { Page.dateSeek() }, prepare: TracerScenarios.cacheHomeArtwork)
        ]
    }

    private static var favorites: [String: ScenarioFactory] {
        typealias Page = LibraryScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            "favorites-list": .init(make: { Page.favorites(.loaded(.row)) }, prepare: artwork),
            "favorites-grid": .init(make: { Page.favorites(.loaded(.grid)) }, prepare: artwork),
            "favorites-empty": .init(make: { Page.favorites(.failed(.notFound)) }),
            "favorites-signed-out": .init(signedIn: false, make: { Page.favorites(.loaded(.row)) }),
            "favorites-category-menu": .init(
                make: { Page.favorites(.loaded(.row)) }, prepare: artwork,
                interact: Page.openCategoryMenu
            )
        ]
    }
}

@MainActor
enum LibraryScenarios {
    typealias ListContent = BrowsingScenarios.ListContent

    // MARK: Search

    /// The Recent Searches section's Remove All, the first of the page's two.
    static var removeAllLabel: String { String(localized: .removeAll) }

    /// The Search tab's root: empty, or with recent searches and recently viewed galleries. With `suggestions`,
    /// tag suggestions are switched on and the synthetic translations are loaded.
    static func searchRoot(history: Bool, suggestions: Bool = false) -> AnyView {
        var state = SearchRootReducer.State()
        if history {
            let galleries = Array(TracerScenarios.homeGalleries().prefix(4))
            state.$historyKeywords.withLock({ $0 = LibraryFixtures.historyKeywords })
            state.$galleryHistory.withLock {
                $0 = galleries.enumerated().map { index, gallery in
                    GalleryHistoryEntry(
                        gid: gallery.gid, token: gallery.token,
                        lastOpenDate: PublicVisualFixtures.fixedDate.addingTimeInterval(-3600 * Double(index + 1))
                    )
                }
            }
            state.historyGalleries = galleries
        }
        if suggestions {
            @Shared(.setting) var setting
            $setting.withLock({ $0.showTagsSearchSuggestion = true })
            @Shared(.tagTranslator) var tagTranslator
            $tagTranslator.withLock({ $0 = translator })
        }
        return AnyView(SearchRootView(store: Store(initialState: state, reducer: SearchRootReducer.init)))
    }

    static var translator: TagTranslator {
        let translations = LibraryFixtures.tagTranslations.map { entry in
            TagTranslation(
                namespace: TagNamespace(rawValue: entry.namespace) ?? .other, key: entry.key, value: entry.value
            )
        }
        return TagTranslator(
            translations: Dictionary(uniqueKeysWithValues: translations.map({ ($0.key, $0) }))
        )
    }

    /// Search results for the synthetic keyword.
    static func searchResults(_ content: ListContent) -> AnyView {
        content.storeDisplayMode(.search)
        var state = SearchReducer.State(keyword: LibraryFixtures.resultsKeyword)
        state.galleries = content.galleries()
        state.loadingState = content.loadingState
        return AnyView(NavigationStack {
            SearchView(store: Store(initialState: state, reducer: SearchReducer.init))
        })
    }

    // MARK: Quick Search, Filters, Date Seek

    enum QuickSearchState {
        case list, empty, deleteConfirmation, wordEditor
    }

    static var savedSearches: [SavedSearch] {
        LibraryFixtures.savedSearches.enumerated().map { index, entry in
            SavedSearch(
                id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, UInt8(index))),
                name: entry.name, content: entry.content
            )
        }
    }

    /// Quick Search as the sheet it is, presented over the Search root by the root's own destination state.
    static func quickSearch(_ kind: QuickSearchState) -> AnyView {
        var quickSearch = QuickSearchReducer.State()
        if kind != .empty {
            quickSearch.$savedSearches.withLock({ $0 = savedSearches })
        }
        var root = SearchRootReducer.State()
        root.destination = .quickSearch(quickSearch)
        let store = Store(initialState: root, reducer: SearchRootReducer.init)
        let first = savedSearches.first ?? .empty
        switch kind {
        case .list, .empty:
            break
        case .deleteConfirmation:
            store.send(.destination(.presented(.quickSearch(.deleteSavedSearchButtonTapped(first)))))
        case .wordEditor:
            store.send(.destination(.presented(.quickSearch(.editSavedSearchButtonTapped(first)))))
            store.send(.destination(.presented(.quickSearch(.binding(.set(\.focusedField, .content))))))
        }
        return AnyView(SearchRootView(store: store))
    }

    /// Filters as the sheet it is over the Search root, loaded from the stored filters as the root presents it.
    static func filters(confirmingReset: Bool) -> AnyView {
        var root = SearchRootReducer.State()
        root.destination = .filters(FiltersReducer.State())
        let store = Store(initialState: root, reducer: SearchRootReducer.init)
        store.send(.destination(.presented(.filters(.fetchFilters))))
        if confirmingReset {
            store.send(.destination(.presented(.filters(.resetFiltersButtonTapped))))
        }
        return AnyView(SearchRootView(store: store))
    }

    /// Date Seek over search results: the picker opens on the newest seekable day, the fixed date, in its month.
    static func dateSeek() -> AnyView {
        ListContent.loaded(.row).storeDisplayMode(.search)
        let newest = PublicVisualFixtures.fixedDate
        let navigation = DateSeekNavigation(
            directions: .both(
                newer: URL(string: "https://visual-fixture.invalid/newer")!,
                older: URL(string: "https://visual-fixture.invalid/older")!
            ),
            minimumDate: newest.addingTimeInterval(-86_400 * 365), maximumDate: newest
        )
        var state = SearchReducer.State(keyword: LibraryFixtures.resultsKeyword)
        state.galleries = ListContent.loaded(.row).galleries()
        state.dateSeekNavigation = navigation
        state.destination = .dateSeek(DateSeekReducer.State(navigation: navigation))
        return AnyView(NavigationStack {
            SearchView(store: Store(initialState: state, reducer: SearchReducer.init))
        })
    }

    // MARK: Favorites

    /// The overflow menu's accessibility label, which holds the Favorites category picker.
    static let moreLabel = "More"

    /// Opens the overflow menu. Its category list is taller than the menu, so the menu flashes its scroll
    /// indicator as it opens; the menu is captured once that flash has faded, as a user sees it at rest.
    static func openCategoryMenu(_ window: UIWindow) async throws {
        try await BrowsingScenarios.activate(moreLabel, in: window)
        try await ContinuousClock().sleep(for: .seconds(2))
    }

    /// Favorites in the Library, as the Library shows it on each device.
    static func favorites(_ content: ListContent) -> AnyView {
        content.storeDisplayMode(.favorites)
        var favorites = FavoritesReducer.State()
        favorites.rawGalleries[-1] = content.galleries()
        favorites.rawLoadingState[-1] = content.loadingState
        return AnyView(LibraryView(
            store: Store(
                initialState: LibraryFeature.State(selection: .favorites(-1)), reducer: LibraryFeature.init
            ),
            favoritesStore: Store(initialState: favorites, reducer: FavoritesReducer.init),
            downloadsStore: Store(initialState: DownloadsReducer.State(), reducer: DownloadsReducer.init)
        ))
    }

    // MARK: User steps

    /// Focuses the search field and types `text`, as a user would; the keyboard is a separate window and is not
    /// drawn. Once the suggestions have appeared the caret is held still.
    static func type(_ text: String, in window: UIWindow) async throws {
        let root = try XCTUnwrap(window.rootViewController?.view)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while true {
            if let field = firstView(of: UISearchTextField.self, in: root), field.becomeFirstResponder() {
                // A key at a time: the suggestions list appears with the first character and reads every
                // later change, as it does under a typing user.
                for character in text {
                    field.insertText(String(character))
                    try await clock.sleep(for: .milliseconds(150))
                }
                break
            }
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound("search field") }
            try await clock.sleep(for: .milliseconds(100))
        }
        try await holdCaret(window)
    }

    private static func firstView<View: UIView>(of type: View.Type, in view: UIView) -> View? {
        if let match = view as? View { return match }
        for subview in view.subviews {
            if let match = firstView(of: type, in: subview) { return match }
        }
        return nil
    }

    /// Lets a field focused by the reducer's own state finish focusing, then holds its caret still.
    static func holdCaret(_ window: UIWindow) async throws {
        try await ContinuousClock().sleep(for: .milliseconds(800))
        try await BrowsingScenarios.freezeIndicators(window)
    }
}
