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
        
    init() {
        UIScrollView.appearance().keyboardDismissMode = .onDrag
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    SearchBar(keyword: homeListBinding.keyword) {
                        store.dispatch(.toggleHomeListType(type: .search))
                        store.dispatch(.fetchSearchItems(keyword: homeList.keyword))
                    } filterAction: {}
                    
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
                    }
                }
                .padding()
                .onAppear {
                    if homeList.popularItems != nil { return }
                    store.dispatch(.fetchPopularItems)
                }
            }
            .navigationBarTitle(homeList.type.rawValue.lString())
            .navigationBarItems(
                leading:
                    CategoryPicker(type: homeListBinding.type)
                    .padding(.bottom, 10),
                trailing:
                    Image(systemName: "person.crop.circle")
                    .foregroundColor(.primary)
                    .imageScale(.large)
                    .sheet(isPresented: homeListBinding.isSettingPresented, content: {
                        EmptyView()
                    })
                    .onTapGesture {
                        store.dispatch(.toggleSettingPresented)
                    }
                
            )
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

// MARK: 汎用リスト
private struct GenericList: View {
    var items: [Manga]?
    var loadingFlag: Bool
    var notFoundFlag: Bool
    var loadFailedFlag: Bool
    
    init(
        items: [Manga]?,
        loadingFlag: Bool,
        notFoundFlag: Bool = false,
        loadFailedFlag: Bool,
        fetchClosure: (()->())? = nil)
    {
        self.items = items
        self.loadingFlag = loadingFlag
        self.notFoundFlag = notFoundFlag
        self.loadFailedFlag = loadFailedFlag
        self.fetchClosure = fetchClosure
    }
    
    var fetchClosure: (()->())?
    
    var body: some View {
        Group {
            if loadingFlag {
                LoadingView()
            } else if loadFailedFlag {
                Text("ネットワーク障害")
            } else if notFoundFlag {
                Text("アイテムが見つかりませんでした")
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
            guard let fetchClosure = fetchClosure,
                  items == nil else { return }
            
            fetchClosure()
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
            WebImage(url: URL(string: manga.coverURL))
                .resizable()
                .placeholder { rectangle }
                .indicator(.activity)
                .scaledToFit()
                .frame(width: 80, height: 110)
            VStack(alignment: .leading) {
                Text(manga.title)
                    .lineLimit(1)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(manga.uploader)
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack {
                    RatingView(rating: manga.rating)
                }
                HStack(alignment: .bottom) {
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
