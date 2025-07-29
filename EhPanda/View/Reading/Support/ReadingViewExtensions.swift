//
//  ReadingViewExtensions.swift
//  EhPanda
//
//  Created by zackie on 2025-07-28 for improved Reading view architecture
//

import SwiftUI
import SwiftUIPager
import ComposableArchitecture

// MARK: - Auto Play Policy
enum AutoPlayPolicy: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }
    
    case off = -1
    case sec1 = 1
    case sec2 = 2
    case sec3 = 3
    case sec4 = 4
    case sec5 = 5
}

extension AutoPlayPolicy {
    /// Human-readable value for the auto play policy
    var value: String {
        switch self {
        case .off:
            return L10n.Localizable.Enum.AutoPlayPolicy.Value.off
        default:
            return L10n.Localizable.Common.Value.seconds("\(rawValue)")
        }
    }
    
    /// Time interval for the timer (0 means disabled)
    var timeInterval: TimeInterval {
        return rawValue > 0 ? TimeInterval(rawValue) : 0
    }
    
    /// Whether auto play is enabled
    var isEnabled: Bool {
        return self != .off
    }
}

// MARK: - Reading View Modifiers

extension View {
    /// Applies all reading view modifiers including sheets, progress HUD, and animations
    func readingViewModifiers(
        store: StoreOf<ReadingReducer>,
        setting: Binding<Setting>,
        blurRadius: Double
    ) -> some View {
        self
            .readingSheets(store: store, setting: setting, blurRadius: blurRadius)
            .readingProgressHUD(store: store)
            .readingAnimations()
            .readingStatusBar(store: store)
    }
    
    /// Applies reading-specific sheet presentations
    private func readingSheets(
        store: StoreOf<ReadingReducer>,
        setting: Binding<Setting>,
        blurRadius: Double
    ) -> some View {
        self
            .sheet(item: Binding(
                get: { store.route?.readingSetting },
                set: { _ in store.send(.setNavigation(nil)) }
            )) { _ in
                NavigationView {
                    ReadingSettingView(
                        readingDirection: setting.readingDirection,
                        prefetchLimit: setting.prefetchLimit,
                        enablesLandscape: setting.enablesLandscape,
                        contentDividerHeight: setting.contentDividerHeight,
                        maximumScaleFactor: setting.maximumScaleFactor,
                        doubleTapScaleFactor: setting.doubleTapScaleFactor
                    )
                    .readingSettingToolbar {
                        store.send(.setNavigation(nil))
                    }
                }
                .accentColor(setting.wrappedValue.accentColor)
                .tint(setting.wrappedValue.accentColor)
                .autoBlur(radius: blurRadius)
                .navigationViewStyle(.stack)
            }
            .sheet(item: Binding(
                get: { store.route?.share },
                set: { _ in store.send(.setNavigation(nil)) }
            )) { shareItemBox in
                ActivityView(activityItems: [shareItemBox.wrappedValue.associatedValue])
                    .accentColor(setting.wrappedValue.accentColor)
                    .autoBlur(radius: blurRadius)
            }
    }
    
    /// Applies progress HUD for reading operations
    private func readingProgressHUD(store: StoreOf<ReadingReducer>) -> some View {
        self.progressHUD(
            config: store.hudConfig,
            unwrapping: Binding(
                get: { store.route },
                set: { store.send(.setNavigation($0)) }
            ),
            case: \.hud
        )
    }
    
    /// Applies reading-specific animations
    private func readingAnimations() -> some View {
        self
            .animation(.linear(duration: 0.1), value: UUID()) // Placeholder for gesture animations
            .animation(.default, value: UUID()) // Placeholder for other animations
    }
    
    /// Configures status bar visibility
    private func readingStatusBar(store: StoreOf<ReadingReducer>) -> some View {
        self.statusBar(hidden: !store.showsPanel)
    }
}

// MARK: - Reading Setting Toolbar

extension View {
    func readingSettingToolbar(dismissAction: @escaping () -> Void) -> some View {
        self.toolbar {
            CustomToolbarItem(placement: .cancellationAction) {
                if !DeviceUtil.isPad && DeviceUtil.isLandscape {
                    Button(action: dismissAction) {
                        Image(systemSymbol: .chevronDown)
                    }
                }
            }
        }
    }
}

// MARK: - Reading Changes Observer

extension View {
    /// Observes reading-related changes and handles side effects
    func observeReadingChanges(
        store: StoreOf<ReadingReducer>,
        setting: Binding<Setting>,
        viewModel: ReadingViewModel,
        pageCoordinator: PageCoordinator,
        page: Page
    ) -> some View {
        self
            .onChange(of: page.index) { _, newValue in
                handlePageIndexChange(
                    newValue: newValue,
                    store: store,
                    setting: setting.wrappedValue,
                    pageCoordinator: pageCoordinator
                )
            }
            .onChange(of: pageCoordinator.sliderValue) { _, newValue in
                handleSliderValueChange(
                    newValue: newValue,
                    store: store,
                    showsSliderPreview: store.showsSliderPreview,
                    page: page,
                    pageCoordinator: pageCoordinator,
                    setting: setting.wrappedValue
                )
            }
            .onChange(of: store.showsSliderPreview) { _, newValue in
                handleSliderPreviewChange(
                    newValue: newValue,
                    pageCoordinator: pageCoordinator,
                    viewModel: viewModel,
                    page: page,
                    setting: setting.wrappedValue
                )
            }
            .onChange(of: store.readingProgress) { _, newValue in
                handleReadingProgressChange(
                    newValue: newValue,
                    pageCoordinator: pageCoordinator,
                    page: page,
                    setting: setting.wrappedValue
                )
            }
            .onChange(of: store.route) { _, newValue in
                handleRouteChange(newValue: newValue, viewModel: viewModel)
            }
            .onChange(of: viewModel.enablesLiveText) { _, newValue in
                handleLiveTextToggle(
                    newValue: newValue,
                    store: store,
                    viewModel: viewModel
                )
            }
            .onChange(of: store.webImageLoadSuccessIndices) { _, newValue in
                handleImageLoadSuccess(
                    newValue: newValue,
                    viewModel: viewModel,
                    store: store
                )
            }
            .onChange(of: setting.wrappedValue.enablesLandscape) { _, newValue in
                handleLandscapeSettingChange(newValue: newValue, store: store)
            }
    }
    
    private func handlePageIndexChange(
        newValue: Int,
        store: StoreOf<ReadingReducer>,
        setting: Setting,
        pageCoordinator: PageCoordinator
    ) {
        Logger.info("Page index changed", context: ["pageIndex": newValue])
        
        let mappedValue = pageCoordinator.mapFromPager(
            index: newValue,
            pageCount: store.gallery.pageCount,
            setting: setting
        )
        
        pageCoordinator.sliderValue = Float(mappedValue)
        
        if store.databaseLoadingState == .idle {
            store.send(.syncReadingProgress(mappedValue))
        }
    }
    
    private func handleSliderValueChange(
        newValue: Float,
        store: StoreOf<ReadingReducer>,
        showsSliderPreview: Bool,
        page: Page,
        pageCoordinator: PageCoordinator,
        setting: Setting
    ) {
        Logger.info("Slider value changed", context: ["sliderValue": newValue])
        
        if !showsSliderPreview {
            let pagerIndex = pageCoordinator.mapToPager(index: Int(newValue), setting: setting)
            if page.index != pagerIndex {
                page.update(.new(index: pagerIndex))
                Logger.info("Pager updated from slider", context: ["pagerIndex": pagerIndex])
            }
        }
    }
    
    private func handleSliderPreviewChange(
        newValue: Bool,
        pageCoordinator: PageCoordinator,
        viewModel: ReadingViewModel,
        page: Page,
        setting: Setting
    ) {
        Logger.info("Slider preview changed", context: ["isShown": newValue])
        
        if !newValue {
            let pagerIndex = pageCoordinator.mapToPager(
                index: Int(pageCoordinator.sliderValue),
                setting: setting
            )
            if page.index != pagerIndex {
                page.update(.new(index: pagerIndex))
            }
        }
        
        viewModel.stopAutoPlay()
    }
    
    private func handleReadingProgressChange(
        newValue: Int,
        pageCoordinator: PageCoordinator,
        page: Page,
        setting: Setting
    ) {
        Logger.info("Reading progress changed", context: ["readingProgress": newValue])
        
        // Ensure valid reading progress (at least page 1)
        let validProgress = max(1, newValue)
        
        // Update slider value
        pageCoordinator.sliderValue = Float(validProgress)
        
        // Update pager position to match the reading progress
        let pagerIndex = pageCoordinator.mapToPager(index: validProgress, setting: setting)
        if page.index != pagerIndex {
            page.update(.new(index: pagerIndex))
            Logger.info("Pager updated from reading progress", context: [
                "readingProgress": validProgress,
                "pagerIndex": pagerIndex
            ])
        }
    }
    
    private func handleRouteChange(newValue: ReadingReducer.Route?, viewModel: ReadingViewModel) {
        Logger.info("Route changed", context: ["route": newValue as Any])
        
        if let route = newValue, ![ReadingReducer.Route.hud, nil].contains(where: { $0 == route }) {
            viewModel.stopAutoPlay()
        }
    }
    
    private func handleLiveTextToggle(
        newValue: Bool,
        store: StoreOf<ReadingReducer>,
        viewModel: ReadingViewModel
    ) {
        Logger.info("Live text toggled", context: ["isEnabled": newValue])
        
        if newValue {
            store.webImageLoadSuccessIndices.forEach { index in
                viewModel.analyzeImageForLiveText(
                    index: index,
                    imageURL: store.imageURLs[index],
                    recognitionLanguages: store.galleryDetail?.language.codes
                )
            }
        }
    }
    
    private func handleImageLoadSuccess(
        newValue: Set<Int>,
        viewModel: ReadingViewModel,
        store: StoreOf<ReadingReducer>
    ) {
        Logger.info("Image load success indices changed", context: [
            "count": newValue.count
        ])
        
        if viewModel.enablesLiveText {
            newValue.forEach { index in
                viewModel.analyzeImageForLiveText(
                    index: index,
                    imageURL: store.imageURLs[index],
                    recognitionLanguages: store.galleryDetail?.language.codes
                )
            }
        }
    }
    
    private func handleLandscapeSettingChange(newValue: Bool, store: StoreOf<ReadingReducer>) {
        Logger.info("Landscape setting changed", context: ["newValue": newValue])
        store.send(.setOrientationPortrait(!newValue))
    }
}

// MARK: - Reading Control Panel

/// Replacement for the original ControlPanel component with improved architecture
struct ReadingControlPanel<G: Gesture>: View {
    @Binding private var showsPanel: Bool
    @Binding private var showsSliderPreview: Bool
    @Binding private var sliderValue: Float
    @Binding private var setting: Setting
    @Binding private var enablesLiveText: Bool
    @Binding private var autoPlayPolicy: AutoPlayPolicy
    
    private let range: ClosedRange<Float>
    private let previewURLs: [Int: URL]
    private let dismissGesture: G
    private let dismissAction: () -> Void
    private let navigateSettingAction: () -> Void
    private let reloadAllImagesAction: () -> Void
    private let retryAllFailedImagesAction: () -> Void
    private let fetchPreviewURLsAction: (Int) -> Void
    
    init(
        showsPanel: Binding<Bool>,
        showsSliderPreview: Binding<Bool>,
        sliderValue: Binding<Float>,
        setting: Binding<Setting>,
        enablesLiveText: Binding<Bool>,
        autoPlayPolicy: Binding<AutoPlayPolicy>,
        range: ClosedRange<Float>,
        previewURLs: [Int: URL],
        dismissGesture: G,
        dismissAction: @escaping () -> Void,
        navigateSettingAction: @escaping () -> Void,
        reloadAllImagesAction: @escaping () -> Void,
        retryAllFailedImagesAction: @escaping () -> Void,
        fetchPreviewURLsAction: @escaping (Int) -> Void
    ) {
        _showsPanel = showsPanel
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        _setting = setting
        _enablesLiveText = enablesLiveText
        _autoPlayPolicy = autoPlayPolicy
        self.range = range
        self.previewURLs = previewURLs
        self.dismissGesture = dismissGesture
        self.dismissAction = dismissAction
        self.navigateSettingAction = navigateSettingAction
        self.reloadAllImagesAction = reloadAllImagesAction
        self.retryAllFailedImagesAction = retryAllFailedImagesAction
        self.fetchPreviewURLsAction = fetchPreviewURLsAction
    }
    
    var body: some View {
        ControlPanel(
            showsPanel: $showsPanel,
            showsSliderPreview: $showsSliderPreview,
            sliderValue: $sliderValue,
            setting: $setting,
            enablesLiveText: $enablesLiveText,
            autoPlayPolicy: $autoPlayPolicy,
            range: range,
            previewURLs: previewURLs,
            dismissGesture: dismissGesture,
            dismissAction: dismissAction,
            navigateSettingAction: navigateSettingAction,
            reloadAllImagesAction: reloadAllImagesAction,
            retryAllFailedImagesAction: retryAllFailedImagesAction,
            fetchPreviewURLsAction: fetchPreviewURLsAction
        )
    }
}

// MARK: - Route Binding Extensions

extension ReadingReducer.Route {
    var readingSetting: EquatableVoid? {
        if case .readingSetting(let void) = self {
            return void
        }
        return nil
    }
    
    var share: IdentifiableBox<ReadingReducer.ShareItem>? {
        if case .share(let shareItem) = self {
            return shareItem
        }
        return nil
    }
    
    var hud: Void? {
        if case .hud = self {
            return ()
        }
        return nil
    }
} 