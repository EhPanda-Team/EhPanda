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
    private let store: Store<MigrationState, MigrationAction>
    @ObservedObject private var viewStore: ViewStore<MigrationState, MigrationAction>

    private var reversedPrimary: Color {
        colorScheme == .light ? .white : .black
    }

    init(store: Store<MigrationState, MigrationAction>) {
        self.store = store
        viewStore = ViewStore(store)
    }

    var body: some View {
        NavigationView {
            ZStack {
                reversedPrimary.ignoresSafeArea()
                LoadingView(title: R.string.localizable.loadingViewTitlePreparingDatabase())
                    .opacity(viewStore.databaseState == .loading ? 1 : 0)
                let error = (/LoadingState.failed).extract(from: viewStore.databaseState)
                let errorNonNil = error ?? .databaseCorrupted(nil)
                AlertView(symbol: errorNonNil.symbol, message: errorNonNil.localizedDescription) {
                    AlertViewButton(title: R.string.localizable.errorViewButtonDropDatabase()) {
                        viewStore.send(.setNavigation(.dropDialog))
                    }
                    .confirmationDialog(
                        message: R.string.localizable.confirmationDialogTitleDropDatabase(),
                        unwrapping: viewStore.binding(\.$route),
                        case: /MigrationState.Route.dropDialog
                    ) {
                        Button(R.string.localizable.confirmationDialogButtonDropDatabase(), role: .destructive) {
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
                reducer: migrationReducer,
                environment: MigrationEnvironment(
                    databaseClient: .live
                )
            )
        )
    }
}
