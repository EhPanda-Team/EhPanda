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
    @Bindable private var store: StoreOf<FavoritesReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<FavoritesReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    private var navigationTitle: String {
        let favoriteCategory = user.getFavoriteCategory(index: store.index)
        return (store.index == -1 ? L10n.Localizable.FavoritesView.Title.favorites : favoriteCategory)
    }

    var body: some View {
        NavigationView {
            let content =
            ZStack {
                if CookieUtil.didLogin {
                    GenericList(
                        galleries: store.galleries ?? [],
                        setting: setting,
                        pageNumber: store.pageNumber,
                        loadingState: store.loadingState ?? .idle,
                        footerLoadingState: store.footerLoadingState ?? .idle,
                        fetchAction: { store.send(.fetchGalleries()) },
                        fetchMoreAction: { store.send(.fetchMoreGalleries) },
                        navigateAction: { store.send(.setNavigation(.detail($0))) },
                        translateAction: {
                            tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
                        }
                    )
                } else {
                    NotLoginView(action: { store.send(.onNotLoginViewButtonTapped) })
                }
            }
            .sheet(unwrapping: $store.route, case: /FavoritesReducer.Route.quickSearch) { _ in
                QuickSearchView(
                    store: store.scope(state: \.quickSearchState, action: \.quickSearch)
                ) { keyword in
                    store.send(.setNavigation(nil))
                    store.send(.fetchGalleries(keyword))
                }
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .searchable(text: $store.keyword)
            .searchSuggestions {
                TagSuggestionView(
                    keyword: $store.keyword, translations: tagTranslator.translations,
                    showsImages: setting.showsImagesInTags, isEnabled: setting.showsTagsSearchSuggestion
                )
            }
            .onSubmit(of: .search) {
                store.send(.fetchGalleries())
            }
            .onAppear {
                if store.galleries?.isEmpty != false && CookieUtil.didLogin {
                    DispatchQueue.main.async {
                        store.send(.fetchGalleries())
                    }
                }
            }
            .background(navigationLink)
            .toolbar(content: toolbar)
            .navigationTitle(navigationTitle)

            if DeviceUtil.isPad {
                content
                    .sheet(unwrapping: $store.route, case: /FavoritesReducer.Route.detail) { route in
                        NavigationView {
                            DetailView(
                                store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                                gid: route.wrappedValue, user: user, setting: $setting,
                                blurRadius: blurRadius, tagTranslator: tagTranslator
                            )
                        }
                        .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
                    }
            } else {
                content
            }
        }
    }

    @ViewBuilder private var navigationLink: some View {
        if DeviceUtil.isPhone {
            NavigationLink(unwrapping: $store.route, case: /FavoritesReducer.Route.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary) {
            FavoritesIndexMenu(user: user, index: store.index) { index in
                if index != store.index {
                    store.send(.setFavoritesIndex(index))
                }
            }
            SortOrderMenu(sortOrder: store.sortOrder) { order in
                if store.sortOrder != order {
                    store.send(.fetchGalleries(nil, order))
                }
            }
            QuickSearchButton(hideText: true) {
                store.send(.setNavigation(.quickSearch))
            }
        }
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView(
            store: .init(initialState: .init(), reducer: FavoritesReducer.init),
            user: .init(),
            setting: .constant(.init()),
            blurRadius: 0,
            tagTranslator: .init()
        )
    }
}
