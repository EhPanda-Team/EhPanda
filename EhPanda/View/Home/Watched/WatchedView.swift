//
//  WatchedView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import ComposableArchitecture

struct WatchedView: View {
    private let store: StoreOf<WatchedReducer>
    @ObservedObject private var viewStore: ViewStoreOf<WatchedReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<WatchedReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        ZStack {
            if CookieUtil.didLogin {
                GenericList(
                    galleries: viewStore.galleries,
                    setting: setting,
                    pageNumber: viewStore.pageNumber,
                    loadingState: viewStore.loadingState,
                    footerLoadingState: viewStore.footerLoadingState,
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
            case: /WatchedReducer.Route.detail,
            isEnabled: DeviceUtil.isPad
        ) { route in
            NavigationView {
                DetailView(
                    store: store.scope(state: \.detailState, action: WatchedReducer.Action.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
            .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
        }
        .sheet(unwrapping: viewStore.binding(\.$route), case: /WatchedReducer.Route.quickSearch) { _ in
            QuickSearchView(
                store: store.scope(state: \.quickSearchState, action: WatchedReducer.Action.quickSearch)
            ) { keyword in
                viewStore.send(.setNavigation(nil))
                viewStore.send(.fetchGalleries(keyword))
            }
            .accentColor(setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
        .sheet(unwrapping: viewStore.binding(\.$route), case: /WatchedReducer.Route.filters) { _ in
            FiltersView(store: store.scope(state: \.filtersState, action: WatchedReducer.Action.filters))
                .autoBlur(radius: blurRadius).environment(\.inSheet, true)
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
            if viewStore.galleries.isEmpty && CookieUtil.didLogin {
                DispatchQueue.main.async {
                    viewStore.send(.fetchGalleries())
                }
            }
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle(L10n.Localizable.WatchedView.Title.watched)
    }

    @ViewBuilder private var navigationLink: some View {
        if DeviceUtil.isPhone {
            NavigationLink(unwrapping: viewStore.binding(\.$route), case: /WatchedReducer.Route.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState, action: WatchedReducer.Action.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            ToolbarFeaturesMenu {
                FiltersButton {
                    viewStore.send(.setNavigation(.filters))
                }
                QuickSearchButton {
                    viewStore.send(.setNavigation(.quickSearch))
                }
            }
        }
    }
}

struct WatchedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WatchedView(
                store: .init(
                    initialState: .init(),
                    reducer: WatchedReducer()
                ),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
