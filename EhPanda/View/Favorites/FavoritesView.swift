//
//  FavoritesView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/13.
//

import SwiftUI
import AlertKit
import SFSafeSymbols
import ComposableArchitecture

struct FavoritesView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let store: Store<FavoritesState, FavoritesAction>
    @ObservedObject private var viewStore: ViewStore<FavoritesState, FavoritesAction>
    private let user: User
    private let setting: Setting
    private let tagTranslator: TagTranslator

    @FocusState private var jumpPageAlertFocused: Bool
    @StateObject private var alertManager = CustomAlertManager()

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
        (viewStore.index == -1 ? "Favorites" : User.getFavNameFrom(
            index: viewStore.index, names: user.favoriteNames
        )).localized
    }

    // MARK: FavoritesView
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
            .customAlert(
                manager: alertManager, widthFactor: DeviceUtil.isPadWidth ? 0.5 : 1.0,
                backgroundOpacity: colorScheme == .light ? 0.2 : 0.5,
                content: {
                    PageJumpView(
                        inputText: viewStore.binding(\.$jumpPageIndex),
                        isFocused: $jumpPageAlertFocused,
                        pageNumber: viewStore.pageNumber ?? PageNumber()
                    )
                },
                buttons: [
                    .regular(
                        content: { Text("Confirm") },
                        action: { viewStore.send(.performJumpPage) }
                    )
                ]
            )
            .searchable(text: viewStore.binding(\.$keyword))
            .onChange(of: alertManager.isPresented) { _ in
                viewStore.send(.setJumpPageAlertFocused(false))
            }
            .synchronize(
                viewStore.binding(\.$jumpPageAlertFocused),
                $jumpPageAlertFocused
            )
            .synchronize(
                viewStore.binding(\.$jumpPageAlertPresented),
                $alertManager.isPresented, animated: true
            )
            .onAppear {
                if viewStore.galleries?.isEmpty != false {
                    viewStore.send(.fetchGalleries())
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar(content: toolbar)
        }
    }

    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        func selectIndexMenu() -> some View {
            Menu {
                ForEach(-1..<10) { index in
                    Button {
                        if index != viewStore.index {
                            viewStore.send(.setFavoritesIndex(index))
                        }
                    } label: {
                        Text(User.getFavNameFrom(
                            index: index, names: user.favoriteNames
                        ))
                        if index == viewStore.index {
                            Image(systemSymbol: .checkmark)
                        }
                    }
                }
            } label: {
                Image(systemSymbol: .dialMin)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        func sortOrderMenu() -> some View {
            Menu {
                ForEach(FavoritesSortOrder.allCases) { order in
                    Button {
                        if order != viewStore.sortOrder {
                            viewStore.send(.fetchGalleries(nil, order))
                        }
                    } label: {
                        Text(order.value.localized)
                        if order == viewStore.sortOrder {
                            Image(systemSymbol: .checkmark)
                        }
                    }
                }
            } label: {
                Image(systemSymbol: .arrowUpArrowDownCircle)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        func moreFeaturesMenu() -> some View {
            Menu {
                Button {
                    viewStore.send(.presentJumpPageAlert)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewStore.send(.setJumpPageAlertFocused(true))
                    }
                } label: {
                    Image(systemSymbol: .arrowshapeBounceForward)
                    Text("Jump page")
                }
                .disabled(viewStore.pageNumber?.isSinglePage ?? true)
            } label: {
                Image(systemSymbol: .ellipsisCircle)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        return ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                selectIndexMenu()
                sortOrderMenu()
                moreFeaturesMenu()
            }
            .foregroundColor(.primary)
        }
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView(
            store: Store<FavoritesState, FavoritesAction>(
                initialState: FavoritesState(),
                reducer: favoritesReducer,
                environment: FavoritesEnvironment(
                    hapticClient: .live,
                    databaseClient: .live
                )
            ),
            user: User(), setting: Setting(), tagTranslator: TagTranslator()
        )
    }
}
