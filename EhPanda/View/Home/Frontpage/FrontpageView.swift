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
    @Bindable private var store: StoreOf<FrontpageReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<FrontpageReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        let content =
        GenericList(
            galleries: store.filteredGalleries,
            setting: setting,
            pageNumber: store.pageNumber,
            loadingState: store.loadingState,
            footerLoadingState: store.footerLoadingState,
            fetchAction: { store.send(.fetchGalleries) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.setNavigation(.detail($0))) },
            translateAction: {
                tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .sheet(item: $store.route.sending(\.setNavigation).filters) { _ in
            FiltersView(store: store.scope(state: \.filtersState, action: \.filters))
                .autoBlur(radius: blurRadius).environment(\.inSheet, true)
        }
        .searchable(text: $store.keyword, prompt: L10n.Localizable.Searchable.Prompt.filter)
        .onAppear {
            if store.galleries.isEmpty {
                DispatchQueue.main.async {
                    store.send(.fetchGalleries)
                }
            }
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle(L10n.Localizable.FrontpageView.Title.frontpage)

        if DeviceUtil.isPad {
            content
                .sheet(item: $store.route.sending(\.setNavigation).detail, id: \.self) { route in
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

    @ViewBuilder private var navigationLink: some View {
        if DeviceUtil.isPhone {
            NavigationLink(unwrapping: $store.route, case: \.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            FiltersButton(hideText: true) {
                store.send(.setNavigation(.filters()))
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
