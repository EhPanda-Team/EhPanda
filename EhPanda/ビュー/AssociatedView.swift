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
    var assciatedItems: [((String, String?), [Manga])] {
        detailInfo.associatedItems
    }
    var assciatedItem: ((String, String?), [Manga]) {
        assciatedItems.count >= depth + 1
            ? assciatedItems[depth] : (("",""), [])
    }
    var title: String {
        keyword.1 == nil ? keyword.0
            : "\(keyword.0)"
            + ":\(keyword.1 ?? "")"
    }
    
    let depth: Int
    let keyword: (String, String?)
    
    var body: some View {
        ScrollView {
            LazyVStack {
                if !assciatedItem.1.isEmpty {
                    ForEach(assciatedItem.1) { manga in
                        NavigationLink(
                            destination: DetailView(
                                id: manga.id,
                                depth: depth + 1
                            )
                        ) {
                            MangaSummaryRow(manga: manga)
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
        if assciatedItem.0 != keyword {
            fetchAssociatedItems()
        }
    }
    func retryAction() {
        fetchAssociatedItems()
    }
    
    func fetchAssociatedItems() {
        store.dispatch(.fetchAssociatedItems(depth: depth, keyword: keyword))
    }
}
