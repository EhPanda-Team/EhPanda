//
//  GenericList.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/25.
//

import SwiftUI
import WaterfallGrid
import ComposableArchitecture

struct GenericList: View {
    private let galleries: [Gallery]
    private let setting: Setting
    private let pageNumber: PageNumber?
    private let loadingState: LoadingState
    private let footerLoadingState: LoadingState
    private let fetchAction: (() -> Void)?
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((String) -> Void)?
    private let translateAction: ((String) -> String)?

    init(
        galleries: [Gallery], setting: Setting, pageNumber: PageNumber?,
        loadingState: LoadingState, footerLoadingState: LoadingState,
        fetchAction: (() -> Void)? = nil,
        fetchMoreAction: (() -> Void)? = nil,
        navigateAction: ((String) -> Void)? = nil,
        translateAction: ((String) -> String)? = nil
    ) {
        self.galleries = galleries
        self.setting = setting
        self.pageNumber = pageNumber
        self.loadingState = loadingState
        self.footerLoadingState = footerLoadingState
        self.fetchAction = fetchAction
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.translateAction = translateAction
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                switch setting.listDisplayMode {
                case .detail:
                    DetailList(
                        galleries: galleries, setting: setting, pageNumber: pageNumber,
                        footerLoadingState: footerLoadingState, fetchMoreAction: fetchMoreAction,
                        navigateAction: navigateAction, translateAction: translateAction
                    )
                case .thumbnail:
                    WaterfallList(
                        galleries: galleries, setting: setting, pageNumber: pageNumber,
                        footerLoadingState: footerLoadingState, fetchMoreAction: fetchMoreAction,
                        navigateAction: navigateAction, translateAction: translateAction
                    )
                }
            }
            .opacity(loadingState == .idle ? 1 : 0).zIndex(2)
            LoadingView().opacity(loadingState == .loading ? 1 : 0).zIndex(0)
            let error = (/LoadingState.failed).extract(from: loadingState)
            ErrorView(error: error ?? .unknown, action: fetchAction)
                .opacity([.idle, .loading].contains(loadingState) ? 0 : 1).zIndex(1)
        }
        .animation(.default, value: loadingState)
        .animation(.default, value: galleries)
        .refreshable { fetchAction?() }
    }
}

// MARK: DetailList
private struct DetailList: View {
    private let galleries: [Gallery]
    private let setting: Setting
    private let pageNumber: PageNumber?
    private let footerLoadingState: LoadingState
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((String) -> Void)?
    private let translateAction: ((String) -> String)?

    init(
        galleries: [Gallery], setting: Setting, pageNumber: PageNumber?,
        footerLoadingState: LoadingState,
        fetchMoreAction: (() -> Void)?,
        navigateAction: ((String) -> Void)? = nil,
        translateAction: ((String) -> String)? = nil
    ) {
        self.galleries = galleries
        self.setting = setting
        self.pageNumber = pageNumber
        self.footerLoadingState = footerLoadingState
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
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
            Button {
                navigateAction?(gallery.id)
            } label: {
                GalleryDetailCell(gallery: gallery, setting: setting, translateAction: translateAction)
            }
            .foregroundColor(.primary)
            .onAppear {
                if gallery == galleries.last {
                    fetchMoreAction?()
                }
            }
            if shouldShowFooter(gallery: gallery) {
                FetchMoreFooter(loadingState: footerLoadingState, retryAction: fetchMoreAction)
            }
        }
    }
}

// MARK: WaterfallList
private struct WaterfallList: View {
    private let galleries: [Gallery]
    private let setting: Setting
    private let pageNumber: PageNumber?
    private let footerLoadingState: LoadingState
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((String) -> Void)?
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
        fetchMoreAction: (() -> Void)?,
        navigateAction: ((String) -> Void)? = nil,
        translateAction: ((String) -> String)? = nil
    ) {
        self.galleries = galleries
        self.setting = setting
        self.pageNumber = pageNumber
        self.footerLoadingState = footerLoadingState
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.translateAction = translateAction
    }

    var body: some View {
        List {
            WaterfallGrid(galleries) { gallery in
                Button {
                    navigateAction?(gallery.id)
                } label: {
                    GalleryThumbnailCell(gallery: gallery, setting: setting, translateAction: translateAction)
                }
                .foregroundColor(.primary)
            }
            .gridStyle(
                columnsInPortrait: columnsInPortrait, columnsInLandscape: columnsInLandscape,
                spacing: 15, animation: nil
            )
            if !shouldShowFooter {
                Button {
                    fetchMoreAction?()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemSymbol: .chevronDown)
                        Spacer()
                    }
                }
                .foregroundStyle(.tint)
            } else {
                FetchMoreFooter(
                    loadingState: footerLoadingState,
                    retryAction: fetchMoreAction
                )
            }
        }
        .listStyle(.plain)
    }
}
