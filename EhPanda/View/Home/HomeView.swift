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

    @State private var archivedKeyword: String?
    @State private var clipboardJumpID: String?
    @State private var isNavLinkActive = false
    @State private var greeting: Greeting?

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    // MARK: HomeView
    var body: some View {
        NavigationView {
            ZStack {
                NavigationLink(
                    "",
                    destination: DetailView(
                        gid: clipboardJumpID ?? "", depth: 1
                    ),
                    isActive: $isNavLinkActive
                )
                conditionalList
                TTProgressHUD($hudVisible, config: hudConfig)
            }
            .searchable(
                text: homeInfoBinding.searchKeyword,
                placement: .navigationBarDrawer(
                    displayMode: .always
                ),
                prompt: "Search",
                suggestions: {
                    ForEach(suggestions, id: \.self) { word in
                        HStack {
                            Text(word)
                                .foregroundStyle(.tint)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(-1..<(favoriteNames?.count ?? 10) - 1) { index in
                            Button {
                                onFavMenuSelect(index: index)
                            } label: {
                                Text(User.getFavNameFrom(index: index, names: favoriteNames))
                                if index == environment.favoritesIndex {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "square.3.stack.3d.top.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.primary)
                    }
                    .opacity(environment.homeListType == .favorites ? 1 : 0)
                }
            }
        }
        .task(onStartTasks)
        .navigationViewStyle(.stack)
        .sheet(item: environmentBinding.homeViewSheetState) { item in
            Group {
                switch item {
                case .setting:
                    SettingView()
                case .filter:
                    FilterView()
                case .newDawn:
                    NewDawnView(greeting: greeting)
                }
            }
            .accentColor(accentColor)
            .blur(radius: environment.blurRadius)
            .allowsHitTesting(environment.isAppUnlocked)
        }
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
            perform: onJumpDetailFetchFinish
        )
        .onChange(
            of: environment.homeListType,
            perform: onHomeListTypeChange
        )
        .onChange(
            of: environment.favoritesIndex,
            perform: onFavIndexChange
        )
        .onChange(
            of: user?.greeting,
            perform: onReceive
        )
        .onChange(
            of: homeInfo.searchKeyword,
            perform: onSearchKeywordChange
        )
    }
}

// MARK: Private Properties
private extension HomeView {
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var homeInfoBinding: Binding<AppState.HomeInfo> {
        $store.appState.homeInfo
    }

    var hasJumpPermission: Bool {
        detectGalleryFromPasteboard
            && viewControllersCount == 1
    }
    var suggestions: [String] {
        homeInfo.historyKeywords?.reversed().filter({ word in
            homeInfo.searchKeyword.isEmpty ? true
            : word.contains(homeInfo.searchKeyword)
        }) ?? []
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
            return user.getFavNameFrom(index: environment.favoritesIndex)
        } else {
            return environment.homeListType.rawValue.localized()
        }
    }

    // MARK: conditionalList
    @ViewBuilder var conditionalList: some View {
        switch environment.homeListType {
        case .search:
            GenericList(
                items: homeInfo.searchItems,
                setting: setting ?? Setting(),
                loadingFlag: homeInfo.searchLoading,
                notFoundFlag: homeInfo.searchNotFound,
                loadFailedFlag: homeInfo.searchLoadFailed,
                moreLoadingFlag: homeInfo.moreSearchLoading,
                moreLoadFailedFlag: homeInfo.moreSearchLoadFailed,
                fetchAction: onSearchRefresh,
                loadMoreAction: fetchMoreSearchItems
            )
        case .frontpage:
            GenericList(
                items: homeInfo.frontpageItems,
                setting: setting ?? Setting(),
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
                setting: setting ?? Setting(),
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
                setting: setting ?? Setting(),
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
                setting: setting ?? Setting(),
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
                setting: setting ?? Setting(),
                loadingFlag: false,
                notFoundFlag: historyItems.isEmpty,
                loadFailedFlag: false,
                moreLoadingFlag: false,
                moreLoadFailedFlag: false
            )
        }
    }
}

// MARK: Private Methods
private extension HomeView {
    func onStartTasks() {
        detectPasteboard()
        fetchGreetingIfNeeded()
        fetchFrontpageItemsIfNeeded()
    }
    func onBecomeActive() {
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
        case .downloaded, .search, .history:
            break
        }
    }
    func onReceive(greeting: Greeting?) {
        if let greeting = greeting,
           !greeting.gainedNothing
        {
            self.greeting = greeting
            store.dispatch(.toggleHomeViewSheet(state: .newDawn))
        }
    }
    func onSearchKeywordChange(keyword: String) {
        if let archivedKeyword = archivedKeyword, keyword.isEmpty {
            store.dispatch(.updateHistoryKeywords(text: archivedKeyword))
        }
    }
    func onFavIndexChange(_ : Int) {
        fetchFavoritesItemsIfNeeded()
    }
    func onFavMenuSelect(index: Int) {
        store.dispatch(.toggleFavorite(index: index))
    }
    func onJumpIDChange(value: String?) {
        if value != nil, hasJumpPermission {
            clipboardJumpID = value
            isNavLinkActive = true

            replaceMangaCommentJumpID(gid: nil)
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
        if !homeInfo.searchKeyword.isEmpty {
            archivedKeyword = homeInfo.searchKeyword
        }
        store.dispatch(.fetchSearchItems(keyword: homeInfo.searchKeyword))
    }
    func onSearchRefresh() {
        if let keyword = archivedKeyword {
            store.dispatch(.fetchSearchItems(keyword: keyword))
        }
    }
    func onSuggestionTap(word: String) {
        store.dispatch(.updateSearchKeyword(text: word))
    }

    // MARK: Tool Methods
    func showHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .loading,
            title: "Loading...".localized()
        )
        hudVisible = true
    }
    func dismissHUD() {
        hudVisible = false
        hudConfig = TTProgressHUDConfig()
    }
    func detectPasteboard() {
        if hasJumpPermission {
            if let link = getPasteboardLinkIfAllowed(),
               isValidDetailURL(url: link)
            {
                let gid = link.pathComponents[2]
                if PersistenceController.hasCached(gid: gid) {
                    replaceMangaCommentJumpID(gid: gid)
                } else {
                    store.dispatch(
                        .fetchMangaItemReverse(
                            detailURL: link.absoluteString
                        )
                    )
                    showHUD()
                }
                clearPasteboard()
                clearObstruction()
            }
        }
    }
    func replaceMangaCommentJumpID(gid: String?) {
        store.dispatch(.replaceMangaCommentJumpID(gid: gid))
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
            store.dispatch(.toggleHomeViewSheet(state: nil))
        }
        if environment.isSlideMenuClosed != true {
            postSlideMenuShouldCloseNotification()
        }
    }

    // MARK: Fetch Methods
    func fetchFrontpageItems() {
        DispatchQueue.main.async {
            store.dispatch(.fetchFrontpageItems)
        }
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

        dispatchMainAsync {
            if setting?.showNewDawnGreeting == true {
                if let greeting = user?.greeting {
                    if verifyDate(with: greeting.updateTime) {
                        store.dispatch(.fetchGreeting)
                    }
                } else {
                    store.dispatch(.fetchGreeting)
                }
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
}

// MARK: GenericList
private struct GenericList: View {
    private let items: [Manga]?
    private let setting: Setting
    private let loadingFlag: Bool
    private let notFoundFlag: Bool
    private let loadFailedFlag: Bool
    private let moreLoadingFlag: Bool
    private let moreLoadFailedFlag: Bool
    private let fetchAction: (() -> Void)?
    private let loadMoreAction: (() -> Void)?

    init(
        items: [Manga]?,
        setting: Setting,
        loadingFlag: Bool,
        notFoundFlag: Bool,
        loadFailedFlag: Bool,
        moreLoadingFlag: Bool,
        moreLoadFailedFlag: Bool,
        fetchAction: (() -> Void)? = nil,
        loadMoreAction: (() -> Void)? = nil
    ) {
        self.items = items
        self.setting = setting
        self.loadingFlag = loadingFlag
        self.notFoundFlag = notFoundFlag
        self.loadFailedFlag = loadFailedFlag
        self.moreLoadingFlag = moreLoadingFlag
        self.moreLoadFailedFlag = moreLoadFailedFlag
        self.fetchAction = fetchAction
        self.loadMoreAction = loadMoreAction
    }

    var body: some View {
        if loadingFlag {
            LoadingView()
        } else if loadFailedFlag {
            NetworkErrorView(retryAction: fetchAction)
        } else if notFoundFlag {
            NotFoundView(retryAction: fetchAction)
        } else {
            List {
                ForEach(items ?? []) { item in
                    ZStack {
                        NavigationLink(
                            destination: DetailView(
                                gid: item.gid, depth: 0
                            )
                        ) {}
                        .opacity(0)
                        MangaSummaryRow(
                            manga: item,
                            setting: setting
                        )
                    }
                    .onAppear {
                        onRowAppear(item: item)
                    }
                }
                .transition(animatedTransition)
                if moreLoadingFlag || moreLoadFailedFlag {
                    LoadMoreFooter(
                        moreLoadingFlag: moreLoadingFlag,
                        moreLoadFailedFlag: moreLoadFailedFlag,
                        retryAction: loadMoreAction
                    )
                }
            }
            .transition(animatedTransition)
            .refreshable(action: onUpdate)
        }
    }

    private func onUpdate() {
        fetchAction?()
    }
    private func onRowAppear(item: Manga) {
        if item == items?.last {
            loadMoreAction?()
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
