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
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<FrontpageState, FrontpageAction>,
        setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.setting = setting
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
        .searchable(text: viewStore.binding(\.$keyword), prompt: "Filter")
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
        .navigationTitle("Frontpage")
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

struct FrontpageView_Previews: PreviewProvider {
    static var previews: some View {
        FrontpageView(
            store: .init(
                initialState: .init(),
                reducer: frontpageReducer,
                environment: FrontpageEnvironment(
                    hapticClient: .live,
                    databaseClient: .live
                )
            ),
            setting: .init(),
            tagTranslator: .init()
        )
    }
}
