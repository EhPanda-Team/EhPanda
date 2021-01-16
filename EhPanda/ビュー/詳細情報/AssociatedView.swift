//
//  AssociatedView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/15.
//

import SwiftUI

struct AssociatedView: View {
    @EnvironmentObject var store: Store

    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
    }
    var loadingFlag: Bool {
        detailInfo.associatedItemsLoading
    }
    var loadFailedFlag: Bool {
        detailInfo.associatedItemsLoadFailed
    }
    var notFoundFlag: Bool {
        detailInfo.associatedItemsNotFound
    }
    var assciatedItems: [AssociatedItem] {
        detailInfo.associatedItems
    }
    var assciatedItem: AssociatedItem {
        assciatedItems.count >= depth + 1
            ? assciatedItems[depth] : AssociatedItem(mangas: [])
    }
    var title: String {
        if keyword.title != nil {
            return keyword.title!
        } else {
            return "\(keyword.category ?? "")"
                + ":\(keyword.content ?? "")"
        }
    }
    
    let depth: Int
    let keyword: AssociatedKeyword
    
    var body: some View {
        ScrollView {
            LazyVStack {
                if !assciatedItem.mangas.isEmpty {
                    ForEach(assciatedItem.mangas) { manga in
                        NavigationLink(
                            destination: DetailView(
                                id: manga.id,
                                depth: depth + 1
                            )
                        ) {
                            MangaSummaryRow(manga: manga)
                                .onAppear(perform: {
                                    onRowAppear(manga)
                                })
                        }
                    }
                } else if loadingFlag {
                    LoadingView()
                        .padding(.top, 30)
                } else if loadFailedFlag {
                    NetworkErrorView(retryAction: retryAction)
                        .padding(.top, 30)
                } else if notFoundFlag {
                    NotFoundView(retryAction: retryAction)
                        .padding(.top, 30)
                }
            }
            .padding()
        }
        .onAppear(perform: onAppear)
        .navigationBarTitle(title)
    }
    
    func onAppear() {
        if assciatedItem.keyword != keyword {
            fetchAssociatedItems()
        }
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
}
