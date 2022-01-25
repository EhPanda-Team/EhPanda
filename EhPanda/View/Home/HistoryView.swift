//
//  HistoryView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import ComposableArchitecture

struct HistoryView: View {
    private let store: Store<HistoryState, HistoryAction>
    @ObservedObject private var viewStore: ViewStore<HistoryState, HistoryAction>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: Store<HistoryState, HistoryAction>,
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
            pageNumber: nil,
            loadingState: viewStore.loadingState,
            footerLoadingState: .idle,
            fetchAction: { viewStore.send(.fetchGalleries) },
            navigateAction: { viewStore.send(.setNavigation(.detail($0))) },
            translateAction: {
                tagTranslator.tryTranslate(text: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .confirmationDialog(
            message: "Are you sure to clear?",
            unwrapping: viewStore.binding(\.$route),
            case: /HistoryState.Route.clearHistory
        ) {
            Button("Clear", role: .destructive) {
                viewStore.send(.clearHistoryGalleries)
            }
        }
        .searchable(text: viewStore.binding(\.$keyword), prompt: "Filter")
        .onAppear {
            if viewStore.galleries.isEmpty {
                DispatchQueue.main.async {
                    viewStore.send(.fetchGalleries)
                }
            }
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle("History")
    }

    private var navigationLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /HistoryState.Route.detail) { route in
            DetailView(
                store: store.scope(state: \.detailState, action: HistoryAction.detail),
                gid: route.wrappedValue, user: user, setting: $setting,
                blurRadius: blurRadius, tagTranslator: tagTranslator
            )
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Button {
                viewStore.send(.setNavigation(.clearHistory))
            } label: {
                Image(systemSymbol: .trashCircle)
            }
            .disabled(viewStore.galleries.isEmpty)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HistoryView(
                store: .init(
                    initialState: .init(),
                    reducer: historyReducer,
                    environment: HistoryEnvironment(
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
