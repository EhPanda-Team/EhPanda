//
//  PopularView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import ComposableArchitecture

struct PopularView: View {
    private let store: Store<PopularState, PopularAction>
    @ObservedObject private var viewStore: ViewStore<PopularState, PopularAction>
    private let user: User
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<PopularState, PopularAction>,
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
            galleries: viewStore.filteredGalleries,
            setting: setting, pageNumber: nil,
            loadingState: viewStore.loadingState,
            footerLoadingState: .idle,
            fetchAction: { viewStore.send(.fetchGalleries) },
            navigateAction: {
                viewStore.send(.setCurrentRouteGalleryID($0))
                viewStore.send(.setNavigation(.detail))
            },
            translateAction: {
                tagTranslator.tryTranslate(text: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .searchable(text: viewStore.binding(\.$keyword), prompt: "Filter")
        .onAppear {
            if viewStore.galleries.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    viewStore.send(.fetchGalleries)
                }
            }
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle("Popular")
    }

    private var navigationLink: some View {
        NavigationLink("", tag: .detail, selection: viewStore.binding(\.$route)) {
            DetailView(
                store: store.scope(state: \.detailState, action: PopularAction.detail),
                gid: viewStore.currentRouteGalleryID, user: user, setting: setting, tagTranslator: tagTranslator
            )
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            FiltersButton(hideText: true) {
                viewStore.send(.onFiltersButtonTapped)
            }
        }
    }
}

// MARK: Definition
enum PopularViewRoute: Equatable {
    case detail
}

struct PopularView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PopularView(
                store: .init(
                    initialState: .init(),
                    reducer: popularReducer,
                    environment: PopularEnvironment(
                        hapticClient: .live,
                        cookiesClient: .live,
                        databaseClient: .live
                    )
                ),
                user: .init(),
                setting: .init(),
                tagTranslator: .init()
            )
        }
    }
}
