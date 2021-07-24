//
//  GenericList.swift
//  GenericList
//
//  Created by 荒木辰造 on 2021/07/25.
//

import SwiftUI

struct GenericList: View {
    private let items: [Manga]?
    private let setting: Setting
    private let loadingFlag: Bool
    private let notFoundFlag: Bool
    private let loadFailedFlag: Bool
    private let moreLoadingFlag: Bool
    private let moreLoadFailedFlag: Bool
    private let fetchAction: (() -> Void)?
    private let loadMoreAction: (() -> Void)?

    init(
        items: [Manga]?,
        setting: Setting,
        loadingFlag: Bool,
        notFoundFlag: Bool,
        loadFailedFlag: Bool,
        moreLoadingFlag: Bool,
        moreLoadFailedFlag: Bool,
        fetchAction: (() -> Void)? = nil,
        loadMoreAction: (() -> Void)? = nil
    ) {
        self.items = items
        self.setting = setting
        self.loadingFlag = loadingFlag
        self.notFoundFlag = notFoundFlag
        self.loadFailedFlag = loadFailedFlag
        self.moreLoadingFlag = moreLoadingFlag
        self.moreLoadFailedFlag = moreLoadFailedFlag
        self.fetchAction = fetchAction
        self.loadMoreAction = loadMoreAction
    }

    var body: some View {
        if loadingFlag {
            LoadingView()
        } else if loadFailedFlag {
            NetworkErrorView(retryAction: fetchAction)
        } else if notFoundFlag {
            NotFoundView(retryAction: fetchAction)
        } else {
            List {
                ForEach(items ?? []) { item in
                    ZStack {
                        NavigationLink(
                            destination: DetailView(
                                gid: item.gid
                            )
                        ) {}
                        .opacity(0)
                        MangaSummaryRow(
                            manga: item,
                            setting: setting
                        )
                    }
                    .onAppear {
                        onRowAppear(item: item)
                    }
                }
                .transition(opacityTransition)
                if moreLoadingFlag || moreLoadFailedFlag {
                    LoadMoreFooter(
                        moreLoadingFlag: moreLoadingFlag,
                        moreLoadFailedFlag: moreLoadFailedFlag,
                        retryAction: loadMoreAction
                    )
                }
            }
            .transition(opacityTransition)
            .refreshable(action: onUpdate)
        }
    }

    private func onUpdate() {
        fetchAction?()
    }
    private func onRowAppear(item: Manga) {
        if item == items?.last {
            loadMoreAction?()
        }
    }
}
