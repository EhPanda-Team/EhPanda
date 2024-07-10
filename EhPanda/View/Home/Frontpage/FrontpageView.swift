//
//  FrontpageView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/18.
//

import SwiftUI
import AlertKit
import ComposableArchitecture

struct FrontpageView: View {
    private let store: StoreOf<FrontpageReducer>
    @ObservedObject private var viewStore: ViewStoreOf<FrontpageReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<FrontpageReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store, observe: { $0 })
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        let content =
        GenericList(
            galleries: viewStore.filteredGalleries,
            setting: setting,
            pageNumber: viewStore.pageNumber,
            loadingState: viewStore.loadingState,
            footerLoadingState: viewStore.footerLoadingState,
            fetchAction: { viewStore.send(.fetchGalleries) },
            fetchMoreAction: { viewStore.send(.fetchMoreGalleries) },
            navigateAction: { viewStore.send(.setNavigation(.detail($0))) },
            translateAction: {
                tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .sheet(unwrapping: viewStore.$route, case: /FrontpageReducer.Route.filters) { _ in
            FiltersView(store: store.scope(state: \.filtersState, action: FrontpageReducer.Action.filters))
                .autoBlur(radius: blurRadius).environment(\.inSheet, true)
        }
        .searchable(text: viewStore.$keyword, prompt: L10n.Localizable.Searchable.Prompt.filter)
        .onAppear {
            if viewStore.galleries.isEmpty {
                DispatchQueue.main.async {
                    viewStore.send(.fetchGalleries)
                }
            }
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle(L10n.Localizable.FrontpageView.Title.frontpage)

        if DeviceUtil.isPad {
            content
                .sheet(unwrapping: viewStore.$route, case: /FrontpageReducer.Route.detail) { route in
                    NavigationView {
                        DetailView(
                            store: store.scope(state: \.detailState, action: FrontpageReducer.Action.detail),
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

    @ViewBuilder private var navigationLink: some View {
        if DeviceUtil.isPhone {
            NavigationLink(unwrapping: viewStore.$route, case: /FrontpageReducer.Route.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState, action: FrontpageReducer.Action.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            FiltersButton(hideText: true) {
                viewStore.send(.setNavigation(.filters))
            }
        }
    }
}

struct FrontpageView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FrontpageView(
                store: .init(initialState: .init(), reducer: FrontpageReducer.init),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
