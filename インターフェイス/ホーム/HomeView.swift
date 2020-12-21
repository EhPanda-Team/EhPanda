//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import SDWebImageSwiftUI

enum HomepageType: String {
    case search = "検索"
    case popular = "人気"
    case favorite = "お気に入り"
    case downloaded = "ダウンロード済み"
}

struct HomeView: View {
    @EnvironmentObject var settings: Settings
    @StateObject var store = HomeItemsStore()
    
    @State var currentPageType: HomepageType = .popular
    @State var isProfilePresented = false
    @State var keyword = ""
    
    init() {
        UIScrollView.appearance().keyboardDismissMode = .onDrag
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack {
                    SearchBar(keyword: $keyword) {
                        if keyword.isEmpty {
                            currentPageType = .popular
                            store.fetchPopularItems()
                            return
                        }
                        currentPageType = .search
                        store.fetchSearchItems(keyword: keyword)
                    } filterAction: {}
                    
                    if !store.homeItems.isEmpty {
                        ForEach(store.homeItems) { item in
                            NavigationLink(destination: DetailView(manga: item)) {
                                MangaSummaryRow(manga: item)
                            }
                        }
                        .transition(AnyTransition.opacity.animation(.default))
                    } else {
                        LoadingView()
                    }
                }
                .padding()
            }
            .navigationBarTitle(currentPageType.rawValue)
            .navigationBarItems(
                leading:
                    CategoryPicker(currentPageType: $currentPageType)
                    .padding(.bottom, 10),
                trailing:
                    Image(systemName: "person.crop.circle")
                    .foregroundColor(.primary)
                    .imageScale(.large)
                    .sheet(isPresented: $isProfilePresented, content: {
                        EmptyView()
                    })
                    .onTapGesture {
                        isProfilePresented.toggle()
                    }
                
            )
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear {
                if store.homeItems.isEmpty {
                    store.fetchPopularItems()
                }
            }
        }
    }
}

// MARK: カテゴリー選択
private struct CategoryPicker: View {
    @Binding var currentPageType: HomepageType
    
    var body: some View {
        Picker(selection: $currentPageType,
           label: Text("☰")
                    .foregroundColor(.primary)
                    .font(.largeTitle),
           content: {
                let homepageTypes: [HomepageType] = [.popular, .favorite, .downloaded]
                ForEach(homepageTypes, id: \.self) {
                    Text($0.rawValue)
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
                TextField("検索ワードを入力してください", text: $keyword, onCommit: commitAction)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                HStack {
                    Spacer()
                    if !keyword.isEmpty {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .onTapGesture {
                                keyword = ""
                                commitAction()
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
    @Environment(\.colorScheme) var colorScheme
    var color: Color {
        colorScheme == .light ? .white : .black
    }
    var rectangle: some View {
        Rectangle()
            .fill(color)
            .frame(width: 70, height: 110)
    }
    
    let manga: Manga
    
    var body: some View {
        HStack {
            WebImage(url: URL(string: manga.coverURL))
                .resizable()
                .placeholder { rectangle }
                .indicator(.activity)
                .scaledToFit()
                .frame(width: 70, height: 110)
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
                    Text(manga.translatedCategory)
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
