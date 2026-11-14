@testable import AppFeature
import AppModels
import ComposableArchitecture
import DateSeekFeature
@testable import DetailFeature
import DownloadsFeature
import FavoritesFeature
@testable import FiltersFeature
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
                interact: { try await Page.type(LibraryFixtures.typedTag, in: $0, until: Page.firstSuggestion) }
            ),
            "search-results-list": ScenarioFactory(
                make: { Page.searchResults(.loaded(.row)) }, prepare: artwork
            ).restingAtTop(),
            "search-results-grid": ScenarioFactory(
                make: { Page.searchResults(.loaded(.grid)) }, prepare: artwork
            ).restingAtTop(),
            "search-results-empty": ScenarioFactory(make: { Page.searchResults(.failed(.notFound)) }).restingAtTop(),
            "search-results-error": ScenarioFactory(
                make: { Page.searchResults(.failed(.networkingFailed)) }
            ).restingAtTop()
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
            "quick-search-filters-reset-confirmation": .init(
                make: { Page.filters(confirmingReset: true) },
                interact: RevealStep.reveal(.label(String(localized: .resetFilters)))
            ),
            "quick-search-date-seek": .init(make: { Page.dateSeek() }, prepare: TracerScenarios.cacheHomeArtwork)
        ]
    }

    private static var favorites: [String: ScenarioFactory] {
        typealias Page = LibraryScenarios
        let artwork = TracerScenarios.cacheHomeArtwork
        let factories: [String: ScenarioFactory] = [
            "favorites-list": .init(make: { Page.favorites(.loaded(.row)) }, prepare: artwork),
            "favorites-grid": .init(make: { Page.favorites(.loaded(.grid)) }, prepare: artwork),
            "favorites-empty": .init(make: { Page.emptyFavorites() }),
            "favorites-signed-out": .init(signedIn: false, make: { Page.favorites(.loaded(.row)) }),
            "favorites-category-menu": .init(
                make: { Page.favorites(.loaded(.row)) }, prepare: artwork,
                interact: Page.openCategoryMenu
            )
        ]
        return factories.mapValues({ $0.restingAtTop() })
    }

    private static var downloads: [String: ScenarioFactory] {
        typealias Page = LibraryScenarios
        let artwork = Page.cacheDownloadArtwork
        let completed = LibraryFixtures.completedDownloads
        let factories: [String: ScenarioFactory] = [
            "downloads-list": .init(make: { Page.downloads(completed, mode: .row) }, prepare: artwork),
            "downloads-grid": .init(make: { Page.downloads(completed, mode: .grid) }, prepare: artwork),
            "downloads-empty": .init(make: { Page.downloads([], mode: .row) }),
            "downloads-active-failed": .init(
                make: { Page.downloads(LibraryFixtures.activeFailedDownloads, mode: .row) }, prepare: artwork
            ),
            "downloads-delete-confirmation": .init(
                make: { Page.downloads(completed, mode: .row, confirming: .delete) }, prepare: artwork,
                interact: Page.tapHeldRow
            ),
            "downloads-move-confirmation": .init(
                make: { Page.downloads(completed, mode: .row, confirming: .move) }, prepare: artwork,
                interact: Page.tapHeldRow
            ),
            "downloads-inspector": .init(
                make: { Page.downloads(completed, mode: .row, inspecting: 0) }, prepare: artwork
            ),
            "downloads-inspector-error": .init(
                make: { Page.downloads(LibraryFixtures.activeFailedDownloads, mode: .row, inspecting: 1) },
                prepare: artwork
            )
        ]
        return factories.mapValues({ $0.restingAtTop() })
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
            // At accessibility5 the rating row is below the fold (run 43403534542): the page is scrolled to it.
            "gallery-detail-rating": .init(
                make: { try Page.detail(.rating) }, prepare: artwork,
                interact: RevealStep.reveal(.label(String(localized: .rateGallery)))
            ),
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

    /// The first suggestion for ``LibraryFixtures/typedTag``, by its tag with its namespace, which is not translated
    /// and which no recent search contains. It is the only row on screen at accessibility5 in iPhone landscape.
    static var firstSuggestion: RevealStep.Target {
        .label(LibraryFixtures.tagTranslations.first.map({ "\($0.namespace):\($0.key)" }) ?? LibraryFixtures.typedTag)
    }

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
    /// Confirming a reset is the tap on Reset Filters, whose row is below the fold at accessibility5: there it is
    /// tapped once the row is shown (``RevealStep/tap(_:)``).
    static func filters(confirmingReset: Bool) -> AnyView {
        var root = SearchRootReducer.State()
        root.destination = .filters(FiltersReducer.State())
        let store = Store(initialState: root, reducer: SearchRootReducer.init)
        store.send(.destination(.presented(.filters(.fetchFilters))))
        if confirmingReset {
            RevealStep.tap { store.send(.destination(.presented(.filters(.resetFiltersButtonTapped)))) }
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

    /// How far past its top ``restAtTop(_:)`` pulls a list: more than the tallest title and search field, which
    /// accessibility5 text makes 134 points.
    static let pull: CGFloat = 400

    /// Brings the hosted page's list to rest at its top with its title and search field fully shown, as a user's
    /// pull down to the top leaves it.
    ///
    /// A list hosted early in a test process sometimes attaches its navigation bar part-way through the title and
    /// search field's hide-on-scroll collapse, and stays there: the field 2 points short or hidden, and at
    /// accessibility5 the large title too (seen on the first Favorites and Downloads captures of a process, and on
    /// the search results in ja-accessibility5). Pulling the list past its top reveals the whole bar, as a user's
    /// pull does; the list then rests at its new top. A page already fully shown is unchanged. Both moves happen in
    /// one main-thread turn, before the page presents a dialog from its initial state, so the dialog is placed over
    /// the list at rest.
    static func restAtTop(_ window: UIWindow) throws {
        let root = try XCTUnwrap(window.rootViewController?.view)
        // The bar may follow either of the list's scroll views (the collection view or SwiftUI's hosting scroll
        // view), so every scroll view of the page is pulled and returned.
        let lists = scrollViews(in: root)
        for list in lists {
            list.setContentOffset(
                CGPoint(x: list.contentOffset.x, y: -list.adjustedContentInset.top - pull), animated: false
            )
        }
        root.layoutIfNeeded()
        for list in lists {
            list.setContentOffset(CGPoint(x: list.contentOffset.x, y: -list.adjustedContentInset.top), animated: false)
        }
        root.layoutIfNeeded()
    }

    /// Opens the overflow menu once the page beneath it has settled. The category list is taller than the menu, so
    /// the menu flashes its scroll indicator as it opens, for about a second; the menu is captured as it rests after
    /// that flash, with the indicator hidden rather than waited out.
    static func openCategoryMenu(_ window: UIWindow) async throws {
        _ = await HostedWindowCapture.settle(window)
        let root = try XCTUnwrap(window.rootViewController?.view)
        try openOverflowMenu(in: root)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while true {
            let menuLists = scrollViews(in: window).filter({ !$0.isDescendant(of: root) })
            if !menuLists.isEmpty {
                menuLists.forEach({ $0.showsVerticalScrollIndicator = false })
                return
            }
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound("menu") }
            try await clock.sleep(for: .milliseconds(100))
        }
    }

    /// Opens the navigation bar's overflow menu, which holds the Favorites category picker, as VoiceOver's
    /// activation of it does. The system labels that button in the process's language ("More" in English), so it is
    /// found as the trailing-most control of the page's navigation bars, outside the search field.
    static func openOverflowMenu(in root: UIView) throws {
        func controls(in view: UIView) -> [UIControl] {
            if view is UISearchBar || view.isHidden { return [] }
            return ((view as? UIControl).map({ [$0] }) ?? []) + view.subviews.flatMap(controls(in:))
        }
        func bars(in view: UIView) -> [UINavigationBar] {
            ((view as? UINavigationBar).map({ [$0] }) ?? []) + view.subviews.flatMap(bars(in:))
        }
        let trailing = bars(in: root).flatMap(controls(in:))
            .map({ ($0, $0.convert($0.bounds, to: nil).maxX) })
            .max(by: { $0.1 < $1.1 })?.0
        let control = try XCTUnwrap(trailing, "The page has no navigation bar control")
        if !control.accessibilityActivate() {
            control.performPrimaryAction()
        }
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map({ [$0] }) ?? []) + view.subviews.flatMap(scrollViews(in:))
    }

    /// Favorites in the Library, as the Library shows it on each device.
    static func favorites(_ content: ListContent) -> AnyView {
        content.storeDisplayMode(.favorites)
        var favorites = FavoritesReducer.State()
        favorites.rawGalleries[-1] = content.galleries()
        favorites.rawLoadingState[-1] = content.loadingState
        return favoritesLibrary(favorites)
    }

    /// Favorites in the Library with nothing saved: the load succeeded with no galleries, which Favorites shows as
    /// its own empty state rather than the not-found error.
    static func emptyFavorites() -> AnyView {
        var favorites = FavoritesReducer.State()
        favorites.rawGalleries[-1] = []
        favorites.rawLoadingState[-1] = .idle
        favorites.emptyFavoritesIndices = [-1]
        return favoritesLibrary(favorites)
    }

    private static func favoritesLibrary(_ favorites: FavoritesReducer.State) -> AnyView {
        AnyView(LibraryView(
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
            try await TracerScenarios.cacheArtwork(image, forKey: url.absoluteString)
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

    /// The first row's tap that presents its confirmation, held from ``downloads(_:mode:confirming:inspecting:)``
    /// until the page is hosted (``tapHeldRow(_:)``).
    private static var heldRowTap: (@MainActor () -> Void)?

    /// Drops a held row tap that no ``tapHeldRow(_:)`` performed (SnapshotMatrixCase, before and after each case).
    static func discardHeldRowTap() {
        heldRowTap = nil
    }

    /// Taps the first row's Delete or Move once the hosted page has settled at rest, as a user taps it.
    ///
    /// The dialog is a popover from the row. Asked for while the page was still being built, before the window held
    /// it, the popover came up in portrait but never in landscape, where every confirmation picture was the plain
    /// list's at every size (run 43403534542). Tapped once the row is on screen, it comes up in both.
    static func tapHeldRow(_ window: UIWindow) async throws {
        let tap = heldRowTap
        heldRowTap = nil
        _ = await HostedWindowCapture.settle(window)
        tap?()
    }

    /// Downloads in the Library, in the first synthetic folder, as the Library shows it on each device. A
    /// confirmation is the first row's own dialog, tapped once the page is hosted; an inspector is the sheet the
    /// list presents for a record.
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
        heldRowTap = nil
        if let confirmation, let first = state.downloads.first {
            let destinations = LibraryFixtures.downloadFolders.filter({ $0 != first.folderName })
            heldRowTap = {
                store.send(.rows(.element(
                    id: first.id,
                    action: confirmation == .delete
                        ? .deleteButtonTapped : .moveButtonTapped(destinations: destinations)
                )))
            }
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
    /// drawn. Once the field has held its focus with `shown` on screen while the window came to rest twice in a row,
    /// the caret is drawn solid (``BrowsingScenarios/stopCaretBlink(in:)``) and the page is held still; a step that
    /// has not got there by ``BrowsingScenarios/focusDeadline`` fails, and the capture retries it.
    ///
    /// On the hosted runner the field gave its focus back after the typing in run 43451019962 (iPhone de
    /// accessibility5 portrait dark, ja large portrait light): the search ended, and the picture held the typed word
    /// over Recent Searches, without the suggestions or a caret. The field is focused again until it holds.
    static func type(_ text: String, in window: UIWindow, until shown: RevealStep.Target) async throws {
        let root = try XCTUnwrap(window.rootViewController?.view)
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = clock.now.advanced(by: .seconds(3))
        var typedField: UISearchTextField?
        while typedField == nil {
            if let field = firstView(of: UISearchTextField.self, in: root), field.becomeFirstResponder() {
                // A key at a time: the suggestions list appears with the first character and reads every
                // later change, as it does under a typing user.
                for character in text {
                    field.insertText(String(character))
                    try await clock.sleep(for: .milliseconds(150))
                }
                typedField = field
                break
            }
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound("search field") }
            try await clock.sleep(for: .milliseconds(100))
        }
        let field = try XCTUnwrap(typedField)
        try await clock.sleep(for: .milliseconds(800))
        let focusDeadline = start.advanced(by: BrowsingScenarios.focusDeadline)
        var held = 0
        while held < 2 {
            let focused = field.isFirstResponder
            let showing = RevealStep.element(shown, in: window) != nil
            guard clock.now < focusDeadline else {
                throw BrowsingScenarios.StepFailure(reason: focused ? "no-suggestions" : "search-focus-not-held")
            }
            if focused && showing {
                held += 1
            } else {
                held = 0
                if !focused { _ = field.becomeFirstResponder() }
            }
            try await clock.sleep(for: .milliseconds(300))
            try await BrowsingScenarios.waitForRest(window)
        }
        BrowsingScenarios.stopCaretBlink(in: window)
        try await BrowsingScenarios.freezeIndicators(window)
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

extension ScenarioFactory {
    /// This scenario with its list brought to rest at its top (``LibraryScenarios/restAtTop(_:)``) before its own
    /// user step: the pages whose navigation bar hides a search field on scroll.
    func restingAtTop() -> ScenarioFactory {
        let step = interact
        return ScenarioFactory(signedIn: signedIn, cookies: cookies, make: make, prepare: prepare, interact: { window in
            try LibraryScenarios.restAtTop(window)
            try await step?(window)
        }, minimumReads: minimumReads)
    }
}
