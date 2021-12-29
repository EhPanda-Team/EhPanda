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
    @Environment(\.colorScheme) private var colorScheme

    let store: Store<FavoritesState, FavoritesAction>
    @ObservedObject var viewStore: ViewStore<FavoritesState, FavoritesAction>

    @FocusState private var jumpPageAlertFocused: Bool
    @StateObject private var alertManager = CustomAlertManager()

    init(store: Store<FavoritesState, FavoritesAction>) {
        self.store = store
        viewStore = ViewStore(store)
    }

    // MARK: FavoritesView
    var body: some View {
        NavigationView {
            GenericList(
                items: viewStore.galleries ?? [], setting: Setting(),
                pageNumber: viewStore.pageNumber,
                loadingFlag: viewStore.loadingState == .loading,
                loadError: (/LoadingState.failed).extract(from: viewStore.loadingState),
                moreLoadingFlag: viewStore.footerLoadingState == .loading,
                moreLoadFailedFlag: ![.none, .idle, .loading].contains(viewStore.footerLoadingState),
                fetchAction: { viewStore.send(.fetchGalleries()) },
                loadMoreAction: { viewStore.send(.fetchMoreGalleries) },
                translateAction: { $0 }
            )
            .customAlert(
                manager: alertManager, widthFactor: DeviceUtil.isPadWidth ? 0.5 : 1.0,
                backgroundOpacity: colorScheme == .light ? 0.2 : 0.5,
                content: { PageJumpView(
                    inputText: viewStore.binding(\.$jumpPageIndex),
                    isFocused: $jumpPageAlertFocused,
                    pageNumber: viewStore.pageNumber ?? PageNumber()
                ) },
                buttons: [.regular(
                    content: { Text("Confirm") }, action: {
                        viewStore.send(.performJumpPage)
                    }
                )]
            )
            .searchable(text: viewStore.binding(\.$keyword))
            .onChange(of: alertManager.isPresented) { _ in
                jumpPageAlertFocused = false
            }
            .onAppear {
                if viewStore.galleries?.isEmpty != false {
                    viewStore.send(.fetchGalleries())
                }
            }
            .synchronize(
                viewStore.binding(\.$jumpPageAlertFocused),
                $jumpPageAlertFocused
            )
            .navigationTitle("Favorites")
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
                        Text(User.getFavNameFrom(index: index, names: [:]))
                        if index == viewStore.index {
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
                        if order != viewStore.sortOrder {
                            viewStore.send(.fetchGalleries(nil, order))
                        }
                    } label: {
                        Text(order.value.localized)
                        if order == viewStore.sortOrder {
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
                    alertManager.show()
                    viewStore.send(.presentJumpPageAlert)
                } label: {
                    Image(systemName: "arrowshape.bounce.forward")
                    Text("Jump page")
                }
                .disabled(viewStore.pageNumber?.isSinglePage ?? true)
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
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView(store: Store<FavoritesState, FavoritesAction>(
            initialState: FavoritesState(), reducer: favoritesReducer, environment: FavoritesEnvironment())
        )
    }
}
