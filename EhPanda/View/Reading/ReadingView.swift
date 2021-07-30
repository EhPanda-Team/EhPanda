//
//  ReadingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/13.
//

import SwiftUI
import Combine
import Kingfisher
import SwiftUIPager

struct ReadingView: View, StoreAccessor, PersistenceAccessor {
    @EnvironmentObject var store: Store

    @Environment(\.colorScheme) private var colorScheme
    private var backgroundColor: Color {
        colorScheme == .light
        ? Color(.systemGray4)
        : Color(.systemGray6)
    }

    @StateObject private var page: Page = .first()

    @State private var showsPanel = false
    @State private var sliderValue: Float = 1
    @State private var sheetState: ReadingViewSheetState?

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var newOffset: CGSize = .zero

    @State private var pageCount = 1
    @State private var controllPanelTitle = ""

    private func imageContainer(index: Int) -> some View {
        ImageContainer(
            url: mangaContents[index] ?? "", index: index,
            retryLimit: setting.contentRetryLimit
        )
        .onAppear {
            onWebImageAppear(index: index)
        }
    }

    @ViewBuilder private var conditionalList: some View {
        if setting.readingDirection == .vertical {
            AdvancedList(
                page: page, data: Array(1...pageCount),
                id: \.self, spacing: setting
                    .contentDividerHeight,
                gesture: SimultaneousGesture(
                    magnifyGesture, tapGesture
                ),
                content: imageContainer
            )
            .disabled(scale != 1)
        } else {
            Pager(
                page: page, data: Array(1...pageCount),
                id: \.self, content: imageContainer
            )
            .horizontal(
                setting.readingDirection == .rightToLeft
                ? .rightToLeft : .leftToRight
            )
            .allowsDragging(scale == 1)
        }
    }

    let gid: String

    init(gid: String) {
        self.gid = gid
        initializeParams()
    }

    mutating func initializeParams() {
        dispatchMainSync {
            _pageCount = State(
                initialValue: mangaDetail?.pageCount ?? 1
            )
            _controllPanelTitle = State(
                initialValue: mangaDetail?.jpnTitle ?? manga.title
            )
        }
    }

    // MARK: ReadingView
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            if contentInfo.contentsLoading[gid]?[0] == true {
                LoadingView()
            } else if contentInfo.contentsLoadFailed[gid]?[0] == true {
                NetworkErrorView(retryAction: fetchMangaContentsIfNeeded)
            } else {
                conditionalList
                    .scaleEffect(scale).offset(offset)
                    .transition(opacityTransition)
                    .gesture(tapGesture)
                    .gesture(dragGesture)
                    .gesture(magnifyGesture)
                    .ignoresSafeArea()
            }
            ControlPanel(
                showsPanel: $showsPanel,
                sliderValue: $sliderValue,
                title: controllPanelTitle,
                range: 1...Float(pageCount),
                previews: detailInfo.previews[gid] ?? [:],
                readingDirection: setting.readingDirection,
                settingAction: toggleSetting,
                sliderChangedAction: onControlPanelSliderChanged
            )
        }
        .task(onStartTasks)
        .statusBar(hidden: !showsPanel)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(environment.navBarHidden)
        .onAppear(perform: toggleNavBarHiddenIfNeeded)
        .onDisappear(perform: onEndTasks)
        .sheet(item: $sheetState) { item in
            Group {
                switch item {
                case .setting:
                    NavigationView {
                        ReadingSettingView()
                    }
                }
            }
            .accentColor(accentColor)
            .blur(radius: environment.blurRadius)
            .allowsHitTesting(environment.isAppUnlocked)
        }
        .onChange(of: page.index) { newValue in
            withAnimation {
                sliderValue = Float(newValue + 1)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("AppWidthDidChange")
            )
        ) { _ in
            DispatchQueue.main.async {
                set(newOffset: .zero)
                set(newScale: 1.1)
                set(newScale: 1)
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
    }
}

// MARK: Private Extension
private extension ReadingView {
    var mangaContents: [Int: String] {
        contentInfo.contents[gid] ?? [:]
    }
    var contentHScale: CGFloat {
        Defaults.ImageSize.contentHScale
    }

    // MARK: Life Cycle
    func onStartTasks() {
        restoreReadingProgress()
        fetchMangaContentsIfNeeded()
    }
    func onEndTasks() {
        saveReadingProgress()
    }
    func restoreReadingProgress() {
        dispatchMainSync {
            page.update(.new(
                index: mangaState
                    .readingProgress - 1
            ))
        }
    }
    func onWebImageAppear(index: Int) {
        if mangaContents[index] == nil {
            fetchMangaContents(index: index)
        }
    }
    func onControlPanelSliderChanged(newValue: Int) {
        page.update(.new(index: newValue - 1))
    }

    // MARK: Misc
    func dismissPanel() {
        if showsPanel {
            toggleShowsPanel()
        }
    }
    func toggleShowsPanel() {
        withAnimation {
            showsPanel.toggle()
        }
    }
    func saveReadingProgress() {
        let progress = page.index + 1
        if progress > 0 {
            store.dispatch(
                .saveReadingProgress(
                    gid: gid,
                    tag: progress
                )
            )
        }
    }

    func fetchMangaContents(index: Int = 1) {
        DispatchQueue.main.async {
            store.dispatch(.fetchMangaContents(gid: gid, index: index))
        }
    }

    func toggleSetting() {
        sheetState = .setting
        impactFeedback(style: .light)
    }
    func fetchMangaContentsIfNeeded() {
        if mangaContents.isEmpty {
            fetchMangaContents()
        }
    }
    func toggleNavBarHiddenIfNeeded() {
        if !environment.navBarHidden {
            store.dispatch(.toggleNavBar(hidden: true))
        }
    }

    // MARK: Gesture
    var tapGesture: some Gesture {
        let singleTap = TapGesture(count: 1)
            .onEnded(onSingleTap)
        let doubleTap = TapGesture(count: 2)
            .onEnded(onDoubleTap)
        return ExclusiveGesture(
            doubleTap, singleTap
        )
    }
    var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged(onMagnificationGestureChanged)
            .onEnded(onMagnificationGestureEnded)
    }
    var dragGesture: some Gesture {
        DragGesture(
            minimumDistance: 0.0,
            coordinateSpace: .local
        )
        .onChanged(onDragGestureChanged)
        .onEnded(onDragGestureEnded)
    }

    func onSingleTap(_: TapGesture.Value) {
        toggleShowsPanel()
    }
    func onDoubleTap(_: TapGesture.Value) {
        set(newOffset: .zero)
        set(newScale: scale == 1 ? setting.doubleTapScaleFactor : 1)
    }

    func onDragGestureChanged(value: DragGesture.Value) {
        if scale > 1 {
            let newX = value.translation.width + newOffset.width
            let marginW = windowW * (scale - 1) / 2
            let newOffsetW = min(max(newX, -marginW), marginW)

            let newY = value.translation.height + newOffset.height
            let marginH = windowH * (scale - 1) / 2
            let newOffsetH = min(max(newY, -marginH), marginH)

            set(newOffset: CGSize(width: newOffsetW, height: newOffsetH))
        }
    }
    func onDragGestureEnded(value: DragGesture.Value) {
        onDragGestureChanged(value: value)

        if scale > 1 {
            newOffset.width = offset.width
            newOffset.height = offset.height
        }
    }
    func onMagnificationGestureChanged(value: MagnificationGesture.Value) {
        if value == 1 {
            baseScale = scale
        }
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
            fixOffset()
        }
    }
    func set(newScale: CGFloat) {
        let max = setting.maximumScaleFactor
        guard scale != newScale && newScale >= 1 && newScale <= max
        else { return }

        withAnimation {
            scale = newScale
        }
        fixOffset()
    }
    func fixOffset() {
        let marginW = windowW * (scale - 1) / 2
        let marginH = windowH * (scale - 1) / 2
        let currentW = offset.width
        let currentH = offset.height

        withAnimation {
            offset.width = min(max(currentW, -marginW), marginW)
            offset.height = min(max(currentH, -marginH), marginH)
        }
    }
}

// MARK: ImageContainer
private struct ImageContainer: View {
    private let url: String
    private let index: Int
    private let retryLimit: Int

    init(
        url: String,
        index: Int,
        retryLimit: Int
    ) {
        self.url = url
        self.index = index
        self.retryLimit = retryLimit
    }

    private func getPlaceholder(_ progress: Progress) -> some View {
        Placeholder(
            style: .progress(
                pageNumber: index,
                progress: progress
            )
        )
        .frame(
            width: absWindowW,
            height: windowH * Defaults
                .ImageSize.contentHScale
        )
    }

    var body: some View {
        Group {
            if !url.contains(".gif") {
                KFImage(URL(string: url))
                    .defaultModifier(
                        withRoundedCorners: false
                    )
                    .retry(
                        maxCount: retryLimit,
                        interval: .seconds(0.5)
                    )
                    .placeholder(getPlaceholder)
            } else {
                KFAnimatedImage(URL(string: url))
                    .retry(
                        maxCount: retryLimit,
                        interval: .seconds(0.5)
                    )
                    .placeholder(getPlaceholder)
                    .fade(duration: 0.25)
            }
        }
        .scaledToFit()
    }
}

// MARK: Definition
enum ReadingViewSheetState: Identifiable {
    var id: Int { hashValue }
    case setting
}

struct ReadingView_Previews: PreviewProvider {
    static var previews: some View {
        PersistenceController.prepareForPreviews()
        return ReadingView(gid: "").environmentObject(Store.preview)
    }
}
