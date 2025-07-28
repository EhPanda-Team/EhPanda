//
//  ReadingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/22.
//  Refactored for improved maintainability by zackie on 2025-07-28.
//

import SwiftUI
import Kingfisher
import SwiftUIPager
import ComposableArchitecture

// MARK: - Main Reading View
struct ReadingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var store: StoreOf<ReadingReducer>
    
    // MARK: - Configuration
    private let gid: String
    @Binding private var setting: Setting
    private let blurRadius: Double

    // MARK: - View Models
    @StateObject private var viewModel: ReadingViewModel
    @StateObject private var gestureCoordinator: GestureCoordinator
    @StateObject private var pageCoordinator: PageCoordinator
    @StateObject private var page: Page = .first()

    // MARK: - Initialization
    init(
        store: StoreOf<ReadingReducer>,
        gid: String,
        setting: Binding<Setting>,
        blurRadius: Double
    ) {
        self.store = store
        self.gid = gid
        _setting = setting
        self.blurRadius = blurRadius
        
        // Initialize view models with dependencies
        _viewModel = StateObject(wrappedValue: ReadingViewModel())
        _gestureCoordinator = StateObject(wrappedValue: GestureCoordinator())
        _pageCoordinator = StateObject(wrappedValue: PageCoordinator())
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ReadingContentView(
                store: store,
                setting: $setting,
                viewModel: viewModel,
                gestureCoordinator: gestureCoordinator,
                pageCoordinator: pageCoordinator,
                page: page
            )
            
            ReadingControlsOverlay(
                store: store,
                setting: $setting,
                viewModel: viewModel,
                pageCoordinator: pageCoordinator,
                gestureCoordinator: gestureCoordinator,
                page: page
            )
        }
        .readingViewModifiers(
            store: store,
            setting: $setting,
            blurRadius: blurRadius
        )
        .onAppear {
            store.send(.onAppear(gid, setting.enablesLandscape))
            setupViewModels()
        }
        .onDisappear {
            cleanup()
        }
        .observeReadingChanges(
            store: store,
            setting: $setting,
            viewModel: viewModel,
            pageCoordinator: pageCoordinator,
            page: page
        )
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGray4) : Color(.systemGray6)
    }
    
    // MARK: - Helper Methods
    private func setupViewModels() {
        viewModel.setup(with: store.state, setting: setting)
        gestureCoordinator.setup(setting: setting)
        
        // Setup page coordinator with initial reading progress if available
        if store.readingProgress > 0 {
            pageCoordinator.setup(
                pageCount: store.gallery.pageCount,
                setting: setting,
                initialPage: store.readingProgress
            )
            
            // Also update the pager to the correct initial position
            let pagerIndex = pageCoordinator.mapToPager(index: store.readingProgress, setting: setting)
            page.update(.new(index: pagerIndex))
        } else {
            pageCoordinator.setup(
                pageCount: store.gallery.pageCount,
                setting: setting
            )
        }
    }
    
    private func cleanup() {
        viewModel.cleanup()
        gestureCoordinator.cleanup()
        pageCoordinator.cleanup()
    }
}

// MARK: - Reading Content View
private struct ReadingContentView: View {
    let store: StoreOf<ReadingReducer>
    @Binding var setting: Setting
    @ObservedObject var viewModel: ReadingViewModel
    @ObservedObject var gestureCoordinator: GestureCoordinator
    @ObservedObject var pageCoordinator: PageCoordinator
    let page: Page
    
    var body: some View {
        Group {
            if setting.readingDirection == .vertical {
                VerticalReadingView(
                    store: store,
                    setting: $setting,
                    viewModel: viewModel,
                    gestureCoordinator: gestureCoordinator,
                    pageCoordinator: pageCoordinator,
                    page: page
                    )
                } else {
                HorizontalReadingView(
                    store: store,
                    setting: $setting,
                    viewModel: viewModel,
                    gestureCoordinator: gestureCoordinator,
                    pageCoordinator: pageCoordinator,
                    page: page,
                    onTogglePanel: { store.send(.toggleShowsPanel) }
                )
            }
        }
        .scaleEffect(gestureCoordinator.scale, anchor: gestureCoordinator.scaleAnchor)
        .offset(gestureCoordinator.offset)
        .ignoresSafeArea()
        .id(store.databaseLoadingState)
        .id(store.forceRefreshID)
    }
}

// MARK: - Vertical Reading View (Fixed for iOS 26)
private struct VerticalReadingView: View {
    let store: StoreOf<ReadingReducer>
    @Binding var setting: Setting
    @ObservedObject var viewModel: ReadingViewModel
    @ObservedObject var gestureCoordinator: GestureCoordinator
    @ObservedObject var pageCoordinator: PageCoordinator
    let page: Page
    
    var body: some View {
        // Fixed vertical scroll implementation for iOS 26 compatibility
        ImprovedScrollView(
            isScrollEnabled: gestureCoordinator.scale <= 1.0,
            page: page,
            data: store.state.containerDataSource(setting: setting),
            spacing: setting.contentDividerHeight,
            gestureCoordinator: gestureCoordinator,
            pageCoordinator: pageCoordinator,
            setting: setting,
            onTogglePanel: { store.send(.toggleShowsPanel) }
        ) { index in
            ImageStackView(
                index: index,
                store: store,
                setting: $setting,
                viewModel: viewModel,
                gestureCoordinator: gestureCoordinator
            )
        }
    }
}

// MARK: - Horizontal Reading View
private struct HorizontalReadingView: View {
    let store: StoreOf<ReadingReducer>
    @Binding var setting: Setting
    @ObservedObject var viewModel: ReadingViewModel
    @ObservedObject var gestureCoordinator: GestureCoordinator
    @ObservedObject var pageCoordinator: PageCoordinator
    let page: Page
    let onTogglePanel: () -> Void

    var body: some View {
        Pager(
            page: page,
            data: store.state.containerDataSource(setting: setting),
            id: \.self
        ) { index in
            ImageStackView(
                index: index,
                store: store,
                setting: $setting,
                viewModel: viewModel,
                gestureCoordinator: gestureCoordinator
            )
        }
        .horizontal(setting.readingDirection == .rightToLeft ? .endToStart : .startToEnd)
        .swipeInteractionArea(.allAvailable)
        .allowsDragging(gestureCoordinator.scale == 1)
        .readingGestures(
            gestureCoordinator: gestureCoordinator,
            pageCoordinator: pageCoordinator,
            setting: setting,
            page: page,
            onTogglePanel: onTogglePanel
        )
    }
}

// MARK: - Improved Scroll View (Fixes iOS 26 bug)
private struct ImprovedScrollView<Content: View>: View {
    let isScrollEnabled: Bool
    let page: Page
    let data: [Int]
    let spacing: CGFloat
    let gestureCoordinator: GestureCoordinator
    let pageCoordinator: PageCoordinator
    let setting: Setting
    let onTogglePanel: () -> Void
    let content: (Int) -> Content
    
    @State private var performingChanges = false
    @State private var scrollTarget: Int?
    @State private var currentVisibleIndex: Int = 0

    init(
        isScrollEnabled: Bool,
        page: Page,
        data: [Int],
        spacing: CGFloat,
        gestureCoordinator: GestureCoordinator,
        pageCoordinator: PageCoordinator,
        setting: Setting,
        onTogglePanel: @escaping () -> Void,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.isScrollEnabled = isScrollEnabled
        self.page = page
        self.data = data
        self.spacing = spacing
        self.gestureCoordinator = gestureCoordinator
        self.pageCoordinator = pageCoordinator
        self.setting = setting
        self.onTogglePanel = onTogglePanel
        self.content = content
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: spacing) {
                    ForEach(data, id: \.self) { index in
                        content(index)
                            .id(index + 1) // Use 1-based indexing for scroll target
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: [index: ScrollOffsetData(
                                                index: index,
                                                frame: geometry.frame(in: .named("ScrollView"))
                                            )]
                                        )
                                }
                            )
                    }
                }
        .onAppear {
                    scrollToCurrentPage(proxy: proxy)
                }
            }
            // Fixed scrollDisabled implementation for iOS 26
            .scrollDisabled(!isScrollEnabled)
            .coordinateSpace(name: "ScrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { preferences in
                updateCurrentVisibleIndex(from: preferences)
            }
            .readingGestures(
                gestureCoordinator: gestureCoordinator,
                pageCoordinator: pageCoordinator,
                setting: setting,
                page: page,
                onTogglePanel: onTogglePanel
            )
            .onChange(of: page.index) { _, newValue in
                scrollToPage(newValue, proxy: proxy)
            }
            .onChange(of: isScrollEnabled) { _, newValue in
                // Re-enable/disable scrolling based on zoom level
                if newValue && scrollTarget != nil {
                    if let target = scrollTarget {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(target, anchor: .center)
                        }
                        scrollTarget = nil
                    }
                }
            }
        }
    }
    
    private func updateCurrentVisibleIndex(from preferences: [Int: ScrollOffsetData]) {
        guard !performingChanges else { return }
        
        // Find the most visible item (closest to center of screen)
        let screenCenter = UIScreen.main.bounds.height / 2
        var mostVisibleIndex = 0
        var maxVisibility: CGFloat = 0
        
        for (_, item) in preferences {
            let itemCenter = item.frame.midY
            let distanceFromCenter = abs(itemCenter - screenCenter)
            let visibility = max(0, 1 - distanceFromCenter / screenCenter)
            
            if visibility > maxVisibility {
                maxVisibility = visibility
                mostVisibleIndex = item.index
            }
        }
        
        // Update page index if it changed significantly
        if mostVisibleIndex != currentVisibleIndex && maxVisibility > 0.5 {
            currentVisibleIndex = mostVisibleIndex
            let newPageIndex = mostVisibleIndex
            if page.index != newPageIndex {
                performingChanges = true
                page.update(.new(index: newPageIndex))
                
                // Reset performing changes after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    performingChanges = false
                }
                
                Logger.info("Updated page index from scroll", context: [
                    "newPageIndex": newPageIndex,
                    "visibility": maxVisibility
                ])
            }
        }
    }
    
    private func handleTap(index: Int) {
        performingChanges = true
        page.update(.new(index: index - 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            performingChanges = false
        }
    }
    
    private func scrollToCurrentPage(proxy: ScrollViewProxy) {
        let targetId = page.index + 1
        DispatchQueue.main.async {
            proxy.scrollTo(targetId, anchor: .center)
        }
    }
    
    private func scrollToPage(_ pageIndex: Int, proxy: ScrollViewProxy) {
        guard !performingChanges else { return }
        
        let targetId = pageIndex + 1
        if isScrollEnabled {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(targetId, anchor: .center)
            }
        } else {
            // Store target for when scrolling is re-enabled
            scrollTarget = targetId
        }
    }
}

// MARK: - Scroll Position Tracking
private struct ScrollOffsetData: Equatable {
    let index: Int
    let frame: CGRect
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: ScrollOffsetData] = [:]
    
    static func reduce(value: inout [Int: ScrollOffsetData], nextValue: () -> [Int: ScrollOffsetData]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Reading Controls Overlay
private struct ReadingControlsOverlay: View {
    let store: StoreOf<ReadingReducer>
    @Binding var setting: Setting
    @ObservedObject var viewModel: ReadingViewModel
    @ObservedObject var pageCoordinator: PageCoordinator
    @ObservedObject var gestureCoordinator: GestureCoordinator
    let page: Page
    
    var body: some View {
        ReadingControlPanel(
            showsPanel: Binding(
                get: { store.showsPanel },
                set: { store.send(.binding(.set(\.showsPanel, $0))) }
            ),
            showsSliderPreview: Binding(
                get: { store.showsSliderPreview },
                set: { store.send(.binding(.set(\.showsSliderPreview, $0))) }
            ),
            sliderValue: $pageCoordinator.sliderValue,
            setting: $setting,
            enablesLiveText: $viewModel.enablesLiveText,
            autoPlayPolicy: .init(
                get: { viewModel.autoPlayPolicy },
                set: { viewModel.setAutoPlayPolicy($0, pageUpdater: {
                    page.update(.next)
                }) }
            ),
            range: 1...Float(store.gallery.pageCount),
            previewURLs: store.previewURLs,
            dismissGesture: createDismissGesture(),
            dismissAction: { store.send(.onPerformDismiss) },
            navigateSettingAction: { store.send(.setNavigation(.readingSetting())) },
            reloadAllImagesAction: { store.send(.reloadAllWebImages) },
            retryAllFailedImagesAction: { store.send(.retryAllFailedWebImages) },
            fetchPreviewURLsAction: { store.send(.fetchPreviewURLs($0)) }
        )
    }
    
    private func createDismissGesture() -> some Gesture {
        DragGesture()
            .onEnded { value in
                gestureCoordinator.handleControlPanelDismiss(
                    value: value,
                    dismissAction: { store.send(.onPerformDismiss) }
                )
            }
    }
}

// MARK: - Preview
struct ReadingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            Text("")
                .fullScreenCover(isPresented: .constant(true)) {
                    ReadingView(
                        store: .init(
                            initialState: .init(gallery: .empty),
                            reducer: ReadingReducer.init
                        ),
                        gid: .init(),
                        setting: .constant(.init()),
                        blurRadius: 0
                    )
                }
        }
    }
}
