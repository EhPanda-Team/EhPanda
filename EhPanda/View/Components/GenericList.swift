//
//  GenericList.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/25.
//

import SwiftUI
import WaterfallGrid

struct GenericList: View {
    private let items: [Gallery]
    private let setting: Setting
    private let pageNumber: PageNumber?
    private let loadingFlag: Bool
    private let loadError: AppError?
    private let moreLoadingFlag: Bool
    private let moreLoadFailedFlag: Bool
    private let fetchAction: (() -> Void)?
    private let loadMoreAction: (() -> Void)?
    private let translateAction: ((String) -> String)?

    init(
        items: [Gallery], setting: Setting, pageNumber: PageNumber?,
        loadingFlag: Bool, loadError: AppError?, moreLoadingFlag: Bool,
        moreLoadFailedFlag: Bool, fetchAction: (() -> Void)? = nil,
        loadMoreAction: (() -> Void)? = nil,
        translateAction: ((String) -> String)? = nil
    ) {
        self.items = items
        self.setting = setting
        self.pageNumber = pageNumber
        self.loadingFlag = loadingFlag
        self.loadError = loadError
        self.moreLoadingFlag = moreLoadingFlag
        self.moreLoadFailedFlag = moreLoadFailedFlag
        self.fetchAction = fetchAction
        self.loadMoreAction = loadMoreAction
        self.translateAction = translateAction
    }

    var body: some View {
        if loadingFlag {
            LoadingView()
        } else if let error = loadError {
            ErrorView(error: error, retryAction: fetchAction)
        } else {
            VStack(spacing: 0) {
                switch setting.listMode {
                case .detail:
                    DetailList(
                        items: items, setting: setting, pageNumber: pageNumber,
                        moreLoadingFlag: moreLoadingFlag, moreLoadFailedFlag: moreLoadFailedFlag,
                        loadMoreAction: loadMoreAction, translateAction: translateAction
                    )
                case .thumbnail:
                    WaterfallList(
                        items: items, setting: setting, pageNumber: pageNumber,
                        moreLoadingFlag: moreLoadingFlag, moreLoadFailedFlag: moreLoadFailedFlag,
                        loadMoreAction: loadMoreAction, translateAction: translateAction
                    )
                }
            }
            .transition(AppUtil.opacityTransition)
            .refreshable { fetchAction?() }
        }
    }
}

// MARK: DetailList
private struct DetailList: View {
    private let items: [Gallery]
    private let setting: Setting
    private let pageNumber: PageNumber?
    private let moreLoadingFlag: Bool
    private let moreLoadFailedFlag: Bool
    private let loadMoreAction: (() -> Void)?
    private let translateAction: ((String) -> String)?

    init(
        items: [Gallery], setting: Setting, pageNumber: PageNumber?,
        moreLoadingFlag: Bool, moreLoadFailedFlag: Bool,
        loadMoreAction: (() -> Void)?,
        translateAction: ((String) -> String)? = nil
    ) {
        self.items = items
        self.setting = setting
        self.pageNumber = pageNumber
        self.moreLoadingFlag = moreLoadingFlag
        self.moreLoadFailedFlag = moreLoadFailedFlag
        self.loadMoreAction = loadMoreAction
        self.translateAction = translateAction
    }

    private var inValidRange: Bool {
        guard let pageNumber = pageNumber else { return false }
        return pageNumber.current + 1 <= pageNumber.maximum
    }

    var body: some View {
        List(items) { item in
            GalleryDetailCell(gallery: item, setting: setting, translateAction: translateAction)
                .background { NavigationLink(destination: DetailView(gid: item.gid)) {}.opacity(0) }
                .onAppear {
                    guard item == items.last else { return }
                    loadMoreAction?()
                }
            if (moreLoadingFlag || moreLoadFailedFlag) && item == items.last && inValidRange {
                LoadMoreFooter(
                    moreLoadingFlag: moreLoadingFlag, moreLoadFailedFlag: moreLoadFailedFlag,
                    retryAction: loadMoreAction
                )
            }
        }
    }
}

// MARK: WaterfallList
private struct WaterfallList: View {
    @State var gid: String = ""
    @State var isNavLinkActive = false

    private let items: [Gallery]
    private let setting: Setting
    private let pageNumber: PageNumber?
    private let moreLoadingFlag: Bool
    private let moreLoadFailedFlag: Bool
    private let loadMoreAction: (() -> Void)?
    private let translateAction: ((String) -> String)?

    private var columnsInPortrait: Int {
        DeviceUtil.isPadWidth ? 4 : 2
    }
    private var columnsInLandscape: Int {
        DeviceUtil.isPadWidth ? 5 : 2
    }
    private var inValidRange: Bool {
        guard let pageNumber = pageNumber else { return false }
        return pageNumber.current + 1 <= pageNumber.maximum
    }

    init(
        items: [Gallery], setting: Setting, pageNumber: PageNumber?,
        moreLoadingFlag: Bool, moreLoadFailedFlag: Bool,
        loadMoreAction: (() -> Void)?,
        translateAction: ((String) -> String)? = nil
    ) {
        self.items = items
        self.setting = setting
        self.pageNumber = pageNumber
        self.moreLoadingFlag = moreLoadingFlag
        self.moreLoadFailedFlag = moreLoadFailedFlag
        self.loadMoreAction = loadMoreAction
        self.translateAction = translateAction
    }

    var body: some View {
        List {
            WaterfallGrid(items) { item in
                GalleryThumbnailCell(gallery: item, setting: setting, translateAction: translateAction)
                    .onTapGesture {
                        gid = item.gid
                        isNavLinkActive.toggle()
                    }
            }
            .gridStyle(
                columnsInPortrait: columnsInPortrait, columnsInLandscape: columnsInLandscape,
                spacing: 15, animation: nil
            )
            if !moreLoadingFlag && !moreLoadFailedFlag && inValidRange {
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
            }
            if moreLoadingFlag || moreLoadFailedFlag {
                LoadMoreFooter(
                    moreLoadingFlag: moreLoadingFlag, moreLoadFailedFlag: moreLoadFailedFlag,
                    retryAction: loadMoreAction
                )
            }
        }
        .background { NavigationLink(destination: DetailView(gid: gid), isActive: $isNavLinkActive) {}.opacity(0) }
        .listStyle(.plain)
    }
}
