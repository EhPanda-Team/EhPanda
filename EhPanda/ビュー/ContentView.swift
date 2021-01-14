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
    var cachedList: AppState.CachedList {
        store.appState.cachedList
    }
    var contentInfo: AppState.ContentInfo {
        store.appState.contentInfo
    }
    var mangaDetail: MangaDetail? {
        cachedList.items?[id]?.detail
    }
    var mangaContents: [MangaContent]? {
        cachedList.items?[id]?.contents
    }
    
    var rectangle: some View {
        Rectangle()
            .fill(Color(.systemGray5))
    }
    
    var body: some View {
        Group {
            if let contents = mangaContents {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(contents) { item in
                                WebImage(url: URL(string: item.url),
                                         options: [.retryFailed, .handleCookies]
                                )
                                .resizable()
                                .placeholder { rectangle }
                                .indicator(.progress)
                                .scaledToFit()
                                .onTapGesture(perform: onWebImageTap)
                                .onLongPressGesture(
                                    minimumDuration: 0,
                                    maximumDistance: .infinity,
                                    pressing: { _ in
                                        onWebImageLongPressing(tag: item.tag)
                                    }, perform: {}
                                )

                            }
                        }
                        .onAppear {
                            onLazyVStackAppear(proxy)
                        }
                    }
                    .ignoresSafeArea()
                    .transition(AnyTransition.opacity.animation(.default))
                }
            } else if contentInfo.mangaContentsLoading {
                LoadingView()
            } else if contentInfo.mangaContentsLoadFailed {
                NetworkErrorView(retryAction: fetchMangaContents)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(environment.navBarHidden)
        .onAppear(perform: onAppear)
    }
    
    func onAppear() {
        toggleNavBarHidden()
        
        if mangaContents?.count != Int(mangaDetail?.pageCount ?? "") {
            fetchMangaContents()
        }
    }
    func onWebImageLongPressing(tag: Int) {
        saveReadingProgress(tag: tag)
    }
    func onWebImageTap() {
        toggleNavBarHidden()
    }
    
    func saveReadingProgress(tag: Int) {
        store.dispatch(.saveReadingProgress(id: id, tag: tag))
    }
    func onLazyVStackAppear(_ proxy: ScrollViewProxy) {
        if let tag = mangaDetail?.readingProgress {
            proxy.scrollTo(tag)
        }
    }
    
    func fetchMangaContents() {
        store.dispatch(.fetchMangaContents(id: id))
    }
    
    func toggleNavBarHidden() {
        store.dispatch(.toggleNavBarHidden(isHidden: true))
    }
}
