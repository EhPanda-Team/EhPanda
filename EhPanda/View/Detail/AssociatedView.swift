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
    @State private var loadError: AppError?
    @State private var moreLoadingFlag = false
    @State private var moreLoadFailedFlag = false
    @State private var associatedItems = [Gallery]()
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
            loadError: loadError,
            moreLoadingFlag: moreLoadingFlag,
            moreLoadFailedFlag: moreLoadFailedFlag,
            fetchAction: fetchAssociatedItems,
            loadMoreAction: fetchMoreAssociatedItems,
            translateAction: translateTag
        )
        .searchable(
            text: $keyword,
            placement: .navigationBarDrawer(
                displayMode: .always
            ),
            prompt: "Search"
        )
        .navigationBarTitle(title)
        .onSubmit(of: .search, fetchAssociatedItems)
        .onAppear(perform: fetchAssociatedItemsIfNeeded)
    }
}

private extension AssociatedView {
    func translateTag(text: String) -> String {
        guard setting.translatesTags else { return text }
        let translator = settings.tagTranslator

        if let range = text.range(of: ":") {
            let before = text[...range.lowerBound]
            let after = String(text[range.upperBound...])
            let result = before + translator.translate(text: after)
            return String(result)
        }
        return translator.translate(text: text)
    }

    func onRowAppear(item: Gallery) {
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

        loadError = nil
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
                SwiftyBeaver.error(error)
                loadError = error
            }
            token.unseal()
        } receiveValue: { pageNumber, galleries in
            self.pageNumber = pageNumber
            if !galleries.isEmpty {
                associatedItems = galleries
            } else {
                loadError = .notFound
            }
            PersistenceController.add(galleries: galleries)

            if galleries.isEmpty
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
        } receiveValue: { pageNumber, galleries in
            self.pageNumber = pageNumber

            if associatedItems.isEmpty {
                associatedItems = galleries
            } else {
                associatedItems.append(
                    contentsOf: galleries.filter({
                        !associatedItems.contains($0)
                    })
                )
            }
            PersistenceController.add(galleries: galleries)

            if galleries.isEmpty
                && pageNumber.current
                < pageNumber.maximum
            {
                fetchMoreAssociatedItems()
            }
        }
        .seal(in: token)
    }
}
