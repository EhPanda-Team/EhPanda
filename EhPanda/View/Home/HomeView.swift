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

    @State private var keyword = ""
    @State private var clipboardJumpID: String?
    @State private var isNavLinkActive = false
    @State private var greeting: Greeting?

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    @State private var alertInput = ""
    @FocusState private var isAlertFocused: Bool
    @StateObject private var alertManager = CustomAlertManager()

    // MARK: HomeView
    var body: some View {
        NavigationView {
            ZStack {
                conditionalList
                TTProgressHUD($hudVisible, config: hudConfig)
            }
            .background {
                NavigationLink(
                    "",
                    destination: DetailView(
                        gid: clipboardJumpID ?? ""
                    ),
                    isActive: $isNavLinkActive
                )
            }
            .searchable(
                text: $keyword,
                placement: .navigationBarDrawer(
                    displayMode: .always
                ),
                suggestions: {
                    ForEach(suggestions, id: \.self) { word in
                        HStack {
                            Text(word).foregroundStyle(.tint)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSuggestionTap(word: word)
                        }
                    }
                }
            )
            .onSubmit(of: .search, onSearchSubmit)
            .navigationBarTitle(navigationBarTitle)
            .toolbar {
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
                        Menu {
                            if environment.homeListType == .favorites {
                                favoritesMenuContent
                            } else if environment.homeListType == .toplists {
                                toplistsMenuContent
                            }
                        } label: {
                            Image(systemName: "square.3.stack.3d.top.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.primary)
                        }
                        .opacity(
                            [.favorites, .toplists]
                                .contains(environment.homeListType) ? 1 : 0
                        )
                        Menu {
                            Button(action: toggleFilter) {
                                Image(systemName: "line.3.horizontal.decrease")
                                Text("Filters")
                            }
                            Button(action: toggleQuickSearch) {
                                Image(systemName: "magnifyingglass")
                                Text("Quick search")
                            }
                            Button(action: toggleJumpPage) {
                                Image(systemName: "arrowshape.bounce.forward")
                                Text("Jump page")
                            }
                            .disabled(currentListTypePageNumber.isSinglePage)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .onOpenURL(perform: onOpen)
        .navigationViewStyle(.stack)
        .onAppear(perform: onStartTasks)
        .customAlert(
            manager: alertManager, widthFactor: DeviceUtil.isPadWidth ? 0.5 : 1.0,
            backgroundOpacity: colorScheme == .light ? 0.2 : 0.5,
            content: {
                PageJumpView(
                    inputText: $alertInput,
                    isFocused: $isAlertFocused,
                    pageNumber: currentListTypePageNumber
                )
            },
            buttons: [
                .regular {
                    Text("Confirm")
                } action: {
                    performJumpPage()
                }
            ]
        )
        .sheet(item: environmentBinding.homeViewSheetState) { item in
            Group {
                switch item {
                case .setting:
                    SettingView().tint(accentColor)
                case .filter:
                    FilterView().tint(accentColor)
                case .newDawn:
                    NewDawnView(greeting: greeting)
                case .quickSearch:
                    QuickSearchView(searchAction: onQuickSearchSubmit)
                }
            }
            .accentColor(accentColor)
            .blur(radius: environment.blurRadius)
            .allowsHitTesting(environment.isAppUnlocked)
        }
        .onReceive(UIApplication.didBecomeActiveNotification.publisher, perform: onBecomeActive)
        .onChange(of: environment.galleryItemReverseLoading, perform: onJumpDetailFetchFinish)
        .onChange(of: alertManager.isPresented, perform: onAlertVisibilityChange)
        .onChange(of: environment.galleryItemReverseID, perform: onJumpIDChange)
        .onChange(of: environment.homeListType, perform: onHomeListTypeChange)
        .onChange(of: currentListTypePageNumber, perform: onPageNumberChange)
        .onChange(of: environment.favoritesIndex, perform: onFavIndexChange)
        .onChange(of: environment.toplistsType, perform: onTopTypeChange)
        .onChange(of: user.greeting, perform: onReceiveGreeting)
        .onChange(of: keyword, perform: onKeywordChange)
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
        detectsLinksFromPasteboard
            && viewControllersCount == 1
    }
    var suggestions: [String] {
        homeInfo.historyKeywords.reversed().filter({ word in
            keyword.isEmpty ? true : word.contains(keyword)
        })
    }
    var navigationBarTitle: String {
        if environment.favoritesIndex != -1,
           environment.homeListType == .favorites
        {
            return settings.user.getFavNameFrom(index: environment.favoritesIndex)
        } else {
            return environment.homeListType.rawValue.localized
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

    // MARK: View Properties
    var favoritesMenuContent: some View {
        ForEach(-1..<10) { index in
            Button {
                onFavMenuSelect(index: index)
            } label: {
                Text(User.getFavNameFrom(index: index, names: favoriteNames))
                if index == environment.favoritesIndex {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
    var toplistsMenuContent: some View {
        ForEach(ToplistsType.allCases) { type in
            Button {
                onTopMenuSelect(type: type)
            } label: {
                Text(type.description.localized)
                if type == environment.toplistsType {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
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
                fetchAction: onSearchRefresh,
                loadMoreAction: fetchMoreSearchItems,
                translateAction: translateTag
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
                translateAction: translateTag
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
                translateAction: translateTag
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
                translateAction: translateTag
            )
        case .favorites:
            GenericList(
                items: homeInfo.favoritesItems[
                    environment.favoritesIndex
                ] ?? [],
                setting: setting,
                pageNumber: homeInfo.favoritesPageNumbers[
                    environment.favoritesIndex
                ],
                loadingFlag: homeInfo.favoritesLoading[
                    environment.favoritesIndex
                ] ?? false,
                loadError: homeInfo.favoritesLoadErrors[
                    environment.favoritesIndex
                ],
                moreLoadingFlag: homeInfo.moreFavoritesLoading[
                    environment.favoritesIndex
                ] ?? false,
                moreLoadFailedFlag: homeInfo.moreFavoritesLoadFailed[
                    environment.favoritesIndex
                ] ?? false,
                fetchAction: fetchFavoritesItems,
                loadMoreAction: fetchMoreFavoritesItems,
                translateAction: translateTag
            )
        case .toplists:
            GenericList(
                items: homeInfo.toplistsItems[
                    environment.toplistsType.rawValue
                ] ?? [],
                setting: setting,
                pageNumber: homeInfo.toplistsPageNumbers[
                    environment.toplistsType.rawValue
                ],
                loadingFlag: homeInfo.toplistsLoading[
                    environment.toplistsType.rawValue
                ] ?? false,
                loadError: homeInfo.toplistsLoadErrors[
                    environment.toplistsType.rawValue
                ],
                moreLoadingFlag: homeInfo.moreToplistsLoading[
                    environment.toplistsType.rawValue
                ] ?? false,
                moreLoadFailedFlag: homeInfo.moreToplistsLoadFailed[
                    environment.toplistsType.rawValue
                ] ?? false,
                fetchAction: fetchToplistsItems,
                loadMoreAction: fetchMoreToplistsItems,
                translateAction: translateTag
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
                translateAction: translateTag
            )
        }
    }
}

private extension HomeView {
    // MARK: Life Cycle
    func onStartTasks() {
        detectPasteboard()
        fetchGreetingIfNeeded()
        fetchFrontpageItemsIfNeeded()
    }
    func onBecomeActive(_: Any? = nil) {
        if viewControllersCount == 1 {
            detectPasteboard()
            fetchGreetingIfNeeded()
        }
    }
    func onHomeListTypeChange(type: HomeListType) {
        switch type {
        case .frontpage:
            fetchFrontpageItemsIfNeeded()
        case .popular:
            fetchPopularItemsIfNeeded()
        case .watched:
            fetchWatchedItemsIfNeeded()
        case .favorites:
            fetchFavoritesItemsIfNeeded()
        case .toplists:
            fetchToplistsItemsIfNeeded()
        case .downloaded, .search, .history:
            break
        }
    }
    func onOpen(url: URL) {
        guard let scheme = url.scheme,
              let replacedURL = URL(
                string: url.absoluteString
                    .replacingOccurrences(
                        of: scheme, with: "https"
                    )
              )
        else { return }

        handle(incomingURL: replacedURL)
    }
    func onReceiveGreeting(_ greeting: Greeting?) {
        if setting.showNewDawnGreeting,
           let greeting = greeting,
           !greeting.gainedNothing
        {
            self.greeting = greeting
            store.dispatch(.toggleHomeViewSheet(state: .newDawn))
        }
    }
    func onKeywordChange(keyword: String) {
        if keyword.isEmpty {
            store.dispatch(.updateHistoryKeywords(text: homeInfo.lastKeyword))
        }
    }
    func onFavIndexChange(_ : Int) {
        fetchFavoritesItemsIfNeeded()
    }
    func onTopTypeChange(_ : ToplistsType) {
        fetchToplistsItemsIfNeeded()
    }
    func onFavMenuSelect(index: Int) {
        store.dispatch(.toggleFavorites(index: index))
    }
    func onTopMenuSelect(type: ToplistsType) {
        store.dispatch(.toggleToplists(type: type))
    }
    func onJumpIDChange(value: String?) {
        if value != nil, hasJumpPermission {
            clipboardJumpID = value
            isNavLinkActive = true

            replaceGalleryCommentJumpID(gid: nil)
        }
    }
    func onJumpDetailFetchFinish(value: Bool) {
        if !value, hasJumpPermission {
            dismissHUD()
        }
    }
    func onSearchSubmit() {
        if environment.homeListType != .search {
            store.dispatch(.toggleHomeList(type: .search))
        }
        if !keyword.isEmpty {
            store.dispatch(.updateLastKeyword(text: keyword))
        }
        store.dispatch(.fetchSearchItems(keyword: keyword))
    }
    func onSearchRefresh() {
        if !homeInfo.lastKeyword.isEmpty {
            store.dispatch(.fetchSearchItems(keyword: homeInfo.lastKeyword))
        }
    }
    func onSuggestionTap(word: String) {
        keyword = word
    }
    func onAlertVisibilityChange(_: Bool) {
        isAlertFocused = false
    }
    func onPageNumberChange(pageNumber: PageNumber) {
        alertInput = String(pageNumber.current + 1)
    }
    func onQuickSearchSubmit(keyword: String) {
        store.dispatch(.toggleHomeViewSheet(state: .none))
        self.keyword = keyword
        onSearchSubmit()
    }

    // MARK: Tool Methods
    func showHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .loading,
            title: "Loading...".localized
        )
        hudVisible = true
    }
    func dismissHUD() {
        hudVisible = false
        hudConfig = TTProgressHUDConfig()
    }
    func detectPasteboard() {
        if hasJumpPermission {
            if let url = getPasteboardURLIfAllowed() {
                handle(incomingURL: url)
            }
        }
    }
    func handle(incomingURL: URL) {
        let shouldDelayDisplay = homeInfo.frontpageItems.isEmpty
        URLUtil.handleIncomingURL(incomingURL) { shouldParseGalleryURL, incomingURL, pageIndex, commentID in
            guard let incomingURL = incomingURL else { return }

            let gid = URLUtil.parseGID(url: incomingURL, isGalleryURL: shouldParseGalleryURL)
            store.dispatch(.updatePendingJumpInfos(
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
                        showHUD()
                    }
                } else {
                    store.dispatch(.fetchGalleryItemReverse(
                        url: incomingURL.absoluteString,
                        shouldParseGalleryURL: shouldParseGalleryURL
                    ))
                    showHUD()
                }
            }
            PasteboardUtil.clear()
            clearObstruction()
        }
    }
    func replaceGalleryCommentJumpID(gid: String?) {
        store.dispatch(.replaceGalleryCommentJumpID(gid: gid))
    }
    func getPasteboardURLIfAllowed() -> URL? {
        let currentChangeCount = UIPasteboard.general.changeCount
        if PasteboardUtil.changeCount != currentChangeCount {
            PasteboardUtil.setChangeCount(value: currentChangeCount)
            return PasteboardUtil.getURL()
        } else {
            return nil
        }
    }
    func clearObstruction() {
        if environment.homeViewSheetState != nil {
            store.dispatch(.toggleHomeViewSheet(state: nil))
        }
        if !environment.isSlideMenuClosed {
            NotificationUtil.post(.shouldHideSlideMenu)
        }
    }
    func translateTag(text: String) -> String {
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

    // MARK: Dispatch Methods
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
        store.dispatch(.fetchMoreSearchItems(keyword: homeInfo.lastKeyword))
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

    func fetchGreetingIfNeeded() {
        func verifyDate(with updateTime: Date?) -> Bool {
            guard let updateTime = updateTime else { return false }

            let currentTime = Date()
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = Defaults.DateFormat.greeting

            let currentTimeString = formatter.string(from: currentTime)
            if let currDay = formatter.date(from: currentTimeString) {
                return currentTime > currDay && updateTime < currDay
            }

            return false
        }

        if setting.showNewDawnGreeting {
            if let greeting = user.greeting {
                if verifyDate(with: greeting.updateTime) {
                    store.dispatch(.fetchGreeting)
                }
            } else {
                store.dispatch(.fetchGreeting)
            }
        }
    }
    func fetchFrontpageItemsIfNeeded() {
        if homeInfo.frontpageItems.isEmpty {
            fetchFrontpageItems()
        }
    }
    func fetchPopularItemsIfNeeded() {
        if homeInfo.popularItems.isEmpty {
            fetchPopularItems()
        }
    }
    func fetchWatchedItemsIfNeeded() {
        if homeInfo.watchedItems.isEmpty {
            fetchWatchedItems()
        }
    }
    func fetchFavoritesItemsIfNeeded() {
        if homeInfo.favoritesItems[environment.favoritesIndex]?.isEmpty != false {
            fetchFavoritesItems()
        }
    }
    func fetchToplistsItemsIfNeeded() {
        if homeInfo.toplistsItems[environment.toplistsType.rawValue]?.isEmpty != false {
            fetchToplistsItems()
        }
    }
    func toggleFilter() {
        store.dispatch(.toggleHomeViewSheet(state: .filter))
    }
    func toggleQuickSearch() {
        store.dispatch(.toggleHomeViewSheet(state: .quickSearch))
    }
    func toggleJumpPage() {
        alertManager.show()
        isAlertFocused = true
        HapticUtil.generateFeedback(style: .light)
    }
    func performJumpPage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let index = Int(alertInput), index <= currentListTypePageNumber.maximum + 1
            { store.dispatch(.handleJumpPage(index: index - 1, keyword: homeInfo.lastKeyword)) }
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
