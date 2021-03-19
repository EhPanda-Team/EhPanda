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
    
    let timer = Timer
        .publish(
            every: 1,
            on: .main,
            in: .common
        )
        .autoconnect()
    
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
    var moreLoadingFlag: Bool {
        contentInfo.moreMangaContentsLoading
    }
    var moreLoadFailedFlag: Bool {
        contentInfo.moreMangaContentsLoadFailed
    }
        
    // MARK: ContentView
    var body: some View {
        Group {
            if let contents = mangaContents,
               let setting = setting,
               !contents.isEmpty
            {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(contents) { item in
                                ImageContainer(
                                    content: item,
                                    retryLimit: setting.contentRetryLimit,
                                    onTapAction: onWebImageTap,
                                    onLongPressAction: onWebImageLongPress
                                )
                                .onAppear {
                                    onWebImageAppear(item)
                                }
                                if setting.showContentDividers {
                                    Rectangle()
                                        .fill(Color(.darkGray))
                                        .frame(height: setting.contentDividerHeight)
                                        .edgesIgnoringSafeArea(.horizontal)
                                }
                            }
                            Group {
                                if moreLoadingFlag {
                                    LoadingView(isCompact: true)
                                } else if moreLoadFailedFlag {
                                    NetworkErrorView(
                                        isCompact: true,
                                        retryAction: fetchMoreMangaContents
                                    )
                                }
                            }
                            .padding()
                            .padding(.bottom, 24)
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
            } else {
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
        .onReceive(timer) { _ in
            onTimerFire()
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(environment.navBarHidden)
    }
    
    func onAppear() {
        toggleNavBarHiddenIfNeeded()
        fetchMangaContentsIfNeeded()
    }
    func onDisappear() {
        saveReadingProgress()
    }
    func onResignActive() {
        saveReadingProgress()
    }
    func onTimerFire() {
        toggleNavBarHiddenIfNeeded()
    }
    func onLazyVStackAppear(_ proxy: ScrollViewProxy) {
        if let tag = mangaDetail?.readingProgress {
            proxy.scrollTo(tag)
        }
    }
    func onWebImageAppear(_ item: MangaContent) {
        if item == mangaContents?.last {
            fetchMoreMangaContents()
        }
    }
    func onWebImageTap() {
        
    }
    func onWebImageLongPress(tag: Int) {
        readingProgress = tag
    }
    
    func saveReadingProgress() {
        if readingProgress != -1 {
            store.dispatch(
                .saveReadingProgress(
                    id: id,
                    tag: readingProgress
                )
            )
        }
    }
    
    func fetchMangaContents() {
        store.dispatch(.fetchMangaContents(id: id))
    }
    func fetchMoreMangaContents() {
        store.dispatch(.fetchMoreMangaContents(id: id))
    }
    
    func fetchMangaContentsIfNeeded() {
        if let contents = mangaContents, !contents.isEmpty {
            if contents.count != Int(mangaDetail?.pageCount ?? "") {
                fetchMangaContents()
            }
        } else {
            fetchMangaContents()
        }
    }
    func toggleNavBarHiddenIfNeeded() {
        if !environment.navBarHidden {
            store.dispatch(.toggleNavBarHidden(isHidden: true))
        }
    }
}

// MARK: ImageContainer
private struct ImageContainer: View {
    @State var percentage: Float = 0
    
    var content: MangaContent
    var retryLimit: Int
    var onTapAction: () -> ()
    var onLongPressAction: (Int) -> ()
    
    var body: some View {
        KFImage(URL(string: content.url))
            .placeholder {
                Placeholder(
                    style: .progress,
                    pageNumber: content.tag,
                    percentage: percentage
                )
            }
            .retry(
                maxCount: retryLimit,
                interval: .seconds(0.5)
            )
            .onProgress(onWebImageProgress)
            .loadImmediately()
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
    
    func onWebImageProgress<I: BinaryInteger>(
        _ received: I, _ total: I
    ) {
        percentage = Float(received) / Float(total)
    }
    func onTap() {
        onTapAction()
    }
    func onLongPressing(tag: Int) {
        onLongPressAction(tag)
    }
}
