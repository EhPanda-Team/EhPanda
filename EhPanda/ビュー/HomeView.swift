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
    
    var homeList: AppState.HomeList {
        store.appState.homeList
    }
    var homeListBinding: Binding<AppState.HomeList> {
        $store.appState.homeList
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    
    init() {
        UIScrollView.appearance().keyboardDismissMode = .onDrag
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack {
                    if exx {
                        SearchBar(keyword: homeListBinding.keyword) {
                            if homeList.type != .search {
                                store.dispatch(.toggleHomeListType(type: .search))
                            }
                            store.dispatch(.fetchSearchItems(keyword: homeList.keyword))
                        } filterAction: {}
                    }
                    
                    if homeList.type == .search {
                        GenericList(
                            items: homeList.searchItems,
                            loadingFlag: homeList.searchLoading,
                            notFoundFlag: homeList.searchNotFound,
                            loadFailedFlag: homeList.searchLoadFailed)
                    } else if homeList.type == .popular {
                        GenericList(
                            items: homeList.popularItems,
                            loadingFlag: homeList.popularLoading,
                            notFoundFlag: homeList.popularNotFound,
                            loadFailedFlag: homeList.popularLoadFailed)
                    } else if homeList.type == .favorites {
                        GenericList(
                            items: homeList.favoritesItems?.map { $0.value },
                            loadingFlag: homeList.favoritesLoading,
                            notFoundFlag: homeList.favoritesNotFound,
                            loadFailedFlag: homeList.favoritesLoadFailed)
                    }
                }
                .padding()
                .onChange(of: homeList.type, perform: { type in
                    switch type {
                    case .popular:
                        if homeList.popularItems != nil { return }
                        store.dispatch(.fetchPopularItems)
                    case .favorites:
                        store.dispatch(.fetchFavoritesItems)
                    case .downloaded:
                        print(type)
                    case .search:
                        print(type)
                    }
                })
                .onAppear {
                    if homeList.popularItems == nil {
                        store.dispatch(.fetchPopularItems)
                    }
                    if homeList.favoritesItems == nil {
                        store.dispatch(.fetchFavoritesItems)
                    }
                }
            }
            .navigationBarTitle(homeList.type.rawValue.lString())
            .navigationBarItems(
                leading:
                    Group {
                        if exx {
                            CategoryPicker(type: homeListBinding.type)
                            .padding(.bottom, 10)
                        }
                    },
                trailing:
                    Group {
                        if exx {
                            Image(systemName: "gear")
                            .foregroundColor(.primary)
                            .imageScale(.large)
                            .sheet(isPresented: environmentBinding.isSettingPresented, content: {
                                SettingView()
                                    .environmentObject(store)
                            })
                            .onTapGesture {
                                store.dispatch(.toggleSettingPresented)
                            }
                        }
                    }
                
            )
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

// MARK: 汎用リスト
private struct GenericList: View {
    @EnvironmentObject var store: Store
    
    var items: [Manga]?
    var loadingFlag: Bool
    var notFoundFlag: Bool
    var loadFailedFlag: Bool
    var fetchAction: (()->())?
    
    var body: some View {
        Group {
            if !didLogin() && exx {
                NotLoginView(loginAction: {
                    store.dispatch(.toggleSettingPresented)
                })
                .padding(.top, 30)
            } else if loadingFlag {
                LoadingView()
                    .padding(.top, 30)
            } else if loadFailedFlag {
                NetworkErrorView(retryAction: nil)
                    .padding(.top, 30)
            } else if notFoundFlag {
                NotFoundView(retryAction: fetchAction)
                    .padding(.top, 30)
            } else {
                ForEach(items ?? []) { item in
                    NavigationLink(destination: DetailView(id: item.id)) {
                        MangaSummaryRow(manga: item)
                    }
                }
                .transition(AnyTransition.opacity.animation(.default))
            }
        }
        .onAppear {
            guard items == nil else { return }
            
            if let action = fetchAction {
                action()
            }
        }
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
                let homepageTypes: [HomeListType] = [.popular, .favorites, .downloaded]
                ForEach(homepageTypes, id: \.self) {
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
            ZStack {
                TextField("検索", text: $keyword, onCommit: commitAction)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                HStack {
                    Spacer()
                    if !keyword.isEmpty {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .onTapGesture {
                                keyword = ""
                            }
                    }
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.gray)
                        .onTapGesture {}
                }
                
            }
        }
        .padding(10)
        .padding(.horizontal, 10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.bottom, 10)
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
                }
                HStack(alignment: .bottom) {
                    if exx {
                        Text(manga.translatedCategory.lString())
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.init(top: 1, leading: 3, bottom: 1, trailing: 3))
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .foregroundColor(Color(manga.color))
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
