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
import SwiftyBeaver
import TTProgressHUD

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

    @State private var imageSaver: ImageSaver?
    @State private var isImageSaveSuccess: Bool?
    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    private var containerDataSource: [Int] {
        let defaultData = Array(1...pageCount)
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return defaultData }

        let data = setting.exceptCover
            ? [1] + Array(stride(from: 2, through: pageCount, by: 2))
            : Array(stride(from: 1, through: pageCount, by: 2))

        return data
    }

    private func getImageContainerConfigs(index: Int) -> (Int, Int, Bool, Bool) {
        let direction = setting.readingDirection
        let isReversed = direction == .rightToLeft
        let isFirstSingle = setting.exceptCover
        let isFirstPageAndSingle = index == 1 && isFirstSingle
        let isDualPage = isLandscape
        && setting.enablesDualPageMode
        && direction != .vertical

        let firstIndex = isDualPage && isReversed &&
            !isFirstPageAndSingle ? index + 1 : index
        let secondIndex = firstIndex + (isReversed ? -1 : 1)
        let isValidFirstRange =
            firstIndex >= 1 && firstIndex <= pageCount
        let isValidSecondRange = isFirstSingle
            ? secondIndex >= 2 && secondIndex <= pageCount
            : secondIndex >= 1 && secondIndex <= pageCount
        return (
            firstIndex, secondIndex,
            isValidFirstRange,
            !isFirstPageAndSingle &&
            isValidSecondRange && isDualPage
        )
    }
    private func imageContainer(index: Int) -> some View {
        HStack(spacing: 0) {
            let (firstIndex, secondIndex, isFirstValid, isSecondValid) =
                getImageContainerConfigs(index: index)
            let isDualPage = setting.enablesDualPageMode
            && setting.readingDirection != .vertical
            && isLandscape

            if isFirstValid {
                ImageContainer(
                    index: firstIndex,
                    imageURL: galleryContents[firstIndex] ?? "",
                    loadingFlag: galleryLoadingFlags[firstIndex] ?? false,
                    loadError: galleryLoadErrors[firstIndex],
                    isDualPage: isDualPage,
                    retryAction: fetchGalleryContents,
                    reloadAction: refetchGalleryContents
                )
                .onAppear { fetchGalleryContents(index: firstIndex) }
                .contextMenu { contextMenuItems(index: firstIndex) }
            }

            if isSecondValid {
                ImageContainer(
                    index: secondIndex,
                    imageURL: galleryContents[secondIndex] ?? "",
                    loadingFlag: galleryLoadingFlags[secondIndex] ?? false,
                    loadError: galleryLoadErrors[secondIndex],
                    isDualPage: isDualPage,
                    retryAction: fetchGalleryContents,
                    reloadAction: refetchGalleryContents
                )
                .onAppear { fetchGalleryContents(index: secondIndex) }
                .contextMenu { contextMenuItems(index: secondIndex) }
            }
        }
    }

    @ViewBuilder private func contextMenuItems(index: Int) -> some View {
        Button(action: { refetchGalleryContents(index: index) }, label: {
            Label("Reload", systemImage: "arrow.counterclockwise")
        })
        if let imageURL = galleryContents[index], !imageURL.isEmpty {
            Button(action: { copyImage(url: imageURL) }, label: {
                Label("Copy", systemImage: "plus.square.on.square")
            })
            Button(action: { saveImage(url: imageURL) }, label: {
                Label("Save", systemImage: "square.and.arrow.down")
            })
            Button(action: { shareImage(url: imageURL) }, label: {
                Label("Share", systemImage: "square.and.arrow.up")
            })
        }
    }

    @ViewBuilder private var conditionalList: some View {
        if setting.readingDirection == .vertical {
            AdvancedList(
                page: page, data: containerDataSource,
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
                page: page, data: containerDataSource,
                id: \.self, content: imageContainer
            )
            .horizontal(
                setting.readingDirection == .rightToLeft
                ? .rightToLeft : .leftToRight
            )
            .swipeInteractionArea(.allAvailable)
            .allowsDragging(scale == 1)
        }
    }

    private var readingSettingView: some View {
        NavigationView {
            ReadingSettingView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if !isPad && isLandscape {
                            Button(action: dismissSetting) {
                                Image(systemName: "chevron.down")
                            }
                        }
                    }
                }
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
                initialValue: galleryDetail?.pageCount ?? 1
            )
        }
    }

    // MARK: ReadingView
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            conditionalList
                .scaleEffect(scale).offset(offset)
                .transition(opacityTransition)
                .gesture(tapGesture)
                .gesture(dragGesture)
                .gesture(magnifyGesture)
                .ignoresSafeArea()
            ControlPanel(
                showsPanel: $showsPanel,
                sliderValue: $sliderValue,
                setting: $store.appState.settings.setting,
                currentIndex: mappingFromPager(index: page.index),
                range: 1...Float(pageCount),
                previews: detailInfo.previews[gid] ?? [:],
                settingAction: toggleSetting,
                fetchAction: fetchGalleryPreivews,
                sliderChangedAction: onControlPanelSliderChanged,
                updateSettingAction: update
            )
            TTProgressHUD($hudVisible, config: hudConfig)
        }
        .statusBar(hidden: !showsPanel)
        .onAppear(perform: onStartTasks)
        .onDisappear(perform: onEndTasks)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(environment.navBarHidden)
        .sheet(item: $sheetState) { item in
            Group {
                switch item {
                case .setting:
                    readingSettingView
                }
            }
            .accentColor(accentColor)
            .blur(radius: environment.blurRadius)
            .allowsHitTesting(environment.isAppUnlocked)
        }
        .onChange(of: page.index, perform: onPagerIndexChanged)
        .onChange(of: setting.exceptCover, perform: onControlPanelSliderChanged)
        .onChange(of: setting.readingDirection, perform: onControlPanelSliderChanged)
        .onChange(of: setting.enablesDualPageMode, perform: onControlPanelSliderChanged)
        .onChange(of: isImageSaveSuccess, perform: { newValue in
            if let isSuccess = newValue { performHUD(isSuccess: isSuccess) }
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
            onControlPanelSliderChanged()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("ReadingViewShouldHideStatusBar")
            )
        ) { _ in
            toggleNavBarHiddenIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )) { _ in
            setOrientation(allowsLandscape: true, shouldChangeOrientation: true)
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

private extension ReadingView {
    var galleryContents: [Int: String] {
        contentInfo.contents[gid] ?? [:]
    }
    var galleryLoadingFlags: [Int: Bool] {
        contentInfo.contentsLoading[gid] ?? [:]
    }
    var galleryLoadErrors: [Int: AppError] {
        contentInfo.contentsLoadErrors[gid] ?? [:]
    }

    // MARK: Life Cycle
    func onStartTasks() {
        setOrientation(
            allowsLandscape: true,
            shouldChangeOrientation: true
        )
        restoreReadingProgress()
        fetchGalleryContentsIfNeeded()
    }
    func onEndTasks() {
        saveReadingProgress()
        setOrientation(allowsLandscape: false)
    }
    func setOrientation(allowsLandscape: Bool, shouldChangeOrientation: Bool = false) {
        guard !isPad, setting.prefersLandscape else { return }
        if allowsLandscape {
            AppDelegate.orientationLock = .all
            if shouldChangeOrientation {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            }
        } else {
            AppDelegate.orientationLock = [.portrait, .portraitUpsideDown]
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
        UINavigationController.attemptRotationToDeviceOrientation()
    }
    func restoreReadingProgress() {
        dispatchMainSync {
            let index = mappingToPager(
                index: galleryState.readingProgress
            )
            page.update(.new(index: index))
        }
    }
    func onControlPanelSliderChanged(_: Any? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newIndex = mappingToPager(index: Int(sliderValue))
            if page.index != newIndex {
                page.update(.new(index: newIndex))
            }
        }
    }
    func onPagerIndexChanged(newIndex: Int) {
        prefetchImages(index: newIndex)
        let newValue = Float(mappingFromPager(index: newIndex))
        withAnimation {
            if sliderValue != newValue {
                sliderValue = newValue
            }
        }
    }

    // MARK: Progress
    func saveReadingProgress() {
        let progress = mappingFromPager(
            index: page.index
        )
        if progress > 0 {
            store.dispatch(
                .saveReadingProgress(
                    gid: gid,
                    tag: progress
                )
            )
        }
    }
    func mappingToPager(index: Int) -> Int {
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return index - 1 }
        if index <= 1 { return 0 }

        return setting.exceptCover
            ? index / 2 : (index - 1) / 2
    }
    func mappingFromPager(index: Int) -> Int {
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return index + 1 }
        if index <= 0 { return 1 }

        let result = setting.exceptCover
            ? index * 2 : index * 2 + 1

        if result + 1 == pageCount {
            return pageCount
        } else {
            return result
        }
    }

    // MARK: Dispatch
    func fetchGalleryContents(index: Int = 1) {
        guard galleryContents[index] == nil else { return }
        if contentInfo.mpvKeys[gid] != nil {
            store.dispatch(.fetchGalleryMPVContent(gid: gid, index: index))
        } else {
            store.dispatch(.fetchThumbnails(gid: gid, index: index))
        }
    }
    func refetchGalleryContents(index: Int) {
        if contentInfo.mpvKeys[gid] != nil {
            store.dispatch(.fetchGalleryMPVContent(gid: gid, index: index, isRefetch: true))
        } else {
            store.dispatch(.refetchGalleryNormalContent(gid: gid, index: index))
        }
    }
    func fetchGalleryPreivews(index: Int) {
        store.dispatch(.fetchGalleryPreviews(gid: gid, index: index))
    }

    func toggleSetting() {
        sheetState = .setting
        impactFeedback(style: .light)
    }
    func dismissSetting() {
        sheetState = nil
    }
    func update(setting: Setting) {
        store.dispatch(.updateSetting(setting: setting))
    }
    func fetchGalleryContentsIfNeeded() {
        if galleryContents.isEmpty {
            fetchGalleryContents()
        }
    }
    func toggleNavBarHiddenIfNeeded() {
        if !environment.navBarHidden {
            store.dispatch(.toggleNavBar(hidden: true))
        }
    }

    // MARK: Prefetch
    func prefetchImages(index: Int) {
        var prefetchIndices = [URL]()

        let prefetchLimit = setting.prefetchLimit / 2

        let previousUpperBound = max(index - 2, 1)
        let previousLowerBound = max(
            previousUpperBound - prefetchLimit, 1
        )
        if previousUpperBound - previousLowerBound > 0 {
            appendPrefetchIndices(
                array: &prefetchIndices,
                range: previousLowerBound...previousUpperBound
            )
        }

        let nextLowerBound = min(index + 2, pageCount)
        let nextUpperBound = min(
            nextLowerBound + prefetchLimit, pageCount
        )
        if nextUpperBound - nextLowerBound > 0 {
            appendPrefetchIndices(
                array: &prefetchIndices,
                range: nextLowerBound...nextUpperBound
            )
        }

        if !prefetchIndices.isEmpty {
            let prefetcher = ImagePrefetcher(urls: prefetchIndices)
            prefetcher.start()
        }
    }

    func appendPrefetchIndices(array: inout [URL], range: ClosedRange<Int>) {
        let indices = Array(range.lowerBound...range.upperBound)
        array.append(contentsOf: indices.compactMap { index in
            fetchGalleryContents(index: index)
            return URL(string: galleryContents[index] ?? "")
        })
    }

    // MARK: ContextMenu
    func retrieveImage(url: String, completion: @escaping (UIImage) -> Void) {
        KingfisherManager.shared.cache.retrieveImage(forKey: url) { result in
            switch result {
            case .success(let result):
                if let image = result.image {
                    completion(image)
                } else {
                    performHUD(isSuccess: false)
                }
            case .failure(let error):
                SwiftyBeaver.error(error)
                performHUD(isSuccess: false)
            }
        }
    }
    func copyImage(url: String) {
        retrieveImage(url: url) { image in
            UIPasteboard.general.image = image
            performHUD(isSuccess: true)
        }
    }
    func saveImage(url: String) {
        retrieveImage(url: url) { image in
            imageSaver = ImageSaver(isSuccess: $isImageSaveSuccess)
            imageSaver?.saveImage(image)
        }
    }
    func shareImage(url: String) {
        retrieveImage(url: url) { image in
            presentActivityVC(items: [image])
        }
    }
    func performHUD(isSuccess: Bool) {
        let type: TTProgressHUDType = isSuccess ? .success : .error
        let title = (isSuccess ? "Success" : "Error").localized

        switch type {
        case .success:
            notificFeedback(style: .success)
        case .error:
            notificFeedback(style: .error)
        default:
            break
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            hudConfig = TTProgressHUDConfig(
                type: type, title: title,
                shouldAutoHide: true,
                autoHideInterval: 2
            )
            hudVisible = true
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
        withAnimation {
            showsPanel.toggle()
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
    @Environment(\.colorScheme) private var colorScheme
    private var backgroundColor: Color {
        colorScheme == .light
        ? Color(.systemGray4)
        : Color(.systemGray6)
    }

    @State private var webImageLoadFailed = false

    private var reloadSymbolName: String =
    "exclamationmark.arrow.triangle.2.circlepath"
    private var width: CGFloat {
        windowW / (isDualPage ? 2 : 1)
    }
    private var height: CGFloat {
        width / Defaults.ImageSize.contentScale
    }
    private var loadFailedFlag: Bool {
        loadError != nil || webImageLoadFailed
    }

    private let index: Int
    private let imageURL: String
    private let isDualPage: Bool
    private let loadingFlag: Bool
    private let loadError: AppError?
    private let retryAction: (Int) -> Void
    private let reloadAction: (Int) -> Void

    init(
        index: Int,
        imageURL: String,
        loadingFlag: Bool,
        loadError: AppError?,
        isDualPage: Bool,
        retryAction: @escaping (Int) -> Void,
        reloadAction: @escaping (Int) -> Void
    ) {
        self.index = index
        self.imageURL = imageURL
        self.loadingFlag = loadingFlag
        self.loadError = loadError
        self.isDualPage = isDualPage
        self.retryAction = retryAction
        self.reloadAction = reloadAction
    }

    private func placeholder(_ progress: Progress) -> some View {
        Placeholder(
            style: .progress(
                pageNumber: index,
                progress: progress,
                isDualPage: isDualPage,
                backgroundColor: backgroundColor
            )
        )
        .frame(width: width, height: height)
    }
    private func retryView() -> some View {
        ZStack {
            backgroundColor
            VStack {
                Text(index.withoutComma)
                    .fontWeight(.bold)
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .padding(.bottom, 30)
                if loadFailedFlag {
                    Button(action: reloadImage) {
                        Image(systemName: reloadSymbolName)
                    }
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.gray)
                } else {
                    ProgressView()
                }
            }
        }
        .frame(width: width, height: height)
    }
    @ViewBuilder
    private func image(url: String) -> some View {
        if !imageURL.contains(".gif") {
            KFImage(URL(string: imageURL))
                .placeholder(placeholder)
                .defaultModifier(withRoundedCorners: false)
                .onSuccess(onSuccess).onFailure(onFailure)
        } else {
            KFAnimatedImage(URL(string: imageURL))
                .placeholder(placeholder)// .fade(duration: 0.25)
                .onSuccess(onSuccess).onFailure(onFailure)
        }
    }

    var body: some View {
        if loadingFlag || loadFailedFlag {
            retryView()
                .onChange(of: imageURL) { _ in
                    webImageLoadFailed = false
                }
        } else {
            image(url: imageURL).scaledToFit()
        }
    }
    private func reloadImage() {
        if webImageLoadFailed {
            reloadAction(index)
        } else if loadError != nil {
            retryAction(index)
        }
    }
    private func onSuccess(_: RetrieveImageResult) {
        webImageLoadFailed = false
    }
    private func onFailure(_: KingfisherError) {
        guard !imageURL.isEmpty else { return }
        webImageLoadFailed = true
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
