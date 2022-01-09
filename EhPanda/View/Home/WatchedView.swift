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
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<WatchedState, WatchedAction>,
        setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
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
            loadMoreAction: { viewStore.send(.fetchMoreGalleries) },
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                viewStore.send(.fetchGalleries())
            }
        }
        .onDisappear {
            viewStore.send(.onDisappear)
        }
        .toolbar(content: toolbar)
        .navigationTitle("Watched")
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            ToolbarFeaturesMenu {
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
                        hapticClient: .live,
                        databaseClient: .live
                    )
                ),
                setting: .init(),
                tagTranslator: .init()
            )
        }
    }
}
