//
//  HomeView+Sections.swift
//  EhPanda
//

import SwiftUI
import Kingfisher
import SwiftUIPager
import SFSafeSymbols

// MARK: CardSlideSection
struct CardSlideSection: View, Equatable {
    @StateObject private var page: Page = .withIndex(1)
    @Binding private var pageIndex: Int

    private let galleries: [Gallery]
    private let currentID: String
    private let colors: [Color]
    private let downloadBadges: [String: DownloadBadge]
    private let navigateAction: (String) -> Void
    private let webImageSuccessAction: (String, RetrieveImageResult) -> Void

    init(
        galleries: [Gallery], pageIndex: Binding<Int>, currentID: String,
        colors: [Color], downloadBadges: [String: DownloadBadge],
        navigateAction: @escaping (String) -> Void,
        webImageSuccessAction: @escaping (String, RetrieveImageResult) -> Void
    ) {
        self.galleries = galleries
        _pageIndex = pageIndex
        self.currentID = currentID
        self.colors = colors
        self.downloadBadges = downloadBadges
        self.navigateAction = navigateAction
        self.webImageSuccessAction = webImageSuccessAction
    }

    static func == (lhs: CardSlideSection, rhs: CardSlideSection) -> Bool {
        lhs.galleries == rhs.galleries
            && lhs.currentID == rhs.currentID
            && lhs.colors == rhs.colors
            && lhs.downloadBadges == rhs.downloadBadges
    }

    var body: some View {
        Pager(page: page, data: galleries) { gallery in
            Button {
                navigateAction(gallery.id)
            } label: {
                GalleryCardCell(
                    gallery: gallery,
                    currentID: currentID,
                    colors: colors,
                    webImageSuccessAction: {
                        webImageSuccessAction(gallery.gid, $0)
                    },
                    downloadBadge: downloadBadges[gallery.gid] ?? .none
                )
                .tint(.primary)
                .multilineTextAlignment(.leading)
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
struct CoverWallSection: View {
    private let galleries: [Gallery]
    private let isLoading: Bool
    private let downloadBadges: [String: DownloadBadge]
    private let navigateAction: (String) -> Void
    private let showAllAction: () -> Void
    private let reloadAction: () -> Void

    init(
        galleries: [Gallery], isLoading: Bool, downloadBadges: [String: DownloadBadge],
        navigateAction: @escaping (String) -> Void,
        showAllAction: @escaping () -> Void,
        reloadAction: @escaping () -> Void
    ) {
        self.galleries = galleries
        self.isLoading = isLoading
        self.downloadBadges = downloadBadges
        self.navigateAction = navigateAction
        self.showAllAction = showAllAction
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
            title: L10n.Localizable.HomeView.Section.Title.frontpage,
            tint: .secondary, isLoading: isLoading,
            reloadAction: reloadAction,
            showAllAction: showAllAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(dataSource, id: \.first) {
                        VerticalCoverStack(
                            galleries: $0,
                            downloadBadges: downloadBadges,
                            navigateAction: navigateAction
                        )
                    }
                    .withHorizontalSpacing(width: 0)
                }
            }
            .frame(height: Defaults.ImageSize.rowH * 2 + 30)
        }
    }
}

struct VerticalCoverStack: View {
    private let galleries: [Gallery]
    private let downloadBadges: [String: DownloadBadge]
    private let navigateAction: (String) -> Void

    init(
        galleries: [Gallery],
        downloadBadges: [String: DownloadBadge],
        navigateAction: @escaping (String) -> Void
    ) {
        self.galleries = galleries
        self.downloadBadges = downloadBadges
        self.navigateAction = navigateAction
    }

    private func placeholder() -> some View {
        Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect))
    }
    private func imageContainer(gallery: Gallery) -> some View {
        Button {
            navigateAction(gallery.id)
        } label: {
            KFImage(gallery.coverURL)
                .placeholder(placeholder)
                .defaultModifier()
                .scaledToFill()
                .frame(width: Defaults.ImageSize.rowW, height: Defaults.ImageSize.rowH).cornerRadius(2)
                .overlay(alignment: .topTrailing) {
                    DownloadBadgeLabel(
                        badge: downloadBadges[gallery.gid] ?? .none,
                        compact: true
                    )
                    .padding(6)
                }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ForEach(galleries, content: imageContainer)
        }
    }
}

// MARK: ToplistsSection
struct ToplistsSection: View {
    private let galleries: [Int: [Gallery]]
    private let isLoading: Bool
    private let downloadBadges: [String: DownloadBadge]
    private let navigateAction: (String) -> Void
    private let showAllAction: () -> Void
    private let reloadAction: () -> Void

    init(
        galleries: [Int: [Gallery]], isLoading: Bool, downloadBadges: [String: DownloadBadge],
        navigateAction: @escaping (String) -> Void,
        showAllAction: @escaping () -> Void,
        reloadAction: @escaping () -> Void
    ) {
        self.galleries = galleries
        self.isLoading = isLoading
        self.downloadBadges = downloadBadges
        self.navigateAction = navigateAction
        self.showAllAction = showAllAction
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
            title: L10n.Localizable.HomeView.Section.Title.toplists,
            tint: .secondary, isLoading: isLoading,
            reloadAction: reloadAction,
            showAllAction: showAllAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(ToplistsType.allCases, content: verticalStacks)
                }
            }
        }
    }
    private func verticalStacks(type: ToplistsType) -> some View {
        VStack(alignment: .leading) {
            Text(type.value).font(.subheadline.bold())
            HStack {
                VerticalToplistsStack(
                    galleries: galleries(type: type, range: 0...2), startRanking: 1,
                    downloadBadges: downloadBadges,
                    navigateAction: navigateAction
                )
                if DeviceUtil.isPad {
                    VerticalToplistsStack(
                        galleries: galleries(type: type, range: 3...5), startRanking: 4,
                        downloadBadges: downloadBadges,
                        navigateAction: navigateAction
                    )
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}

struct VerticalToplistsStack: View {
    private let galleries: [Gallery]
    private let startRanking: Int
    private let downloadBadges: [String: DownloadBadge]
    private let navigateAction: (String) -> Void

    init(
        galleries: [Gallery],
        startRanking: Int,
        downloadBadges: [String: DownloadBadge],
        navigateAction: @escaping (String) -> Void
    ) {
        self.galleries = galleries
        self.startRanking = startRanking
        self.downloadBadges = downloadBadges
        self.navigateAction = navigateAction
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<galleries.count, id: \.self) { index in
                VStack(spacing: 10) {
                    Button {
                        navigateAction(galleries[index].id)
                    } label: {
                        GalleryRankingCell(
                            gallery: galleries[index],
                            ranking: startRanking + index,
                            downloadBadge: downloadBadges[galleries[index].gid] ?? .none
                        )
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
struct MiscGridSection: View {
    private let navigateAction: (HomeMiscGridType) -> Void

    init(navigateAction: @escaping (HomeMiscGridType) -> Void) {
        self.navigateAction = navigateAction
    }

    var body: some View {
        SubSection(title: L10n.Localizable.HomeView.Section.Title.other, showAll: false) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    let types = HomeMiscGridType.allCases
                    ForEach(types) { type in
                        Button {
                            navigateAction(type)
                        } label: {
                            MiscGridItem(title: type.title, symbol: type.symbol).tint(.primary)
                        }
                        .padding(.trailing, type == types.last ? 0 : 10)
                    }
                    .withHorizontalSpacing()
                }
            }
        }
    }
}

struct MiscGridItem: View {
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
