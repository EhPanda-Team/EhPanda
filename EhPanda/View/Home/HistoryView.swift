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
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<HistoryState, HistoryAction>,
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
            pageNumber: nil,
            loadingState: viewStore.loadingState,
            footerLoadingState: .idle,
            fetchAction: { viewStore.send(.fetchGalleries) },
            translateAction: {
                tagTranslator.tryTranslate(text: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .confirmationDialog(
            "Are you sure to clear?", isPresented: viewStore.binding(\.$clearDialogPresented),
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                viewStore.send(.clearHistoryGalleries)
            }
        }
        .searchable(text: viewStore.binding(\.$keyword), prompt: "Filter")
        .onAppear {
            if viewStore.galleries.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    viewStore.send(.fetchGalleries)
                }
            }
        }
        .toolbar(content: toolbar)
        .navigationTitle("History")
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Button {
                viewStore.send(.setClearDialogPresented(true))
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
                        databaseClient: .live
                    )
                ),
                setting: .init(),
                tagTranslator: .init()
            )
        }
    }
}
