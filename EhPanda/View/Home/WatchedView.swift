//
//  WatchedView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import ComposableArchitecture

struct WatchedView: View {
    private let store: Store<WatchedState, WatchedAction>
    @ObservedObject private var viewStore: ViewStore<WatchedState, WatchedAction>
    private let user: User
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<WatchedState, WatchedAction>,
        user: User, setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.user = user
        self.setting = setting
        self.tagTranslator = tagTranslator
    }

    var body: some View {
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
                tagTranslator.tryTranslate(text: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .jumpPageAlert(
            index: viewStore.binding(\.$jumpPageIndex),
            isPresented: viewStore.binding(\.$jumpPageAlertPresented),
            isFocused: viewStore.binding(\.$jumpPageAlertFocused),
            pageNumber: viewStore.pageNumber,
            jumpAction: { viewStore.send(.performJumpPage) }
        )
        .animation(.default, value: viewStore.jumpPageAlertPresented)
        .navigationBarBackButtonHidden(viewStore.jumpPageAlertPresented)
        .searchable(text: viewStore.binding(\.$keyword))
        .onSubmit(of: .search) {
            viewStore.send(.fetchGalleries())
        }
        .onAppear {
            if viewStore.galleries.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    viewStore.send(.fetchGalleries())
                }
            }
        }
        .onDisappear {
            viewStore.send(.onDisappear)
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle("Watched")
    }

    private var navigationLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /WatchedState.Route.detail) { route in
            DetailView(
                store: store.scope(state: \.detailState, action: WatchedAction.detail),
                gid: route.wrappedValue, user: user, setting: setting, tagTranslator: tagTranslator
            )
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(disabled: viewStore.jumpPageAlertPresented) {
            ToolbarFeaturesMenu {
                FiltersButton {
                    viewStore.send(.onFiltersButtonTapped)
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

struct WatchedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WatchedView(
                store: .init(
                    initialState: .init(),
                    reducer: watchedReducer,
                    environment: WatchedEnvironment(
                        urlClient: .live,
                        fileClient: .live,
                        hapticClient: .live,
                        cookiesClient: .live,
                        databaseClient: .live,
                        clipboardClient: .live,
                        uiApplicationClient: .live
                    )
                ),
                user: .init(),
                setting: .init(),
                tagTranslator: .init()
            )
        }
    }
}
