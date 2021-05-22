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

struct ContentView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var readingProgress: Int = -1

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var newOffset: CGSize = .zero

    private let gid: String

    init(gid: String) {
        self.gid = gid
    }

    // MARK: ContentView
    var body: some View {
        let tapGesture = TapGesture(
            count: 2
        )
        .onEnded(onTapGestureEnded)

        let magnificationGesture = MagnificationGesture()
        .onChanged(onMagnificationGestureChanged)
        .onEnded(onMagnificationGestureEnded)

        let dragGesture = DragGesture(
            minimumDistance: 0.0,
            coordinateSpace: .local
        )
        .onChanged(onDragGestureChanged)
        .onEnded(onDragGestureEnded)

        return Group {
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
                    .transition(
                        AnyTransition
                            .opacity
                            .animation(
                                .default
                            )
                    )
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(tapGesture)
                    .gesture(dragGesture)
                    .gesture(magnificationGesture)
                }
            } else if contentInfo.mangaContentsLoading {
                LoadingView()
            } else {
                NetworkErrorView(retryAction: fetchMangaContents)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("DetailViewOnDisappear")
            )
        ) { _ in
            onReceiveDetailViewOnDisappearNotification()
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
}

private extension ContentView {
    var mangaDetail: MangaDetail? {
        cachedList.items?[gid]?.detail
    }
    var mangaContents: [MangaContent]? {
        cachedList.items?[gid]?.contents
    }
    var moreLoadingFlag: Bool {
        contentInfo.moreMangaContentsLoading
    }
    var moreLoadFailedFlag: Bool {
        contentInfo.moreMangaContentsLoadFailed
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
    func onReceiveDetailViewOnDisappearNotification() {
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
    func onWebImageTap() {}
    func onWebImageLongPress(tag: Int) {
        readingProgress = tag
    }

    func saveReadingProgress() {
        if readingProgress != -1 {
            store.dispatch(
                .saveReadingProgress(
                    gid: gid,
                    tag: readingProgress
                )
            )
        }
    }

    func fetchMangaContents() {
        store.dispatch(.fetchMangaContents(gid: gid))
    }
    func fetchMoreMangaContents() {
        store.dispatch(.fetchMoreMangaContents(gid: gid))
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

    // MARK: Gestures
    func onTapGestureEnded(_ value: TapGesture.Value) {
        setOffset(.zero)
        setScale(scale == 1 ? 2 : 1)
    }
    func onDragGestureChanged(_ value: DragGesture.Value) {
//        pointTapped = value.startLocation

        if scale > 1 {
            let newX = value.translation.width + newOffset.width
            let screenW = UIScreen.main.bounds.width
            let marginW = screenW * (scale - 1) / 2

            let newOffsetW = min(max(newX, -marginW), marginW)
            setOffset(CGSize(width: newOffsetW, height: offset.height))
        }
    }
    func onDragGestureEnded(_ value: DragGesture.Value) {
        onDragGestureChanged(value)

        if scale > 1 {
            newOffset.width = offset.width
        }
    }
    func onMagnificationGestureChanged(_ value: MagnificationGesture.Value) {
        withAnimation {
            setOffset(.zero)
            setScale(max(value.magnitude, 1))
        }
    }
    func onMagnificationGestureEnded(_ value: MagnificationGesture.Value) {
        onMagnificationGestureChanged(value)
    }

    func setOffset(_ newOffset: CGSize) {
        let animation = Animation
            .linear(duration: 0.1)
        withAnimation(animation) {
            offset = newOffset
        }
    }
    func setScale(_ newScale: CGFloat) {
        withAnimation {
            scale = newScale
        }
    }
}

// MARK: ImageContainer
private struct ImageContainer: View {
    @State private var percentage: Float = 0

    private var content: MangaContent
    private var retryLimit: Int
    private var onTapAction: () -> Void
    private var onLongPressAction: (Int) -> Void

    init(
        content: MangaContent,
        retryLimit: Int,
        onTapAction: @escaping () -> Void,
        onLongPressAction: @escaping (Int) -> Void
    ) {
        self.content = content
        self.retryLimit = retryLimit
        self.onTapAction = onTapAction
        self.onLongPressAction = onLongPressAction
    }

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
//            .onTapGesture(perform: onTap)
//            .onLongPressGesture(
//                minimumDuration: 2,
//                maximumDistance: .infinity,
//                pressing: { _ in
//                    onLongPressing(tag: content.tag)
//                }, perform: {}
//            )
    }

    private func onWebImageProgress<I: BinaryInteger>(
        _ received: I, _ total: I
    ) {
        percentage = Float(received) / Float(total)
    }
    private func onTap() {
        onTapAction()
    }
    private func onLongPressing(tag: Int) {
        onLongPressAction(tag)
    }
}
