//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import SDWebImageSwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    
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
    
    var categoryPicker: some View {
        Group {
            if exx {
                CategoryPicker(type: environmentBinding.homeListType)
                    .padding(.bottom, 10)
            }
        }
    }
    var settingEntry: some View {
        Group {
            if exx {
                Image(systemName: "gear")
                    .foregroundColor(.primary)
                    .imageScale(.large)
                    .onTapGesture(perform: toggleSetting)
            }
        }
    }
    var conditionalList: some View {
        Group {
            if environment.homeListType == .search {
                GenericList(
                    items: homeInfo.searchItems,
                    loadingFlag: homeInfo.searchLoading,
                    notFoundFlag: homeInfo.searchNotFound,
                    loadFailedFlag: homeInfo.searchLoadFailed,
                    fetchAction: fetchSearchItems,
                    loadMoreAction: fetchMoreSearchItems
                )
            } else if environment.homeListType == .frontpage {
                GenericList(
                    items: homeInfo.frontpageItems,
                    loadingFlag: homeInfo.frontpageLoading,
                    notFoundFlag: homeInfo.frontpageNotFound,
                    loadFailedFlag: homeInfo.frontpageLoadFailed,
                    fetchAction: fetchFrontpageItems,
                    loadMoreAction: fetchMoreFrontpageItems
                )
            } else if environment.homeListType == .popular {
                GenericList(
                    items: homeInfo.popularItems,
                    loadingFlag: homeInfo.popularLoading,
                    notFoundFlag: homeInfo.popularNotFound,
                    loadFailedFlag: homeInfo.popularLoadFailed,
                    fetchAction: fetchPopularItems
                )
            } else if environment.homeListType == .favorites {
                GenericList(
                    items: homeInfo.favoritesItems?.map { $0.value },
                    loadingFlag: homeInfo.favoritesLoading,
                    notFoundFlag: homeInfo.favoritesNotFound,
                    loadFailedFlag: homeInfo.favoritesLoadFailed,
                    fetchAction: fetchFavoritesItems,
                    loadMoreAction: fetchMoreFavoritesItems
                )
            }
        }
    }
    
    // MARK: HomeView本体
    var body: some View {
        NavigationView {
            conditionalList
                .sheet(item: environmentBinding.homeViewSheetState, content: { item in
                    switch item {
                    case .setting:
                        SettingView()
                            .environmentObject(store)
                    case .filter:
                        FilterView()
                            .environmentObject(store)
                    }
                })
                .navigationBarTitle(
                    environment.homeListType.rawValue.lString()
                )
                .navigationBarItems(
                    leading: categoryPicker,
                    trailing: settingEntry
                )
                .onChange(
                    of: environment.homeListType,
                    perform: onHomeListTypeChange
                )
                .onAppear(perform: onAppear)
            
            SecondaryView()
        }
        .modify(
            if: isPad && setting?.hideSideBar == false,
            then: DefaultNavStyle(),
            else: StackNavStyle()
        )
    }
    
    func onAppear() {
        if settings.setting == nil {
            store.dispatch(.initiateSetting)
        }
        fetchFrontpageItemsIfNeeded()
        fetchFavoritesItemsIfNeeded()
    }
    func onHomeListTypeChange(_ type: HomeListType) {
        switch type {
        case .frontpage:
            fetchFrontpageItemsIfNeeded()
        case .popular:
            fetchPopularItemsIfNeeded()
        case .favorites:
            fetchFavoritesItemsIfNeeded()
        case .downloaded:
            print(type)
        case .search:
            print(type)
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
    func fetchFavoritesItems() {
        store.dispatch(.fetchFavoritesItems)
    }
    
    func fetchMoreSearchItems() {
        
    }
    func fetchMoreFrontpageItems() {
        
    }
    func fetchMoreFavoritesItems() {
        
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
    func fetchFavoritesItemsIfNeeded() {
        if homeInfo.favoritesItems?.isEmpty != false {
            fetchFavoritesItems()
        }
    }
    
    func toggleSetting() {
        store.dispatch(.toggleHomeViewSheetState(state: .setting))
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
        VStack {
            if exx {
                SearchBar(
                    keyword: homeInfoBinding.searchKeyword,
                    commitAction: searchBarCommit,
                    filterAction: searchBarFilter
                )
                .padding(.top, 15)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            KRefreshScrollView(
                progressTint: .gray,
                arrowTint: .primary,
                onUpdate: onUpdate
            ) {
                if !didLogin() && exx {
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
                        NavigationLink(destination: DetailView(id: item.id)) {
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

// MARK: カテゴリー選択
private struct CategoryPicker: View {
    @Binding var type: HomeListType
    
    var body: some View {
        Picker(selection: $type,
               label: Text("☰")
                .foregroundColor(.primary)
                .font(.largeTitle),
               content: {
                let frontpageTypes: [HomeListType]
                    = [.frontpage, .popular, .favorites, .downloaded]
                ForEach(frontpageTypes, id: \.self) {
                    Text($0.rawValue.lString())
                }
               })
            .pickerStyle(MenuPickerStyle())
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

// MARK: 概要列
private struct MangaSummaryRow: View {
    var rectangle: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 80, height: 110)
    }
    
    let manga: Manga
    
    var body: some View {
        HStack {
            WebImage(url: URL(string: manga.coverURL),
                     options: [.retryFailed, .handleCookies])
                .resizable()
                .placeholder { rectangle }
                .indicator(.activity)
                .scaledToFit()
                .frame(width: 80, height: 110)
            VStack(alignment: .leading) {
                Text(manga.title)
                    .lineLimit(manga.uploader == nil ? 2 : 1)
                    .font(.headline)
                    .foregroundColor(.primary)
                if let uploader = manga.uploader {
                    Text(uploader)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                HStack {
                    RatingView(rating: manga.rating)
                    if let language = manga.language {
                        Spacer()
                        Text(language.translatedLanguage.lString())
                            .lineLimit(1)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(alignment: .bottom) {
                    if exx {
                        Text(manga.jpnCategories.lString())
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.init(top: 1, leading: 3, bottom: 1, trailing: 3))
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .foregroundColor(manga.color)
                            )
                    }
                    Spacer()
                    Text(manga.publishedTime)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 1)
            }.padding(10)
        }
        .background(Color(.systemGray6))
        .cornerRadius(3)
    }
}

// MARK: 定義
enum HomeListType: String {
    case search = "検索"
    case frontpage = "ホーム"
    case popular = "人気"
    case favorites = "お気に入り"
    case downloaded = "ダウンロード済み"
}

enum HomeViewSheetState: Identifiable {
    var id: Int { hashValue }
    
    case setting
    case filter
}
