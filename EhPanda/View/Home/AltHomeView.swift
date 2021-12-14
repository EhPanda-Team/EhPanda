//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/13.
//

import SwiftUI
import Kingfisher
import SwiftUIPager

struct HomeView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationView {
            ZStack {
                if !homeInfo.popularItems.isEmpty {
                    ScrollView(showsIndicators: false) {
                        VStack {
                            CardSlideSection(galleries: homeInfo.popularItems)
                            Divider()
                            CoverWallSection(galleries: homeInfo.frontpageItems)
                            Divider()
                            ToplistsSection(galleries: homeInfo.toplistsItems)
                            Spacer()
                        }
                    }
                    .transition(AppUtil.opacityTransition)
                } else if homeInfo.popularLoading {
                    LoadingView()
                } else if let error = homeInfo.popularLoadError {
                    ErrorView(error: error, retryAction: fetchPopularItems)
                }
            }
            .onAppear(perform: tryFetchPopularItems)
            .navigationTitle("Home")
        }
    }
}

private extension HomeView {
    func fetchPopularItems() {
        store.dispatch(.fetchPopularItems)
        store.dispatch(.fetchFrontpageItems())
        store.dispatch(.fetchToplistsItems())
        store.dispatch(.setToplistsType(.pastYear))
        store.dispatch(.fetchToplistsItems())
        store.dispatch(.setToplistsType(.pastMonth))
        store.dispatch(.fetchToplistsItems())
        store.dispatch(.setToplistsType(.yesterday))
        store.dispatch(.fetchToplistsItems())
    }
    func tryFetchPopularItems() {
        guard homeInfo.popularItems.isEmpty else { return }
        fetchPopularItems()
    }
}

private struct CardSlideSection: View {
    @State private var currentID: String
    @StateObject private var page: Page = .withIndex(1)

    private let galleries: [Gallery]

    init(galleries: [Gallery]) {
        self.galleries = Array(galleries.sorted { lhs, rhs in
            lhs.title.count > rhs.title.count
        }
        .prefix(6))
        _currentID = State(initialValue: self.galleries[1].gid)
    }

    var body: some View {
        Pager(page: page, data: galleries) { gallery in
            GalleryCardCell(gallery: gallery, currentID: $currentID)
        }
        .preferredItemSize(CGSize(width: DeviceUtil.windowW * 0.8, height: 100))
        .interactive(opacity: 0.2).itemSpacing(20).loopPages().frame(height: 240)
        .onChange(of: page.index) { newValue in
            currentID = galleries[newValue].gid
        }
    }
}

private struct CoverWallSection: View {
    private let galleries: [Gallery]

    init(galleries: [Gallery]) {
        self.galleries = galleries
    }

    private var coverURLs: [[String]] {
        let urls = galleries.map(\.coverURL).prefix(20)
        return stride(from: 0, to: urls.count, by: 2).map { index in
            [urls[index], urls[index + 1]]
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Frontpage").font(.title3.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(coverURLs, id: \.hashValue, content: VerticalCoverStack.init)
                        .withHorizontalSpacing(width: 0)
                }
            }
            .frame(height: Defaults.ImageSize.rowH * 2 + 20)
        }
        .padding(.vertical)
    }
}

private struct VerticalCoverStack: View {
    private let coverURLs: [String]

    init(coverURLs: [String]) {
        self.coverURLs = coverURLs
    }

    private func placeholder() -> some View {
        Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect))
    }
    private func imageContainer(url: String) -> some View {
        KFImage(URL(string: url)).placeholder(placeholder).defaultModifier().scaledToFill()
            .frame(width: Defaults.ImageSize.rowW, height: Defaults.ImageSize.rowH).cornerRadius(2)
    }

    var body: some View {
        VStack(spacing: 20) {
            ForEach(coverURLs, id: \.self, content: imageContainer)
        }
    }
}

private struct ToplistsSection: View {
    private let galleries: [Int: [Gallery]]

    init(galleries: [Int: [Gallery]]) {
        self.galleries = galleries
    }

    private func galleries(type: ToplistsType, range: ClosedRange<Int>) -> [Gallery] {
        let galleries = galleries[type.rawValue] ?? []
        guard galleries.count > range.upperBound else { return [] }
        return Array(galleries[range])
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Toplists").font(.title3.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(ToplistsType.allCases.reversed()) { type in
                        VStack(alignment: .leading) {
                            Text(type.description.localized).font(.subheadline.bold())
                            HStack {
                                VerticalToplistStack(galleries: galleries(type: type, range: 0...2), startRanking: 1)
                                if DeviceUtil.isPad {
                                    VerticalToplistStack(galleries: galleries(type: type, range: 3...5), startRanking: 4)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}

private struct VerticalToplistStack: View {
    private let galleries: [Gallery]
    private let startRanking: Int

    init(galleries: [Gallery], startRanking: Int) {
        self.galleries = galleries
        self.startRanking = startRanking
    }

    var body: some View {
        VStack {
            ForEach(0..<galleries.count, id: \.self) { index in
                GalleryRankingCell(gallery: galleries[index], ranking: startRanking + index)
                    .frame(width: DeviceUtil.windowW * 0.8)
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(Store.preview)
    }
}
