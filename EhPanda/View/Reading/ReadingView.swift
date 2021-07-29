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
    @State private var allowsDragging = true

    @State private var showsPanel = false
    @State private var sliderValue: Float = 1
    @State private var sheetState: ReadingViewSheetState?

    @State private var index: Int = 0
    @State private var position: CGRect = .zero

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var newOffset: CGSize = .zero

    @State private var timer = Timer.publish(
        every: 3, on: .main, in: .common
    )

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
        if setting.readingDirection == .vertical && pageCount >= 1 {
            AdvancedList(
                page: page, data:
                    Array(1...pageCount) as [Int],
                id: \.self, spacing: setting
                    .contentDividerHeight,
                gesture: gestures,
                content: imageContainer
            )
            .disabled(!allowsDragging)
        } else if pageCount >= 1 {
            Pager(
                page: page, data:
                    Array(1...pageCount) as [Int],
                id: \.self, content: imageContainer
            )
            .horizontal(
                setting.readingDirection == .rightToLeft
                ? .rightToLeft : .leftToRight
            )
            .allowsDragging(allowsDragging)
        }
    }

    let gid: String

    init(gid: String) {
        self.gid = gid
    }

    // MARK: ReadingView
    @ViewBuilder var body: some View {
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
                    .gesture(gestures)
                    .ignoresSafeArea()
            }
            ControlPanel(
                showsPanel: $showsPanel,
                sliderValue: $sliderValue,
                title: mangaDetail?.jpnTitle ?? manga.title,
                range: 1...Float(pageCount),
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
        .onReceive(timer, perform: { _ in
            dismissPanel()
            invalidateTimer()
        })
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
    // MARK: Properties
    var pageCount: Int {
        mangaDetail?.pageCount ?? 0
    }
    var mangaContents: [Int: String] {
        mangaState.contents
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
    func onControlPanelSliderChanged(newValue: Int, isDragging: Bool) {
        page.update(.new(index: newValue - 1))

        if isDragging {
            invalidateTimer()
        } else {
            resetTimer()
        }
    }

    // MARK: Timer
    func connectTimer() {
        _ = timer.connect()
    }
    func resetTimer() {
        timer = Timer.publish(
            every: 3, on: .main, in: .common
        )
        connectTimer()
    }
    func invalidateTimer() {
        timer.connect().cancel()
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
        if progress > 1 {
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
    var gestures: some Gesture {
        let singleTap = TapGesture(count: 1)
            .onEnded(onSingleTap)
        let doubleTap = TapGesture(count: 2)
            .onEnded(onDoubleTap)
        let tap = ExclusiveGesture(
            doubleTap, singleTap
        )
        let drag = DragGesture(
            minimumDistance: 0.0,
            coordinateSpace: .local
        )
        .onChanged(onDragGestureChanged)
        .onEnded(onDragGestureEnded)
        let magnify = MagnificationGesture()
            .onChanged(onMagnificationGestureChanged)
            .onEnded(onMagnificationGestureEnded)
        return magnify.simultaneously(with: tap)
            .simultaneously(with: drag)
    }

    func onSingleTap(_: TapGesture.Value) {
        toggleShowsPanel()

        if showsPanel {
            resetTimer()
        }
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

        if newScale > 1 && allowsDragging {
            allowsDragging = false
        } else if newScale == 1 && !allowsDragging {
            allowsDragging = true
        }
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

// MARK: AdvancedList
private struct AdvancedList<Element, ID, PageView, G>: View
where PageView: View, Element: Equatable, ID: Hashable, G: Gesture {
    @State var performingChanges = false

    private let pagerModel: Page
    private var data: [Element]
    private let id: KeyPath<Element, ID>
    private let spacing: CGFloat
    private let gesture: G
    private let content: (Element) -> PageView

    init<Data: RandomAccessCollection>(
        page: Page, data: Data,
        id: KeyPath<Element, ID>, spacing: CGFloat,
        gesture: G,
        @ViewBuilder content:
            @escaping (Element) -> PageView
    )
    where Data.Index == Int,
    Data.Element == Element
    {
        self.pagerModel = page
        self.data = Array(data)
        self.id = id
        self.spacing = spacing
        self.gesture = gesture
        self.content = content
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: spacing) {
                    ForEach(data, id: id) { index in
                        let longPress = LongPressGesture(
                            minimumDuration: 0,
                            maximumDistance: .infinity
                        ).onEnded { _ in
                            if let index = index as? Int {
                                performingChanges = true
                                pagerModel.update(
                                    .new(index: index - 1)
                                )
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.2
                                ) { performingChanges = false }
                            }
                        }
                        let gestures = longPress
                            .simultaneously(with: gesture)
                        content(index).gesture(gestures)
                    }
                }
                .task {
                    performScrollTo(id: pagerModel.index + 1, proxy: proxy)
                }
            }
            .onChange(of: pagerModel.index) { newValue in
                performScrollTo(id: newValue + 1, proxy: proxy)
            }
        }
    }

    private func performScrollTo(id: Int, proxy: ScrollViewProxy) {
        guard !performingChanges else { return }
        dispatchMainSync {
            proxy.scrollTo(id, anchor: .center)
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

// MARK: ControlPanel
private struct ControlPanel: View {
    @Environment(\.dismiss) var dismissAction

    @State private var isSliderDragging = false
    @Binding private var showsPanel: Bool
    @Binding private var sliderValue: Float
    private let title: String
    private let range: ClosedRange<Float>
    private let readingDirection: ReadingDirection
    private let settingAction: () -> Void
    private let sliderChangedAction: (Int, Bool) -> Void

    private var shouldReverseDirection: Bool {
        readingDirection == .rightToLeft
    }
    private var lowerBoundText: String {
        shouldReverseDirection
        ? "\(Int(range.upperBound))"
        : "\(Int(range.lowerBound))"
    }
    private var upperBoundText: String {
        shouldReverseDirection
        ? "\(Int(range.lowerBound))"
        : "\(Int(range.upperBound))"
    }
    private var sliderAngle: Angle {
        Angle(degrees: shouldReverseDirection ? 180 : 0)
    }
    private var pageIndicatorWidth: CGFloat {
        CGFloat("\(Int(sliderValue))".count) * 15 + 60
    }

    init(
        showsPanel: Binding<Bool>,
        sliderValue: Binding<Float>,
        title: String, range: ClosedRange<Float>,
        readingDirection: ReadingDirection,
        settingAction: @escaping () -> Void,
        sliderChangedAction: @escaping (Int, Bool) -> Void
    ) {
        _showsPanel = showsPanel
        _sliderValue = sliderValue
        self.title = title
        self.range = range
        self.readingDirection = readingDirection
        self.settingAction = settingAction
        self.sliderChangedAction = sliderChangedAction
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: dismissAction.callAsFunction) {
                    Image(systemName: "chevron.backward")
                }
                .imageScale(.large)
                .padding(.leading)
                Spacer()
                ZStack {
                    Text(title).bold()
                        .lineLimit(1)
                        .padding()
                    Slider(value: $sliderValue)
                        .opacity(0)
                }
                Spacer()
                Button(action: settingAction) {
                    Image(systemName: "gear")
                }
                .imageScale(.large)
                .padding(.trailing)
            }
            .background(.thinMaterial)
            .offset(y: showsPanel ? 0 : -50)
            Spacer()
            Text("\(Int(sliderValue))").bold()
                .font(.title).lineLimit(1)
                .padding(.vertical, 20)
                .frame(maxWidth: windowW * 0.8)
                .frame(width: pageIndicatorWidth)
                .background(.ultraThinMaterial)
                .opacity(isSliderDragging ? 1 : 0)
                .cornerRadius(15)
            Spacer()
            VStack {
                HStack {
                    Text(lowerBoundText)
                        .boundTextModifier()
                    Slider(
                        value: $sliderValue,
                        in: range, step: 1,
                        onEditingChanged: { isDragging in
                            sliderChangedAction(
                                Int(sliderValue), isDragging
                            )
                            impactFeedback(style: .soft)
                            withAnimation {
                                isSliderDragging = isDragging
                            }
                        }
                    )
                    .rotationEffect(sliderAngle)
                    Text(upperBoundText)
                        .boundTextModifier()
                }
            }
            .background(.thinMaterial)
            .offset(y: showsPanel ? 0 : 50)
        }
        .opacity(showsPanel ? 1 : 0)
        .disabled(!showsPanel)
    }
}

private extension Text {
    func boundTextModifier() -> some View {
        self.fontWeight(.medium).font(.caption).padding()
    }
}

// MARK: Definition
enum ReadingViewSheetState: Identifiable {
    var id: Int { hashValue }
    case setting
}
