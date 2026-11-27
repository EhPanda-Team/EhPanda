import AppModels
import ComposableArchitecture
@testable import FiltersFeature
import Foundation
import Testing

/// The Reset Filters confirmation is a presented dialog: whichever way it closes, its state must clear, or the store
/// keeps a dialog the screen no longer shows (TCA reports the binding set to nil while the state stayed set). Found
/// when UIKit closed the dialog it could not anchor in a 19-26 measuring run.
///
/// `@MainActor` is on the cases that build a `TestStore`, whose `init` and `state` are main-actor-isolated.
struct FiltersResetConfirmationTests {
    @MainActor
    @Test
    func dismissingWithoutChoosingClearsTheDialog() async throws {
        let defaults = try #require(UserDefaults(suiteName: "FiltersResetConfirmationTests-\(UUID().uuidString)"))
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let store = Self.makeStore(defaults: defaults)

            await store.send(.resetFiltersButtonTapped)
            #expect(store.state.confirmationDialog != nil)

            await store.send(.confirmationDialog(.dismiss))
            #expect(store.state.confirmationDialog == nil)
        }
    }

    @MainActor
    @Test
    func confirmingResetsTheFilterAndClearsTheDialog() async throws {
        let defaults = try #require(UserDefaults(suiteName: "FiltersResetConfirmationTests-\(UUID().uuidString)"))
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let store = Self.makeStore(defaults: defaults)
            await store.send(.binding(.set(\.searchFilter, Filter(doujinshi: true))))

            await store.send(.resetFiltersButtonTapped)
            await store.send(.confirmationDialog(.presented(.confirmReset)))
            await store.skipReceivedActions()

            #expect(store.state.confirmationDialog == nil)
            #expect(store.state.searchFilter == Filter())
        }
    }

    @MainActor
    private static func makeStore(defaults: UserDefaults) -> TestStoreOf<FiltersReducer> {
        let store = TestStore(initialState: FiltersReducer.State(), reducer: FiltersReducer.init) {
            $0.defaultAppStorage = defaults
        }
        // The assertions read the state they are about; the store is not asked to account for every mutation.
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}
