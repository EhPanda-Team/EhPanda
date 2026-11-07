@testable import AppFeature
import AppModels
import ComposableArchitecture
import DateSeekFeature
import DetailFeature
import DownloadsFeature
import FavoritesFeature
import FiltersFeature
import Foundation
import Kingfisher
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
        [search, quickSearch, favorites, downloads, galleryDetail].reduce(into: [:]) { result, group in
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
    private static var downloads: [String: ScenarioFactory] {
        typealias Page = LibraryScenarios
        let artwork = Page.cacheDownloadArtwork
        let completed = LibraryFixtures.completedDownloads
        return [
            "downloads-list": .init(make: { Page.downloads(completed, mode: .row) }, prepare: artwork),
            "downloads-grid": .init(make: { Page.downloads(completed, mode: .grid) }, prepare: artwork),
            "downloads-empty": .init(make: { Page.downloads([], mode: .row) }),
            "downloads-active-failed": .init(
                make: { Page.downloads(LibraryFixtures.activeFailedDownloads, mode: .row) }, prepare: artwork
            ),
            "downloads-delete-confirmation": .init(
                make: { Page.downloads(completed, mode: .row, confirming: .delete) }, prepare: artwork
            ),
            "downloads-move-confirmation": .init(
                make: { Page.downloads(completed, mode: .row, confirming: .move) }, prepare: artwork
            ),
            "downloads-inspector": .init(
                make: { Page.downloads(completed, mode: .row, inspecting: 0) }, prepare: artwork
            ),
            "downloads-inspector-error": .init(
                make: { Page.downloads(LibraryFixtures.activeFailedDownloads, mode: .row, inspecting: 1) },
                prepare: artwork
            )
        ]
    }

    private static var galleryDetail: [String: ScenarioFactory] {
        typealias Page = LibraryScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            "gallery-detail-loaded": .init(make: { try Page.detail(.loaded) }, prepare: artwork),
            "gallery-detail-loading": .init(
                make: { try Page.detail(.loading) }, prepare: artwork, interact: BrowsingScenarios.freezeIndicators
            ),
            "gallery-detail-error": .init(make: { try Page.detail(.error) }, prepare: artwork),
            "gallery-detail-rating": .init(make: { try Page.detail(.rating) }, prepare: artwork),
            "gallery-detail-downloading": .init(make: { try Page.detail(.downloading) }, prepare: artwork),
            "gallery-detail-delete-download-confirmation": .init(
                make: { try Page.detail(.deleteDownloadConfirmation) }, prepare: artwork
            ),
            "gallery-detail-retry-confirmation": .init(
                make: { try Page.detail(.retryConfirmation) }, prepare: artwork
            ),
            "gallery-detail-sheet": .init(make: { try Page.gallerySheet() }, prepare: artwork)
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

    // MARK: Downloads

    enum DownloadConfirmation {
        case delete, move
    }

    /// Kingfisher cache keys for the `downloads-finite` covers, which the records use as their local covers.
    static func downloadCoverURL(_ index: Int) -> URL? {
        URL(string: "https://visual-fixture.invalid/downloads/\(index).png")
    }

    /// Fills the image cache with the `downloads-finite` covers, so no cover loads while the window settles.
    static func cacheDownloadArtwork() async throws {
        for (index, fixture) in PublicVisualFixtures.downloadGalleries.enumerated() {
            guard let url = downloadCoverURL(index) else { continue }
            let image = PublicVisualFixtures.artwork(marker: fixture.gid, colorIndex: fixture.colorIndex)
            try await ImageCache.default.store(image, forKey: url.absoluteString, toDisk: false)
        }
    }

    /// A download record of `gallery` with `completedPages` of its pages landed, in the first synthetic folder.
    static func download(
        _ gallery: Gallery, coverURL: URL?, status: DownloadDisplayStatus, completedPages: Int
    ) -> DownloadedGallery {
        let pages = Dictionary(uniqueKeysWithValues: (1...gallery.pageCount).map { page in
            (page, page <= completedPages ? "public-page-hash-\(page)" : "")
        })
        let manifest = DownloadManifest(
            gid: gallery.gid, host: .ehentai, token: gallery.token, title: gallery.title, jpnTitle: nil,
            category: gallery.category, language: .english, remoteCoverURL: coverURL,
            uploader: gallery.uploader, tags: gallery.tags, postedDate: gallery.postedDate, rating: gallery.rating,
            pages: pages
        )
        let folder = LibraryFixtures.downloadFolders.first ?? ""
        return DownloadedGallery(
            manifest: manifest, folderURL: URL(filePath: "/visual-fixture/\(folder)/\(gallery.gid)"),
            folderName: folder, localCoverURL: coverURL, localPageURLs: [:],
            modificationDate: PublicVisualFixtures.fixedDate, displayStatus: status,
            lastError: status == .error
                ? DownloadFailure(code: .networkingFailed, message: AppError.networkingFailed.alertText) : nil
        )
    }

    static func downloadStatus(_ status: DownloadRecordFixture.Status) -> DownloadDisplayStatus {
        switch status {
        case .completed: .completed
        case .active: .active
        case .error: .error
        case .inactive: .inactive
        }
    }

    /// The records over the `downloads-finite` galleries.
    static func downloadRecords(_ records: [DownloadRecordFixture]) -> [DownloadedGallery] {
        zip(PublicVisualFixtures.downloadGalleries.enumerated(), records).map { entry, record in
            let (index, fixture) = entry
            let gallery = Gallery(
                gid: fixture.gid, token: fixture.token, title: fixture.title, rating: 4.5, tags: [],
                category: .doujinshi, uploader: "Visual Fixture", pageCount: fixture.pageCount,
                postedDate: PublicVisualFixtures.fixedDate, coverURL: downloadCoverURL(index), galleryURL: nil
            )
            return download(
                gallery, coverURL: downloadCoverURL(index), status: downloadStatus(record.status),
                completedPages: record.completedPages
            )
        }
    }

    /// The inspection of `download`: its landed pages downloaded, the rest failed if it failed, pending otherwise.
    static func inspection(_ download: DownloadedGallery) -> DownloadInspection {
        let failed = download.displayStatus == .error
        return DownloadInspection(
            download: download, coverURL: download.coverURL,
            pages: (1...download.pageCount).map { page in
                if page <= download.completedPageCount {
                    return DownloadPageInspection(index: page, status: .downloaded)
                }
                return DownloadPageInspection(
                    index: page, status: failed ? .failed : .pending, failure: failed ? download.lastError : nil
                )
            }
        )
    }

    /// Downloads in the Library, in the first synthetic folder, as the Library shows it on each device. A
    /// confirmation is the first row's own dialog; an inspector is the sheet the list presents for a record.
    static func downloads(
        _ records: [DownloadRecordFixture], mode: GalleryListDisplayMode,
        confirming confirmation: DownloadConfirmation? = nil, inspecting inspected: Int? = nil
    ) -> AnyView {
        ListContent.loaded(mode).storeDisplayMode(.downloads)
        let folder = LibraryFixtures.downloadFolders.first ?? ""
        var state = DownloadsReducer.State()
        state.folders = LibraryFixtures.downloadFolders
        state.folderFilter = .folder(folder)
        state.downloads = downloadRecords(records)
        state.loadingState = .idle
        state.hasLoadedInitialDownloads = true
        if let inspected, let download = state.downloads.dropFirst(inspected).first {
            var inspector = DownloadInspectorReducer.State(gid: download.gid)
            inspector.inspection = inspection(download)
            inspector.stableInspection = inspector.inspection
            inspector.loadingState = .idle
            state.destination = .inspector(inspector)
        }
        let store = Store(initialState: state, reducer: DownloadsReducer.init)
        if let confirmation, let first = state.downloads.first {
            let destinations = LibraryFixtures.downloadFolders.filter({ $0 != first.folderName })
            store.send(.rows(.element(
                id: first.id,
                action: confirmation == .delete ? .deleteButtonTapped : .moveButtonTapped(destinations: destinations)
            )))
        }
        return AnyView(LibraryView(
            store: Store(
                initialState: LibraryFeature.State(selection: .downloads(.folder(folder))),
                reducer: LibraryFeature.init
            ),
            favoritesStore: Store(initialState: FavoritesReducer.State(), reducer: FavoritesReducer.init),
            downloadsStore: store
        ))
    }

    // MARK: Gallery detail

    enum DetailState {
        case loaded, loading, error, rating, downloading, deleteDownloadConfirmation, retryConfirmation
    }

    /// The synthetic gallery's detail, with invented counts.
    static func galleryDetail(_ gallery: Gallery) -> GalleryDetail {
        GalleryDetail(
            gid: gallery.gid, title: gallery.title, isFavorited: false, visibility: .yes, rating: gallery.rating,
            userRating: 0, ratingCount: 120, category: gallery.category, language: .english,
            uploader: gallery.uploader ?? "", postedDate: gallery.postedDate, coverURL: gallery.coverURL,
            favoritedCount: 42, pageCount: gallery.pageCount, sizeCount: 12.5, sizeType: "MB", torrentCount: 0
        )
    }

    static var detailTags: [GalleryTag] {
        LibraryFixtures.detailTags.map { entry in
            GalleryTag(rawNamespace: entry.namespace, contents: entry.words.map { word in
                GalleryTag.Content(rawNamespace: entry.namespace, text: word, isVotedUp: false, isVotedDown: false)
            })
        }
    }

    /// The detail reducer's state for the first synthetic gallery: seeded from its download record when the
    /// state has one, as the Downloads tab seeds it, and loaded unless the state is the load itself.
    static func detailState(_ kind: DetailState) throws -> DetailReducer.State {
        let gallery = try XCTUnwrap(TracerScenarios.homeGalleries().first)
        var state: DetailReducer.State
        switch kind {
        case .downloading, .deleteDownloadConfirmation, .retryConfirmation:
            let status: DownloadDisplayStatus = switch kind {
            case .downloading: .active
            case .retryConfirmation: .error
            default: .completed
            }
            let pages = kind == .downloading ? LibraryFixtures.detailDownloadPages : gallery.pageCount
            state = DetailReducer.State(seededFrom: download(
                gallery, coverURL: gallery.coverURL, status: status,
                completedPages: kind == .retryConfirmation ? pages / 2 : pages
            ))
        default:
            state = DetailReducer.State(gallery: gallery)
        }
        state.downloadFolders = LibraryFixtures.downloadFolders
        state.hasLoadedDownloadBadge = true
        switch kind {
        case .loading:
            state.loadingState = .loading
        case .error:
            state.loadingState = .failed(.networkingFailed)
        default:
            state.galleryDetail = galleryDetail(gallery)
            state.galleryTags = detailTags
        }
        if kind == .rating {
            state.showsUserRating = true
            state.userRating = 7
        }
        return state
    }

    /// The gallery page pushed onto a stack, as an iPhone shows it; a confirmation is the reducer's own alert.
    static func detail(_ kind: DetailState) throws -> AnyView {
        let state = try detailState(kind)
        let store = Store(initialState: state, reducer: DetailReducer.init)
        switch kind {
        case .deleteDownloadConfirmation:
            store.send(.deleteDownloadButtonTapped)
        case .retryConfirmation:
            store.send(.retryDownloadButtonTapped(.redownload))
        default:
            break
        }
        return AnyView(NavigationStack {
            DetailView(store: store, gid: state.gid)
        })
    }

    /// The gallery as the sheet the app presents over a tab where the window is regular in both dimensions.
    static func gallerySheet() throws -> AnyView {
        var app = AppReducer.State()
        app.tabBarState.tabBarItemType = .search
        app.presentationState.gallery = GallerySheetFeature.State(detail: try detailState(.loaded))
        return AnyView(TabBarView(store: Store(initialState: app, reducer: AppReducer.init)))
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
