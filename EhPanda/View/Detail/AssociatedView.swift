//
//  AssociatedView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/15.
//

import SwiftUI

struct AssociatedView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    private let depth: Int
    private let keyword: AssociatedKeyword

    init(depth: Int, keyword: AssociatedKeyword) {
        self.depth = depth
        self.keyword = keyword
    }

    var body: some View {
        Group {
            if !assciatedItem.mangas.isEmpty {
                List {
                    ForEach(assciatedItem.mangas) { manga in
                        ZStack {
                            NavigationLink(
                                destination: DetailView(
                                    gid: manga.gid,
                                    depth: depth + 1
                                )
                            ) {}
                            .opacity(0)
                            MangaSummaryRow(
                                manga: manga,
                                setting: setting
                            )
                        }
                        .onAppear {
                            onRowAppear(item: manga)
                        }
                    }
                    .transition(opacityTransition)
                    if moreLoadingFlag || moreLoadFailedFlag {
                        LoadMoreFooter(
                            moreLoadingFlag: moreLoadingFlag,
                            moreLoadFailedFlag: moreLoadFailedFlag,
                            retryAction: fetchMoreAssociatedItems
                        )
                    }
                }
                .refreshable(action: fetchAssociatedItems)
                .transition(opacityTransition)
            } else if detailInfo.associatedItemsLoading {
                LoadingView()
            } else if detailInfo.associatedItemsNotFound {
                NotFoundView(retryAction: fetchAssociatedItems)
            } else {
                NetworkErrorView(retryAction: fetchAssociatedItems)
            }
        }
        .task(fetchAssociatedItemsIfNeeded)
        .navigationBarTitle(title)
    }
}

private extension AssociatedView {
    var moreLoadingFlag: Bool {
        detailInfo.moreAssociatedItemsLoading
    }
    var moreLoadFailedFlag: Bool {
        detailInfo.moreAssociatedItemsLoadFailed
    }
    var assciatedItem: AssociatedItem {
        assciatedItems.count >= depth + 1
            ? assciatedItems[depth] : AssociatedItem(mangas: [])
    }
    var title: String {
        if let title = keyword.title {
            return title
        } else {
            var cat: String?
            var content: String?

            if let tagCategory = TagCategory(
                rawValue: keyword.category ?? ""
            ) {
                cat = tagCategory.rawValue.localized()
            }
            if let language = Language(
                rawValue: keyword.content?
                    .capitalizingFirstLetter() ?? ""
            ) {
                content = language.rawValue.localized()
            }
            if cat == nil {
                cat = keyword.category
            }
            if content == nil {
                content = keyword.content
            }

            return "\(cat ?? ""): \"\(content ?? "")\""
        }
    }

    func onRowAppear(item: Manga) {
        if item == assciatedItem.mangas.last {
            fetchMoreAssociatedItems()
        }
    }

    func fetchAssociatedItems() {
        store.dispatch(.fetchAssociatedItems(depth: depth, keyword: keyword))
    }
    func fetchMoreAssociatedItems() {
        store.dispatch(.fetchMoreAssociatedItems(depth: depth, keyword: keyword))
    }

    func fetchAssociatedItemsIfNeeded() {
        DispatchQueue.main.async {
            if assciatedItem.keyword != keyword {
                fetchAssociatedItems()
            }
        }
    }
}
