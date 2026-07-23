import AnimatedImageFeature
import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import Dependencies
import DeviceClient
import Observation
import OSLogExt
import ReadingSettingFeature
import SFSafeSymbols
import SFSafeSymbolsExt
import Sharing
import SwiftUI
import SystemNotification

private let logger = Logger(category: .init(describing: ReadingView.self))

public struct ReadingView: View {
    @Dependency(\.dataCache) private var dataCache
    @Dependency(\.deviceClient) private var deviceClient
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var store: StoreOf<ReadingReducer>
    // Write handle backing the reader's own controls (e.g. the ControlPanel slider). The reading-setting
    // sheet owns its own `@Shared(.setting)`; other reads go through `store.setting`. Same underlying
    // storage — the model clamps keep every write safe.
    @Shared(.setting) private var setting: Setting

    @State private var liveTextHandler = LiveTextHandler()
    @State private var autoPlayHandler = AutoPlayHandler()
    @State var gestureHandler = GestureHandler()
    @State private var pageHandler: PageHandler
    @State var pageModel: PageModel
    @State private var scrollPositionID: Int?
    @State private var performingChanges = false

    public init(store: StoreOf<ReadingReducer>) {
        @Dependency(\.deviceClient) var deviceClient
        self.store = store
        // Seed the pager and slider from the resume page the reducer computed in `State.init`, so the
        // reader opens on the saved page. Seeding replaced a `.restoreSession` action that mutated
        // `readingProgress` after the view had subscribed; with no post-subscribe change event, the
        // pager must be positioned at construction or every session would open at page 1.
        let resumePage = max(store.state.readingProgress, 1)
        let handler = PageHandler()
        handler.sliderValue = Float(resumePage)
        let pagerIndex = handler.mapToPager(
            index: resumePage,
            setting: store.state.setting,
            isLandscape: deviceClient.isLandscape()
        )
        _pageHandler = State(wrappedValue: handler)
        _pageModel = State(wrappedValue: .withIndex(pagerIndex))
        _scrollPositionID = State(initialValue: pagerIndex)
    }

    private var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGray4) : Color(.systemGray6)
    }

    private var displayPreviewURLs: [Int: URL] {
        store.localPageURLs.merging(store.previewURLs, uniquingKeysWith: { local, _ in local })
    }

    private var displayImageURLs: [Int: URL] {
        store.localPageURLs.merging(store.imageURLs, uniquingKeysWith: { local, _ in local })
    }

    private var displayOriginalImageURLs: [Int: URL] {
        if store.contentSource == .remote {
            return store.originalImageURLs
        }
        return store.localPageURLs.merging(store.originalImageURLs, uniquingKeysWith: { local, _ in local })
    }

    private var isLandscape: Bool {
        gestureHandler.containerSize.width > gestureHandler.containerSize.height
    }

    public var body: some View {
        changeTriggers(content: { content })
            .accessibilityIdentifier("reading_view")
            .sheet(
                item: $store.scope(\.$destination, action: \.destination).readingSetting
            ) { readingSettingStore in
                NavigationStack {
                    ReadingSettingView(store: readingSettingStore)
                    .toolbar {
                        if deviceClient.deviceType() != .pad && isLandscape {
                            CustomToolbarItem(placement: .cancellationAction) {
                                Button {
                                    store.send(.destination(.dismiss))
                                } label: {
                                    Label(.close, systemSymbol: .chevronDown)
                                }
                            }
                        }
                    }
                }
                .privacyMask()
            }
            .sheet(item: $store.destination.share, id: \.id) { shareItemBox in
                ActivityView(activityItems: [shareItemBox.wrappedValue.associatedValue])
                    .privacyMask()
            }
            .toast($store.scope(\.$toast, action: \.toast))

            .animation(.linear(duration: 0.1), value: gestureHandler.offset)
            .animation(.default, value: liveTextHandler.enablesLiveText)
            .animation(.default, value: liveTextHandler.liveTextGroups)
            .animation(.default, value: gestureHandler.scale)
            .animation(.default, value: store.showsPanel)
            .statusBarHidden(!store.showsPanel)
            // D-02 exception candidate: teardown of two view-owned `@State` handlers that hold live
            // work of their own — `liveTextHandler`'s in-flight Vision requests and `autoPlayHandler`'s
            // repeating timer. Neither is reducer state, so no reducer action can stand in for this,
            // and no value change marks the view's removal. Dropping it would leak an autoplay timer
            // that keeps turning pages of a reader nobody is looking at.
            // Progress is NOT flushed here: the reducer flushes on `.onPerformDismiss`, before the
            // presentation is torn down; a send from here would arrive after the destination is
            // nil'd and be dropped. So only non-persistence teardown happens here.
            // swiftlint:disable:next lifecycle_modifiers
            .onDisappear {
                liveTextHandler.cancelRequests()
                setAutoPlayPolocy(.off)
            }
    }

    @ViewBuilder
    var content: some View {
        @Bindable var bindableLiveTextHandler = liveTextHandler
        @Bindable var bindablePageHandler = pageHandler

        VStack {
            switch store.setting.readingDirection {
            case .vertical:
                AdvancedList(
                    page: pageModel,
                    data: store.state.containerDataSource(
                        setting: store.setting,
                        isLandscape: isLandscape
                    ),
                    id: \.self,
                    spacing: store.setting.contentDividerHeight,
                    gesture: SimultaneousGesture(magnificationGesture, tapGesture),
                    content: imageStack
                )
                .scrollDisabled(gestureHandler.scale != 1)

            case .leftToRight, .rightToLeft:
                horizontalPagingList
            }
        }
        .scaleEffect(gestureHandler.scale, anchor: gestureHandler.scaleAnchor)
        .offset(gestureHandler.offset)
        .highPriorityGesture(
            dragGesture.simultaneously(with: tapGesture),
            isEnabled: gestureHandler.scale > 1
        )
        .gesture(tapGesture, isEnabled: gestureHandler.scale == 1)
        .gesture(magnificationGesture)
        .ignoresSafeArea()
        .id(store.forceRefreshID)
        .background {
            backgroundColor
                .ignoresSafeArea()
        }
        .overlay {
            ControlPanel(
                showsPanel: $store.showsPanel,
                showsSliderPreview: $store.showsSliderPreview,
                sliderValue: $bindablePageHandler.sliderValue, setting: Binding($setting),
                enablesLiveText: $bindableLiveTextHandler.enablesLiveText,
                autoPlayPolicy: .init(get: { autoPlayHandler.policy }, set: { setAutoPlayPolocy($0) }),
                containerSize: gestureHandler.containerSize,
                range: 1...Float(store.gallery.pageCount),
                previewURLs: displayPreviewURLs,
                dismissGesture: controlPanelDismissGesture,
                dismissAction: { store.send(.onPerformDismiss) },
                navigateSettingAction: { store.send(.presentReadingSetting) },
                reloadAllImagesAction: { store.send(.reloadAllWebImages) },
                retryAllFailedImagesAction: { store.send(.retryAllFailedWebImages) },
                fetchPreviewURLsAction: { store.send(.fetchPreviewURLs($0)) }
            )
        }
        .onGeometryChange(for: CGSize.self, of: \.size) {
            gestureHandler.containerSize = $0
        }
    }

    // D-04/D-05: the non-vertical reader pages through a stock horizontal paging ScrollView.
    // The `.scrollPosition(id:)` ids are the 0-based POSITIONS in `containerDataSource` — the
    // same index space as `pageModel.index` and `PageHandler.mapToPager` (in dual-page mode the
    // element values are non-uniform reading pages, so positions, not elements, are the ids).
    private var horizontalPagingList: some View {
        let dataSource = store.state.containerDataSource(
            setting: store.setting,
            isLandscape: isLandscape
        )
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                // `enumerated()` rather than indexing by position: `\.offset` is the identical
                // 0-based position id the `indices` form produced, so the scroll ids are unchanged,
                // and the page is read as an element instead of through an unguarded subscript.
                ForEach(dataSource.enumerated(), id: \.offset) { _, page in
                    imageStack(index: page)
                        .containerRelativeFrame(.horizontal)
                        // Pages re-normalize to LTR: `imageContainerConfigs` already swaps the
                        // spread order for RTL, so the environment flip on the ScrollView may
                        // only reverse the paging axis, never the in-page order (no double-flip).
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPositionID)
        .scrollDisabled(gestureHandler.scale != 1)
        // RTL flips only the paging axis; the data source stays forward so every index keeps
        // its logical meaning (PageHandler stays direction-agnostic).
        .environment(
            \.layoutDirection,
            store.setting.readingDirection == .rightToLeft ? .rightToLeft : .leftToRight
        )
        .onScrollPhaseChange { _, newValue in
            if newValue == .idle, let position = scrollPositionID {
                performingChanges = true
                pageModel.update(.new(index: position))
                DispatchQueue.main.asyncAfter(deadline: .now() + PageModel.echoGuardDuration) {
                    performingChanges = false
                }
            }
        }
        // `initial: true` re-applies the seed at appearance, which is what the former `.onAppear`
        // did. It is belt-and-braces: `scrollPositionID` is already seeded in `init`, so the resume
        // page survives even if this initial fire lands late.
        .onChange(of: pageModel.index, initial: true) { _, newValue in
            tryScrollTo(id: newValue)
        }
    }

    @ViewBuilder
    private func changeTriggers<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        pageAndAutoPlayTriggers(content: content)
            // LiveText
            .onChange(of: liveTextHandler.enablesLiveText) { _, newValue in
                if newValue { store.webImageLoadSuccessIndices.forEach(analyzeImageForLiveText) }
            }
            .onChange(of: store.webImageLoadSuccessIndices) { _, newValue in
                if liveTextHandler.enablesLiveText {
                    newValue.forEach(analyzeImageForLiveText)
                }
            }
    }

    @ViewBuilder
    private func pageAndAutoPlayTriggers<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            // Page
            .onChange(
                of: store.state.containerDataSource(
                    setting: store.setting,
                    isLandscape: isLandscape
                )
            ) { _, _ in
                setPageIndex(sliderValue: pageHandler.sliderValue)
            }
            .onChange(of: pageModel.index) { _, newValue in
                let newValue = pageHandler.mapFromPager(
                    index: newValue,
                    pageCount: store.gallery.pageCount,
                    setting: store.setting,
                    isLandscape: isLandscape
                )
                pageHandler.sliderValue = .init(newValue)
                store.send(.syncReadingProgress(.init(newValue)))
            }
            .onChange(of: pageHandler.sliderValue) { _, newValue in
                if !store.showsSliderPreview {
                    setPageIndex(sliderValue: newValue)
                }
            }
            .onChange(of: store.showsSliderPreview) { _, newValue in
                if !newValue { setPageIndex(sliderValue: pageHandler.sliderValue) }
                setAutoPlayPolocy(.off)
            }
            // AutoPlay
            .onChange(of: store.destination != nil) { _, isPresented in
                if isPresented {
                    setAutoPlayPolocy(.off)
                }
            }
    }

    @ViewBuilder private func imageStack(index: Int) -> some View {
        let setting = store.setting
        let imageStackConfig = store.state.imageContainerConfigs(
            index: index,
            setting: setting,
            isLandscape: isLandscape
        )
        let isDualPage = setting.enableDualPageMode
            && setting.readingDirection != .vertical && isLandscape
        let dataSource = store.state.containerDataSource(setting: setting, isLandscape: isLandscape)
        let activeStackIndex = dataSource.indices.contains(pageModel.index) ? dataSource[pageModel.index] : nil
        HorizontalImageStack(
            index: index,
            isDualPage: isDualPage,
            isActive: index == activeStackIndex,
            backgroundColor: backgroundColor,
            config: imageStackConfig,
            imageURLs: displayImageURLs,
            originalImageURLs: displayOriginalImageURLs,
            loadingStates: store.imageURLLoadingStates,
            enablesLiveText: liveTextHandler.enablesLiveText,
            liveTextGroups: liveTextHandler.liveTextGroups,
            focusedLiveTextGroup: liveTextHandler.focusedLiveTextGroup,
            liveTextTapAction: liveTextHandler.setFocusedLiveTextGroup,
            fetchAction: { store.send(.fetchImageURLs($0)) },
            refetchAction: { store.send(.refetchImageURLs($0)) },
            prefetchAction: { store.send(.prefetchImages(fromIndex: $0, prefetchLimit: store.setting.prefetchLimit)) },
            loadRetryAction: { store.send(.onWebImageRetry($0)) },
            loadSucceededAction: { store.send(.onWebImageSucceeded($0)) },
            loadFailedAction: { store.send(.onWebImageFailed($0)) },
            copyImageAction: { store.send(.copyImage($0)) },
            saveImageAction: { store.send(.saveImage($0)) },
            shareImageAction: { store.send(.shareImage($0)) }
        )
    }
}

// MARK: Handler methods
extension ReadingView {
    // The single programmatic write path (D-07): autoplay, the slider seek, and tap-to-turn all
    // land here, so every write is clamped to the data source's bounds and guarded against the
    // scroll-read feedback loop before it reaches the shared index. Clamping also covers vertical
    // autoplay, which was effectively unclamped under SwiftUIPager (`totalPages` was only set by
    // a rendered `Pager`) — a deliberate small improvement, not drift.
    func jump(toPagerIndex target: Int) {
        let dataSource = store.state.containerDataSource(
            setting: store.setting,
            isLandscape: isLandscape
        )
        guard !dataSource.isEmpty else { return }
        let clampedIndex = min(max(target, 0), dataSource.count - 1)
        guard pageModel.index != clampedIndex else { return }
        performingChanges = true
        pageModel.update(.new(index: clampedIndex))
        withAnimation {
            scrollPositionID = clampedIndex
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + PageModel.echoGuardDuration) {
            performingChanges = false
        }
    }
    func setPageIndex(sliderValue: Float) {
        let newValue = pageHandler.mapToPager(
            index: .init(sliderValue),
            setting: store.setting,
            isLandscape: isLandscape
        )
        jump(toPagerIndex: newValue)
    }
    func setAutoPlayPolocy(_ policy: AutoPlayPolicy) {
        autoPlayHandler.setPolicy(policy, updatePageAction: {
            let dataSource = store.state.containerDataSource(
                setting: store.setting, isLandscape: isLandscape
            )
            let target = pageModel.index + 1
            jump(toPagerIndex: target)
            // The tick that reaches the final page stops autoplay, rather than ticking uselessly
            // against the clamp for the rest of the interval.
            if target >= dataSource.count - 1 {
                setAutoPlayPolocy(.off)
            }
        })
    }
    private func tryScrollTo(id: Int) {
        if !performingChanges {
            scrollPositionID = id
        }
    }
    func analyzeImageForLiveText(page: Int) {
        guard liveTextHandler.liveTextGroups[page] == nil else {
            return
        }
        guard let imageURL = displayImageURLs[page] else {
            logger.debug("analyzeImageForLiveText URL not found, page: \(page, privacy: .public)")
            return
        }
        if imageURL.isFileURL {
            analyzeLocalImage(at: imageURL, page: page)
            return
        }
        Task {
            await analyzeCachedImageData(
                cacheKeys: imageURL.imageCacheKeys,
                page: page
            )
        }
    }

    /// The downloaded page file's bytes, or nil when it cannot be read.
    ///
    /// Nil is the ordinary "nothing to scan" answer rather than a swallowed error: the caller's
    /// guard already reports an unusable local page through its own debug log, so surfacing the
    /// read error separately would duplicate that one message.
    private func localImageData(at imageURL: URL) -> Data? {
        do {
            return try Data(contentsOf: imageURL)
        } catch {
            return nil
        }
    }

    /// Runs Live Text over a downloaded page file. Animated images are skipped by design
    /// (Live Text scans still images only), so a single non-animating frame is never lifted
    /// out of an animation.
    private func analyzeLocalImage(at imageURL: URL, page: Int) {
        // Local-file loading is an optional Live Text probe; failure skips analysis without affecting reading.
        guard let data = localImageData(at: imageURL),
              !data.isAnimatedImageData,
              let image = data.decodedImage,
              let cgImage = image.cgImage
        else {
            logger.debug("analyzeImageForLiveText local image not found, page: \(page, privacy: .public)")
            return
        }

        liveTextHandler.analyzeImage(
            cgImage, size: image.size, page: page, recognitionLanguages:
                store.language?.codes
        )
    }

    /// Runs Live Text over a remote page's cached bytes, read from the owned `DataCache`
    /// (the reader's cache, not Kingfisher's). Animated images are skipped by design
    /// (Live Text scans still images only).
    private func analyzeCachedImageData(cacheKeys: [String], page: Int) async {
        guard let data = await dataCache.data(forKeys: cacheKeys),
              !data.isAnimatedImageData,
              let image = data.decodedImage,
              let cgImage = image.cgImage
        else {
            logger.debug("analyzeImageForLiveText image not found, page: \(page, privacy: .public)")
            return
        }

        liveTextHandler.analyzeImage(
            cgImage, size: image.size, page: page, recognitionLanguages:
                store.language?.codes
        )
    }
}

#Preview("Loaded") {
    NavigationStack {
        Color.clear
            .fullScreenCover(isPresented: .constant(true)) {
                ReadingView(
                    store: .init(initialState: .init(gallery: .preview), reducer: ReadingReducer.init)
                )
            }
    }
}
