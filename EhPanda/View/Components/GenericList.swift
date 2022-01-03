//
//  GenericList.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/25.
//

import SwiftUI
import WaterfallGrid

struct GenericList: View {
    private let galleries: [Gallery]
    private let setting: Setting
    private let pageNumber: PageNumber?
    private let loadingState: LoadingState
    private let footerLoadingState: LoadingState
    private let fetchAction: (() -> Void)?
    private let loadMoreAction: (() -> Void)?
    private let translateAction: ((String) -> String)?

    init(
        galleries: [Gallery], setting: Setting, pageNumber: PageNumber?,
        loadingState: LoadingState, footerLoadingState: LoadingState,
        fetchAction: (() -> Void)? = nil,
        loadMoreAction: (() -> Void)? = nil,
        translateAction: ((String) -> String)? = nil
    ) {
        self.galleries = galleries
        self.setting = setting
        self.pageNumber = pageNumber
        self.loadingState = loadingState
        self.footerLoadingState = footerLoadingState
        self.fetchAction = fetchAction
        self.loadMoreAction = loadMoreAction
        self.translateAction = translateAction
    }

    var body: some View {
        if loadingState == .loading {
            LoadingView()
        } else if case .failed(let error) = loadingState {
            ErrorView(error: error, retryAction: fetchAction)
        } else {
            VStack(spacing: 0) {
                switch setting.listMode {
                case .detail:
                    DetailList(
                        galleries: galleries, setting: setting, pageNumber: pageNumber,
                        footerLoadingState: footerLoadingState,
                        loadMoreAction: loadMoreAction, translateAction: translateAction
                    )
                case .thumbnail:
                    WaterfallList(
                        galleries: galleries, setting: setting, pageNumber: pageNumber,
                        footerLoadingState: footerLoadingState,
                        loadMoreAction: loadMoreAction, translateAction: translateAction
                    )
                }
            }
            .transition(AppUtil.opacityTransition)
            .refreshable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    fetchAction?()
                }
            }
        }
    }
}

// MARK: DetailList
private struct DetailList: View {
    private let galleries: [Gallery]
    private let setting: Setting
    private let pageNumber: PageNumber?
    private let footerLoadingState: LoadingState
    private let loadMoreAction: (() -> Void)?
    private let translateAction: ((String) -> String)?

    init(
        galleries: [Gallery], setting: Setting, pageNumber: PageNumber?,
        footerLoadingState: LoadingState,
        loadMoreAction: (() -> Void)?,
        translateAction: ((String) -> String)? = nil
    ) {
        self.galleries = galleries
        self.setting = setting
        self.pageNumber = pageNumber
        self.footerLoadingState = footerLoadingState
        self.loadMoreAction = loadMoreAction
        self.translateAction = translateAction
    }

    private func shouldShowFooter(gallery: Gallery) -> Bool {
        guard let pageNumber = pageNumber else { return false }

        let isLastGallery = gallery == galleries.last
        let isLoadingStateIdle = footerLoadingState == .idle
        let isPageNumberValid = pageNumber.current + 1 <= pageNumber.maximum

        return isLastGallery && !isLoadingStateIdle && isPageNumberValid
    }

    var body: some View {
        List(galleries) { gallery in
            GalleryDetailCell(gallery: gallery, setting: setting, translateAction: translateAction)
                .background { NavigationLink(destination: DetailView(gid: gallery.gid)) {}.opacity(0) }
                .onAppear {
                    if gallery == galleries.last {
                        loadMoreAction?()
                    }
                }
            if shouldShowFooter(gallery: gallery) {
                LoadMoreFooter(loadingState: footerLoadingState, retryAction: loadMoreAction)
            }
        }
    }
}

// MARK: WaterfallList
private struct WaterfallList: View {
    @State var gid: String = ""
    @State var isNavLinkActive = false

    private let galleries: [Gallery]
    private let setting: Setting
    private let pageNumber: PageNumber?
    private let footerLoadingState: LoadingState
    private let loadMoreAction: (() -> Void)?
    private let translateAction: ((String) -> String)?

    private var columnsInPortrait: Int {
        DeviceUtil.isPadWidth ? 4 : 2
    }
    private var columnsInLandscape: Int {
        DeviceUtil.isPadWidth ? 5 : 2
    }

    private var shouldShowFooter: Bool {
        guard let pageNumber = pageNumber else { return false }

        let isPageNumberValid = pageNumber.current + 1 <= pageNumber.maximum
        let isLoadingStateIdle = footerLoadingState == .idle

        return !isLoadingStateIdle && isPageNumberValid
    }

    init(
        galleries: [Gallery], setting: Setting, pageNumber: PageNumber?,
        footerLoadingState: LoadingState,
        loadMoreAction: (() -> Void)?,
        translateAction: ((String) -> String)? = nil
    ) {
        self.galleries = galleries
        self.setting = setting
        self.pageNumber = pageNumber
        self.footerLoadingState = footerLoadingState
        self.loadMoreAction = loadMoreAction
        self.translateAction = translateAction
    }

    var body: some View {
        List {
            WaterfallGrid(galleries) { gallery in
                GalleryThumbnailCell(gallery: gallery, setting: setting, translateAction: translateAction)
                    .onTapGesture {
                        gid = gallery.gid
                        isNavLinkActive.toggle()
                    }
            }
            .gridStyle(
                columnsInPortrait: columnsInPortrait, columnsInLandscape: columnsInLandscape,
                spacing: 15, animation: nil
            )
            if !shouldShowFooter {
                Button {
                    loadMoreAction?()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.down")
                        Spacer()
                    }
                }
                .foregroundStyle(.tint)
            } else {
                LoadMoreFooter(
                    loadingState: footerLoadingState,
                    retryAction: loadMoreAction
                )
            }
        }
        .background { NavigationLink(destination: DetailView(gid: gid), isActive: $isNavLinkActive) {}.opacity(0) }
        .listStyle(.plain)
    }
}
