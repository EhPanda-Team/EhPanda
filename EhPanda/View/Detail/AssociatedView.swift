//
//  AssociatedView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/15.
//

import SwiftUI
import AlertKit

struct AssociatedView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme

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
        _title = State(initialValue: keyword)
        _keyword = State(initialValue: keyword)
    }

    // MARK: AssociatedView
    var body: some View {
        GenericList(
            items: associatedItems, setting: setting, pageNumber: pageNumber,
            loadingFlag: loadingFlag, loadError: loadError, moreLoadingFlag: moreLoadingFlag,
            moreLoadFailedFlag: moreLoadFailedFlag, fetchAction: fetchAssociatedItems,
            loadMoreAction: fetchMoreAssociatedItems, translateAction: translateTag
        )
        .searchable(
            text: $keyword, placement: .navigationBarDrawer(displayMode: .always)
        ) { SuggestionProvider(keyword: $keyword) }
        .toolbar(content: toolbar)
        .customAlert(
            manager: alertManager, widthFactor: DeviceUtil.isPadWidth ? 0.5 : 1.0,
            backgroundOpacity: colorScheme == .light ? 0.2 : 0.5,
            content: {
                PageJumpView(inputText: $alertInput, isFocused: $isAlertFocused, pageNumber: pageNumber)
            },
            buttons: [ .regular { Text("Confirm") } action: { performJumpPage()} ]
        )
        .navigationBarTitle(title)
        .onSubmit(of: .search, fetchAssociatedItems)
        .onAppear(perform: fetchAssociatedItemsIfNeeded)
        .onChange(of: pageNumber) { alertInput = String($0.current + 1) }
        .onChange(of: alertManager.isPresented) { _ in isAlertFocused = false }
    }
    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    store.dispatch(.setHomeViewSheetState(.filter))
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text("Filters")
                }
                Button(action: presentJumpPageAlert) {
                    Image(systemName: "arrowshape.bounce.forward")
                    Text("Jump page")
                }
                .disabled(pageNumber.isSinglePage)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

private extension AssociatedView {
    // MARK: Tools
    func translateTag(text: String) -> String {
        guard setting.translatesTags else { return text }
        let translator = settings.tagTranslator

        guard let range = text.range(of: ":") else {
            return translator.translate(text: text)
        }

        let before = text[...range.lowerBound]
        let after = String(text[range.upperBound...])
        let result = before + translator.translate(text: after)
        return String(result)
    }
    func presentJumpPageAlert() {
        alertManager.show()
        isAlertFocused = true
        HapticUtil.generateFeedback(style: .light)
    }
    func performJumpPage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let index = Int(alertInput), index <= pageNumber.maximum + 1 else { return }
            fetchAssociatedItems(pageNum: index - 1)
        }
    }

    func fetchAssociatedItemsIfNeeded() {
        DispatchQueue.main.async {
            guard associatedItems.isEmpty else { return }
            fetchAssociatedItems()
        }
    }
    func fetchAssociatedItems() {
        fetchAssociatedItems(pageNum: nil)
    }

    // MARK: Networking
    func fetchAssociatedItems(pageNum: Int? = nil) {
        if !keyword.isEmpty {
            title = keyword
        }

        loadError = nil
        guard !loadingFlag else { return }
        loadingFlag = true

        let token = SubscriptionToken()
        SearchItemsRequest(
            keyword: keyword.isEmpty ? title : keyword,
            filter: searchFilter, pageNum: pageNum
        )
        .publisher.receive(on: DispatchQueue.main)
        .sink { completion in
            loadingFlag = false
            if case .failure(let error) = completion {
                Logger.error(error)
                loadError = error

                Logger.error(
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

                Logger.info(
                    "SearchItemsRequest succeeded",
                    context: [
                        "Keyword": keyword.isEmpty ? title : keyword, "PageNumber": pageNumber,
                        "Galleries count": galleries.count
                    ]
                )
            } else {
                loadError = .notFound

                Logger.error(
                    "SearchItemsRequest failed",
                    context: [
                        "Keyword": keyword.isEmpty ? title : keyword,
                        "PageNumber": pageNumber, "Error": loadError as Any
                    ]
                )
            }
            PersistenceController.add(galleries: galleries)

            if galleries.isEmpty && pageNumber.current < pageNumber.maximum {
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
            keyword: keyword.isEmpty ? title : keyword, filter: searchFilter,
            lastID: lastID, pageNum: pageNumber.current + 1
        )
        .publisher.receive(on: DispatchQueue.main)
        .sink { completion in
            moreLoadingFlag = false
            if case .failure(let error)  = completion {
                moreLoadFailedFlag = true
                Logger.error(error)

                Logger.error(
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

            Logger.info(
                "MoreSearchItemsRequest succeeded",
                context: [
                    "Keyword": keyword, "LastID": lastID, "PageNumber": pageNumber,
                    "Galleries count": galleries.count
                ]
            )

            if galleries.isEmpty && pageNumber.current < pageNumber.maximum {
                fetchMoreAssociatedItems()
                Logger.warning("MoreSearchItemsRequest result empty, requesting more...")
            }
        }
        .seal(in: token)
    }
}
