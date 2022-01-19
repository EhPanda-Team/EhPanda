//
//  SearchRequestView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/12.
//

import SwiftUI
import ComposableArchitecture

struct SearchRequestView: View {
    private let store: Store<SearchRequestState, SearchRequestAction>
    @ObservedObject private var viewStore: ViewStore<SearchRequestState, SearchRequestAction>
    private let keyword: String
    private let user: User
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<SearchRequestState, SearchRequestAction>,
        keyword: String, user: User, setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.keyword = keyword
        self.user = user
        self.setting = setting
        self.tagTranslator = tagTranslator
    }

    private var navigationTitle: String {
        viewStore.lastKeyword.isEmpty ? "Search".localized : viewStore.lastKeyword
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
        .searchable(text: viewStore.binding(\.$keyword))
        .onSubmit(of: .search) {
            viewStore.send(.fetchGalleries())
        }
        .onAppear {
            if viewStore.galleries.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    viewStore.send(.fetchGalleries(nil, keyword))
                }
            }
        }
        .onDisappear {
            viewStore.send(.onDisappear)
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle(navigationTitle)
    }

    private var navigationLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SearchRequestState.Route.detail) { route in
            DetailView(
                store: store.scope(state: \.detailState, action: SearchRequestAction.detail),
                gid: route.wrappedValue, user: user, setting: setting, tagTranslator: tagTranslator
            )
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary, disabled: viewStore.jumpPageAlertPresented) {
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

struct SearchRequestView_Previews: PreviewProvider {
    static var previews: some View {
        SearchRequestView(
            store: .init(
                initialState: .init(),
                reducer: searchRequestReducer,
                environment: SearchRequestEnvironment(
                    urlClient: .live,
                    fileClient: .live,
                    hapticClient: .live,
                    cookiesClient: .live,
                    databaseClient: .live,
                    clipboardClient: .live,
                    uiApplicationClient: .live
                )
            ),
            keyword: .init(),
            user: .init(),
            setting: .init(),
            tagTranslator: .init()
        )
    }
}
