//
//  MigrationView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/03.
//

import SwiftUI
import ComposableArchitecture

struct MigrationView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let store: StoreOf<MigrationReducer>
    @ObservedObject private var viewStore: ViewStoreOf<MigrationReducer>

    private var reversedPrimary: Color {
        colorScheme == .light ? .white : .black
    }

    init(store: StoreOf<MigrationReducer>) {
        self.store = store
        viewStore = ViewStore(store)
    }

    var body: some View {
        NavigationView {
            ZStack {
                reversedPrimary.ignoresSafeArea()
                LoadingView(title: L10n.Localizable.LoadingView.Title.preparingDatabase)
                    .opacity(viewStore.databaseState == .loading ? 1 : 0)
                let error = (/LoadingState.failed).extract(from: viewStore.databaseState)
                let errorNonNil = error ?? .databaseCorrupted(nil)
                AlertView(symbol: errorNonNil.symbol, message: errorNonNil.localizedDescription) {
                    AlertViewButton(title: L10n.Localizable.ErrorView.Button.dropDatabase) {
                        viewStore.send(.setNavigation(.dropDialog))
                    }
                    .confirmationDialog(
                        message: L10n.Localizable.ConfirmationDialog.Title.dropDatabase,
                        unwrapping: viewStore.binding(\.$route),
                        case: /MigrationReducer.Route.dropDialog
                    ) {
                        Button(L10n.Localizable.ConfirmationDialog.Button.dropDatabase, role: .destructive) {
                            viewStore.send(.dropDatabase)
                        }
                    }
                }
                .opacity(error != nil ? 1 : 0)
            }
            .animation(.default, value: viewStore.databaseState)
        }
    }
}

struct MigrationView_Previews: PreviewProvider {
    static var previews: some View {
        MigrationView(
            store: .init(
                initialState: .init(),
                reducer: MigrationReducer()
            )
        )
    }
}
