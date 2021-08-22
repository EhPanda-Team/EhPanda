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
                }
            }
        }
        .onOpenURL(perform: onOpen)
        .navigationViewStyle(.stack)
        .onAppear(perform: onStartTasks)
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
            of: environment.galleryItemReverseID,
            perform: onJumpIDChange
        )
        .onChange(
            of: environment.galleryItemReverseLoading,
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
            of: environment.toplistsType,
            perform: onTopTypeChange
        )
        .onChange(
            of: user.greeting,
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
            homeInfo.searchKeyword.isEmpty ? true
            : word.contains(homeInfo.searchKeyword)
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
                loadingFlag: homeInfo.searchLoading,
                notFoundFlag: homeInfo.searchNotFound,
                loadFailedFlag: homeInfo.searchLoadFailed,
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
                loadingFlag: homeInfo.frontpageLoading,
                notFoundFlag: homeInfo.frontpageNotFound,
                loadFailedFlag: homeInfo.frontpageLoadFailed,
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
                loadingFlag: homeInfo.popularLoading,
                notFoundFlag: homeInfo.popularNotFound,
                loadFailedFlag: homeInfo.popularLoadFailed,
                moreLoadingFlag: false,
                moreLoadFailedFlag: false,
                fetchAction: fetchPopularItems,
                translateAction: translateTag
            )
        case .watched:
            GenericList(
                items: homeInfo.watchedItems,
                setting: setting,
                loadingFlag: homeInfo.watchedLoading,
                notFoundFlag: homeInfo.watchedNotFound,
                loadFailedFlag: homeInfo.watchedLoadFailed,
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
                ],
                setting: setting,
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
                loadMoreAction: fetchMoreFavoritesItems,
                translateAction: translateTag
            )
        case .toplists:
            GenericList(
                items: homeInfo.toplistsItems[
                    environment.toplistsType.rawValue
                ],
                setting: setting,
                loadingFlag: homeInfo.toplistsLoading[
                    environment.toplistsType.rawValue
                ] ?? false,
                notFoundFlag: homeInfo.toplistsNotFound[
                    environment.toplistsType.rawValue
                ] ?? false,
                loadFailedFlag: homeInfo.toplistsLoadFailed[
                    environment.toplistsType.rawValue
                ] ?? false,
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
            NotFoundView(retryAction: nil)
        case .history:
            GenericList(
                items: galleryHistory,
                setting: setting,
                loadingFlag: false,
                notFoundFlag: galleryHistory.isEmpty,
                loadFailedFlag: false,
                moreLoadingFlag: false,
                moreLoadFailedFlag: false,
                translateAction: translateTag
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

        handle(jumpLink: replacedURL)
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
            if let link = getPasteboardLinkIfAllowed() {
                handle(jumpLink: link)
            }
        }
    }
    func handle(jumpLink: URL) {
        guard isValidGalleryURL(url: jumpLink) else { return }
        let gid = jumpLink.pathComponents[2]
        if PersistenceController.galleryCached(gid: gid) {
            replaceGalleryCommentJumpID(gid: gid)
        } else {
            store.dispatch(
                .fetchGalleryItemReverse(
                    galleryURL: jumpLink.absoluteString
                )
            )
            showHUD()
        }
        clearPasteboard()
        clearObstruction()
    }
    func replaceGalleryCommentJumpID(gid: String?) {
        store.dispatch(.replaceGalleryCommentJumpID(gid: gid))
    }
    func getPasteboardLinkIfAllowed() -> URL? {
        let currentChangeCount = UIPasteboard.general.changeCount
        if pasteboardChangeCount != currentChangeCount {
            setPasteboardChangeCount(with: currentChangeCount)
            return getPasteboardLink()
        } else {
            return nil
        }
    }
    func clearObstruction() {
        if environment.homeViewSheetState != nil {
            store.dispatch(.toggleHomeViewSheet(state: nil))
        }
        if !environment.isSlideMenuClosed {
            postSlideMenuShouldCloseNotification()
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

    // MARK: Fetch Methods
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
        store.dispatch(.fetchFavoritesItems)
    }
    func fetchToplistsItems() {
        store.dispatch(.fetchToplistsItems)
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
            formatter.dateFormat = "dd MMMM yyyy"
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

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
    func fetchToplistsItemsIfNeeded() {
        if homeInfo.toplistsItems[environment.toplistsType.rawValue]?.isEmpty != false {
            fetchToplistsItems()
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
