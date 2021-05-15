//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import TTProgressHUD

struct HomeView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme

    @State private var clipboardJumpID: String?
    @State private var isJumpNavActive = false
    @State private var greeting: Greeting?

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig(
        hapticsEnabled: false
    )

    // MARK: HomeView
    var body: some View {
        NavigationView {
            ZStack {
                NavigationLink(
                    "",
                    destination: DetailView(
                        gid: clipboardJumpID ?? "",
                        depth: 1
                    ),
                    isActive: $isJumpNavActive
                )
                conditionalList
                    .onChange(
                        of: environment.homeListType,
                        perform: onHomeListTypeChange
                    )
                    .onChange(
                        of: environment.favoritesIndex,
                        perform: onFavoritesIndexChange
                    )
                    .onChange(
                        of: user?.greeting,
                        perform: onReceiveGreeting
                    )
                    .onAppear(perform: onListAppear)
                    .navigationBarTitle(navigationBarTitle)
                    .navigationBarItems(trailing:
                        navigationBarItem
                    )
                TTProgressHUD($hudVisible, config: hudConfig)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: environmentBinding.homeViewSheetState) { item in
            switch item {
            case .setting:
                SettingView()
                    .environmentObject(store)
                    .accentColor(accentColor)
                    .preferredColorScheme(colorScheme)
                    .blur(radius: environment.blurRadius)
                    .allowsHitTesting(environment.isAppUnlocked)
            case .filter:
                FilterView()
                    .environmentObject(store)
                    .accentColor(accentColor)
                    .preferredColorScheme(colorScheme)
                    .blur(radius: environment.blurRadius)
                    .allowsHitTesting(environment.isAppUnlocked)
            case .newDawn:
                NewDawnView(greeting: greeting)
                    .preferredColorScheme(colorScheme)
                    .blur(radius: environment.blurRadius)
                    .allowsHitTesting(environment.isAppUnlocked)
            }
        }
        .onAppear(perform: onAppear)
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification
            )
        ) { _ in
            onBecomeActive()
        }
        .onChange(
            of: environment.mangaItemReverseID,
            perform: onJumpIDChange
        )
        .onChange(
            of: environment.mangaItemReverseLoading,
            perform: onFetchFinish
        )
    }
}

private extension HomeView {
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var historyItems: [Manga] {
        var items = homeInfo.historyItems?
            .compactMap({ $0.value })
            .filter({ $0.lastOpenTime != nil })
        items?.sort {
            $0.lastOpenTime ?? Date()
                > $1.lastOpenTime ?? Date()
        }
        return items ?? []
    }
    var navigationBarTitle: String {
        if let user = settings.user,
           environment.favoritesIndex != -1,
           environment.homeListType == .favorites
        {
            return user.getFavNameFrom(environment.favoritesIndex)
        } else {
            return environment.homeListType.rawValue.localized()
        }
    }
    var hasJumpPermission: Bool {
        vcsCount == 1 && isTokenMatched
            && setting?.detectGalleryFromPasteboard == true
    }

    var conditionalList: some View {
        Group {
            switch environment.homeListType {
            case .search:
                GenericList(
                    items: homeInfo.searchItems,
                    loadingFlag: homeInfo.searchLoading,
                    notFoundFlag: homeInfo.searchNotFound,
                    loadFailedFlag: homeInfo.searchLoadFailed,
                    moreLoadingFlag: homeInfo.moreSearchLoading,
                    moreLoadFailedFlag: homeInfo.moreSearchLoadFailed,
                    fetchAction: fetchSearchItems,
                    loadMoreAction: fetchMoreSearchItems
                )
            case .frontpage:
                GenericList(
                    items: homeInfo.frontpageItems,
                    loadingFlag: homeInfo.frontpageLoading,
                    notFoundFlag: homeInfo.frontpageNotFound,
                    loadFailedFlag: homeInfo.frontpageLoadFailed,
                    moreLoadingFlag: homeInfo.moreFrontpageLoading,
                    moreLoadFailedFlag: homeInfo.moreFrontpageLoadFailed,
                    fetchAction: fetchFrontpageItems,
                    loadMoreAction: fetchMoreFrontpageItems
                )
            case .popular:
                GenericList(
                    items: homeInfo.popularItems,
                    loadingFlag: homeInfo.popularLoading,
                    notFoundFlag: homeInfo.popularNotFound,
                    loadFailedFlag: homeInfo.popularLoadFailed,
                    moreLoadingFlag: false,
                    moreLoadFailedFlag: false,
                    fetchAction: fetchPopularItems
                )
            case .watched:
                GenericList(
                    items: homeInfo.watchedItems,
                    loadingFlag: homeInfo.watchedLoading,
                    notFoundFlag: homeInfo.watchedNotFound,
                    loadFailedFlag: homeInfo.watchedLoadFailed,
                    moreLoadingFlag: homeInfo.moreWatchedLoading,
                    moreLoadFailedFlag: homeInfo.moreWatchedLoadFailed,
                    fetchAction: fetchWatchedItems,
                    loadMoreAction: fetchMoreWatchedItems
                )
            case .favorites:
                GenericList(
                    items: homeInfo.favoritesItems[
                        environment.favoritesIndex
                    ],
                    loadingFlag: homeInfo.favoritesLoading[
                        environment.favoritesIndex
                    ] ?? false,
                    notFoundFlag: homeInfo.favoritesNotFound[
                        environment.favoritesIndex
                    ] ?? false,
                    loadFailedFlag: homeInfo.favoritesLoadFailed[
                        environment.favoritesIndex
                    ] ?? false,
                    moreLoadingFlag: homeInfo.moreFavoritesLoading[
                        environment.favoritesIndex
                    ] ?? false,
                    moreLoadFailedFlag: homeInfo.moreFavoritesLoadFailed[
                        environment.favoritesIndex
                    ] ?? false,
                    fetchAction: fetchFavoritesItems,
                    loadMoreAction: fetchMoreFavoritesItems
                )
            case .downloaded:
                NotFoundView(retryAction: nil)
            case .history:
                GenericList(
                    items: historyItems,
                    loadingFlag: false,
                    notFoundFlag: historyItems.isEmpty,
                    loadFailedFlag: false,
                    moreLoadingFlag: false,
                    moreLoadFailedFlag: false
                )
            }
        }
    }

    var navigationBarItem: some View {
        Group {
            if let user = settings.user,
               let names = user.favoriteNames,
               environment.homeListType == .favorites
            {
                Menu {
                    ForEach(-1..<names.count - 1) { index in
                        Button(action: {
                            onFavMenuSelect(index)
                        }, label: {
                            HStack {
                                Text(user.getFavNameFrom(index))
                                if index == environment.favoritesIndex {
                                    Image(systemName: "checkmark")
                                }
                            }
                        })
                    }
                } label: {
                    Image(systemName: "square.2.stack.3d.top.fill")
                        .foregroundColor(.primary)
                }

            }
        }
    }

    func onAppear() {
        detectPasteboard()
        fetchGreetingIfNeeded()
    }
    func onListAppear() {
        if settings.user == nil {
            store.dispatch(.initiateUser)
        }
        if setting == nil {
            store.dispatch(.initiateSetting)
        }
        if settings.user?.displayName?.isEmpty != false {
            fetchUserInfo()
        }
        fetchFavoriteNames()
        fetchFrontpageItemsIfNeeded()
    }
    func onBecomeActive() {
        if vcsCount == 1 {
            detectPasteboard()
            fetchGreetingIfNeeded()
        }
    }
    func onHomeListTypeChange(_ type: HomeListType) {
        switch type {
        case .frontpage:
            fetchFrontpageItemsIfNeeded()
        case .popular:
            fetchPopularItemsIfNeeded()
        case .watched:
            fetchWatchedItemsIfNeeded()
        case .favorites:
            fetchFavoritesItemsIfNeeded()
        case .downloaded:
            print(type)
        case .search:
            print(type)
        case .history:
            print(type)
        }
    }
    func onReceiveGreeting(_ greeting: Greeting?) {
        if let greeting = greeting,
           !greeting.gainedNothing
        {
            self.greeting = greeting
            toggleNewDawn()
        }
    }
    func onFavoritesIndexChange(_ : Int) {
        fetchFavoritesItemsIfNeeded()
    }
    func onFavMenuSelect(_ index: Int) {
        store.dispatch(.toggleFavoriteIndex(index: index))
    }
    func onJumpIDChange(_ value: String?) {
        if value != nil, hasJumpPermission {
            clipboardJumpID = value
            isJumpNavActive = true

            replaceMangaCommentJumpID(gid: nil)
        }
    }
    func onFetchFinish(_ value: Bool) {
        if !value, hasJumpPermission {
            dismissHUD()
        }
    }

    func showHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .loading,
            title: "Loading...".localized()
        )
        hudVisible = true
    }
    func dismissHUD() {
        hudVisible = false
        hudConfig = TTProgressHUDConfig(
            hapticsEnabled: false
        )
    }
    func detectPasteboard() {
        if hasJumpPermission {
            if let link = getPasteboardLinkIfAllowed(),
               isValidDetailURL(url: link)
            {
                let gid = link.pathComponents[2]
                if cachedList.hasCached(gid: gid) {
                    replaceMangaCommentJumpID(gid: gid)
                } else {
                    fetchMangaWithDetailURL(link.absoluteString)
                    showHUD()
                }
                clearPasteboard()
                clearObstruction()
            }
        }
    }
    func getPasteboardLinkIfAllowed() -> URL? {
        if setting?.allowsDetectionWhenNoChange == true {
            return getPasteboardLink()
        } else {
            let currentChangeCount = UIPasteboard.general.changeCount
            if pasteboardChangeCount != currentChangeCount {
                setPasteboardChangeCount(with: currentChangeCount)
                return getPasteboardLink()
            } else {
                return nil
            }
        }
    }
    func clearObstruction() {
        if environment.homeViewSheetState != nil {
            store.dispatch(.toggleHomeViewSheetNil)
        }
        if environment.isSlideMenuClosed != true {
            postSlideMenuShouldCloseNotification()
        }
    }

    func fetchGreeting() {
        store.dispatch(.fetchGreeting)
    }
    func fetchUserInfo() {
        if let uid = settings.user?.apiuid, !uid.isEmpty {
            store.dispatch(.fetchUserInfo(uid: uid))
        }
    }
    func fetchFavoriteNames() {
        store.dispatch(.fetchFavoriteNames)
    }
    func fetchSearchItems() {
        store.dispatch(.fetchSearchItems(keyword: homeInfo.searchKeyword))
    }
    func fetchFrontpageItems() {
        store.dispatch(.fetchFrontpageItems)
    }
    func fetchPopularItems() {
        store.dispatch(.fetchPopularItems)
    }
    func fetchWatchedItems() {
        store.dispatch(.fetchWatchedItems)
    }
    func fetchFavoritesItems() {
        store.dispatch(.fetchFavoritesItems(index: environment.favoritesIndex))
    }

    func fetchMoreSearchItems() {
        store.dispatch(.fetchMoreSearchItems(keyword: homeInfo.searchKeyword))
    }
    func fetchMoreFrontpageItems() {
        store.dispatch(.fetchMoreFrontpageItems)
    }
    func fetchMoreWatchedItems() {
        store.dispatch(.fetchMoreWatchedItems)
    }
    func fetchMoreFavoritesItems() {
        store.dispatch(.fetchMoreFavoritesItems(index: environment.favoritesIndex))
    }

    func fetchMangaWithDetailURL(_ detailURL: String) {
        store.dispatch(.fetchMangaItemReverse(detailURL: detailURL))
    }
    func replaceMangaCommentJumpID(gid: String?) {
        store.dispatch(.replaceMangaCommentJumpID(gid: gid))
    }

    func fetchGreetingIfNeeded() {
        func verifyDate(with updateTime: Date?) -> Bool {
            guard let updateTime = updateTime else { return false }

            let currentTime = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMMM yyyy"
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            let currentTimeString = formatter.string(from: currentTime)
            if let currDay = formatter.date(from: currentTimeString) {
                return currentTime > currDay && updateTime < currDay
            }

            return false
        }

        if setting?.showNewDawnGreeting == true {
            if let greeting = user?.greeting {
                if verifyDate(with: greeting.updateTime) {
                    fetchGreeting()
                }
            } else {
                fetchGreeting()
            }
        }
    }
    func fetchFrontpageItemsIfNeeded() {
        if homeInfo.frontpageItems?.isEmpty != false {
            fetchFrontpageItems()
        }
    }
    func fetchPopularItemsIfNeeded() {
        if homeInfo.popularItems?.isEmpty != false {
            fetchPopularItems()
        }
    }
    func fetchWatchedItemsIfNeeded() {
        if homeInfo.watchedItems?.isEmpty != false {
            fetchWatchedItems()
        }
    }
    func fetchFavoritesItemsIfNeeded() {
        if homeInfo.favoritesItems[environment.favoritesIndex]?.isEmpty != false {
            fetchFavoritesItems()
        }
    }

    func toggleNewDawn() {
        store.dispatch(.toggleHomeViewSheetState(state: .newDawn))
    }
}

// MARK: GenericList
private struct GenericList: View, StoreAccessor {
    @EnvironmentObject var store: Store

    private let items: [Manga]?
    private let loadingFlag: Bool
    private let notFoundFlag: Bool
    private let loadFailedFlag: Bool
    private let moreLoadingFlag: Bool
    private let moreLoadFailedFlag: Bool
    private let fetchAction: (() -> Void)?
    private let loadMoreAction: (() -> Void)?

    init(
        items: [Manga]?,
        loadingFlag: Bool,
        notFoundFlag: Bool,
        loadFailedFlag: Bool,
        moreLoadingFlag: Bool,
        moreLoadFailedFlag: Bool,
        fetchAction: (() -> Void)? = nil,
        loadMoreAction: (() -> Void)? = nil
    ) {
        self.items = items
        self.loadingFlag = loadingFlag
        self.notFoundFlag = notFoundFlag
        self.loadFailedFlag = loadFailedFlag
        self.moreLoadingFlag = moreLoadingFlag
        self.moreLoadFailedFlag = moreLoadFailedFlag
        self.fetchAction = fetchAction
        self.loadMoreAction = loadMoreAction

        UIScrollView.appearance().keyboardDismissMode = .onDrag
    }

    var body: some View {
        KRefreshScrollView(
            progressTint: .gray,
            arrowTint: .primary,
            onUpdate: onUpdate
        ) {
            if isTokenMatched {
                SearchBar(
                    keyword: homeInfoBinding.searchKeyword,
                    commitAction: searchBarCommit,
                    filterAction: searchBarFilter
                )
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            if !didLogin && isTokenMatched {
                NotLoginView(loginAction: toggleSetting)
                    .padding(.top, 30)
            } else if loadingFlag {
                LoadingView()
                    .padding(.top, 30)
            } else if loadFailedFlag {
                NetworkErrorView(retryAction: fetchAction)
                    .padding(.top, 30)
            } else if notFoundFlag {
                NotFoundView(retryAction: fetchAction)
                    .padding(.top, 30)
            } else {
                ForEach(items ?? []) { item in
                    NavigationLink(destination: DetailView(gid: item.id, depth: 0)) {
                        MangaSummaryRow(manga: item)
                            .onAppear {
                                onRowAppear(item)
                            }
                    }
                }
                .padding(.horizontal)
                .transition(
                    AnyTransition
                        .opacity
                        .animation(.default)
                )
                if moreLoadingFlag {
                    LoadingView(isCompact: true)
                        .padding()
                } else if moreLoadFailedFlag {
                    NetworkErrorView(
                        isCompact: true,
                        retryAction: loadMoreAction
                    )
                    .padding()
                }
            }
        }
    }
}

private extension GenericList {
    var homeInfoBinding: Binding<AppState.HomeInfo> {
        $store.appState.homeInfo
    }

    func onUpdate() {
        if let action = fetchAction {
            action()
        }
    }
    func onRowAppear(_ item: Manga) {
        if let action = loadMoreAction,
           item == items?.last
        {
            action()
        }
    }

    func searchBarCommit() {
        hideKeyboard()

        if environment.homeListType != .search {
            store.dispatch(.toggleHomeListType(type: .search))
        }
        fetchSearchItems()
    }
    func searchBarFilter() {
        toggleFilter()
    }

    func fetchSearchItems() {
        store.dispatch(.fetchSearchItems(keyword: homeInfo.searchKeyword))
    }

    func toggleSetting() {
        store.dispatch(.toggleHomeViewSheetState(state: .setting))
    }
    func toggleFilter() {
        store.dispatch(.toggleHomeViewSheetState(state: .filter))
    }
}

// MARK: SearchBar
private struct SearchBar: View {
    @Binding private var keyword: String
    private var commitAction: () -> Void
    private var filterAction: () -> Void

    init(
        keyword: Binding<String>,
        commitAction: @escaping () -> Void,
        filterAction: @escaping () -> Void
    ) {
        _keyword = keyword
        self.commitAction = commitAction
        self.filterAction = filterAction
    }

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search", text: $keyword, onCommit: commitAction)
                .disableAutocorrection(true)
                .autocapitalization(.none)
            HStack {
                Group {
                    if !keyword.isEmpty {
                        Button(action: onClearButtonTap) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    Button(action: filterAction) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.gray)
                            .padding(.vertical, 13)
                            .padding(.trailing, 10)
                    }
                }
            }
        }
        .padding(.leading, 10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func onClearButtonTap() {
        keyword = ""
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
}
