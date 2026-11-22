@testable import AppFeature
import AppModels
import ComposableArchitecture
import DateSeekFeature
@testable import DetailFeature
import DownloadClient
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

@MainActor
enum LibraryScenarios {
    typealias ListContent = BrowsingScenarios.ListContent

    // MARK: Search

    /// The Recent Searches section's Remove All, the first of the page's two.
    static var removeAllLabel: String { String(localized: .removeAll) }

    /// The user's stars under Rate Gallery, which carry no accessibility element of their own to reveal: a line of
    /// the 24-point symbols the detail page scales with Title 2 (`userRatingSymbolSize`) and the 10 points above it.
    /// Measured at the run's text size, which `traits` carry, so it is read when the step runs, not when the catalog
    /// is built.
    static func userRatingHeight(compatibleWith traits: UITraitCollection) -> CGFloat {
        let size = UIFontMetrics(forTextStyle: .title2).scaledValue(for: 24, compatibleWith: traits)
        return UIFont.systemFont(ofSize: size).lineHeight + 10
    }

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
        let quickSearch = QuickSearchReducer.State()
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
    /// Confirming a reset is the tap on Reset Filters, whose row can be below the fold: it is tapped once the row is
    /// shown (``RevealStep/tap(_:)``).
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
        window.layoutIfNeeded()
        for list in lists {
            list.setContentOffset(CGPoint(x: list.contentOffset.x, y: -list.adjustedContentInset.top), animated: false)
        }
        window.layoutIfNeeded()
    }

    /// Opens the overflow menu once the page beneath it has settled. The category list is taller than the menu, so
    /// the menu flashes its scroll indicator as it opens, for about a second; the menu is captured as it rests after
    /// that flash, with the indicator hidden rather than waited out.
    static func openCategoryMenu(_ window: UIWindow) async throws {
        _ = await HostedWindowCapture.settle(window)
        let root = try XCTUnwrap(window.rootViewController?.view)
        try openOverflowMenu(in: root)
        let clock = ContinuousClock()
        let budget = StepBudget(.seconds(3))
        while true {
            let menuLists = scrollViews(in: window).filter({ !$0.isDescendant(of: root) })
            if !menuLists.isEmpty {
                menuLists.forEach({ $0.showsVerticalScrollIndicator = false })
                return
            }
            guard !budget.isSpent else { throw AccessibilityActionDriver.Failure.notFound("menu") }
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

    /// The row's tap that presents its confirmation or its inspector, held from
    /// ``downloads(_:mode:confirming:inspecting:)`` until the page is hosted (``tapHeldRow(_:)``).
    private static var heldRowTap: (@MainActor () -> Void)?

    /// Drops a held row tap that no ``tapHeldRow(_:)`` performed (SnapshotMatrixCase, before and after each case).
    static func discardHeldRowTap() {
        heldRowTap = nil
    }

    /// Taps the row's Delete, Move or inspector button once the hosted page has settled at rest, as a user taps it.
    ///
    /// The dialog is a popover from the row. Asked for while the page was still being built, before the window held
    /// it, the popover came up in portrait but never in landscape, where every confirmation picture was the plain
    /// list's at every size (run 43403534542). Tapped once the row is on screen, it comes up in both.
    static func tapHeldRow(_ window: UIWindow) async throws {
        let tap = heldRowTap
        heldRowTap = nil
        _ = await HostedWindowCapture.settle(window)
        tap?()
        try await RevealStep.awaitDialogPlatter()(window)
        try await syncDisabledBarControls(in: window)
    }

    /// Waits for SwiftUI's toolbar update after a row confirmation to disable `GalleryLayoutPicker`'s bar item, then
    /// toggles `isEnabled` once under the already-dimmed bar so UIKit computes the same disabled+dimmed symbol color
    /// regardless of whether `.disabled(true)` arrived before or after the dialog dimmed the bar.
    private static func syncDisabledBarControls(in window: UIWindow) async throws {
        guard hasPresentedAlert(in: window.rootViewController) else { return }
        let navigations = navigationControllers(in: window.rootViewController)
        guard !navigations.isEmpty else { return }
        func allItems(of navigation: UINavigationController) -> [UIBarButtonItem] {
            guard let item = navigation.topViewController?.navigationItem else { return [] }
            let grouped = (item.leadingItemGroups + item.centerItemGroups + item.trailingItemGroups)
                .flatMap(\.barButtonItems)
            let pinned = item.pinnedTrailingGroup?.barButtonItems ?? []
            return (item.leftBarButtonItems ?? []) + (item.rightBarButtonItems ?? []) + grouped + pinned
        }
        let clock = ContinuousClock()
        var budget = StepBudget(.seconds(2))
        while !budget.isSpent {
            budget.look()
            if navigations.flatMap(allItems(of:)).contains(where: { !$0.isEnabled }) {
                break
            }
            try await clock.sleep(for: .milliseconds(100))
        }
        for navigation in navigations {
            let disabled = allItems(of: navigation).filter({ !$0.isEnabled })
            guard !disabled.isEmpty else { continue }
            disabled.forEach({ $0.isEnabled = true })
            navigation.navigationBar.setNeedsLayout()
            navigation.navigationBar.layoutIfNeeded()
            disabled.forEach({ $0.isEnabled = false })
            navigation.navigationBar.setNeedsLayout()
            navigation.navigationBar.layoutIfNeeded()
        }
        window.layoutIfNeeded()
        try await BrowsingScenarios.waitForRest(window)
    }

    private static func hasPresentedAlert(in controller: UIViewController?) -> Bool {
        guard let controller else { return false }
        if controller.presentedViewController is UIAlertController { return true }
        if let presented = controller.presentedViewController, hasPresentedAlert(in: presented) { return true }
        return controller.children.contains(where: hasPresentedAlert(in:))
    }

    /// Downloads in the Library, in the first synthetic folder, as the Library shows it on each device. A
    /// confirmation is the first row's own dialog, tapped once the page is hosted; an inspector is the sheet the
    /// list presents for a record, opened the same way.
    ///
    /// The inspector was first in the initial state, so the sheet came up before the window held the page, and
    /// UIKit left the page under it without its dim, which it gives a sheet opened over a page on screen
    /// (`quick-search-filters`, and a user's tap here). In some pictures the list also showed under the sheet's
    /// bottom edge (candidate run 44025665174). It now opens through the list's own action, as a tap opens it; the
    /// download client answers that action's load with the record's inspection.
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
        let inspectedDownload = inspected.flatMap({ state.downloads.dropFirst($0).first })
        let store = Store(initialState: state, reducer: DownloadsReducer.init) {
            if let inspectedDownload {
                let prepared = inspection(inspectedDownload)
                $0.downloadClient.loadInspection = { _ in prepared }
            }
        }
        heldRowTap = nil
        if let inspectedDownload {
            heldRowTap = { store.send(.inspectorButtonTapped(inspectedDownload.gid)) }
        } else if let confirmation, let first = state.downloads.first {
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
    ///
    /// Both waits are counted in time the main run loop turned (``StepBudget``): run 43621303643 failed the step as
    /// `no-suggestions` on attempts of 40 s and more in pictures that took 60 and 67 s.
    static func type(_ text: String, in window: UIWindow, until shown: RevealStep.Target) async throws {
        _ = await HostedWindowCapture.settle(window)
        let root = try XCTUnwrap(window.rootViewController?.view)
        let clock = ContinuousClock()
        KeyboardWatch.start()
        let mark = KeyboardWatch.mark
        var focusBudget = StepBudget(BrowsingScenarios.focusDeadline)
        let fieldBudget = StepBudget(.seconds(3))
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
            guard !fieldBudget.isSpent else { throw AccessibilityActionDriver.Failure.notFound("search field") }
            try await clock.sleep(for: .milliseconds(100))
        }
        let field = try XCTUnwrap(typedField)
        try await clock.sleep(for: .milliseconds(800))
        var held = 0
        while held < 2 {
            let focused = field.isFirstResponder
            let showing = RevealStep.element(shown, in: window) != nil
            let keyboardUp = GalleryScenarios.keyboardIsUp(over: window)
            guard !focusBudget.isSpent else {
                let reason: String
                if !focused {
                    reason = "search-focus-not-held"
                } else if !showing {
                    reason = "no-suggestions"
                } else {
                    let state = GalleryScenarios.keyboardState(over: window, focused: true, since: mark.announcements)
                    reason = "no-keyboard:\(state)" + KeyboardWatch.editing(since: mark, in: window)
                }
                throw focusBudget.failure(reason)
            }
            focusBudget.look()
            if focused && showing && keyboardUp {
                held += 1
            } else {
                held = 0
                if !focused { _ = field.becomeFirstResponder() }
            }
            try await clock.sleep(for: .milliseconds(300))
            try await BrowsingScenarios.waitForRest(window)
            if !field.isFirstResponder || !GalleryScenarios.keyboardIsUp(over: window) {
                held = 0
            }
        }
        if let suggestionView = RevealStep.view(of: shown, in: window),
           let list = enclosingScrollView(of: suggestionView) {
            // SearchRootView's scroll view stays behind the suggestions overlay; naming the suggestions list as the
            // page's top content scroll view stops the bar from drawing a scroll-edge hairline in some runs and not in
            // others (zh-Hans and zh-Hant accessibility5 landscape, runs 44025665174 and 44137794244).
            list.setContentOffset(CGPoint(x: list.contentOffset.x, y: -list.adjustedContentInset.top), animated: false)
            for navigation in navigationControllers(in: window.rootViewController) {
                guard let page = navigation.topViewController else { continue }
                page.setContentScrollView(list, for: .top)
                navigation.navigationBar.setNeedsLayout()
                navigation.view.setNeedsLayout()
                navigation.view.layoutIfNeeded()
            }
        }
        window.layoutIfNeeded()
        try await BrowsingScenarios.waitForRest(window)
        BrowsingScenarios.stopCaretBlink(in: window)
        try await BrowsingScenarios.freezeIndicators(window)
    }

    /// Waits for a pre-filled search field's clear button to appear and hold its frame (`search-results-*`), so a slow
    /// bar pass neither omits the button nor captures it one pixel to the left.
    static func awaitClearButtonIfNeeded(_ window: UIWindow) async throws {
        guard let root = window.rootViewController?.view,
              let field = firstView(of: UISearchTextField.self, in: root),
              !(field.text ?? "").isEmpty
        else { return }
        let clock = ContinuousClock()
        var budget = StepBudget(.seconds(3))
        var previous: CGRect?
        while !budget.isSpent {
            budget.look()
            field.layoutIfNeeded()
            window.layoutIfNeeded()
            if let button = clearButton(in: field) {
                let frame = button.convert(button.bounds, to: window)
                if frame == previous {
                    try await BrowsingScenarios.waitForRest(window)
                    return
                }
                previous = frame
            } else {
                previous = nil
            }
            try await clock.sleep(for: .milliseconds(100))
        }
    }

    private static func clearButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton, !button.isHidden, button.alpha > 0.99, !button.bounds.isEmpty {
            return button
        }
        for subview in view.subviews {
            if let match = clearButton(in: subview) { return match }
        }
        return nil
    }

    private static func enclosingScrollView(of view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView { return scrollView }
            current = candidate.superview
        }
        return nil
    }

    private static func navigationControllers(in controller: UIViewController?) -> [UINavigationController] {
        guard let controller else { return [] }
        let own = (controller as? UINavigationController).map({ [$0] }) ?? []
        return own + controller.children.flatMap(navigationControllers(in:))
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
        return ScenarioFactory(
            signedIn: signedIn, cookies: cookies, make: make, prepare: prepare, still: still,
            interact: { window in
                try LibraryScenarios.restAtTop(window)
                try await LibraryScenarios.awaitClearButtonIfNeeded(window)
                try await step?(window)
            },
            minimumReads: minimumReads
        )
    }
}
