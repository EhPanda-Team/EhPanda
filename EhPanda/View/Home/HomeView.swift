//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/13.
//

import SwiftUI
import Kingfisher
import SwiftUIPager
import SFSafeSymbols
import ComposableArchitecture

struct HomeView: View {
    private let store: Store<HomeState, HomeAction>
    @ObservedObject private var viewStore: ViewStore<HomeState, HomeAction>

    init(store: Store<HomeState, HomeAction>) {
        self.store = store
        viewStore = ViewStore(store)
    }

    // MARK: HomeView
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack {
                        CardSlideSection(
                            galleries: viewStore.popularGalleries,
                            pageIndex: viewStore.binding(\.$cardPageIndex),
                            currentID: viewStore.currentCardID,
                            colors: viewStore.cardColors,
                            navigateAction: navigateTo(gid:)
                        ) { gid, result in
                            viewStore.send(.analyzeImageColors(gid, result))
                        }
                        .allowsHitTesting(viewStore.allowsCardHitTesting)
                        Group {
                            CoverWallSection(
                                galleries: viewStore.frontpageGalleries,
                                isLoading: viewStore.frontpageLoadingState == .loading,
                                navigateAction: navigateTo(gid:)
                            ) {
                                viewStore.send(.fetchFrontpageGalleries())
                            }
                            ToplistsSection(
                                galleries: viewStore.toplistsGalleries,
                                isLoading: !viewStore.toplistsLoadingState
                                    .values.allSatisfy({ $0 != .loading }),
                                navigateAction: navigateTo(gid:)
                            ) {
                                viewStore.send(.fetchAllToplistsGalleries)
                            }
                            MiscGridSection(navigateAction: navigateTo(type:))
                        }
                        .padding(.vertical)
                    }
                }
                .opacity(viewStore.popularGalleries.isEmpty ? 0 : 1).zIndex(2)
                LoadingView()
                    .opacity(
                        viewStore.popularLoadingState == .loading
                        && viewStore.popularGalleries.isEmpty ? 1 : 0
                    )
                    .zIndex(0)
                let error = (/LoadingState.failed)
                    .extract(from: viewStore.popularLoadingState)
                ErrorView(error: error ?? .unknown) {
                    viewStore.send(.fetchAllGalleries)
                }
                .opacity(
                    ![.idle, .loading].contains(viewStore.popularLoadingState)
                    && viewStore.popularGalleries.isEmpty ? 1 : 0
                )
                .zIndex(1)
            }
            .animation(.default, value: viewStore.popularLoadingState)
            .onAppear {
                if viewStore.popularGalleries.isEmpty {
                    viewStore.send(.fetchAllGalleries)
                }
            }
            .background(navigationLinks)
            .navigationTitle("Home")
        }
    }
}

// MARK: NavigationLinks
private extension HomeView {
    var navigationLinks: some View {
        Group {
            ForEach(viewStore.frontpageGalleries, content: detailViewLink)
            ForEach(viewStore.popularGalleries, content: detailViewLink)
            ForEach(ToplistsType.allCases) { type in
                let galleries = viewStore.toplistsGalleries[type.categoryIndex]
                ForEach(galleries ?? [], content: detailViewLink)
            }
            miscGridLinks
        }
    }
    var miscGridLinks: some View {
        ForEach(MiscGridType.allCases) { type in
            NavigationLink(
                "", tag: type, selection: .init(
                    get: { (/HomeViewRoute.misc).extract(from: viewStore.route) },
                    set: {
                        var route: HomeViewRoute?
                        if let type = $0 {
                            route = .misc(type)
                        }
                        viewStore.send(.setNavigation(route))
                    }
                )
            ) {
                EmptyView()
            }
        }
    }
    func detailViewLink(gallery: Gallery) -> NavigationLink<Text, DetailView> {
        NavigationLink(
            "", tag: gallery.id, selection: .init(
                get: { (/HomeViewRoute.detail).extract(from: viewStore.route) },
                set: {
                    var route: HomeViewRoute?
                    if let identifier = $0 {
                        route = .detail(identifier)
                    }
                    viewStore.send(.setNavigation(route))
                }
            )
        ) {
            DetailView(gid: gallery.id)
        }
    }
    func navigateTo(gid: String) {
        viewStore.send(.setNavigation(.detail(gid)))
    }
    func navigateTo(type: MiscGridType) {
        viewStore.send(.setNavigation(.misc(type)))
    }
}

// MARK: CardSlideSection
private struct CardSlideSection: View {
    @StateObject private var page: Page = .withIndex(1)
    @Binding private var pageIndex: Int

    private let galleries: [Gallery]
    private let currentID: String
    private let colors: [Color]
    private let navigateAction: (String) -> Void
    private let webImageSuccessAction: (String, RetrieveImageResult) -> Void

    init(
        galleries: [Gallery], pageIndex: Binding<Int>, currentID: String,
        colors: [Color], navigateAction: @escaping (String) -> Void,
        webImageSuccessAction: @escaping (String, RetrieveImageResult) -> Void
    ) {
        self.galleries = galleries
        _pageIndex = pageIndex
        self.currentID = currentID
        self.colors = colors
        self.navigateAction = navigateAction
        self.webImageSuccessAction = webImageSuccessAction
    }

    var body: some View {
        Pager(page: page, data: galleries) { gallery in
            Button {
                navigateAction(gallery.id)
            } label: {
                GalleryCardCell(gallery: gallery, currentID: currentID, colors: colors) {
                    webImageSuccessAction(gallery.gid, $0)
                }
                .tint(.primary).multilineTextAlignment(.leading)
            }
        }
        .preferredItemSize(Defaults.FrameSize.cardCellSize)
        .interactive(opacity: 0.2).itemSpacing(20)
        .loopPages().pagingPriority(.high)
        .synchronize($pageIndex, $page.index)
        .frame(height: Defaults.FrameSize.cardCellHeight)
    }
}

// MARK: CoverWallSection
private struct CoverWallSection: View {
    private let galleries: [Gallery]
    private let isLoading: Bool
    private let navigateAction: (String) -> Void
    private let reloadAction: () -> Void

    init(
        galleries: [Gallery], isLoading: Bool,
        navigateAction: @escaping (String) -> Void,
        reloadAction: @escaping () -> Void
    ) {
        self.galleries = galleries
        self.isLoading = isLoading
        self.navigateAction = navigateAction
        self.reloadAction = reloadAction
    }

    private var dataSource: [[Gallery]] {
        var galleries = galleries
        if galleries.isEmpty {
            galleries = Gallery.mockGalleries(count: 25)
        }
        if galleries.count % 2 != 0 { galleries = galleries.dropLast() }
        return stride(from: 0, to: galleries.count, by: 2).map { index in
            [galleries[index], galleries[index + 1]]
        }
    }

    var body: some View {
        SubSection(
            title: "Frontpage", tint: .secondary,
            isLoading: isLoading, reloadAction: reloadAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(dataSource, id: \.first) {
                        VerticalCoverStack(galleries: $0, navigateAction: navigateAction)
                    }
                    .withHorizontalSpacing(width: 0)
                }
            }
            .frame(height: Defaults.ImageSize.rowH * 2 + 30)
        }
    }
}

private struct VerticalCoverStack: View {
    private let galleries: [Gallery]
    private let navigateAction: (String) -> Void

    init(galleries: [Gallery], navigateAction: @escaping (String) -> Void) {
        self.galleries = galleries
        self.navigateAction = navigateAction
    }

    private func placeholder() -> some View {
        Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect))
    }
    private func imageContainer(gallery: Gallery) -> some View {
        Button {
            navigateAction(gallery.id)
        } label: {
            KFImage(URL(string: gallery.coverURL)).placeholder(placeholder).defaultModifier().scaledToFill()
                .frame(width: Defaults.ImageSize.rowW, height: Defaults.ImageSize.rowH).cornerRadius(2)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ForEach(galleries, content: imageContainer)
        }
    }
}

// MARK: ToplistsSection
private struct ToplistsSection: View {
    private let galleries: [Int: [Gallery]]
    private let isLoading: Bool
    private let navigateAction: (String) -> Void
    private let reloadAction: () -> Void

    init(
        galleries: [Int: [Gallery]], isLoading: Bool,
        navigateAction: @escaping (String) -> Void,
        reloadAction: @escaping () -> Void
    ) {
        self.galleries = galleries
        self.isLoading = isLoading
        self.navigateAction = navigateAction
        self.reloadAction = reloadAction
    }

    private var dataSource: [Int: [Gallery]] {
        guard !galleries.isEmpty else {
            var dictionary = [Int: [Gallery]]()
            var gallery: Gallery = .empty
            gallery.title = "......"
            gallery.uploader = "......"
            let galleries = Array(repeating: gallery, count: 6)

            ToplistsType.allCases.forEach { type in
                dictionary[type.categoryIndex] = galleries
            }
            return dictionary
        }
        return galleries
    }
    private func galleries(type: ToplistsType, range: ClosedRange<Int>) -> [Gallery] {
        let galleries = dataSource[type.categoryIndex] ?? []
        guard galleries.count > range.upperBound else { return [] }
        return Array(galleries[range])
    }

    var body: some View {
        SubSection(
            title: "Toplists", tint: .secondary,
            isLoading: isLoading, reloadAction: reloadAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(ToplistsType.allCases.reversed(), content: verticalStacks)
                }
            }
        }
    }
    private func verticalStacks(type: ToplistsType) -> some View {
        VStack(alignment: .leading) {
            Text(type.description.localized).font(.subheadline.bold())
            HStack {
                VerticalToplistStack(
                    galleries: galleries(type: type, range: 0...2), startRanking: 1,
                    navigateAction: navigateAction
                )
                if DeviceUtil.isPad {
                    VerticalToplistStack(
                        galleries: galleries(type: type, range: 3...5), startRanking: 4,
                        navigateAction: navigateAction
                    )
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}

private struct VerticalToplistStack: View {
    private let galleries: [Gallery]
    private let startRanking: Int
    private let navigateAction: (String) -> Void

    init(galleries: [Gallery], startRanking: Int, navigateAction: @escaping (String) -> Void) {
        self.galleries = galleries
        self.startRanking = startRanking
        self.navigateAction = navigateAction
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<galleries.count, id: \.self) { index in
                VStack(spacing: 10) {
                    Button {
                        navigateAction(galleries[index].id)
                    } label: {
                        GalleryRankingCell(gallery: galleries[index], ranking: startRanking + index)
                            .tint(.primary).multilineTextAlignment(.leading)
                    }
                    Divider().opacity(index == galleries.count - 1 ? 0 : 1)
                }
            }
        }
        .frame(width: Defaults.FrameSize.rankingCellWidth)
    }
}

// MARK: MiscGridSection
private struct MiscGridSection: View {
    private let navigateAction: (MiscGridType) -> Void

    init(navigateAction: @escaping (MiscGridType) -> Void) {
        self.navigateAction = navigateAction
    }

    var body: some View {
        SubSection(title: "Other", showAll: false) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    let types = MiscGridType.allCases
                    ForEach(types) { type in
                        Button {
                            navigateAction(type)
                        } label: {
                            MiscGridItem(title: type.rawValue.localized, symbol: type.symbol).tint(.primary)
                        }
                        .padding(.trailing, type == types.last ? 0 : 10)
                    }
                    .withHorizontalSpacing()
                }
            }
        }
    }
}

private struct MiscGridItem: View {
    private let title: String
    private let subTitle: String?
    private let symbol: SFSymbol

    init(title: String, subTitle: String? = nil, symbol: SFSymbol) {
        self.title = title
        self.subTitle = subTitle
        self.symbol = symbol
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.title2.bold()).lineLimit(1).frame(minWidth: 100)
                if let subTitle = subTitle {
                    Text(subTitle).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                }
            }
            Image(systemSymbol: symbol).font(.system(size: 50, weight: .light, design: .default))
                .foregroundColor(.secondary).imageScale(.large).offset(x: 20, y: 20)
        }
        .padding(30).cornerRadius(15).background(Color(.systemGray6).cornerRadius(15))
    }
}

// MARK: Definition
enum MiscGridType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case popular = "Popular"
    case watched = "Watched"
    case history = "History"
}

extension MiscGridType {
    var destination: some View {
        EmptyView()
    }
    var symbol: SFSymbol {
        switch self {
        case .popular:
            return .flame
        case .watched:
            return .tagCircle
        case .history:
            return .clockArrowCirclepath
        }
    }
}

enum HomeViewRoute: Equatable {
    case detail(String)
    case misc(MiscGridType)
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            store: Store<HomeState, HomeAction>(
                initialState: HomeState(),
                reducer: homeReducer,
                environment: HomeEnvironment(
                    libraryClient: .live,
                    databaseClient: .live
                )
            )
        )
    }
}
