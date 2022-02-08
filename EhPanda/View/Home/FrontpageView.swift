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
    private let store: Store<FrontpageState, FrontpageAction>
    @ObservedObject private var viewStore: ViewStore<FrontpageState, FrontpageAction>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: Store<FrontpageState, FrontpageAction>,
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
        GenericList(
            galleries: viewStore.filteredGalleries,
            setting: setting,
            pageNumber: viewStore.pageNumber,
            loadingState: viewStore.loadingState,
            footerLoadingState: viewStore.footerLoadingState,
            fetchAction: { viewStore.send(.fetchGalleries()) },
            fetchMoreAction: { viewStore.send(.fetchMoreGalleries) },
            navigateAction: { viewStore.send(.setNavigation(.detail($0))) },
            translateAction: {
                tagTranslator.tryTranslate(text: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .sheet(
            unwrapping: viewStore.binding(\.$route),
            case: /FrontpageState.Route.detail,
            isEnabled: DeviceUtil.isPad
        ) { route in
            NavigationView {
                DetailView(
                    store: store.scope(state: \.detailState, action: FrontpageAction.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
            .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
        }
        .sheet(unwrapping: viewStore.binding(\.$route), case: /FrontpageState.Route.filters) { _ in
            FiltersView(store: store.scope(state: \.filtersState, action: FrontpageAction.filters))
                .autoBlur(radius: blurRadius).environment(\.inSheet, true)
        }
        .jumpPageAlert(
            index: viewStore.binding(\.$jumpPageIndex),
            isPresented: viewStore.binding(\.$jumpPageAlertPresented),
            isFocused: viewStore.binding(\.$jumpPageAlertFocused),
            pageNumber: viewStore.pageNumber,
            jumpAction: { viewStore.send(.performJumpPage) }
        )
        .searchable(text: viewStore.binding(\.$keyword), prompt: R.string.localizable.searchablePromptFilter())
        .navigationBarBackButtonHidden(viewStore.jumpPageAlertPresented)
        .animation(.default, value: viewStore.jumpPageAlertPresented)
        .onAppear {
            if viewStore.galleries.isEmpty {
                DispatchQueue.main.async {
                    viewStore.send(.fetchGalleries())
                }
            }
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle(R.string.localizable.frontpageViewTitleFrontpage())
    }

    @ViewBuilder private var navigationLink: some View {
        if DeviceUtil.isPhone {
            NavigationLink(unwrapping: viewStore.binding(\.$route), case: /FrontpageState.Route.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState, action: FrontpageAction.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(disabled: viewStore.jumpPageAlertPresented) {
            ToolbarFeaturesMenu {
                FiltersButton {
                    viewStore.send(.setNavigation(.filters))
                }
                JumpPageButton(pageNumber: viewStore.pageNumber) {
                    viewStore.send(.presentJumpPageAlert)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewStore.send(.setJumpPageAlertFocused(true))
                    }
                }
            }
        }
    }
}

struct FrontpageView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FrontpageView(
                store: .init(
                    initialState: .init(),
                    reducer: frontpageReducer,
                    environment: FrontpageEnvironment(
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
}
