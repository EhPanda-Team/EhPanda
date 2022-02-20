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
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: Store<FavoritesState, FavoritesAction>,
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
        return (viewStore.index == -1 ? R.string.localizable.favoritesViewTitleFavorites() : favoriteCategory)
    }

    var body: some View {
        NavigationView {
            ZStack {
                if CookiesUtil.didLogin {
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
                case: /FavoritesState.Route.detail,
                isEnabled: DeviceUtil.isPad
            ) { route in
                NavigationView {
                    DetailView(
                        store: store.scope(state: \.detailState, action: FavoritesAction.detail),
                        gid: route.wrappedValue, user: user, setting: $setting,
                        blurRadius: blurRadius, tagTranslator: tagTranslator
                    )
                }
                .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
            }
            .sheet(unwrapping: viewStore.binding(\.$route), case: /FavoritesState.Route.quickSearch) { _ in
                QuickSearchView(
                    store: store.scope(state: \.quickSearchState, action: FavoritesAction.quickSearch)
                ) { keyword in
                    viewStore.send(.setNavigation(nil))
                    viewStore.send(.fetchGalleries(nil, keyword))
                }
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .jumpPageAlert(
                index: viewStore.binding(\.$jumpPageIndex),
                isPresented: viewStore.binding(\.$jumpPageAlertPresented),
                isFocused: viewStore.binding(\.$jumpPageAlertFocused),
                pageNumber: viewStore.pageNumber ?? .init(),
                jumpAction: { viewStore.send(.performJumpPage) }
            )
            .animation(.default, value: viewStore.jumpPageAlertPresented)
            .searchable(text: viewStore.binding(\.$keyword)) {
                TagSuggestionView(
                    keyword: viewStore.binding(\.$keyword), translations: tagTranslator.translations,
                    showsImages: setting.showsImagesInTags, isEnabled: setting.showsTagsSearchSuggestions
                )
            }
            .onSubmit(of: .search) {
                viewStore.send(.fetchGalleries())
            }
            .onAppear {
                if viewStore.galleries?.isEmpty != false && CookiesUtil.didLogin {
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
            NavigationLink(unwrapping: viewStore.binding(\.$route), case: /FavoritesState.Route.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState, action: FavoritesAction.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
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
                    viewStore.send(.fetchGalleries(nil, nil, order))
                }
            }
            ToolbarFeaturesMenu(symbolRenderingMode: .hierarchical) {
                QuickSearchButton {
                    viewStore.send(.setNavigation(.quickSearch))
                }
                JumpPageButton(pageNumber: viewStore.pageNumber ?? .init()) {
                    viewStore.send(.presentJumpPageAlert)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewStore.send(.setJumpPageAlertFocused(true))
                    }
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
                    urlClient: .live,
                    fileClient: .live,
                    imageClient: .live,
                    deviceClient: .live,
                    hapticClient: .live,
                    cookiesClient: .live,
                    databaseClient: .live,
                    clipboardClient: .live,
                    appDelegateClient: .live,
                    uiApplicationClient: .live
                )
            ),
            user: .init(),
            setting: .constant(.init()),
            blurRadius: 0,
            tagTranslator: .init()
        )
    }
}
