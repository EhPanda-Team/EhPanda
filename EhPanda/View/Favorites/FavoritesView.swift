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
    private let store: StoreOf<FavoritesReducer>
    @ObservedObject private var viewStore: ViewStoreOf<FavoritesReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<FavoritesReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    private var navigationTitle: String {
        let favoriteCategory = user.getFavoriteCategory(index: viewStore.index)
        return (viewStore.index == -1 ? L10n.Localizable.FavoritesView.Title.favorites : favoriteCategory)
    }

    var body: some View {
        NavigationView {
            ZStack {
                if CookieUtil.didLogin {
                    GenericList(
                        galleries: viewStore.galleries ?? [],
                        setting: setting,
                        pageNumber: viewStore.pageNumber,
                        loadingState: viewStore.loadingState ?? .idle,
                        footerLoadingState: viewStore.footerLoadingState ?? .idle,
                        fetchAction: { viewStore.send(.fetchGalleries()) },
                        fetchMoreAction: { viewStore.send(.fetchMoreGalleries) },
                        navigateAction: { viewStore.send(.setNavigation(.detail($0))) },
                        translateAction: {
                            tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
                        }
                    )
                } else {
                    NotLoginView(action: { viewStore.send(.onNotLoginViewButtonTapped) })
                }
            }
            .sheet(
                unwrapping: viewStore.binding(\.$route),
                case: /FavoritesReducer.Route.detail,
                isEnabled: DeviceUtil.isPad
            ) { route in
                NavigationView {
                    DetailView(
                        store: store.scope(state: \.detailState, action: FavoritesReducer.Action.detail),
                        gid: route.wrappedValue, user: user, setting: $setting,
                        blurRadius: blurRadius, tagTranslator: tagTranslator
                    )
                }
                .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
            }
            .sheet(unwrapping: viewStore.binding(\.$route), case: /FavoritesReducer.Route.quickSearch) { _ in
                QuickSearchView(
                    store: store.scope(state: \.quickSearchState, action: FavoritesReducer.Action.quickSearch)
                ) { keyword in
                    viewStore.send(.setNavigation(nil))
                    viewStore.send(.fetchGalleries(keyword))
                }
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .searchable(text: viewStore.binding(\.$keyword))
            .searchSuggestions {
                TagSuggestionView(
                    keyword: viewStore.binding(\.$keyword), translations: tagTranslator.translations,
                    showsImages: setting.showsImagesInTags, isEnabled: setting.showsTagsSearchSuggestion
                )
            }
            .onSubmit(of: .search) {
                viewStore.send(.fetchGalleries())
            }
            .onAppear {
                if viewStore.galleries?.isEmpty != false && CookieUtil.didLogin {
                    DispatchQueue.main.async {
                        viewStore.send(.fetchGalleries())
                    }
                }
            }
            .background(navigationLink)
            .toolbar(content: toolbar)
            .navigationTitle(navigationTitle)
        }
    }

    @ViewBuilder private var navigationLink: some View {
        if DeviceUtil.isPhone {
            NavigationLink(unwrapping: viewStore.binding(\.$route), case: /FavoritesReducer.Route.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState, action: FavoritesReducer.Action.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary) {
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
            QuickSearchButton(hideText: true) {
                viewStore.send(.setNavigation(.quickSearch))
            }
        }
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView(
            store: .init(
                initialState: .init(),
                reducer: FavoritesReducer()
            ),
            user: .init(),
            setting: .constant(.init()),
            blurRadius: 0,
            tagTranslator: .init()
        )
    }
}
