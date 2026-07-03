import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import AppComponents

public struct MigrationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var store: StoreOf<MigrationReducer>

    private var reversedPrimary: Color {
        colorScheme == .light ? .white : .black
    }

    public init(store: StoreOf<MigrationReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                reversedPrimary.ignoresSafeArea()
                LoadingView(title: .preparingDatabase)
                    .opacity(store.databaseState == .loading ? 1 : 0)
                let error = store.databaseState.failed
                let errorNonNil = error ?? .databaseCorrupted(nil)
                AlertView(symbol: errorNonNil.symbol, message: errorNonNil.localizedDescription) {
                    AlertViewButton(title: .dropDatabase) {
                        store.send(.dropDatabaseButtonTapped)
                    }
                    .confirmationDialog(
                        $store.scope(state: \.confirmationDialog, action: \.confirmationDialog)
                    )
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
