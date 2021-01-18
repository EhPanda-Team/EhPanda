//
//  ContentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

import SwiftUI
import Kingfisher

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State var percentages: [Int : Float] = [:]
    
    let id: String
    var environment: AppState.Environment {
        store.appState.environment
    }
    var setting: Setting? {
        store.appState.settings.setting
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
    func placeholder(_ pageNum: Int) -> some View {
        Placeholder(
            style: .progress,
            pageNumber: pageNum,
            percentage: percentages[pageNum]
        )
    }
    
    var body: some View {
        Group {
            if let contents = mangaContents,
               let setting = setting
            {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(contents) { item in
                                KFImage(URL(string: item.url), options: [])
                                    .placeholder {
                                        placeholder(item.tag)
                                    }
                                    .onProgress {
                                        onWebImageProgress(tag: item.tag, $0, $1)
                                    }
                                    .retry(
                                        maxCount: setting.contentRetryLimit,
                                        interval: .seconds(0.5)
                                    )
                                    .cancelOnDisappear(true)
                                    .resizable()
                                    .scaledToFit()
                                    .onTapGesture(perform: onWebImageTap)
                                    .onLongPressGesture(
                                        minimumDuration: 0,
                                        maximumDistance: .infinity,
                                        pressing: { _ in
                                            onWebImageLongPressing(tag: item.tag)
                                        }, perform: {}
                                    )
                                if setting.showContentDividers
                                {
                                    Rectangle()
                                        .fill(Color(.darkGray))
                                        .frame(height: setting.contentDividerHeight)
                                        .edgesIgnoringSafeArea(.horizontal)
                                }
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
    func onLazyVStackAppear(_ proxy: ScrollViewProxy) {
        if let tag = mangaDetail?.readingProgress {
            proxy.scrollTo(tag)
        }
    }
    func onWebImageProgress(tag: Int, _ received: Int64, _ total: Int64) {
        percentages[tag] = Float(received) / Float(total)
    }
    func onWebImageTap() {
        toggleNavBarHidden()
    }
    func onWebImageLongPressing(tag: Int) {
        saveReadingProgress(tag: tag)
    }
    
    func saveReadingProgress(tag: Int) {
        store.dispatch(.saveReadingProgress(id: id, tag: tag))
    }
    
    func fetchMangaContents() {
        store.dispatch(.fetchMangaContents(id: id))
    }
    
    func toggleNavBarHidden() {
        store.dispatch(.toggleNavBarHidden(isHidden: true))
    }
}
