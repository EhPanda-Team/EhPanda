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
            navigateAction: { viewStore.send(.setNavigation(.detail($0))) },
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
        .background(navigationLinks)
        .toolbar(content: toolbar)
        .navigationTitle("Popular")
    }

    private var navigationLinks: some View {
        ForEach(viewStore.galleries) { gallery in
            NavigationLink(
                "", tag: gallery.id,
                selection: .init(
                    get: { (/PopularViewRoute.detail).extract(from: viewStore.route) },
                    set: {
                        var route: PopularViewRoute?
                        if let identifier = $0 {
                            route = .detail(identifier)
                        }
                        viewStore.send(.setNavigation(route))
                    }
                )
            ) {
                DetailView(
                    store: store.scope(state: \.detailState, action: PopularAction.detail),
                    gid: gallery.id, user: user, setting: setting, tagTranslator: tagTranslator
                )
            }
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
    case detail(String)
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
