import SwiftUI
import AppModels
import OSLogExt
import Observation
import SFSafeSymbols
import SwiftUIPager
import ComposableArchitecture
import AppTools
import AnimatedImageFeature
import SystemNotificationExt
import AppComponents
import ReadingSettingFeature

private let logger = Logger(category: .init(describing: ReadingView.self))

public struct ReadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var store: StoreOf<ReadingReducer>
    let gid: String
    @Binding var setting: Setting
    let blurRadius: Double

    @State private var liveTextHandler = LiveTextHandler()
    @State private var autoPlayHandler = AutoPlayHandler()
    @State var gestureHandler = GestureHandler()
    @State private var pageHandler = PageHandler()
    @StateObject var page: Page = .first()

    public init(
        store: StoreOf<ReadingReducer>,
        gid: String, setting: Binding<Setting>, blurRadius: Double
    ) {
        self.store = store
        self.gid = gid
        _setting = setting
        self.blurRadius = blurRadius
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

    public var body: some View {
        @Bindable var bindableLiveTextHandler = liveTextHandler
        @Bindable var bindablePageHandler = pageHandler

        return changeTriggers(content: { content })
            .sheet(item: $store.destination.readingSetting, id: \.id) { _ in
                NavigationStack {
                    ReadingSettingView(
                        readingDirection: $setting.readingDirection,
                        prefetchLimit: $setting.prefetchLimit,
                        enablesLandscape: $setting.enablesLandscape,
                        contentDividerHeight: $setting.contentDividerHeight,
                        maximumScaleFactor: $setting.maximumScaleFactor,
                        doubleTapScaleFactor: $setting.doubleTapScaleFactor
                    )
                    .toolbar {
                        if !DeviceUtil.isPad && DeviceUtil.isLandscape {
                            CustomToolbarItem(placement: .cancellationAction) {
                                Button {
                                    store.send(.destination(.dismiss))
                                } label: {
                                    Image(systemSymbol: .chevronDown)
                                }
                            }
                        }
                    }
                }
                .accentColor(setting.accentColor)
                .tint(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.destination.share, id: \.id) { shareItemBox in
                ActivityView(activityItems: [shareItemBox.wrappedValue.associatedValue])
                    .accentColor(setting.accentColor)
                    .autoBlur(radius: blurRadius)
            }
            .toast($store.scope(state: \.toast, action: \.toast))

            .animation(.linear(duration: 0.1), value: gestureHandler.offset)
            .animation(.default, value: liveTextHandler.enablesLiveText)
            .animation(.default, value: liveTextHandler.liveTextGroups)
            .animation(.default, value: gestureHandler.scale)
            .animation(.default, value: store.showsPanel)
            .statusBar(hidden: !store.showsPanel)
            .onDisappear {
                // Progress is flushed in the reducer on `.onPerformDismiss` (before the presentation is
                // torn down); an `onDisappear` send would arrive after the destination is nil'd and be
                // dropped. So only non-persistence teardown happens here.
                liveTextHandler.cancelRequests()
                setAutoPlayPolocy(.off)
            }
            .onAppear { store.send(.onAppear(gid, setting.enablesLandscape)) }
    }

    var content: some View {
        @Bindable var bindableLiveTextHandler = liveTextHandler
        @Bindable var bindablePageHandler = pageHandler

        return ZStack {
            backgroundColor.ignoresSafeArea()

            ZStack {
                if setting.readingDirection == .vertical {
                    AdvancedList(
                        page: page,
                        data: store.state.containerDataSource(
                            setting: setting,
                            isLandscape: DeviceUtil.isLandscape
                        ),
                        id: \.self,
                        spacing: setting.contentDividerHeight,
                        gesture: SimultaneousGesture(magnificationGesture, tapGesture),
                        content: imageStack
                    )
                    .scrollDisabled(gestureHandler.scale != 1)
                } else {
                    Pager(
                        page: page,
                        data: store.state.containerDataSource(
                            setting: setting,
                            isLandscape: DeviceUtil.isLandscape
                        ),
                        id: \.self,
                        content: imageStack
                    )
                    .horizontal(setting.readingDirection == .rightToLeft ? .endToStart : .startToEnd)
                    .swipeInteractionArea(.allAvailable)
                    .allowsDragging(gestureHandler.scale == 1)
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

            ControlPanel(
                showsPanel: $store.showsPanel,
                showsSliderPreview: $store.showsSliderPreview,
                sliderValue: $bindablePageHandler.sliderValue, setting: $setting,
                enablesLiveText: $bindableLiveTextHandler.enablesLiveText,
                autoPlayPolicy: .init(get: { autoPlayHandler.policy }, set: { setAutoPlayPolocy($0) }),
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
            // Orientation
            .onChange(of: setting.enablesLandscape) { _, newValue in
                store.send(.setOrientationPortrait(!newValue))
            }
    }

    @ViewBuilder
    private func pageAndAutoPlayTriggers<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            // Page
            .onChange(of: page.index) { _, newValue in
                let newValue = pageHandler.mapFromPager(
                    index: newValue, pageCount: store.gallery.pageCount, setting: setting
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
            .onChange(of: store.readingProgress) { _, newValue in
                pageHandler.sliderValue = .init(newValue)
            }
            // AutoPlay
            .onChange(of: store.destination != nil) { _, isPresented in
                if isPresented {
                    setAutoPlayPolocy(.off)
                }
            }
    }

    @ViewBuilder private func imageStack(index: Int) -> some View {
        let imageStackConfig = store.state.imageContainerConfigs(
            index: index,
            setting: setting,
            isLandscape: DeviceUtil.isLandscape
        )
        let isDualPage = setting.enablesDualPageMode && setting.readingDirection != .vertical && DeviceUtil.isLandscape
        let dataSource = store.state.containerDataSource(setting: setting, isLandscape: DeviceUtil.isLandscape)
        let activeStackIndex = dataSource.indices.contains(page.index) ? dataSource[page.index] : nil
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
            prefetchAction: { store.send(.prefetchImages($0, setting.prefetchLimit)) },
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
    func setPageIndex(sliderValue: Float) {
        let newValue = pageHandler.mapToPager(
            index: .init(sliderValue), setting: setting
        )
        if page.index != newValue {
            page.update(.new(index: newValue))
        }
    }
    func setAutoPlayPolocy(_ policy: AutoPlayPolicy) {
        autoPlayHandler.setPolicy(policy, updatePageAction: {
            page.update(.next)
        })
    }
    func analyzeImageForLiveText(index: Int) {
        guard liveTextHandler.liveTextGroups[index] == nil else {
            return
        }
        guard let imageURL = displayImageURLs[index] else {
            logger.debug("analyzeImageForLiveText URL not found, index: \(index, privacy: .public)")
            return
        }
        if imageURL.isFileURL {
            analyzeLocalImage(at: imageURL, index: index)
            return
        }
        Task {
            await analyzeCachedImageData(
                cacheKeys: imageURL.imageCacheKeys,
                index: index
            )
        }
    }

    /// Runs Live Text over a downloaded page file. Animated images are skipped by design
    /// (Live Text scans still images only), so a single non-animating frame is never lifted
    /// out of an animation.
    private func analyzeLocalImage(at imageURL: URL, index: Int) {
        guard let data = try? Data(contentsOf: imageURL),
              !data.isAnimatedImageData,
              let image = data.decodedImage,
              let cgImage = image.cgImage
        else {
            logger.debug("analyzeImageForLiveText local image not found, index: \(index, privacy: .public)")
            return
        }

        liveTextHandler.analyzeImage(
            cgImage, size: image.size, index: index, recognitionLanguages:
                store.language?.codes
        )
    }

    /// Runs Live Text over a remote page's cached bytes, read from the owned `DataCache`
    /// (the reader's cache, not Kingfisher's). Animated images are skipped by design
    /// (Live Text scans still images only).
    private func analyzeCachedImageData(cacheKeys: [String], index: Int) async {
        guard let data = await DataCache.shared.data(forKeys: cacheKeys),
              !data.isAnimatedImageData,
              let image = data.decodedImage,
              let cgImage = image.cgImage
        else {
            logger.debug("analyzeImageForLiveText image not found, index: \(index, privacy: .public)")
            return
        }

        liveTextHandler.analyzeImage(
            cgImage, size: image.size, index: index, recognitionLanguages:
                store.language?.codes
        )
    }
}

struct ReadingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Color.clear
                .fullScreenCover(isPresented: .constant(true)) {
                    ReadingView(
                        store: .init(initialState: .init(gallery: .empty), reducer: ReadingReducer.init),
                        gid: .init(),
                        setting: .constant(.init()),
                        blurRadius: 0
                    )
                }
        }
    }
}
