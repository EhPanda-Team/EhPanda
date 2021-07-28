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
    @Environment(\.dismiss) var dismissAction

    @StateObject private var page: Page = .first()
    @State private var allowsDragging = true

    @State private var showsPanel = false
    @State private var sliderValue: Float = 1
    @State private var sheetState: ReadingViewSheetState?

    @State private var index: Int = 0
    @State private var position: CGRect = .zero
    @State private var aspectBox = [Int: CGFloat]()

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var newOffset: CGSize = .zero

    let gid: String

    init(gid: String) {
        self.gid = gid
    }

    // MARK: ReadingView
    @ViewBuilder var body: some View {
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

        ZStack {
            if contentInfo.contentsLoading[gid]?[0] == true {
                LoadingView()
            } else if contentInfo.contentsLoadFailed[gid]?[0] == true {
                NetworkErrorView(retryAction: fetchMangaContentsIfNeeded)
            } else {
                Pager(page: page, data: Array(1...pageCount) as [Int], id: \.self) { index in
                    ImageContainer(
                        url: mangaContents[index] ?? "", index: index,
                        retryLimit: setting.contentRetryLimit,
                        onSuccessAction: onWebImageSuccess
                    )
                    .onAppear {
                        onWebImageAppear(index: index)
                    }
                }
                .horizontal(
                    setting.readingDirection == .rightToLeft
                    ? .rightToLeft : .leftToRight
                )
                .allowsDragging(allowsDragging)
                .transition(opacityTransition)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(tap)
                .gesture(drag)
                .gesture(magnify)
                .ignoresSafeArea()
                ControlPanel(
                    showsPanel: $showsPanel,
                    sliderValue: $sliderValue,
                    title: mangaDetail?.jpnTitle ?? manga.title,
                    range: 1...Float(pageCount),
                    readingDirection: setting.readingDirection,
                    backAction: dismissAction.callAsFunction,
                    settingAction: toggleSetting,
                    sliderChangedAction: onControlPanelSliderChanged
                )
            }
        }
        .onChange(of: page.index) { newValue in
            withAnimation {
                sliderValue = Float(newValue + 1)
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
            DispatchQueue.main.async {
                set(newOffset: .zero)
                set(newScale: 1.1)
                set(newScale: 1)
            }
        }
        .task(onStartTasks)
        .onAppear(perform: toggleNavBarHiddenIfNeeded)
        .onDisappear(perform: onEndTasks)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(environment.navBarHidden)
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
    }
}

// MARK: ControlPanel
private struct ControlPanel: View {
    @Binding private var showsPanel: Bool
    @Binding private var sliderValue: Float
    private let title: String
    private let range: ClosedRange<Float>
    private let readingDirection: ReadingDirection
    private let backAction: () -> Void
    private let settingAction: () -> Void
    private let sliderChangedAction: (Int) -> Void

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

    init(
        showsPanel: Binding<Bool>,
        sliderValue: Binding<Float>,
        title: String, range: ClosedRange<Float>,
        readingDirection: ReadingDirection,
        backAction: @escaping () -> Void,
        settingAction: @escaping () -> Void,
        sliderChangedAction: @escaping (Int) -> Void
    ) {
        _showsPanel = showsPanel
        _sliderValue = sliderValue
        self.title = title
        self.range = range
        self.readingDirection = readingDirection
        self.backAction = backAction
        self.settingAction = settingAction
        self.sliderChangedAction = sliderChangedAction
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: backAction) {
                    Image(systemName: "chevron.backward")
                }
                .imageScale(.large)
                .padding(.leading)
                Text(title)
                    .lineLimit(1)
                    .font(.callout)
                    .padding()
                Button(action: settingAction) {
                    Image(systemName: "gear")
                }
                .imageScale(.large)
                .padding(.trailing)
            }
            .frame(width: windowW)
            .background(.thinMaterial)
            .offset(y: showsPanel ? 0 : -50)
            Spacer()
            Text("")
            Spacer()
            HStack {
                Text(lowerBoundText)
                    .boundTextModifier()
                Slider(
                    value: $sliderValue,
                    in: range, step: 1,
                    onEditingChanged: { _ in
                        sliderChangedAction(
                            Int(sliderValue)
                        )
                    }
                )
                .rotationEffect(sliderAngle)
                Text(upperBoundText)
                    .boundTextModifier()
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
        self.bold().font(.caption).padding()
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
        restoreAspectBox()
        fetchMangaContentsIfNeeded()
    }
    func onEndTasks() {
        saveAspectBox()
        saveReadingProgress()
    }
    func onLazyVStackAppear(proxy: ScrollViewProxy) {
        let progress = mangaState.readingProgress
        if progress > 0 {
            proxy.scrollTo(progress)
        }
    }
    func onWebImageAppear(index: Int) {
        if mangaContents[index] == nil {
            fetchMangaContents(index: index)
        }
    }
    func onWebImageSuccess(tag: Int, aspect: CGFloat) {
        aspectBox[tag] = aspect
    }
    func onControlPanelSliderChanged(newValue: Int) {
        if page.index != newValue - 1 {
            page.update(.new(index: newValue - 1))
        }
    }

    // MARK: Dispatch
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

    // MARK: ReadingProgress
    func calImageHeight(index: Int) -> CGFloat {
        if let aspect = aspectBox[index] {
            return absWindowW * aspect
        } else {
            return windowH * contentHScale
        }
    }
    func calReadingProgress() -> Int {
        var heightArray = Array(
            repeating: windowH * contentHScale,
            count: pageCount + 1
        )
        heightArray[0] = 0
        aspectBox.forEach { (key: Int, value: CGFloat) in
            heightArray[key] = value * windowW
        }

        var remainingPosition = abs(position.minY) + windowH / 2
        for (index, value) in heightArray.enumerated() {
            remainingPosition -= value
            if remainingPosition < 0 {
                return index
            }
        }
        return -1
    }

    func saveReadingProgress() {
//        let progress = calReadingProgress()
        let progress = page.index + 1
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
        let box = mangaState.aspectBox
        if !box.isEmpty {
            aspectBox = box
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

    // MARK: Gesture
    func onSingleTap(_: TapGesture.Value) {
        withAnimation {
            showsPanel.toggle()
        }
    }
    func onDoubleTap(value: TapGesture.Value) {
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
        let marginW = windowW * (scale - 1) / 2

        withAnimation {
            if offset.width > marginW {
                offset.width = marginW
            } else if offset.width < -marginW {
                offset.width = -marginW
            }
        }
    }
    func set(newScale: CGFloat) {
        let max = setting.maximumScaleFactor
        guard scale != newScale && newScale >= 1 && newScale <= max
        else { return }

        withAnimation {
            scale = newScale
        }

        if newScale > 1 && allowsDragging {
            allowsDragging = false
        } else if !allowsDragging {
            allowsDragging = true
        }
    }
}

// MARK: ImageContainer
private struct ImageContainer: View {
    private let url: String
    private let index: Int
    private let retryLimit: Int
    private let onSuccessAction: ((Int, CGFloat)) -> Void

    init(
        url: String,
        index: Int,
        retryLimit: Int,
        onSuccessAction: @escaping ((Int, CGFloat)) -> Void
    ) {
        self.url = url
        self.index = index
        self.retryLimit = retryLimit
        self.onSuccessAction = onSuccessAction
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
                    .onSuccess(onWebImageSuccess)
            } else {
                KFAnimatedImage(URL(string: url))
                    .retry(
                        maxCount: retryLimit,
                        interval: .seconds(0.5)
                    )
                    .onSuccess(onWebImageSuccess)
                    .placeholder(getPlaceholder)
                    .fade(duration: 0.25)
            }
        }
        .scaledToFit()
    }

    private func onWebImageSuccess(result: RetrieveImageResult) {
        let size = result.image.size
        let aspect = size.height / size.width
        onSuccessAction((index, aspect))
    }
}

// MARK: AdvancedScrollView
private struct AdvancedScrollView<Content>: View where Content: View {
    @Binding private var index: Int
    @Binding private var frame: CGRect
    private let spacing: CGFloat
    private let content: Content

    init(
        index: Binding<Int>, frame: Binding<CGRect>,
        spacing: CGFloat, @ViewBuilder content: () -> Content
    ) {
        _index = index
        _frame = frame
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                MeasureTool(frame: $frame)
                LazyVStack(spacing: spacing) {
                    content
                }
            }
            .task {
                if index > 0 {
                    proxy.scrollTo(index)
                }
            }
        }
    }
}

//                AdvancedScrollView(
//                    index: $index, frame: $position,
//                    spacing: setting.contentDividerHeight
//                ) {
//                    ForEach(1..<pageCount + 1) { index in
//                        ImageContainer(
//                            url: mangaContents[index] ?? "", index: index,
//                            retryLimit: setting.contentRetryLimit,
//                            onSuccessAction: onWebImageSuccess
//                        )
//                        .frame(
//                            width: absWindowW,
//                            height: calImageHeight(index: index)
//                        )
//                        .onAppear {
//                            onWebImageAppear(index: index)
//                        }
//                        .id(index)
//                    }
//                }
//                ScrollViewReader { scrollProxy in
//                    ScrollView {
//                        MeasureTool(bindingFrame: $position)
//                        LazyVStack(spacing: setting.contentDividerHeight) {
//                            ForEach(1..<pageCount + 1) { index in
//                                ImageContainer(
//                                    url: mangaContents[index] ?? "", index: index,
//                                    retryLimit: setting.contentRetryLimit,
//                                    onSuccessAction: onWebImageSuccess
//                                )
//                                .frame(
//                                    width: absWindowW,
//                                    height: calImageHeight(index: index)
//                                )
//                                .onAppear {
//                                    onWebImageAppear(index: index)
//                                }
//                                .id(index)
//                            }
//                        }
//                        .task {
//                            onLazyVStackAppear(proxy: scrollProxy)
//                        }
//                    }
//                }

enum ReadingViewSheetState: Identifiable {
    var id: Int { hashValue }
    case setting
}
