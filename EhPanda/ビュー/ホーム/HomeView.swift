//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    
    var homeInfo: AppState.HomeInfo {
        store.appState.homeInfo
    }
    var environment: AppState.Environment {
        store.appState.environment
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var settings: AppState.Settings {
        store.appState.settings
    }
    var setting: Setting? {
        settings.setting
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
                    fetchAction: fetchSearchItems,
                    loadMoreAction: fetchMoreSearchItems
                )
            case .frontpage:
                GenericList(
                    items: homeInfo.frontpageItems,
                    loadingFlag: homeInfo.frontpageLoading,
                    notFoundFlag: homeInfo.frontpageNotFound,
                    loadFailedFlag: homeInfo.frontpageLoadFailed,
                    fetchAction: fetchFrontpageItems,
                    loadMoreAction: fetchMoreFrontpageItems
                )
            case .popular:
                GenericList(
                    items: homeInfo.popularItems,
                    loadingFlag: homeInfo.popularLoading,
                    notFoundFlag: homeInfo.popularNotFound,
                    loadFailedFlag: homeInfo.popularLoadFailed,
                    fetchAction: fetchPopularItems
                )
            case .watched:
                GenericList(
                    items: homeInfo.watchedItems,
                    loadingFlag: homeInfo.watchedLoading,
                    notFoundFlag: homeInfo.watchedNotFound,
                    loadFailedFlag: homeInfo.watchedLoadFailed,
                    fetchAction: fetchWatchedItems,
                    loadMoreAction: fetchMoreWatchedItems
                )
            case .favorites:
                GenericList(
                    items: homeInfo.favoritesItems,
                    loadingFlag: homeInfo.favoritesLoading,
                    notFoundFlag: homeInfo.favoritesNotFound,
                    loadFailedFlag: homeInfo.favoritesLoadFailed,
                    fetchAction: fetchFavoritesItems,
                    loadMoreAction: fetchMoreFavoritesItems
                )
            case .downloaded:
                Text("")
            }
        }
    }
    
    // MARK: HomeView本体
    var body: some View {
        NavigationView {
            conditionalList
                .sheet(item: environmentBinding.homeViewSheetState) { item in
                    switch item {
                    case .setting:
                        SettingView()
                            .environmentObject(store)
                            .preferredColorScheme(colorScheme)
                    case .filter:
                        FilterView()
                            .environmentObject(store)
                            .preferredColorScheme(colorScheme)
                    }
                }
                .navigationBarTitle(
                    environment.homeListType.rawValue.lString()
                )
                .onChange(
                    of: environment.homeListType,
                    perform: onHomeListTypeChange
                )
                .onAppear(perform: onAppear)
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func onAppear() {
        if settings.user == nil {
            store.dispatch(.initiateUser)
        }
        if setting == nil {
            store.dispatch(.initiateSetting)
        }
        fetchUserInfo()
        fetchFrontpageItemsIfNeeded()
        fetchFavoritesItemsIfNeeded()
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
        }
    }
    
    func fetchUserInfo() {
        if let uid = settings.user?.apiuid {
            store.dispatch(.fetchDisplayName(uid: uid))
        }
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
        store.dispatch(.fetchFavoritesItems)
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
        if homeInfo.favoritesItems?.isEmpty != false {
            fetchFavoritesItems()
        }
    }
}

// MARK: 汎用リスト
private struct GenericList: View {
    @EnvironmentObject var store: Store
    
    var homeInfo: AppState.HomeInfo {
        store.appState.homeInfo
    }
    var homeInfoBinding: Binding<AppState.HomeInfo> {
        $store.appState.homeInfo
    }
    var environment: AppState.Environment {
        store.appState.environment
    }
    
    var items: [Manga]?
    var loadingFlag: Bool
    var notFoundFlag: Bool
    var loadFailedFlag: Bool
    var fetchAction: (()->())?
    var loadMoreAction: (()->())?
    
    init(items: [Manga]?,
         loadingFlag: Bool,
         notFoundFlag: Bool,
         loadFailedFlag: Bool,
         fetchAction: (()->())? = nil,
         loadMoreAction: (()->())? = nil)
    {
        self.items = items
        self.loadingFlag = loadingFlag
        self.notFoundFlag = notFoundFlag
        self.loadFailedFlag = loadFailedFlag
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
            if exx {
                SearchBar(
                    keyword: homeInfoBinding.searchKeyword,
                    commitAction: searchBarCommit,
                    filterAction: searchBarFilter
                )
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            if !didLogin && exx {
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
                    NavigationLink(destination: DetailView(id: item.id, depth: 0)) {
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
            }
        }
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

// MARK: 検索バー
private struct SearchBar: View {
    @Binding var keyword: String
    var commitAction: () -> ()
    var filterAction: () -> ()
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("検索", text: $keyword, onCommit: commitAction)
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
    
    func onClearButtonTap() {
        keyword = ""
    }
}

// MARK: 定義
enum HomeListType: String, Identifiable, CaseIterable {
    var id: Int { hashValue }
    
    case search = "検索"
    case frontpage = "ホーム"
    case popular = "人気"
    case watched = "フォロー"
    case favorites = "お気に入り"
    case downloaded = "ダウンロード済み"
    
    var symbolName: String {
        switch self {
        case .search:
            return "magnifyingglass.circle"
        case .frontpage:
            return "house"
        case .popular:
            return "flame"
        case .watched:
            return "eye.circle"
        case .favorites:
            return "heart.circle"
        case .downloaded:
            return "arrow.down.circle"
        }
    }
}

enum HomeViewSheetState: Identifiable {
    var id: Int { hashValue }
    
    case setting
    case filter
}
