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

    @State private var position: CGFloat = 0
    @State private var aspectBox = [Int: CGFloat]()

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var newOffset: CGSize = .zero

    private let gid: String

    init(gid: String) {
        self.gid = gid
    }

    // MARK: ContentView
    @ViewBuilder var body: some View {
        let doubleTap = TapGesture(
            count: 2
        )
        .onEnded(onDoubleTap)
        let drag = DragGesture(
            minimumDistance: 0.0,
            coordinateSpace: .local
        )
        .onChanged(onDragGestureChanged)
        .onEnded(onDragGestureEnded)
        let magnify = MagnificationGesture()
        .onChanged(onMagnificationGestureChanged)
        .onEnded(onMagnificationGestureEnded)

        Group {
            if let contents = mangaContents,
               let setting = setting,
               !contents.isEmpty
            {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        GeometryReader { geoProxy in
                            Text("I'm invisible~")
                                .onChange(
                                    of: geoProxy.frame(in: .global).minY,
                                    perform: updateGeoProxyMinY
                                )
                        }
                        .frame(width: 0, height: 0)
                        LazyVStack(spacing: setting.contentDividerHeight) {
                            ForEach(contents) { item in
                                ZStack {
                                    ImageContainer(
                                        content: item,
                                        retryLimit: setting.contentRetryLimit,
                                        onSuccessAction: onWebImageSuccess
                                    )
                                    .frame(
                                        width: absoluteScreenW,
                                        height: calImageHeight(tag: item.tag)
                                    )
                                    .onAppear {
                                        onWebImageAppear(item: item)
                                    }
                                }
                            }
                            LoadMoreFooter(
                                moreLoadingFlag: moreLoadingFlag,
                                moreLoadFailedFlag: moreLoadFailedFlag,
                                retryAction: fetchMoreMangaContents
                            )
                            .padding(.bottom, 20)
                        }
                        .task {
                            onLazyVStackAppear(proxy: scrollProxy)
                        }
                    }
                    .transition(animatedTransition)
                    .ignoresSafeArea()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(doubleTap)
                    .gesture(drag)
                    .gesture(magnify)
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
            toggleNavBarHiddenIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willResignActiveNotification
            )
        ) { _ in
            onEndTasks()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willTerminateNotification
            )
        ) { _ in
            onEndTasks()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("AppWidthDidChange")
            )
        ) { _ in
            onWidthChange()
        }
        .task(onStartTasks)
        .onAppear(perform: toggleNavBarHiddenIfNeeded)
        .onDisappear(perform: onEndTasks)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(environment.navBarHidden)
    }
}

// MARK: Private Extension
private extension ContentView {
    // MARK: Properties
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
    var contentHScale: CGFloat {
        Defaults.ImageSize.contentHScale
    }

    // MARK: Life Cycle
    func onStartTasks() {
        restoreAspectBox()
        fetchMangaContentsIfNeeded()
    }
    func onEndTasks() {
        saveAspectBox()
        saveReadingProgress()
    }
    func onWidthChange() {
        DispatchQueue.main.async {
            set(newOffset: .zero)
            set(newScale: 1.1)
            set(newScale: 1)
        }
    }
    func onLazyVStackAppear(proxy: ScrollViewProxy) {
        if let tag = mangaDetail?.readingProgress {
            proxy.scrollTo(tag)
        }
    }
    func onWebImageAppear(item: MangaContent) {
        if item == mangaContents?.last {
            fetchMoreMangaContents()
        }
    }
    func onWebImageSuccess(tag: Int, aspect: CGFloat) {
        aspectBox[tag] = aspect
    }

    // MARK: Dispatch
    func fetchMangaContents() {
        DispatchQueue.main.async {
            store.dispatch(.fetchMangaContents(gid: gid))
        }
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

    // MARK: ReadingProgress
    func calImageHeight(tag: Int) -> CGFloat {
        if let aspect = aspectBox[tag] {
            return absoluteScreenW * aspect
        } else {
            return screenH * contentHScale
        }
    }
    func calReadingProgress() -> Int {
        guard let contentsCount = mangaContents?.count
        else { return -1 }

        var heightArray = Array(
            repeating: screenH * contentHScale,
            count: contentsCount
        )
        aspectBox.forEach { (key: Int, value: CGFloat) in
            heightArray[key] = value * screenW
        }

        var remainingPosition = position + screenH / 2
        for (index, value) in heightArray.enumerated() {
            remainingPosition -= value
            if remainingPosition < 0 {
                return index
            }
        }
        return -1
    }
    func updateGeoProxyMinY(value: CGFloat) {
        position = abs(value)
    }

    func saveReadingProgress() {
        let progress = calReadingProgress()
        if progress != -1 {
            store.dispatch(
                .saveReadingProgress(
                    gid: gid,
                    tag: progress
                )
            )
        }
    }
    func restoreAspectBox() {
        if let aspectBox = mangaDetail?.aspectBox {
            self.aspectBox = aspectBox
        }
    }
    func saveAspectBox() {
        if !aspectBox.isEmpty {
            store.dispatch(
                .saveAspectBox(
                    gid: gid,
                    box: aspectBox
                )
            )
        }
    }

    // MARK: Gestures
    func onDoubleTap(value: TapGesture.Value) {
        set(newOffset: .zero)
        set(newScale: scale == 1 ? setting?.doubleTapScaleFactor ?? 2 : 1)
    }
    func onDragGestureChanged(value: DragGesture.Value) {
        if scale > 1 {
            let newX = value.translation.width + newOffset.width
            let screenW = UIScreen.main.bounds.width
            let marginW = screenW * (scale - 1) / 2

            let newOffsetW = min(max(newX, -marginW), marginW)
            set(newOffset: CGSize(width: newOffsetW, height: offset.height))
        }
    }
    func onDragGestureEnded(value: DragGesture.Value) {
        onDragGestureChanged(value: value)

        if scale > 1 {
            newOffset.width = offset.width
        }
    }
    func onMagnificationGestureChanged(value: MagnificationGesture.Value) {
        if value == 1 {
            baseScale = scale
        }
        fixOffset()
        set(newScale: value * baseScale)
    }
    func onMagnificationGestureEnded(value: MagnificationGesture.Value) {
        onMagnificationGestureChanged(value: value)
        if value * baseScale - 1 < 0.01 {
            set(newScale: 1)
        }
        baseScale = scale
    }

    func set(newOffset: CGSize) {
        let animation = Animation
            .linear(duration: 0.1)
        if offset != newOffset {
            withAnimation(animation) {
                offset = newOffset
            }
        }
    }
    func fixOffset() {
        let screenW = UIScreen.main.bounds.width
        let marginW = screenW * (scale - 1) / 2

        withAnimation {
            if offset.width > marginW {
                offset.width = marginW
            } else if offset.width < -marginW {
                offset.width = -marginW
            }
        }
    }
    func set(newScale: CGFloat) {
        let max = setting?.maximumScaleFactor ?? 3
        guard scale != newScale && newScale >= 1 && newScale <= max
        else { return }

        withAnimation {
            scale = newScale
            print("debugMark: \(newScale)")
        }
    }
}

// MARK: ImageContainer
private struct ImageContainer: View {
    @State private var percentage: Float = 0

    private var content: MangaContent
    private var retryLimit: Int
    private var onSuccessAction: ((Int, CGFloat)) -> Void

    private var contentHScale: CGFloat {
        Defaults.ImageSize.contentHScale
    }

    init(
        content: MangaContent,
        retryLimit: Int,
        onSuccessAction: @escaping ((Int, CGFloat)) -> Void
    ) {
        self.content = content
        self.retryLimit = retryLimit
        self.onSuccessAction = onSuccessAction
    }

    var body: some View {
        KFImage(URL(string: content.url))
            .placeholder {
                Placeholder(
                    style: .progress(
                        pageNumber: content.tag,
                        percentage: percentage
                    )
                )
                .frame(
                    width: absoluteScreenW,
                    height: screenH * contentHScale
                )
            }
            .retry(
                maxCount: retryLimit,
                interval: .seconds(0.5)
            )
            .onProgress(onWebImageProgress)
            .onSuccess(onWebImageSuccess)
            .loadImmediately()
            .resizable()
            .scaledToFit()
    }

    private func onWebImageProgress<I: BinaryInteger>(received: I, total: I) {
        percentage = Float(received) / Float(total)
    }
    private func onWebImageSuccess(result: RetrieveImageResult) {
        let size = result.image.size
        let aspect = size.height / size.width
        onSuccessAction((content.tag, aspect))
    }
}
