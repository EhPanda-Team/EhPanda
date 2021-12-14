//
//  FavoritesView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/13.
//

import SwiftUI
import AlertKit

struct FavoritesView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme

    @State private var keyword = ""
    @State private var lastKeyword = ""

    @State private var alertInput = ""
    @FocusState private var isAlertFocused: Bool
    @StateObject private var alertManager = CustomAlertManager()

    var body: some View {
        NavigationView {
            GenericList(
                items: homeInfo.favoritesItems[environment.favoritesIndex] ?? [], setting: setting,
                pageNumber: homeInfo.favoritesPageNumbers[environment.favoritesIndex],
                loadingFlag: homeInfo.favoritesLoading[environment.favoritesIndex] ?? false,
                loadError: homeInfo.favoritesLoadErrors[environment.favoritesIndex],
                moreLoadingFlag: homeInfo.moreFavoritesLoading[environment.favoritesIndex] ?? false,
                moreLoadFailedFlag: homeInfo.moreFavoritesLoadFailed[environment.favoritesIndex] ?? false,
                fetchAction: fetchFavoritesItems, loadMoreAction: fetchMoreFavoritesItems,
                translateAction: tryTranslateTag
            )
            .customAlert(
                manager: alertManager, widthFactor: DeviceUtil.isPadWidth ? 0.5 : 1.0,
                backgroundOpacity: colorScheme == .light ? 0.2 : 0.5,
                content: {
                    PageJumpView(
                        inputText: $alertInput, isFocused: $isAlertFocused,
                        pageNumber: currentListTypePageNumber
                    )
                },
                buttons: [.regular(content: { Text("Confirm") }, action: tryPerformJumpPage)]
            )
            .searchable(text: $keyword) { SuggestionProvider(keyword: $keyword) }
            .onAppear(perform: tryFetchFavoritesItems)
            .navigationTitle("Favorites")
            .toolbar(content: toolbar)
        }
    }

    var currentListTypePageNumber: PageNumber {
        switch environment.homeListType {
        case .search:
            return homeInfo.searchPageNumber
        case .frontpage:
            return homeInfo.frontpagePageNumber
        case .watched:
            return homeInfo.watchedPageNumber
        case .favorites:
            let index = environment.favoritesIndex
            return homeInfo.favoritesPageNumbers[index] ?? PageNumber()
        case .toplists:
            let index = environment.toplistsType.rawValue
            return homeInfo.toplistsPageNumbers[index] ?? PageNumber()
        case .popular, .downloaded, .history:
            return PageNumber()
        }
    }
    func toolbar() -> some ToolbarContent {
        func selectIndexMenu() -> some View {
            Menu {
                ForEach(-1..<10) { index in
                    Button {
                        guard index != environment.favoritesIndex else { return }
                        store.dispatch(.setFavoritesIndex(index))
                    } label: {
                        Text(User.getFavNameFrom(index: index, names: favoriteNames))
                        if index == environment.favoritesIndex {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Image(systemName: "dial.min")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.primary)
            }
        }
        func sortOrderMenu() -> some View {
            Menu {
                ForEach(FavoritesSortOrder.allCases) { order in
                    Button {
                        guard order != environment.favoritesSortOrder else { return }
                        store.dispatch(.fetchFavoritesItems(sortOrder: order))
                    } label: {
                        Text(order.value.localized)
                        if order == environment.favoritesSortOrder {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.primary)
            }
        }
        func moreFeaturesMenu() -> some View {
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
                .disabled(currentListTypePageNumber.isSinglePage)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.primary)
            }
        }
        return ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                selectIndexMenu()
                sortOrderMenu()
                moreFeaturesMenu()
            }
        }
    }
    func fetchFavoritesItems() {
        store.dispatch(.fetchFavoritesItems())
    }
    func fetchMoreFavoritesItems() {
        store.dispatch(.fetchMoreFavoritesItems)
    }
    func tryFetchFavoritesItems() {
        guard homeInfo.favoritesItems[environment.favoritesIndex]?.isEmpty != false else { return }
        fetchFavoritesItems()
    }
    func tryTranslateTag(text: String) -> String {
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
    func presentJumpPageAlert() {
        alertManager.show()
        isAlertFocused = true
        HapticUtil.generateFeedback(style: .light)
    }
    func tryPerformJumpPage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let index = Int(alertInput), index <= currentListTypePageNumber.maximum + 1 else { return }
            store.dispatch(.handleJumpPage(index: index - 1, keyword: lastKeyword))
        }
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView()
    }
}
