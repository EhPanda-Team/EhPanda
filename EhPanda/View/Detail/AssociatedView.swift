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
                            MangaSummaryRow(manga: manga)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onAppear(perform: {
                            onRowAppear(manga)
                        })
                    }
                    .transition(animatedTransition)
                    HStack(alignment: .center) {
                        Spacer()
                        ProgressView()
                        .opacity(moreLoadingFlag ? 1 : 0)
                        NetworkErrorCompactView(
                            retryAction: fetchMoreAssociatedItems
                        )
                        .opacity(moreLoadFailedFlag ? 1 : 0)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .frame(height: 30)
                }
                .refreshable(action: fetchAssociatedItems)
                .transition(animatedTransition)
                .listStyle(.plain)
            } else if loadingFlag {
                LoadingView()
            } else if notFoundFlag {
                NotFoundView(retryAction: retryAction)
            } else {
                NetworkErrorView(retryAction: retryAction)
            }
        }
        .onAppear(perform: onAppear)
        .navigationBarTitle(title)
    }
}

private extension AssociatedView {
    var loadingFlag: Bool {
        detailInfo.associatedItemsLoading
    }
    var loadFailedFlag: Bool {
        detailInfo.associatedItemsLoadFailed
    }
    var notFoundFlag: Bool {
        detailInfo.associatedItemsNotFound
    }
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

    func onAppear() {
        fetchAssociatedItemsIfNeeded()
    }
    func onRowAppear(_ item: Manga) {
        if item == assciatedItem.mangas.last {
            fetchMoreAssociatedItems()
        }
    }

    func retryAction() {
        fetchAssociatedItems()
    }

    func fetchAssociatedItems() {
        store.dispatch(.fetchAssociatedItems(depth: depth, keyword: keyword))
    }
    func fetchMoreAssociatedItems() {
        store.dispatch(.fetchMoreAssociatedItems(depth: depth, keyword: keyword))
    }

    func fetchAssociatedItemsIfNeeded() {
        if assciatedItem.keyword != keyword {
            fetchAssociatedItems()
        }
    }
}
