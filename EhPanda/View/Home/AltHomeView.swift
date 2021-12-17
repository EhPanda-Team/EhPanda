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
        let sortedGalleries = galleries.sorted { lhs, rhs in
            lhs.title.count > rhs.title.count
        }
        var trimmedGalleries = Array(sortedGalleries.prefix(10)).duplicatesRemoved
        if trimmedGalleries.count >= 6 {
            trimmedGalleries = Array(trimmedGalleries.prefix(6))
        }
        self.galleries = trimmedGalleries
        _currentID = State(initialValue: trimmedGalleries[1].gid)
    }

    var body: some View {
        Pager(page: page, data: galleries) { gallery in
            NavigationLink(destination: DetailView(gid: gallery.gid)) {
                GalleryCardCell(gallery: gallery, currentID: $currentID)
                    .accentColor(.primary).multilineTextAlignment(.leading)
            }
        }
        .preferredItemSize(CGSize(width: DeviceUtil.windowW * 0.8, height: 100))
        .interactive(opacity: 0.2).itemSpacing(20).loopPages().pagingPriority(.high)
        .frame(height: 240).onChange(of: page.index) { newValue in
            currentID = galleries[newValue].gid
        }
    }
}

private struct CoverWallSection: View {
    private let galleries: [Gallery]

    init(galleries: [Gallery]) {
        self.galleries = galleries
    }

    private var filteredGalleries: [[Gallery]] {
        var galleries = Array(galleries.prefix(25)).duplicatesRemoved
        if galleries.count % 2 != 0 { galleries = galleries.dropLast() }
        return stride(from: 0, to: galleries.count, by: 2).map { index in
            [galleries[index], galleries[index + 1]]
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Frontpage").font(.title3.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(filteredGalleries, id: \.description, content: VerticalCoverStack.init)
                        .withHorizontalSpacing(width: 0)
                }
            }
            .frame(height: Defaults.ImageSize.rowH * 2 + 20)
        }
        .padding(.vertical)
    }
}

private struct VerticalCoverStack: View {
    private let galleries: [Gallery]

    init(galleries: [Gallery]) {
        self.galleries = galleries
    }

    private func placeholder() -> some View {
        Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect))
    }
    private func imageContainer(gallery: Gallery) -> some View {
        NavigationLink(destination: DetailView(gid: gallery.gid)) {
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
                                VerticalToplistStack(
                                    galleries: galleries(type: type, range: 0...2), startRanking: 1
                                )
                                if DeviceUtil.isPad {
                                    VerticalToplistStack(
                                        galleries: galleries(type: type, range: 3...5), startRanking: 4
                                    )
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
                NavigationLink(destination: DetailView(gid: galleries[index].gid)) {
                    GalleryRankingCell(gallery: galleries[index], ranking: startRanking + index)
                        .accentColor(.primary).multilineTextAlignment(.leading)
                        .frame(width: DeviceUtil.windowW * 0.8)
                }
            }
        }
    }
}

private extension Array where Element == Gallery {
    var duplicatesRemoved: [Element] {
        var result = [Element]()
        for value in self {
            guard result.filter({
                $0.trimmedTitle == value.trimmedTitle
            }).isEmpty else { continue }
            result.append(value)
        }
        return result
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(Store.preview)
    }
}
