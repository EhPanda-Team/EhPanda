//
//  AssociatedView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/15.
//

import SwiftUI
import AlertKit
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

    @State private var alertInput = ""
    @FocusState private var isAlertFocused: Bool
    @StateObject private var alertManager = CustomAlertManager()

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: toggleFilter) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filters")
                    }
                    Button(action: toggleJumpPage) {
                        Image(systemName: "arrowshape.bounce.forward")
                        Text("Jump page")
                    }
                    .disabled(pageNumber.isSinglePage)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .customAlert(
            manager: alertManager,
            widthFactor: isPadWidth ? 0.5 : 1.0,
            content: {
                PageJumpView(
                    inputText: $alertInput,
                    isFocused: $isAlertFocused,
                    pageNumber: pageNumber
                )
            }, buttons: [
                .regular {
                    Text("Confirm")
                } action: {
                    performJumpPage()
                }
            ]
        )
        .navigationBarTitle(title)
        .onSubmit(of: .search, fetchAssociatedItems)
        .onAppear(perform: fetchAssociatedItemsIfNeeded)
        .onChange(of: pageNumber, perform: onPageNumberChanged)
        .onChange(of: alertManager.isPresented, perform: onAlertVisibilityChanged)
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
    func onAlertVisibilityChanged(_: Bool) {
        isAlertFocused = false
    }
    func onPageNumberChanged(pageNumber: PageNumber) {
        alertInput = String(pageNumber.current + 1)
    }

    func fetchAssociatedItemsIfNeeded() {
        DispatchQueue.main.async {
            if associatedItems.isEmpty {
                fetchAssociatedItems()
            }
        }
    }

    func fetchAssociatedItems() {
        fetchAssociatedItems(pageNum: nil)
    }
    func fetchAssociatedItems(pageNum: Int? = nil) {
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
            filter: filter,
            pageNum: pageNum
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            loadingFlag = false
            if case .failure(let error) = completion {
                SwiftyBeaver.error(error)
                loadError = error

                SwiftyBeaver.error(
                    "SearchItemsRequest failed",
                    context: [
                        "Keyword": keyword.isEmpty ? title : keyword,
                        "Error": error
                    ]
                )
            }
            token.unseal()
        } receiveValue: { pageNumber, galleries in
            self.pageNumber = pageNumber
            if !galleries.isEmpty {
                associatedItems = galleries

                SwiftyBeaver.info(
                    "SearchItemsRequest succeeded",
                    context: [
                        "Keyword": keyword.isEmpty ? title : keyword, "PageNumber": pageNumber,
                        "Galleries count": galleries.count
                    ]
                )
            } else {
                loadError = .notFound

                SwiftyBeaver.error(
                    "SearchItemsRequest failed",
                    context: [
                        "Keyword": keyword.isEmpty ? title : keyword,
                        "PageNumber": pageNumber, "Error": loadError as Any
                    ]
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
    func fetchMoreAssociatedItems() {
        moreLoadFailedFlag = false
        guard let lastID = associatedItems.last?.id,
              pageNumber.current + 1 <= pageNumber.maximum,
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

                SwiftyBeaver.error(
                    "MoreSearchItemsRequest failed",
                    context: [
                        "Keyword": keyword, "LastID": lastID,
                        "PageNumber": pageNumber, "Error": error
                    ]
                )
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

            SwiftyBeaver.info(
                "MoreSearchItemsRequest succeeded",
                context: [
                    "Keyword": keyword, "LastID": lastID, "PageNumber": pageNumber,
                    "Galleries count": galleries.count
                ]
            )

            if galleries.isEmpty && pageNumber.current < pageNumber.maximum {
                fetchMoreAssociatedItems()

                SwiftyBeaver.warning(
                    "MoreSearchItemsRequest result empty, requesting more..."
                )
            }
        }
        .seal(in: token)
    }
    func toggleFilter() {
        store.dispatch(.toggleHomeViewSheet(state: .filter))
    }
    func toggleJumpPage() {
        alertManager.show()
        isAlertFocused = true
        impactFeedback(style: .light)
    }
    func performJumpPage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let index = Int(alertInput), index <= pageNumber.maximum + 1
            { fetchAssociatedItems(pageNum: index - 1) }
        }
    }
}
