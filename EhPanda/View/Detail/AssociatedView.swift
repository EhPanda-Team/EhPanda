//
//  AssociatedView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/15.
//

import SwiftUI
import SwiftyBeaver

struct AssociatedView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    @State private var title: String
    @State private var keyword: String

    @State private var loadingFlag = false
    @State private var notFoundFlag = false
    @State private var loadFailedFlag = false
    @State private var moreLoadingFlag = false
    @State private var moreLoadFailedFlag = false
    @State private var associatedItems = [Manga]()
    @State private var pageNumber = PageNumber()

    init(keyword: String) {
        self.title = keyword
        self.keyword = keyword
    }

    var body: some View {
        GenericList(
            items: associatedItems,
            setting: setting,
            loadingFlag: loadingFlag,
            notFoundFlag: notFoundFlag,
            loadFailedFlag: loadFailedFlag,
            moreLoadingFlag: moreLoadingFlag,
            moreLoadFailedFlag: moreLoadFailedFlag,
            fetchAction: fetchAssociatedItems,
            loadMoreAction: fetchMoreAssociatedItems
        )
        .searchable(
            text: $keyword,
            placement: .navigationBarDrawer(
                displayMode: .always
            ),
            prompt: "Search"
        )
        .task(fetchAssociatedItemsIfNeeded)
        .onSubmit(of: .search, fetchAssociatedItems)
        .navigationBarTitle(title, displayMode: .inline)
    }
}

private extension AssociatedView {
    func onRowAppear(item: Manga) {
        if item == associatedItems.last {
            fetchMoreAssociatedItems()
        }
    }

    func fetchAssociatedItemsIfNeeded() {
        DispatchQueue.main.async {
            if associatedItems.isEmpty {
                fetchAssociatedItems()
            }
        }
    }

    func fetchAssociatedItems() {
        if !keyword.isEmpty {
            title = keyword
        }

        notFoundFlag = false
        loadFailedFlag = false
        guard !loadingFlag else { return }
        loadingFlag = true

        let token = SubscriptionToken()
        SearchItemsRequest(
            keyword: keyword.isEmpty
                ? title : keyword,
            filter: filter
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            loadingFlag = false
            if case .failure(let error) = completion {
                loadFailedFlag = true
                SwiftyBeaver.error(error)
            }
            token.unseal()
        } receiveValue: { pageNumber, mangas in
            self.pageNumber = pageNumber
            if !mangas.isEmpty {
                associatedItems = mangas
            } else {
                notFoundFlag = true
            }
            PersistenceController.add(mangas: mangas)

            if mangas.isEmpty
                && pageNumber.current
                < pageNumber.maximum
            {
                fetchMoreAssociatedItems()
            }
        }
        .seal(in: token)
    }
    func fetchMoreAssociatedItems() {
        moreLoadFailedFlag = false
        guard let lastID = associatedItems.last?.id,
              pageNumber.current + 1 < pageNumber.maximum,
              !moreLoadingFlag else { return }
        moreLoadingFlag = true

        let token = SubscriptionToken()
        MoreSearchItemsRequest(
            keyword: keyword, filter: filter,
            lastID: lastID, pageNum: pageNumber.current + 1
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            moreLoadingFlag = false
            if case .failure(let error)  = completion {
                moreLoadFailedFlag = true
                SwiftyBeaver.error(error)
            }
            token.unseal()
        } receiveValue: { pageNumber, mangas in
            self.pageNumber = pageNumber

            if associatedItems.isEmpty {
                associatedItems = mangas
            } else {
                associatedItems.append(
                    contentsOf: mangas.filter({
                        !associatedItems.contains($0)
                    })
                )
            }
            PersistenceController.add(mangas: mangas)

            if mangas.isEmpty
                && pageNumber.current
                < pageNumber.maximum
            {
                fetchMoreAssociatedItems()
            }
        }
        .seal(in: token)
    }
}
