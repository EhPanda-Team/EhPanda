//
//  ContentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

import SwiftUI
import Combine
import Kingfisher
import SDWebImageSwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State var readingProgress: Int = -1
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
    
    // MARK: ContentView本体
    var body: some View {
        Group {
            if let contents = mangaContents,
               let setting = setting
            {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(contents) { item in
                                SDContainer(
                                    content: item,
                                    retryLimit: setting.contentRetryLimit,
                                    onTapAction: onWebImageTap,
                                    onLongPressAction: onWebImageLongPress
                                )
                                if setting.showContentDividers {
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willResignActiveNotification
            )
        ) { _ in
            onResignActive()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willTerminateNotification
            )
        ) { _ in
            onResignActive()
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(environment.navBarHidden)
    }
    
    func onAppear() {
        toggleNavBarHiddenIfNeeded()
        
        if mangaContents?.count != Int(mangaDetail?.pageCount ?? "") {
            fetchMangaContents()
        }
    }
    func onDisappear() {
        saveReadingProgress()
    }
    func onResignActive() {
        saveReadingProgress()
    }
    func onLazyVStackAppear(_ proxy: ScrollViewProxy) {
        if let tag = mangaDetail?.readingProgress {
            proxy.scrollTo(tag)
        }
    }
    func onWebImageTap() {
        toggleNavBarHiddenIfNeeded()
    }
    func onWebImageLongPress(tag: Int) {
        readingProgress = tag
    }
    
    func saveReadingProgress() {
        if readingProgress != -1 {
            store.dispatch(.saveReadingProgress(id: id, tag: readingProgress))
        }
    }
    
    func fetchMangaContents() {
        store.dispatch(.fetchMangaContents(id: id))
    }
    
    func toggleNavBarHiddenIfNeeded() {
        if !environment.navBarHidden {
            store.dispatch(.toggleNavBarHidden(isHidden: true))
        }
    }
}

// MARK: SDContainer
private struct SDContainer: View {
    @State var percentage: Float = 0
    
    var content: MangaContent
    var retryLimit: Int
    var onTapAction: () -> ()
    var onLongPressAction: (Int) -> ()
    
    var body: some View {
        WebImage(url: URL(string: content.url))
            .placeholder {
                Placeholder(
                    style: .progress,
                    pageNumber: content.tag,
                    percentage: percentage
                )
            }
//            .retry(
//                maxCount: retryLimit,
//                interval: .seconds(0.5)
//            )
            .onProgress(perform: onWebImageProgress)
            .cancelOnDisappear(true)
            .resizable()
            .scaledToFit()
            .onTapGesture(perform: onTap)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { _ in
                    onLongPressing(tag: content.tag)
                }, perform: {}
            )
    }
    
    func onWebImageProgress(_ received: Int, _ total: Int) {
        percentage = min(Float(received) / Float(total), 0.5)
    }
    func onTap() {
        onTapAction()
    }
    func onLongPressing(tag: Int) {
        onLongPressAction(tag)
    }
}
