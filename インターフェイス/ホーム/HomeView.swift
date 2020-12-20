//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: Settings
    @StateObject var store = HomeItemsStore()
    @State var keyword = ""
    
    init() {
        UIScrollView.appearance().keyboardDismissMode = .onDrag
    }
    
    var body: some View {
        NavigationView {
            ScrollView { LazyVStack {
                SearchBar(keyword: $keyword) {
                    if keyword.isEmpty {
                        store.fetchPopularItems()
                        return
                    }
                    store.fetchSearchItems(keyword: keyword)
                }
                if !store.homeItems.isEmpty {
                    ForEach(store.homeItems) { item in NavigationLink(destination: DetailView(manga: item)) {
                        let imageContainer = ImageContainer(from: item.coverURL, type: .cover, 110)
                        MangaSummaryRow(container: imageContainer, manga: item)
                    }}
                    .transition(AnyTransition.opacity.animation(.linear(duration: 0.5)))
                    
                } else {
                    LoadingView()
                }}
                .padding()
            }
            .navigationBarTitle("ホーム")
            .navigationBarItems(trailing:
                NavigationLink(destination: EmptyView(), label: {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.primary)
                        .imageScale(.large)
                })
            )
        }
        .navigationBarHidden(settings.navBarHidden)
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            settings.navBarHidden = false
            
            if store.homeItems.isEmpty {
                store.fetchPopularItems()
            }
        }
    }
}

private struct SearchBar: View {
    @Binding var keyword: String
    var commitAction: () -> ()
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            ZStack {
                TextField("検索ワードを入力してください", text: $keyword, onCommit: commitAction)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                if !keyword.isEmpty {
                    HStack {
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .onTapGesture {
                                keyword = ""
                                commitAction()
                            }
                    }
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

private struct MangaSummaryRow: View {
    @StateObject var container: ImageContainer
    let manga: Manga
    
    var body: some View {
        HStack {
            container.image
                .resizable()
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
