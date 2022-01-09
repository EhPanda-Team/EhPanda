//
//  FavoritesView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/13.
//

import SwiftUI
import AlertKit
import ComposableArchitecture

struct FavoritesView: View {
    private let store: Store<FavoritesState, FavoritesAction>
    @ObservedObject private var viewStore: ViewStore<FavoritesState, FavoritesAction>
    private let user: User
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<FavoritesState, FavoritesAction>,
        user: User, setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.user = user
        self.setting = setting
        self.tagTranslator = tagTranslator
    }

    private var navigationTitle: String {
        let favoritesName = user.getFavoritesName(index: viewStore.index)
        return (viewStore.index == -1 ? "Favorites" : favoritesName).localized
    }

    var body: some View {
        NavigationView {
            GenericList(
                galleries: viewStore.galleries ?? [],
                setting: setting,
                pageNumber: viewStore.pageNumber,
                loadingState: viewStore.loadingState ?? .idle,
                footerLoadingState: viewStore.footerLoadingState ?? .idle,
                fetchAction: { viewStore.send(.fetchGalleries()) },
                loadMoreAction: { viewStore.send(.fetchMoreGalleries) },
                translateAction: { tagTranslator.tryTranslate(
                    text: $0, returnOriginal: setting.translatesTags
                ) }
            )
            .jumpPageAlert(
                index: viewStore.binding(\.$jumpPageIndex),
                isPresented: viewStore.binding(\.$jumpPageAlertPresented),
                isFocused: viewStore.binding(\.$jumpPageAlertFocused),
                pageNumber: viewStore.pageNumber ?? PageNumber(),
                jumpAction: { viewStore.send(.performJumpPage) }
            )
            .animation(.default, value: viewStore.jumpPageAlertPresented)
            .searchable(text: viewStore.binding(\.$keyword))
            .onSubmit(of: .search) {
                viewStore.send(.fetchGalleries())
            }
            .onAppear {
                if viewStore.galleries?.isEmpty != false {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewStore.send(.fetchGalleries())
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar(content: toolbar)
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary, disabled: viewStore.jumpPageAlertPresented) {
            FavoritesIndexMenu(user: user, index: viewStore.index) { index in
                if index != viewStore.index {
                    viewStore.send(.setFavoritesIndex(index))
                }
            }
            SortOrderMenu(sortOrder: viewStore.sortOrder) { order in
                if viewStore.sortOrder != order {
                    viewStore.send(.fetchGalleries(nil, order))
                }
            }
            JumpPageButton(pageNumber: viewStore.pageNumber ?? PageNumber(), hideText: true) {
                viewStore.send(.presentJumpPageAlert)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    viewStore.send(.setJumpPageAlertFocused(true))
                }
            }
        }
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView(
            store: .init(
                initialState: .init(),
                reducer: favoritesReducer,
                environment: FavoritesEnvironment(
                    hapticClient: .live,
                    databaseClient: .live
                )
            ),
            user: .init(),
            setting: .init(),
            tagTranslator: .init()
        )
    }
}
