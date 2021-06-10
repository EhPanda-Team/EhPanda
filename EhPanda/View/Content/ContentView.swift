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
    var body: some View {
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

        return Group {
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
                        LazyVStack(spacing: 0) {
                            ForEach(contents) { item in
                                ZStack {
                                    ImageContainer(
                                        content: item,
                                        retryLimit: setting.contentRetryLimit,
                                        onSuccessAction: onWebImageSuccess
                                    )
                                    .frame(
                                        width: absoluteScreenW,
                                        height: calImageHeight(item.tag)
                                    )
                                    .onAppear {
                                        onWebImageAppear(item)
                                    }
                                }
                                if setting.contentDividerHeight > 0 {
                                    Rectangle()
                                        .fill(Color(.darkGray))
                                        .frame(height: setting.contentDividerHeight)
                                        .edgesIgnoringSafeArea(.horizontal)
                                }
                            }
                            HStack(alignment: .center) {
                                Spacer()
                                ProgressView()
                                    .opacity(moreLoadingFlag ? 1 : 0)
                                NetworkErrorCompactView(
                                    retryAction: fetchMoreMangaContents
                                )
                                    .opacity(moreLoadFailedFlag ? 1 : 0)
                                Spacer()
                            }
                            .frame(height: 30)
                        }
                        .onAppear {
                            onLazyVStackAppear(scrollProxy)
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
            onDetailViewDisappear()
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("AppWidthDidChange")
            )
        ) { _ in
            onWidthChange()
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
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
    func onAppear() {
        restoreAspectBox()
        toggleNavBarHiddenIfNeeded()
        fetchMangaContentsIfNeeded()
    }
    func onDisappear() {
        saveAspectBox()
        saveReadingProgress()
    }
    func onResignActive() {
        saveAspectBox()
        saveReadingProgress()
    }
    func onDetailViewDisappear() {
        toggleNavBarHiddenIfNeeded()
    }
    func onWidthChange() {
        DispatchQueue.main.async {
            setOffset(.zero)
            setScale(1.1)
            setScale(1)
        }
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
    func onWebImageSuccess(_ tag: Int, _ aspect: CGFloat) {
        aspectBox[tag] = aspect
    }

    // MARK: Dispatch
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

    // MARK: ReadingProgress
    func calImageHeight(_ tag: Int) -> CGFloat {
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
    func updateGeoProxyMinY(_ value: CGFloat) {
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
    func onDoubleTap(_ value: TapGesture.Value) {
        setOffset(.zero)
        setScale(scale == 1 ? setting?.doubleTapScaleFactor ?? 2 : 1)
    }
    func onDragGestureChanged(_ value: DragGesture.Value) {
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
        if value == 1 {
            baseScale = scale
        }
        fixOffset()
        setScale(value * baseScale)
    }
    func onMagnificationGestureEnded(_ value: MagnificationGesture.Value) {
        onMagnificationGestureChanged(value)
        if value * baseScale - 1 < 0.01 {
            setScale(1)
        }
        baseScale = scale
    }

    func setOffset(_ newOffset: CGSize) {
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
    func setScale(_ newScale: CGFloat) {
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
                    style: .progress,
                    pageNumber: content.tag,
                    percentage: percentage
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

    private func onWebImageProgress<I: BinaryInteger>(
        _ received: I, _ total: I
    ) {
        percentage = Float(received) / Float(total)
    }
    private func onWebImageSuccess(_ result: RetrieveImageResult) {
        let size = result.image.size
        let aspect = size.height / size.width
        onSuccessAction((content.tag, aspect))
    }
}
