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
    @Bindable private var store: StoreOf<MigrationReducer>

    private var reversedPrimary: Color {
        colorScheme == .light ? .white : .black
    }

    init(store: StoreOf<MigrationReducer>) {
        self.store = store
    }

    var body: some View {
        NavigationView {
            ZStack {
                reversedPrimary.ignoresSafeArea()
                LoadingView(title: L10n.Localizable.LoadingView.Title.preparingDatabase)
                    .opacity(store.databaseState == .loading ? 1 : 0)
                let error = (/LoadingState.failed).extract(from: store.databaseState)
                let errorNonNil = error ?? .databaseCorrupted(nil)
                AlertView(symbol: errorNonNil.symbol, message: errorNonNil.localizedDescription) {
                    AlertViewButton(title: L10n.Localizable.ErrorView.Button.dropDatabase) {
                        store.send(.setNavigation(.dropDialog))
                    }
                    .confirmationDialog(
                        message: L10n.Localizable.ConfirmationDialog.Title.dropDatabase,
                        unwrapping: $store.route,
                        case: /MigrationReducer.Route.dropDialog
                    ) {
                        Button(L10n.Localizable.ConfirmationDialog.Button.dropDatabase, role: .destructive) {
                            store.send(.dropDatabase)
                        }
                    }
                }
                .opacity(error != nil ? 1 : 0)
            }
            .animation(.default, value: store.databaseState)
        }
    }
}

struct MigrationView_Previews: PreviewProvider {
    static var previews: some View {
        MigrationView(store: .init(initialState: .init(), reducer: MigrationReducer.init))
    }
}
