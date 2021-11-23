//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import AlertKit
import TTProgressHUD

struct HomeView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(wrappedValue: .ehentai, AppUserDefaults.galleryHost.rawValue)
    var galleryHost: GalleryHost

    @State private var isSearching = false
    @State private var keyword = ""
    @State private var lastKeyword = ""
    @State private var pendingKeywords = [String]()

    @State private var clipboardJumpID: String?
    @State private var isNavLinkActive = false
    @State private var greeting: Greeting?

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    @State private var alertInput = ""
    @FocusState private var isAlertFocused: Bool
    @StateObject private var alertManager = CustomAlertManager()
    @State private var clearHistoryDialogPresented = false

    // MARK: HomeView
    var body: some View {
        NavigationView {
            ZStack {
                conditionalList
                SearchHelper(isSearching: $isSearching)
                TTProgressHUD($hudVisible, config: hudConfig)
            }
            .background {
                NavigationLink(
                    "",
                    destination: DetailView(gid: clipboardJumpID ?? ""),
                    isActive: $isNavLinkActive
                )
            }
            .searchable(
                text: $keyword, placement: .navigationBarDrawer(displayMode: .always)
            ) { SuggestionProvider(keyword: $keyword) }
            .navigationBarTitle(navigationBarTitle)
            .onSubmit(of: .search, performSearch)
            .toolbar(content: toolbar)
        }
        .navigationViewStyle(.stack)
        .onOpenURL(perform: tryOpenURL).onAppear(perform: onStartTasks)
        .sheet(item: environmentBinding.homeViewSheetState, content: sheet)
        .onReceive(UIApplication.didBecomeActiveNotification.publisher, perform: onBecomeActive)
        .onChange(of: environment.galleryItemReverseLoading, perform: tryDismissLoadingHUD)
        .onChange(of: currentListTypePageNumber) { alertInput = String($0.current + 1) }
        .onChange(of: environment.galleryItemReverseID, perform: tryActivateNavLink)
        .onChange(of: environment.favoritesIndex) { _ in tryFetchFavoritesItems() }
        .onChange(of: environment.toplistsType) { _ in tryFetchToplistsItems() }
        .onChange(of: alertManager.isPresented) { _ in isAlertFocused = false }
        .onChange(of: environment.homeListType, perform: onHomeListTypeChange)
        .onChange(of: galleryHost) { _ in store.dispatch(.resetHomeInfo) }
        .onChange(of: user.greeting, perform: tryPresentNewDawnSheet)
        .onChange(of: isSearching, perform: tryUpdateHistoryKeywords)
        .customAlert(
            manager: alertManager, widthFactor: DeviceUtil.isPadWidth ? 0.5 : 1.0,
            backgroundOpacity: colorScheme == .light ? 0.2 : 0.5,
            content: {
                PageJumpView(
                    inputText: $alertInput, isFocused: $isAlertFocused,
                    pageNumber: currentListTypePageNumber
                )
            },
            buttons: [.regular(content: { Text("Confirm") }, action: tryPerformJumpPage)]
        )
        .confirmationDialog(
            "Are you sure to clear?",
            isPresented: $clearHistoryDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive, action: PersistenceController.clearGalleryHistory)
        }
    }
}

private extension HomeView {
    // MARK: Sheet
    func sheet(item: HomeViewSheetState) -> some View {
        Group {
            switch item {
            case .setting:
                SettingView().tint(accentColor)
            case .filter:
                FilterView().tint(accentColor)
            case .newDawn:
                NewDawnView(greeting: greeting)
            case .quickSearch:
                QuickSearchView(searchAction: performQuickSearch)
            }
        }
        .accentColor(accentColor)
        .blur(radius: environment.blurRadius)
        .allowsHitTesting(environment.isAppUnlocked)
    }

    // MARK: Toolbar
    func toolbar() -> some ToolbarContent {
        func selectIndexMenu() -> some View {
            Menu {
                if environment.homeListType == .favorites {
                    ForEach(-1..<10) { index in
                        Button {
                            store.dispatch(.setFavoritesIndex(index))
                        } label: {
                            Text(User.getFavNameFrom(index: index, names: favoriteNames))
                            if index == environment.favoritesIndex {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } else if environment.homeListType == .toplists {
                    ForEach(ToplistsType.allCases) { type in
                        Button {
                            store.dispatch(.setToplistsType(type))
                        } label: {
                            Text(type.description.localized)
                            if type == environment.toplistsType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "square.3.stack.3d.top.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.primary)
            }
            .opacity([.favorites, .toplists].contains(environment.homeListType) ? 1 : 0)
        }
        func moreFeaturesMenu() -> some View {
            Menu {
                Button {
                    store.dispatch(.setHomeViewSheetState(.filter))
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text("Filters")
                }
                Button {
                    store.dispatch(.setHomeViewSheetState(.quickSearch))
                } label: {
                    Image(systemName: "magnifyingglass")
                    Text("Quick search")
                }
                Button(action: presentJumpPageAlert) {
                    Image(systemName: "arrowshape.bounce.forward")
                    Text("Jump page")
                }
                .disabled(currentListTypePageNumber.isSinglePage)
                if environment.homeListType == .history {
                    Button {
                        clearHistoryDialogPresented = true
                    } label: {
                        Image(systemName: "trash")
                        Text("Clear history")
                    }
                    .disabled(galleryHistory.isEmpty)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.primary)
            }
        }
        return Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    NotificationUtil.post(.shouldShowSlideMenu)
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.secondary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    selectIndexMenu()
                    moreFeaturesMenu()
                }
            }
        }
    }

    // MARK: List
    @ViewBuilder var conditionalList: some View {
        switch environment.homeListType {
        case .search:
            GenericList(
                items: homeInfo.searchItems,
                setting: setting,
                pageNumber: homeInfo.searchPageNumber,
                loadingFlag: homeInfo.searchLoading,
                loadError: homeInfo.searchLoadError,
                moreLoadingFlag: homeInfo.moreSearchLoading,
                moreLoadFailedFlag: homeInfo.moreSearchLoadFailed,
                fetchAction: tryRefetchSearchItems,
                loadMoreAction: fetchMoreSearchItems,
                translateAction: tryTranslateTag
            )
        case .frontpage:
            GenericList(
                items: homeInfo.frontpageItems,
                setting: setting,
                pageNumber: homeInfo.frontpagePageNumber,
                loadingFlag: homeInfo.frontpageLoading,
                loadError: homeInfo.frontpageLoadError,
                moreLoadingFlag: homeInfo.moreFrontpageLoading,
                moreLoadFailedFlag: homeInfo.moreFrontpageLoadFailed,
                fetchAction: fetchFrontpageItems,
                loadMoreAction: fetchMoreFrontpageItems,
                translateAction: tryTranslateTag
            )
        case .popular:
            GenericList(
                items: homeInfo.popularItems,
                setting: setting,
                pageNumber: nil,
                loadingFlag: homeInfo.popularLoading,
                loadError: homeInfo.popularLoadError,
                moreLoadingFlag: false,
                moreLoadFailedFlag: false,
                fetchAction: fetchPopularItems,
                translateAction: tryTranslateTag
            )
        case .watched:
            GenericList(
                items: homeInfo.watchedItems,
                setting: setting,
                pageNumber: homeInfo.watchedPageNumber,
                loadingFlag: homeInfo.watchedLoading,
                loadError: homeInfo.watchedLoadError,
                moreLoadingFlag: homeInfo.moreWatchedLoading,
                moreLoadFailedFlag: homeInfo.moreWatchedLoadFailed,
                fetchAction: fetchWatchedItems,
                loadMoreAction: fetchMoreWatchedItems,
                translateAction: tryTranslateTag
            )
        case .favorites:
            GenericList(
                items: homeInfo.favoritesItems[environment.favoritesIndex] ?? [], setting: setting,
                pageNumber: homeInfo.favoritesPageNumbers[environment.favoritesIndex],
                loadingFlag: homeInfo.favoritesLoading[environment.favoritesIndex] ?? false,
                loadError: homeInfo.favoritesLoadErrors[environment.favoritesIndex],
                moreLoadingFlag: homeInfo.moreFavoritesLoading[environment.favoritesIndex] ?? false,
                moreLoadFailedFlag: homeInfo.moreFavoritesLoadFailed[environment.favoritesIndex] ?? false,
                fetchAction: fetchFavoritesItems, loadMoreAction: fetchMoreFavoritesItems,
                translateAction: tryTranslateTag
            )
        case .toplists:
            GenericList(
                items: homeInfo.toplistsItems[environment.toplistsType.rawValue] ?? [], setting: setting,
                pageNumber: homeInfo.toplistsPageNumbers[environment.toplistsType.rawValue],
                loadingFlag: homeInfo.toplistsLoading[environment.toplistsType.rawValue] ?? false,
                loadError: homeInfo.toplistsLoadErrors[environment.toplistsType.rawValue],
                moreLoadingFlag: homeInfo.moreToplistsLoading[environment.toplistsType.rawValue] ?? false,
                moreLoadFailedFlag: homeInfo.moreToplistsLoadFailed[environment.toplistsType.rawValue] ?? false,
                fetchAction: fetchToplistsItems, loadMoreAction: fetchMoreToplistsItems,
                translateAction: tryTranslateTag
            )
        case .downloaded:
            ErrorView(error: .notFound, retryAction: nil)
        case .history:
            GenericList(
                items: galleryHistory,
                setting: setting,
                pageNumber: nil,
                loadingFlag: false,
                loadError: galleryHistory.isEmpty ? .notFound : nil,
                moreLoadingFlag: false,
                moreLoadFailedFlag: false,
                translateAction: tryTranslateTag
            )
        }
    }
}

// MARK: Private Properties
private extension HomeView {
    var galleryHistory: [Gallery] {
        PersistenceController.fetchGalleryHistory()
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var homeInfoBinding: Binding<AppState.HomeInfo> {
        $store.appState.homeInfo
    }

    var hasJumpPermission: Bool {
        detectsLinksFromPasteboard && viewControllersCount == 1
    }
    var navigationBarTitle: String {
        if environment.favoritesIndex != -1, environment.homeListType == .favorites {
            return settings.user.getFavNameFrom(index: environment.favoritesIndex)
        } else {
            return environment.homeListType.rawValue.localized
        }
    }
    var pasteboardURL: URL? {
        let currentChangeCount = UIPasteboard.general.changeCount
        if PasteboardUtil.changeCount != currentChangeCount {
            PasteboardUtil.setChangeCount(value: currentChangeCount)
            return PasteboardUtil.url
        } else {
            return nil
        }
    }
    var currentListTypePageNumber: PageNumber {
        switch environment.homeListType {
        case .search:
            return homeInfo.searchPageNumber
        case .frontpage:
            return homeInfo.frontpagePageNumber
        case .watched:
            return homeInfo.watchedPageNumber
        case .favorites:
            let index = environment.favoritesIndex
            return homeInfo.favoritesPageNumbers[index] ?? PageNumber()
        case .toplists:
            let index = environment.toplistsType.rawValue
            return homeInfo.toplistsPageNumbers[index] ?? PageNumber()
        case .popular, .downloaded, .history:
            return PageNumber()
        }
    }
}

private extension HomeView {
    // MARK: Life Cycle
    func onStartTasks() {
        tryOpenPasteboardURL()
        tryFetchGreeting()
        tryFetchFrontpageItems()
    }
    func onBecomeActive(_: Any? = nil) {
        guard viewControllersCount == 1 else { return }
        tryOpenPasteboardURL()
        tryFetchGreeting()
    }
    func onHomeListTypeChange(type: HomeListType) {
        switch type {
        case .frontpage:
            tryFetchFrontpageItems()
        case .popular:
            guard homeInfo.popularItems.isEmpty else { return }
            fetchPopularItems()
        case .watched:
            guard homeInfo.watchedItems.isEmpty else { return }
            fetchWatchedItems()
        case .favorites:
            tryFetchFavoritesItems()
        case .toplists:
            tryFetchToplistsItems()
        case .downloaded, .search, .history:
            return
        }
    }
    func tryPresentNewDawnSheet(newValue: Greeting?) {
        guard setting.showNewDawnGreeting, let greeting = newValue, !greeting.gainedNothing else { return }

        self.greeting = greeting
        if environment.homeViewSheetState == nil {
            store.dispatch(.setHomeViewSheetState(.newDawn))
        } else {
            store.dispatch(.setHomeViewSheetState(nil))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                store.dispatch(.setHomeViewSheetState(.newDawn))
            }
        }
    }

    // MARK: Navigation(handleURL)
    func tryOpenURL(_ url: URL) {
        guard let scheme = url.scheme else { return }
        let replacedString = url.absoluteString
            .replacingOccurrences(of: scheme, with: "https")
        guard let replacedURL = URL(string: replacedString) else { return }

        handleURL(replacedURL)
    }
    func tryOpenPasteboardURL() {
        guard hasJumpPermission, let url = pasteboardURL else { return }
        handleURL(url)
    }
    func handleURL(_ url: URL) {
        let shouldDelayDisplay = homeInfo.frontpageItems.isEmpty
        URLUtil.handleURL(url) { shouldParseGalleryURL, incomingURL, pageIndex, commentID in
            guard let incomingURL = incomingURL else { return }

            let gid = URLUtil.parseGID(url: incomingURL, isGalleryURL: shouldParseGalleryURL)
            store.dispatch(.setPendingJumpInfos(
                gid: gid, pageIndex: pageIndex, commentID: commentID
            ))

            if PersistenceController.galleryCached(gid: gid) {
                replaceGalleryCommentJumpID(gid: gid)
            } else {
                if shouldDelayDisplay {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        store.dispatch(.fetchGalleryItemReverse(
                            url: incomingURL.absoluteString,
                            shouldParseGalleryURL: shouldParseGalleryURL
                        ))
                        presentLoadingHUD()
                    }
                } else {
                    store.dispatch(.fetchGalleryItemReverse(
                        url: incomingURL.absoluteString,
                        shouldParseGalleryURL: shouldParseGalleryURL
                    ))
                    presentLoadingHUD()
                }
            }
            PasteboardUtil.clear()
            clearObstruction()
        }
    }
    // Removing this could cause unexpected blank leading space
    func clearObstruction() {
        if environment.homeViewSheetState != nil {
            store.dispatch(.setHomeViewSheetState(nil))
        }
        if !environment.slideMenuClosed {
            NotificationUtil.post(.shouldHideSlideMenu)
        }
    }

    // MARK: Navigation(other)
    func presentLoadingHUD() {
        hudConfig = TTProgressHUDConfig(type: .loading, title: "Loading...".localized)
        hudVisible = true
    }
    func tryDismissLoadingHUD(newValue: Bool) {
        guard !newValue, hasJumpPermission else { return }
        hudVisible = false
        hudConfig = TTProgressHUDConfig()
    }
    func replaceGalleryCommentJumpID(gid: String?) {
        store.dispatch(.setGalleryCommentJumpID(gid: gid))
    }
    func presentJumpPageAlert() {
        alertManager.show()
        isAlertFocused = true
        HapticUtil.generateFeedback(style: .light)
    }
    func tryPerformJumpPage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let index = Int(alertInput), index <= currentListTypePageNumber.maximum + 1 else { return }
            store.dispatch(.handleJumpPage(index: index - 1, keyword: lastKeyword))
        }
    }
    func tryActivateNavLink(newValue: String?) {
        guard newValue != nil, hasJumpPermission else { return }
        clipboardJumpID = newValue
        isNavLinkActive = true
        replaceGalleryCommentJumpID(gid: nil)
    }

    // MARK: Search
    func tryUpdateHistoryKeywords(isSearching: Bool) {
        guard !isSearching, !lastKeyword.isEmpty else { return }
        store.dispatch(.appendHistoryKeywords(texts: pendingKeywords))
        pendingKeywords = []
    }
    func tryRefetchSearchItems() {
        guard !lastKeyword.isEmpty else { return }
        store.dispatch(.fetchSearchItems(keyword: lastKeyword))
    }
    func performSearch() {
        if environment.homeListType != .search {
            store.dispatch(.setHomeListType(.search))
        }
        if !keyword.isEmpty {
            pendingKeywords.append(keyword)
            lastKeyword = keyword
        }
        store.dispatch(.fetchSearchItems(keyword: keyword))
    }
    func performQuickSearch(keyword: String) {
        store.dispatch(.setHomeViewSheetState(.none))
        self.keyword = keyword
        performSearch()
    }

    // MARK: Tools
    func tryTranslateTag(text: String) -> String {
        guard setting.translatesTags else { return text }
        let translator = settings.tagTranslator

        if let range = text.range(of: ":") {
            let before = text[...range.lowerBound]
            let after = String(text[range.upperBound...])
            let result = before + translator.translate(text: after)
            return String(result)
        }
        return translator.translate(text: text)
    }
    func tryFetchGreeting() {
        func verifyDate(with updateTime: Date?) -> Bool {
            guard let updateTime = updateTime else { return false }

            let currentTime = Date()
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = Defaults.DateFormat.greeting

            let currentTimeString = formatter.string(from: currentTime)
            if let currentDay = formatter.date(from: currentTimeString) {
                return currentTime > currentDay && updateTime < currentDay
            }

            return false
        }

        guard setting.showNewDawnGreeting else { return }
        if let greeting = user.greeting {
            guard verifyDate(with: greeting.updateTime) else { return }
            store.dispatch(.fetchGreeting)
        } else {
            store.dispatch(.fetchGreeting)
        }
    }

    // MARK: Fetching list items
    func fetchFrontpageItems() {
        store.dispatch(.fetchFrontpageItems())
    }
    func fetchPopularItems() {
        store.dispatch(.fetchPopularItems)
    }
    func fetchWatchedItems() {
        store.dispatch(.fetchWatchedItems())
    }
    func fetchFavoritesItems() {
        store.dispatch(.fetchFavoritesItems())
    }
    func fetchToplistsItems() {
        store.dispatch(.fetchToplistsItems())
    }

    func fetchMoreSearchItems() {
        store.dispatch(.fetchMoreSearchItems(keyword: lastKeyword))
    }
    func fetchMoreFrontpageItems() {
        store.dispatch(.fetchMoreFrontpageItems)
    }
    func fetchMoreWatchedItems() {
        store.dispatch(.fetchMoreWatchedItems)
    }
    func fetchMoreFavoritesItems() {
        store.dispatch(.fetchMoreFavoritesItems)
    }
    func fetchMoreToplistsItems() {
        store.dispatch(.fetchMoreToplistsItems)
    }

    func tryFetchFrontpageItems() {
        guard homeInfo.frontpageItems.isEmpty else { return }
        fetchFrontpageItems()
    }
    func tryFetchFavoritesItems() {
        guard homeInfo.favoritesItems[environment.favoritesIndex]?.isEmpty != false else { return }
        fetchFavoritesItems()
    }
    func tryFetchToplistsItems() {
        guard homeInfo.toplistsItems[environment.toplistsType.rawValue]?.isEmpty != false else { return }
        fetchToplistsItems()
    }
}

// MARK: SearchHelper
private struct SearchHelper: View {
    @Environment(\.isSearching) var isSearchingEnvironment
    @Binding var isSearching: Bool

    init(isSearching: Binding<Bool>) {
        _isSearching = isSearching
    }

    var body: some View {
        Text("").onChange(of: isSearchingEnvironment) { newValue in
            isSearching = newValue
        }
    }
}

// MARK: Definition
enum HomeListType: String, Identifiable, CaseIterable {
    var id: Int { hashValue }

    case search = "Search"
    case frontpage = "Frontpage"
    case popular = "Popular"
    case watched = "Watched"
    case favorites = "Favorites"
    case toplists = "Toplists"
    case downloaded = "Downloaded"
    case history = "History"

    var symbolName: String {
        switch self {
        case .search:
            return "magnifyingglass.circle"
        case .frontpage:
            return "house"
        case .popular:
            return "flame"
        case .watched:
            return "tag.circle"
        case .favorites:
            return "heart.circle"
        case .toplists:
            return "list.bullet.circle"
        case .downloaded:
            return "arrow.down.circle"
        case .history:
            return "clock.arrow.circlepath"
        }
    }
}

enum HomeViewSheetState: Identifiable {
    var id: Int { hashValue }

    case setting
    case filter
    case newDawn
    case quickSearch
}

enum ToplistsType: Int, Codable, CaseIterable, Identifiable {
    case allTime
    case pastYear
    case pastMonth
    case yesterday
}

extension ToplistsType {
    var id: Int { description.hashValue }

    var description: String {
        switch self {
        case .allTime:
            return "All time"
        case .pastYear:
            return "Past year"
        case .pastMonth:
            return "Past month"
        case .yesterday:
            return "Yesterday"
        }
    }
    var categoryIndex: Int {
        switch self {
        case .allTime:
            return 11
        case .pastYear:
            return 12
        case .pastMonth:
            return 13
        case .yesterday:
            return 15
        }
    }
}
