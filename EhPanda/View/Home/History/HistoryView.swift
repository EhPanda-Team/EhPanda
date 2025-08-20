//
//  HistoryView.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

struct HistoryView: View {
    @Bindable private var store: StoreOf<HistoryReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<HistoryReducer>,
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
            pageNumber: nil,
            loadingState: store.loadingState,
            footerLoadingState: .idle,
            fetchAction: { store.send(.fetchGalleries) },
            navigateAction: { store.send(.setNavigation(.detail($0))) },
            translateAction: {
                tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
            }
        )
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
        .navigationTitle(L10n.Localizable.HistoryView.Title.history)

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
            Button {
                store.send(.setNavigation(.clearHistory))
            } label: {
                Image(systemSymbol: .trashCircle)
            }
            .disabled(store.loadingState != .idle || store.galleries.isEmpty)
            .confirmationDialog(
                message: L10n.Localizable.ConfirmationDialog.Title.clear,
                unwrapping: $store.route,
                case: \.clearHistory
            ) {
                Button(L10n.Localizable.ConfirmationDialog.Button.clear, role: .destructive) {
                    store.send(.clearHistoryGalleries)
                }
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HistoryView(
                store: .init(initialState: .init(), reducer: HistoryReducer.init),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
