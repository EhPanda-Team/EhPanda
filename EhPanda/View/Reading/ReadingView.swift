//
//  ReadingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/22.
//

import SwiftUI
import Kingfisher
import SwiftUIPager
import ComposableArchitecture

struct ReadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    let store: Store<ReadingState, ReadingAction>
    @ObservedObject private var viewStore: ViewStore<ReadingState, ReadingAction>
    private let gid: String
    @Binding private var setting: Setting
    private let blurRadius: Double

    @StateObject private var page: Page = .first()

    init(
        store: Store<ReadingState, ReadingAction>,
        gid: String, setting: Binding<Setting>, blurRadius: Double
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.gid = gid
        _setting = setting
        self.blurRadius = blurRadius
    }

    private var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGray4) : Color(.systemGray6)
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            conditionalList.scaleEffect(viewStore.scale, anchor: viewStore.scaleAnchor)
                .offset(viewStore.offset).gesture(tapGesture).gesture(dragGesture)
                .gesture(magnificationGesture).ignoresSafeArea()
            ControlPanel(
                showsPanel: viewStore.binding(\.$showsPanel),
                sliderValue: viewStore.binding(\.$sliderValue),
                setting: $setting,
                autoPlayPolicy: viewStore.binding(\.$autoPlayPolicy),
                currentIndex: viewStore.state.mapFromPager(
                    setting: setting, isLandscape: DeviceUtil.isLandscape
                ),
                range: 1...Float(viewStore.gallery.pageCount),
                previews: viewStore.previews,
                settingAction: { viewStore.send(.setNavigation(.readingSetting)) },
                fetchAction: { viewStore.send(.fetchPreviews($0)) },
                sliderChangedAction: { _ in },
                updateSettingAction: { _ in }
            )
        }
        .sheet(unwrapping: viewStore.binding(\.$route), case: /ReadingState.Route.readingSetting) { _ in
            NavigationView {
                ReadingSettingView(
                    readingDirection: $setting.readingDirection,
                    prefetchLimit: $setting.prefetchLimit,
                    prefersLandscape: $setting.prefersLandscape,
                    contentDividerHeight: $setting.contentDividerHeight,
                    maximumScaleFactor: $setting.maximumScaleFactor,
                    doubleTapScaleFactor: $setting.doubleTapScaleFactor
                )
            }
//            .toolbar(content: { /* landscape */ })
            .accentColor(setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
        .synchronize(viewStore.binding(\.$pageIndex), $page.index)
        .onAppear { viewStore.send(.fetchDatabaseInfos(gid)) }
    }

    // MARK: ConditionalList
    @ViewBuilder private var conditionalList: some View {
        if setting.readingDirection == .vertical {
            AdvancedList(
                page: page, data: viewStore.state.containerDataSource(
                    setting: setting, isLandscape: DeviceUtil.isLandscape
                ),
                id: \.self, spacing: setting.contentDividerHeight,
                gesture: SimultaneousGesture(magnificationGesture, tapGesture),
                content: imageContainer
            )
            .disabled(viewStore.scale != 1)
        } else {
            Pager(
                page: page, data: viewStore.state.containerDataSource(
                    setting: setting, isLandscape: DeviceUtil.isLandscape
                ),
                id: \.self, content: imageContainer
            )
            .horizontal(setting.readingDirection == .rightToLeft ? .rightToLeft : .leftToRight)
            .swipeInteractionArea(.allAvailable).allowsDragging(viewStore.scale == 1)
        }
    }
    private func imageContainer(index: Int) -> some View {
        HStack(spacing: 0) {
            let (firstIndex, secondIndex, isFirstValid, isSecondValid) = viewStore.state.imageContainerConfigs(
                index: index, setting: setting, isLandscape: DeviceUtil.isLandscape
            )
            let isDualPage = setting.enablesDualPageMode
            && setting.readingDirection != .vertical
            && DeviceUtil.isLandscape

            if isFirstValid {
                ImageContainer(
                    index: firstIndex,
                    imageURL: viewStore.contents[firstIndex] ?? "",
                    loadingState: viewStore.contentLoadingStates[firstIndex] ?? .idle,
                    isDualPage: isDualPage,
                    backgroundColor: backgroundColor,
                    retryAction: {
                        if viewStore.contents[$0] == nil {
                            viewStore.send(.fetchContents($0))
                        }
                    },
                    reloadAction: { viewStore.send(.refetchContents($0)) }
                )
                .onAppear {
                    if viewStore.contents[firstIndex] == nil {
                        viewStore.send(.fetchContents(firstIndex))
                    }
                }
                .contextMenu { contextMenuItems(index: firstIndex) }
            }

            if isSecondValid {
                ImageContainer(
                    index: secondIndex,
                    imageURL: viewStore.contents[secondIndex] ?? "",
                    loadingState: viewStore.contentLoadingStates[secondIndex] ?? .idle,
                    isDualPage: isDualPage,
                    backgroundColor: backgroundColor,
                    retryAction: {
                        if viewStore.contents[$0] == nil {
                            viewStore.send(.fetchContents($0))
                        }
                    },
                    reloadAction: { viewStore.send(.refetchContents($0)) }
                )
                .onAppear {
                    if viewStore.contents[secondIndex] == nil {
                        viewStore.send(.fetchContents(secondIndex))
                    }
                }
                .contextMenu { contextMenuItems(index: secondIndex) }
            }
        }
    }
    // MARK: ContextMenu
    @ViewBuilder private func contextMenuItems(index: Int) -> some View {
        Button {
            viewStore.send(.refetchContents(index))
        } label: {
            Label("Reload", systemSymbol: .arrowCounterclockwise)
        }
        if let content = viewStore.contents[index], !content.isEmpty {
            Button {
                viewStore.send(.copyImage(content))
            } label: {
                Label("Copy", systemSymbol: .plusSquareOnSquare)
            }
            Button {
                viewStore.send(.saveImage(content))
            } label: {
                Label("Save", systemSymbol: .squareAndArrowDown)
            }
            if let originalContent = viewStore.originalContents[index], !originalContent.isEmpty {
                Button {
                    viewStore.send(.saveImage(originalContent))
                } label: {
                    Label("Save original", systemSymbol: .squareAndArrowDownOnSquare)
                }
            }
            Button {
                viewStore.send(.shareImage(content))
            } label: {
                Label("Share", systemSymbol: .squareAndArrowUp)
            }
        }
    }
}

extension ReadingView {
    // MARK: Gesture
    var tapGesture: some Gesture {
        let singleTap = TapGesture(count: 1)
            .onEnded { viewStore.send(.onSingleTapGestureEnded(setting)) }
        let doubleTap = TapGesture(count: 2)
            .onEnded { viewStore.send(.onDoubleTapGestureEnded(setting)) }
        return ExclusiveGesture(doubleTap, singleTap)
    }
    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { viewStore.send(.onMagnificationGestureChanged($0, setting)) }
            .onEnded { viewStore.send(.onMagnificationGestureEnded($0, setting)) }
    }
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0, coordinateSpace: .local)
            .onChanged { viewStore.send(.onDragGestureChanged($0)) }
            .onEnded { viewStore.send(.onDragGestureEnded($0)) }
    }
}

// MARK: ImageContainer
private struct ImageContainer: View {
    @State private var webImageLoadFailed = false

    private var width: CGFloat {
        DeviceUtil.windowW / (isDualPage ? 2 : 1)
    }
    private var height: CGFloat {
        width / Defaults.ImageSize.contentAspect
    }
    private var loadFailedFlag: Bool {
        loadError != nil || webImageLoadFailed
    }
    private var loadError: AppError? {
        (/LoadingState.failed).extract(from: loadingState)
    }

    private let index: Int
    private let imageURL: String
    private let loadingState: LoadingState
    private let isDualPage: Bool
    private let backgroundColor: Color
    private let retryAction: (Int) -> Void
    private let reloadAction: (Int) -> Void

    init(
        index: Int, imageURL: String,
        loadingState: LoadingState,
        isDualPage: Bool, backgroundColor: Color,
        retryAction: @escaping (Int) -> Void,
        reloadAction: @escaping (Int) -> Void
    ) {
        self.index = index
        self.imageURL = imageURL
        self.loadingState = loadingState
        self.isDualPage = isDualPage
        self.backgroundColor = backgroundColor
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
                Text(String(index)).font(.largeTitle.bold())
                    .foregroundColor(.gray).padding(.bottom, 30)
                if loadFailedFlag {
                    Button(action: reloadImage) {
                        Image(systemSymbol: .exclamationmarkArrowTriangle2Circlepath)
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
        if loadingState == .loading || loadFailedFlag {
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
