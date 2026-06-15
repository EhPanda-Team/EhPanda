//
//  ReadingView.swift
//  EhPanda
//

import SwiftUI
import Observation
import SwiftUIPager
import ComposableArchitecture

struct ReadingView: View {
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

    init(
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

    var body: some View {
        @Bindable var bindableLiveTextHandler = liveTextHandler
        @Bindable var bindablePageHandler = pageHandler

        return changeTriggers(content: { content })
            .sheet(item: $store.route.sending(\.setNavigation).readingSetting) { _ in
                NavigationView {
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
                                    store.send(.setNavigation(nil))
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
                .navigationViewStyle(.stack)
            }
            .sheet(item: $store.route.sending(\.setNavigation).share) { shareItemBox in
                ActivityView(activityItems: [shareItemBox.wrappedValue.associatedValue])
                    .accentColor(setting.accentColor)
                    .autoBlur(radius: blurRadius)
            }
            .progressHUD(
                config: store.hudConfig,
                unwrapping: $store.route,
                case: \.hud
            )

            .animation(.linear(duration: 0.1), value: gestureHandler.offset)
            .animation(.default, value: liveTextHandler.enablesLiveText)
            .animation(.default, value: liveTextHandler.liveTextGroups)
            .animation(.default, value: gestureHandler.scale)
            .animation(.default, value: store.showsPanel)
            .statusBar(hidden: !store.showsPanel)
            .onDisappear {
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
            .id(store.databaseLoadingState)
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
                navigateSettingAction: { store.send(.setNavigation(.readingSetting())) },
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
                Logger.info("liveTextHandler.enablesLiveText changed", context: ["isEnabled": newValue])
                if newValue { store.webImageLoadSuccessIndices.forEach(analyzeImageForLiveText) }
            }
            .onChange(of: store.webImageLoadSuccessIndices) { _, newValue in
                Logger.info("store.webImageLoadSuccessIndices changed", context: [
                    "count": store.webImageLoadSuccessIndices.count
                ])
                if liveTextHandler.enablesLiveText {
                    newValue.forEach(analyzeImageForLiveText)
                }
            }
            // Orientation
            .onChange(of: setting.enablesLandscape) { _, newValue in
                Logger.info("setting.enablesLandscape changed", context: ["newValue": newValue])
                store.send(.setOrientationPortrait(!newValue))
            }
    }

    @ViewBuilder
    private func pageAndAutoPlayTriggers<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            // Page
            .onChange(of: page.index) { _, newValue in
                Logger.info("page.index changed", context: ["pageIndex": newValue])
                let newValue = pageHandler.mapFromPager(
                    index: newValue, pageCount: store.gallery.pageCount, setting: setting
                )
                pageHandler.sliderValue = .init(newValue)
                if store.databaseLoadingState == .idle {
                    store.send(.syncReadingProgress(.init(newValue)))
                }
            }
            .onChange(of: pageHandler.sliderValue) { _, newValue in
                Logger.info("pageHandler.sliderValue changed", context: ["sliderValue": newValue])
                if !store.showsSliderPreview {
                    setPageIndex(sliderValue: newValue)
                }
            }
            .onChange(of: store.showsSliderPreview) { _, newValue in
                Logger.info("store.showsSliderPreview changed", context: ["isShown": newValue])
                if !newValue { setPageIndex(sliderValue: pageHandler.sliderValue) }
                setAutoPlayPolocy(.off)
            }
            .onChange(of: store.readingProgress) { _, newValue in
                Logger.info("store.readingProgress changed", context: ["readingProgress": newValue])
                pageHandler.sliderValue = .init(newValue)
            }
            // AutoPlay
            .onChange(of: store.route) { _, newValue in
                Logger.info("store.route changed", context: ["route": newValue])
                if ![.hud, .none].contains(newValue) {
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
            isDatabaseLoading: store.databaseLoadingState != .idle,
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
            Logger.info("Pager.update", context: ["update": newValue])
        }
    }
    func setAutoPlayPolocy(_ policy: AutoPlayPolicy) {
        autoPlayHandler.setPolicy(policy, updatePageAction: {
            page.update(.next)
            Logger.info("Pager.update", context: ["update": "next"])
        })
    }
    func analyzeImageForLiveText(index: Int) {
        Logger.info("analyzeImageForLiveText", context: ["index": index])
        guard liveTextHandler.liveTextGroups[index] == nil else {
            Logger.info("analyzeImageForLiveText duplicated", context: ["index": index])
            return
        }
        guard let imageURL = displayImageURLs[index] else {
            Logger.info("analyzeImageForLiveText URL not found", context: ["index": index])
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

    private func analyzeLocalImage(at imageURL: URL, index: Int) {
        guard let data = try? Data(contentsOf: imageURL),
              !data.isAnimatedImageData,
              let image = data.decodedImage,
              let cgImage = image.cgImage
        else {
            Logger.info("analyzeImageForLiveText local image not found", context: ["index": index])
            return
        }

        liveTextHandler.analyzeImage(
            cgImage, size: image.size, index: index, recognitionLanguages:
                store.language?.codes
        )
    }

    private func analyzeCachedImageData(cacheKeys: [String], index: Int) async {
        guard let data = await DataCache.shared.data(forKeys: cacheKeys),
              !data.isAnimatedImageData,
              let image = data.decodedImage,
              let cgImage = image.cgImage
        else {
            Logger.info("analyzeImageForLiveText image not found", context: ["index": index])
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
        NavigationView {
            Text("")
                .fullScreenCover(isPresented: .constant(true)) {
                    ReadingView(
                        store: .init(initialState: .init(), reducer: ReadingReducer.init),
                        gid: .init(),
                        setting: .constant(.init()),
                        blurRadius: 0
                    )
                }
        }
    }
}
