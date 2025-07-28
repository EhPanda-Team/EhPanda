//
//  ImageStackView.swift
//  EhPanda
//
//  Created by zackie on 2025-07-28 for improved Reading view architecture
//

import SwiftUI
import Kingfisher
import ComposableArchitecture

// MARK: - Image Stack View
struct ImageStackView: View {
    // MARK: - Properties
    private let index: Int
    private let store: StoreOf<ReadingReducer>
    @Binding private var setting: Setting
    @ObservedObject private var viewModel: ReadingViewModel
    @ObservedObject private var gestureCoordinator: GestureCoordinator
    
    // MARK: - Computed Properties
    private var isDualPage: Bool {
        setting.enablesDualPageMode && 
        setting.readingDirection != .vertical && 
        DeviceUtil.isLandscape
    }
    
    private var backgroundColor: Color {
        Color(.systemGray4) // This should match the main view's background
    }
    
    private var imageStackConfig: ImageStackConfig {
        let dualPageConfig = pageCoordinator.getDualPageConfiguration(
            for: index,
            setting: setting
        )
        return ImageStackConfig(from: dualPageConfig)
    }
    
    // MARK: - Dependencies
    private var pageCoordinator: PageCoordinator {
        // This would ideally be injected, but for now we create a temporary one
        let coordinator = PageCoordinator()
        coordinator.setup(pageCount: store.gallery.pageCount, setting: setting)
        return coordinator
    }
    
    // MARK: - Initialization
    init(
        index: Int,
        store: StoreOf<ReadingReducer>,
        setting: Binding<Setting>,
        viewModel: ReadingViewModel,
        gestureCoordinator: GestureCoordinator
    ) {
        self.index = index
        self.store = store
        _setting = setting
        self.viewModel = viewModel
        self.gestureCoordinator = gestureCoordinator
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            if imageStackConfig.isFirstAvailable {
                ImageContainerView(
                    index: imageStackConfig.firstIndex,
                    store: store,
                    setting: $setting,
                    viewModel: viewModel,
                    isDualPage: isDualPage,
                    backgroundColor: backgroundColor
                )
            }
            
            if imageStackConfig.isSecondAvailable {
                ImageContainerView(
                    index: imageStackConfig.secondIndex,
                    store: store,
                    setting: $setting,
                    viewModel: viewModel,
                    isDualPage: isDualPage,
                    backgroundColor: backgroundColor
                )
            }
        }
    }
}

// MARK: - Image Container View
private struct ImageContainerView: View {
    // MARK: - Properties
    private let index: Int
    private let store: StoreOf<ReadingReducer>
    @Binding private var setting: Setting
    @ObservedObject private var viewModel: ReadingViewModel
    private let isDualPage: Bool
    private let backgroundColor: Color
    
    // MARK: - Computed Properties
    private var imageURL: URL? {
        store.imageURLs[index]
    }
    
    private var originalImageURL: URL? {
        store.originalImageURLs[index]
    }
    
    private var loadingState: LoadingState {
        store.imageURLLoadingStates[index] ?? .idle
    }
    
    private var liveTextGroups: [LiveTextGroup] {
        viewModel.liveTextGroups[index] ?? []
    }
    
    private var containerSize: CGSize {
        let width = DeviceUtil.windowW / (isDualPage ? 2 : 1)
        let height = width / Defaults.ImageSize.contentAspect
        return CGSize(width: width, height: height)
    }
    
    // MARK: - Initialization
    init(
        index: Int,
        store: StoreOf<ReadingReducer>,
        setting: Binding<Setting>,
        viewModel: ReadingViewModel,
        isDualPage: Bool,
        backgroundColor: Color
    ) {
        self.index = index
        self.store = store
        _setting = setting
        self.viewModel = viewModel
        self.isDualPage = isDualPage
        self.backgroundColor = backgroundColor
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if loadingState == .idle {
                successView
            } else {
                loadingOrErrorView
            }
        }
        .onAppear {
            handleAppear()
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Success View
    private var successView: some View {
        ZStack {
            imageView
                .scaledToFit()
                .overlay(
                    LiveTextView(
                        liveTextGroups: liveTextGroups,
                        focusedLiveTextGroup: viewModel.focusedLiveTextGroup,
                        tapAction: viewModel.setFocusedLiveTextGroup
                    )
                    .opacity(viewModel.enablesLiveText ? 1 : 0)
                )
        }
    }
    
    // MARK: - Image View
    @ViewBuilder
    private var imageView: some View {
        if let url = imageURL {
            if url.isGIF {
                KFAnimatedImage(url)
                    .placeholder { placeholderView() }
                    .fade(duration: 0.25)
                    .onSuccess { _ in handleImageSuccess() }
                    .onFailure { _ in handleImageFailure() }
            } else {
                KFImage(url)
                    .placeholder { placeholderView() }
                    .defaultModifier(withRoundedCorners: false)
                    .onSuccess { _ in handleImageSuccess() }
                    .onFailure { _ in handleImageFailure() }
            }
        } else {
            placeholderView(Progress())
        }
    }
    
    // MARK: - Placeholder View
    private func placeholderView(_ progress: Progress = Progress()) -> some View {
        Placeholder(
            style: .progress(
                pageNumber: index,
                progress: progress,
                isDualPage: isDualPage,
                backgroundColor: backgroundColor
            )
        )
        .frame(width: containerSize.width, height: containerSize.height)
    }
    
    // MARK: - Loading/Error View
    private var loadingOrErrorView: some View {
        ZStack {
            backgroundColor
            
            VStack(spacing: 30) {
                Text("\(index)")
                    .font(.largeTitle.bold())
                    .foregroundColor(.gray)
                
                ZStack {
                    if loadingState == .loading {
                        ProgressView()
                    } else {
                        Button(action: handleReloadTap) {
                            Image(systemSymbol: .exclamationmarkArrowTriangle2Circlepath)
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: handleRefetch) {
            Label(
                L10n.Localizable.ReadingView.ContextMenu.Button.reload,
                systemSymbol: .arrowCounterclockwise
            )
        }
        
        if let imageURL = imageURL {
            Button(action: { handleCopyImage(imageURL) }) {
                Label(
                    L10n.Localizable.ReadingView.ContextMenu.Button.copy,
                    systemSymbol: .plusSquareOnSquare
                )
            }
            
            Button(action: { handleSaveImage(imageURL) }) {
                Label(
                    L10n.Localizable.ReadingView.ContextMenu.Button.save,
                    systemSymbol: .squareAndArrowDown
                )
            }
            
            if let originalImageURL = originalImageURL {
                Button(action: { handleSaveImage(originalImageURL) }) {
                    Label(
                        L10n.Localizable.ReadingView.ContextMenu.Button.saveOriginal,
                        systemSymbol: .squareAndArrowDownOnSquare
                    )
                }
            }
            
            Button(action: { handleShareImage(imageURL) }) {
                Label(
                    L10n.Localizable.ReadingView.ContextMenu.Button.share,
                    systemSymbol: .squareAndArrowUp
                )
            }
        }
    }
    
    // MARK: - Event Handlers
    private func handleAppear() {
        let isDatabaseLoading = store.databaseLoadingState != .idle
        
        if !isDatabaseLoading {
            if imageURL == nil {
                store.send(.fetchImageURLs(index))
            }
            store.send(.prefetchImages(index, setting.prefetchLimit))
        }
    }
    
    private func handleImageSuccess() {
        store.send(.onWebImageSucceeded(index))
        
        if viewModel.enablesLiveText {
            viewModel.analyzeImageForLiveText(
                index: index,
                imageURL: imageURL,
                recognitionLanguages: store.galleryDetail?.language.codes
            )
        }
    }
    
    private func handleImageFailure() {
        store.send(.onWebImageFailed(index))
    }
    
    private func handleReloadTap() {
        if case .failed(let error) = loadingState {
            if case .webImageFailed = error {
                store.send(.onWebImageRetry(index))
            } else {
                store.send(.refetchImageURLs(index))
            }
        }
    }
    
    private func handleRefetch() {
        store.send(.refetchImageURLs(index))
    }
    
    private func handleCopyImage(_ url: URL) {
        store.send(.copyImage(url))
    }
    
    private func handleSaveImage(_ url: URL) {
        store.send(.saveImage(url))
    }
    
    private func handleShareImage(_ url: URL) {
        store.send(.shareImage(url))
    }
}

// MARK: - Preview
struct ImageStackView_Previews: PreviewProvider {
    static var previews: some View {
        ImageStackView(
            index: 1,
            store: .init(
                initialState: .init(gallery: .empty),
                reducer: ReadingReducer.init
            ),
            setting: .constant(.init()),
            viewModel: ReadingViewModel(),
            gestureCoordinator: GestureCoordinator()
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
} 