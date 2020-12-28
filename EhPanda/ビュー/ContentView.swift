//
//  ContentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

import SwiftUI
import SDWebImageSwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store
    
    let id: String
    var environment: AppState.Environment {
        store.appState.environment
    }
    var contentsInfo: AppState.ContentsInfo {
        store.appState.contentsInfo
    }
    var mangaContents: [MangaContent]? {
        store.appState.cachedList.items?[id]?.contents
    }
    
    var rectangle: some View {
        Rectangle()
            .fill(Color(.systemGray5))
    }
    
    var body: some View {
        Group {
            if let contents = mangaContents {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(contents) { item in
                            WebImage(url: URL(string: item.url),
                                     options: [.retryFailed, .handleCookies])
                                .resizable()
                                .placeholder { rectangle }
                                .indicator(.progress)
                                .scaledToFit()
                        }
                    }
                }
                .ignoresSafeArea()
                .transition(AnyTransition.opacity.animation(.default))
            } else if contentsInfo.mangaContentsLoading {
                LoadingView()
            } else if contentsInfo.mangaContentsLoadFailed {
                NetworkErrorView {
//                    store.dispatch(.fetchMangaContents(id: id))
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(environment.navBarHidden)
        .onAppear {
//            store.dispatch(.fetchMangaContents(id: id))
        }
    }
}
