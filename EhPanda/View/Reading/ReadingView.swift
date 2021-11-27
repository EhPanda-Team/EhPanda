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

    @State private var autoPlayTimer: Timer?
    @State private var autoPlayPolicy: AutoPlayPolicy = .never

    @State private var scaleAnchor: UnitPoint = .center
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var newOffset: CGSize = .zero

    @State private var pageCount = 1

    @State private var imageSaver: ImageSaver?
    @State private var isImageSaveSuccess: Bool?
    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    let gid: String

    init(gid: String) {
        self.gid = gid
        initializeParams()
    }

    mutating func initializeParams() {
        AppUtil.dispatchMainSync {
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
                .scaleEffect(scale, anchor: scaleAnchor)
                .offset(offset).transition(AppUtil.opacityTransition)
                .gesture(tapGesture).gesture(dragGesture)
                .gesture(magnifyGesture).ignoresSafeArea()
            ControlPanel(
                showsPanel: $showsPanel,
                sliderValue: $sliderValue,
                setting: $store.appState.settings.setting,
                autoPlayPolicy: $autoPlayPolicy,
                currentIndex: mapFromPager(index: page.index),
                range: 1...Float(pageCount),
                previews: detailInfo.previews[gid] ?? [:],
                settingAction: presentSettingSheet,
                fetchAction: fetchGalleryPreivews,
                sliderChangedAction: tryUpdatePagerIndex,
                updateSettingAction: updateSetting
            )
            TTProgressHUD($hudVisible, config: hudConfig)
        }
        .statusBar(hidden: !showsPanel)
        .onAppear(perform: onStartTasks)
        .onDisappear(perform: onEndTasks)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(environment.navigationBarHidden)
        .sheet(item: $sheetState, content: sheet)
        .onChange(of: page.index, perform: updateSliderValue)
        .onChange(of: autoPlayPolicy, perform: reconfigureTimer)
        .onChange(of: setting.exceptCover, perform: tryUpdatePagerIndex)
        .onChange(of: setting.readingDirection, perform: tryUpdatePagerIndex)
        .onChange(of: setting.enablesDualPageMode, perform: tryUpdatePagerIndex)
        .onChange(of: isImageSaveSuccess, perform: { newValue in
            guard let isSuccess = newValue else { return }
            presentHUD(isSuccess: isSuccess, caption: "Saved to photo library")
        })
        .onReceive(AppNotification.appWidthDidChange.publisher) { _ in
            DispatchQueue.main.async {
                trySetOffset(.zero)
                trySetScale(1.1)
                trySetScale(1)
            }
            tryUpdatePagerIndex()
        }
        .onReceive(UIApplication.didBecomeActiveNotification.publisher) { _ in
            trySetOrientation(allowsLandscape: true, shouldChangeOrientation: true)
        }
        .onReceive(UIApplication.willTerminateNotification.publisher) { _ in onEndTasks() }
        .onReceive(UIApplication.willResignActiveNotification.publisher) { _ in onEndTasks() }
        .onReceive(AppNotification.readingViewShouldHideStatusBar.publisher, perform: trySetNavigationBarHidden)
    }
    // MARK: ImageContainer
    private var containerDataSource: [Int] {
        let defaultData = Array(1...pageCount)
        guard DeviceUtil.isLandscape && setting.enablesDualPageMode
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
        let isDualPage = DeviceUtil.isLandscape
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
            firstIndex, secondIndex, isValidFirstRange,
            !isFirstPageAndSingle && isValidSecondRange && isDualPage
        )
    }
    private func imageContainer(index: Int) -> some View {
        HStack(spacing: 0) {
            let (firstIndex, secondIndex, isFirstValid, isSecondValid) =
                getImageContainerConfigs(index: index)
            let isDualPage = setting.enablesDualPageMode
            && setting.readingDirection != .vertical
            && DeviceUtil.isLandscape

            if isFirstValid {
                ImageContainer(
                    index: firstIndex,
                    imageURL: galleryContents[firstIndex] ?? "",
                    loadingFlag: galleryLoadingFlags[firstIndex] ?? false,
                    loadError: galleryLoadErrors[firstIndex],
                    isDualPage: isDualPage,
                    retryAction: tryFetchGalleryContents,
                    reloadAction: refetchGalleryContents
                )
                .onAppear { tryFetchGalleryContents(index: firstIndex) }
                .contextMenu { contextMenuItems(index: firstIndex) }
            }

            if isSecondValid {
                ImageContainer(
                    index: secondIndex,
                    imageURL: galleryContents[secondIndex] ?? "",
                    loadingFlag: galleryLoadingFlags[secondIndex] ?? false,
                    loadError: galleryLoadErrors[secondIndex],
                    isDualPage: isDualPage,
                    retryAction: tryFetchGalleryContents,
                    reloadAction: refetchGalleryContents
                )
                .onAppear { tryFetchGalleryContents(index: secondIndex) }
                .contextMenu { contextMenuItems(index: secondIndex) }
            }
        }
    }
    // MARK: ContextMenu
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
    // MARK: ConditionalList
    @ViewBuilder private var conditionalList: some View {
        if setting.readingDirection == .vertical {
            AdvancedList(
                page: page, data: containerDataSource,
                id: \.self, spacing: setting.contentDividerHeight,
                gesture: SimultaneousGesture(magnifyGesture, tapGesture),
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
    // MARK: Sheet
    private func sheet(item: ReadingViewSheetState) -> some View {
        Group {
            switch item {
            case .setting:
                NavigationView {
                    ReadingSettingView().tint(accentColor)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                if !DeviceUtil.isPad && DeviceUtil.isLandscape {
                                    Button {
                                        sheetState = nil
                                    } label: {
                                        Image(systemName: "chevron.down")
                                    }
                                }
                            }
                        }
                }
            }
        }
        .accentColor(accentColor)
        .blur(radius: environment.blurRadius)
        .allowsHitTesting(environment.isAppUnlocked)
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
        trySetOrientation(allowsLandscape: true, shouldChangeOrientation: true)
        restoreReadingProgress()
        trySetNavigationBarHidden()
        fetchGalleryContentsIfNeeded()
    }
    func onEndTasks() {
        trySaveReadingProgress()
        autoPlayPolicy = .never
        trySetOrientation(allowsLandscape: false)
    }
    func trySetOrientation(allowsLandscape: Bool, shouldChangeOrientation: Bool = false) {
        guard !DeviceUtil.isPad, setting.prefersLandscape else { return }
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
        AppUtil.dispatchMainSync {
            let index = mapToPager(index: galleryState.readingProgress)
            page.update(.new(index: index))
        }
    }

    // MARK: Progress
    func tryUpdatePagerIndex(_: Any? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newIndex = mapToPager(index: Int(sliderValue))
            guard page.index != newIndex else { return }
            page.update(.new(index: newIndex))
        }
    }
    func updateSliderValue(newIndex: Int) {
        tryPrefetchImages(index: newIndex)
        let newValue = Float(mapFromPager(index: newIndex))
        withAnimation {
            if sliderValue != newValue {
                sliderValue = newValue
            }
        }
    }
    func reconfigureTimer(newPolicy: AutoPlayPolicy) {
        autoPlayTimer?.invalidate()
        guard newPolicy != .never else { return }
        autoPlayTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(newPolicy.rawValue),
            repeats: true, block: tryUpdatePagerIndexByTimer
        )
    }
    func tryUpdatePagerIndexByTimer(_: Timer) {
        guard Int(sliderValue) < pageCount else {
            autoPlayPolicy = .never
            return
        }
        page.update(.next)
    }
    func trySaveReadingProgress() {
        let progress = mapFromPager(index: page.index)
        guard progress > 0 else { return }
        store.dispatch(.setReadingProgress(gid: gid, tag: progress))
    }
    func mapToPager(index: Int) -> Int {
        guard DeviceUtil.isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return index - 1 }
        guard index > 1 else { return 0 }

        return setting.exceptCover ? index / 2 : (index - 1) / 2
    }
    func mapFromPager(index: Int) -> Int {
        guard DeviceUtil.isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return index + 1 }
        guard index > 0 else { return 1 }

        let result = setting.exceptCover ? index * 2 : index * 2 + 1

        if result + 1 == pageCount {
            return pageCount
        } else {
            return result
        }
    }

    // MARK: Dispatch
    func tryFetchGalleryContents(index: Int = 1) {
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

    func presentSettingSheet() {
        sheetState = .setting
        autoPlayPolicy = .never
        HapticUtil.generateFeedback(style: .light)
    }
    func updateSetting(_ setting: Setting) {
        store.dispatch(.setSetting(setting))
    }
    func fetchGalleryContentsIfNeeded() {
        guard galleryContents.isEmpty else { return }
        tryFetchGalleryContents()
    }
    func trySetNavigationBarHidden(_: Any? = nil) {
        guard !environment.navigationBarHidden else { return }
        store.dispatch(.setNavigationBarHidden(true))
    }

    // MARK: Prefetch
    func tryPrefetchImages(index: Int) {
        var prefetchIndices = [URL]()
        let prefetchLimit = setting.prefetchLimit / 2

        let previousUpperBound = max(index - 2, 1)
        let previousLowerBound = max(previousUpperBound - prefetchLimit, 1)
        if previousUpperBound - previousLowerBound > 0 {
            appendPrefetchIndices(
                array: &prefetchIndices,
                range: previousLowerBound...previousUpperBound
            )
        }

        let nextLowerBound = min(index + 2, pageCount)
        let nextUpperBound = min(nextLowerBound + prefetchLimit, pageCount)
        if nextUpperBound - nextLowerBound > 0 {
            appendPrefetchIndices(
                array: &prefetchIndices,
                range: nextLowerBound...nextUpperBound
            )
        }

        guard !prefetchIndices.isEmpty else { return }
        ImagePrefetcher(urls: prefetchIndices).start()
    }

    func appendPrefetchIndices(array: inout [URL], range: ClosedRange<Int>) {
        let indices = Array(range.lowerBound...range.upperBound)
        array.append(contentsOf: indices.compactMap { index in
            tryFetchGalleryContents(index: index)
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
                    presentHUD(isSuccess: false)
                }
            case .failure(let error):
                SwiftyBeaver.error(error)
                presentHUD(isSuccess: false)
            }
        }
    }
    func copyImage(url: String) {
        retrieveImage(url: url) { image in
            UIPasteboard.general.image = image
            presentHUD(isSuccess: true, caption: "Copied to clipboard")
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
            AppUtil.presentActivity(items: [image])
        }
    }
    func presentHUD(isSuccess: Bool, caption: String? = nil) {
        let type: TTProgressHUDType = isSuccess ? .success : .error
        let title = (isSuccess ? "Success" : "Error").localized

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            switch type {
            case .success:
                HapticUtil.generateNotificationFeedback(style: .success)
            case .error:
                HapticUtil.generateNotificationFeedback(style: .error)
            default:
                break
            }

            hudConfig = TTProgressHUDConfig(
                type: type, title: title, caption: caption?.localized,
                shouldAutoHide: true, autoHideInterval: 1
            )
            hudVisible = true
        }
        isImageSaveSuccess = nil
    }

    // MARK: Gesture
    var tapGesture: some Gesture {
        let singleTap = TapGesture(count: 1).onEnded { _ in
            let defaultAction = { withAnimation { showsPanel.toggle() } }
            guard setting.readingDirection != .vertical,
                  let pointX = TouchHandler.shared.currentPoint?.x
            else {
                defaultAction()
                return
            }
            let rightToLeft = setting.readingDirection == .rightToLeft
            if pointX < DeviceUtil.absWindowW * 0.2 {
                page.update(rightToLeft ? .next : .previous)
            } else if pointX > DeviceUtil.absWindowW * (1 - 0.2) {
                page.update(rightToLeft ? .previous : .next)
            } else {
                defaultAction()
            }
        }
        let doubleTap = TapGesture(count: 2).onEnded { _ in
            trySyncScaleAnchor()
            trySetOffset(.zero)
            trySetScale(scale == 1 ? setting.doubleTapScaleFactor : 1)
        }
        return ExclusiveGesture(doubleTap, singleTap)
    }
    var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged(onMagnificationGestureChanged)
            .onEnded(onMagnificationGestureEnded)
    }
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0, coordinateSpace: .local)
            .onChanged(onDragGestureChanged).onEnded(onDragGestureEnded)
    }

    func onDragGestureChanged(value: DragGesture.Value) {
        guard scale > 1 else { return }

        let newX = value.translation.width + newOffset.width
        let newY = value.translation.height + newOffset.height
        let newOffsetW = fixWidth(x: newX)
        let newOffsetH = fixHeight(y: newY)

        trySetOffset(CGSize(width: newOffsetW, height: newOffsetH))
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
        trySyncScaleAnchor()
        trySetScale(value * baseScale)
    }
    func onMagnificationGestureEnded(value: MagnificationGesture.Value) {
        onMagnificationGestureChanged(value: value)
        if value * baseScale - 1 < 0.01 {
            trySetScale(1)
        }
        baseScale = scale
    }

    func trySetOffset(_ newValue: CGSize) {
        let animation = Animation.linear(duration: 0.1)
        guard offset != newValue else { return }
        withAnimation(animation) {
            offset = newValue
        }
        fixOffset()

    }
    func trySetScale(_ newValue: CGFloat) {
        let max = setting.maximumScaleFactor
        guard scale != newValue && newValue >= 1 && newValue <= max else { return }

        withAnimation {
            scale = newValue
        }
        fixOffset()
    }
    func trySyncScaleAnchor() {
        guard let point = TouchHandler.shared.currentPoint else { return }

        let x = min(max(point.x / DeviceUtil.absWindowW, 0), 1)
        let y = min(max(point.y / DeviceUtil.absWindowH, 0), 1)
        scaleAnchor = UnitPoint(x: x, y: y)
    }
    func fixOffset() {
        withAnimation {
            offset.width = fixWidth(x: offset.width)
            offset.height = fixHeight(y: offset.height)
        }
    }
    func fixWidth(x: CGFloat) -> CGFloat {
        let marginW = DeviceUtil.absWindowW * (scale - 1) / 2
        let leadingMargin = scaleAnchor.x / 0.5 * marginW
        let trailingMargin = (1 - scaleAnchor.x) / 0.5 * marginW
        return min(max(x, -trailingMargin), leadingMargin)
    }
    func fixHeight(y: CGFloat) -> CGFloat {
        let marginH = DeviceUtil.absWindowH * (scale - 1) / 2
        let topMargin = scaleAnchor.y / 0.5 * marginH
        let bottomMargin = (1 - scaleAnchor.y) / 0.5 * marginH
        return min(max(y, -bottomMargin), topMargin)
    }
}

// MARK: ImageContainer
private struct ImageContainer: View {
    @Environment(\.colorScheme) private var colorScheme
    private var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGray4) : Color(.systemGray6)
    }

    @State private var webImageLoadFailed = false

    private var reloadSymbolName: String =
    "exclamationmark.arrow.triangle.2.circlepath"
    private var width: CGFloat {
        DeviceUtil.windowW / (isDualPage ? 2 : 1)
    }
    private var height: CGFloat {
        width / Defaults.ImageSize.contentAspect
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
        index: Int, imageURL: String, loadingFlag: Bool,
        loadError: AppError?, isDualPage: Bool,
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
        Placeholder(style: .progress(
            pageNumber: index, progress: progress,
            isDualPage: isDualPage, backgroundColor: backgroundColor
        ))
        .frame(width: width, height: height)
    }
    private func retryView() -> some View {
        ZStack {
            backgroundColor
            VStack {
                Text(String(index))
                    .fontWeight(.bold).font(.largeTitle)
                    .foregroundColor(.gray).padding(.bottom, 30)
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
    @ViewBuilder private func image(url: String) -> some View {
        if !imageURL.contains(".gif") {
            KFImage(URL(string: imageURL))
                .placeholder(placeholder)
                .defaultModifier(withRoundedCorners: false)
                .onSuccess(onSuccess).onFailure(onFailure)
        } else {
            KFAnimatedImage(URL(string: imageURL))
                .placeholder(placeholder).fade(duration: 0.25)
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

enum AutoPlayPolicy: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }

    case never = -1
    case sec1 = 1
    case sec2 = 2
    case sec3 = 3
    case sec4 = 4
    case sec5 = 5
}

extension AutoPlayPolicy {
    var descriptionKey: LocalizedStringKey {
        switch self {
        case .never:
            return "Never"
        default:
            return "\(rawValue) seconds"
        }
    }
}
