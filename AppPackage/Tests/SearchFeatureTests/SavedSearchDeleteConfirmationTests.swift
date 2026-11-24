import AnalyticsClient
import AppModels
import ComposableArchitecture
import Foundation
@testable import QuickSearchFeature
import Testing

/// The Delete Saved Search confirmation belongs to one saved search row (the owner's C7 item, 19-13). The reducer keeps
/// one dialog and the ID of the saved search it was asked for, and exposes the dialog only for that ID, so each row can
/// attach its own `.confirmationDialog` and the iPad's popover points at the row.
///
/// `@MainActor` is on the cases that build a `TestStore`, whose `init` and `state` are main-actor-isolated.
struct SavedSearchDeleteConfirmationTests {
    private static let first = SavedSearch(name: "Reading list", content: "language:english")
    private static let second = SavedSearch(name: "Favourites", content: "rating:5")

    @MainActor
    @Test
    func deleteButtonTappedExposesTheDialogForThatSavedSearchOnly() async {
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let store = Self.makeStore()

            await store.send(.deleteSavedSearchButtonTapped(Self.first))

            #expect(store.state.pendingDeletion == Self.first.id)
            #expect(store.state[deleteConfirmationFor: Self.first.id] != nil)
            #expect(store.state[deleteConfirmationFor: Self.first.id] == store.state.confirmationDialog)
            #expect(store.state[deleteConfirmationFor: Self.second.id] == nil)
        }
    }

    @MainActor
    @Test
    func confirmingDeletesTheTargetedSavedSearchOnly() async {
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let store = Self.makeStore()
            store.state.$savedSearches.withLock({ $0 = [Self.first, Self.second] })

            await store.send(.deleteSavedSearchButtonTapped(Self.first))
            await store.send(.confirmationDialog(.presented(.confirmDelete(Self.first))))

            #expect(store.state.savedSearches == [Self.second])
            #expect(store.state.pendingDeletion == nil)
            #expect(store.state.confirmationDialog == nil)
        }
    }

    @MainActor
    @Test
    func dismissingClearsTheDialogAndTheTarget() async {
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let store = Self.makeStore()
            store.state.$savedSearches.withLock({ $0 = [Self.first, Self.second] })

            await store.send(.deleteSavedSearchButtonTapped(Self.second))
            await store.send(.confirmationDialog(.dismiss))

            #expect(store.state.pendingDeletion == nil)
            #expect(store.state.confirmationDialog == nil)
            #expect(store.state[deleteConfirmationFor: Self.second.id] == nil)
            #expect(store.state.savedSearches == [Self.first, Self.second])
        }
    }

    @MainActor
    private static func makeStore() -> TestStoreOf<QuickSearchReducer> {
        let store = TestStore(initialState: QuickSearchReducer.State(), reducer: QuickSearchReducer.init) {
            $0.analyticsClient = .noop
            $0.defaultAppStorage = UserDefaults.inMemory
        }
        // The assertions read the state they are about; the store is not asked to account for every mutation.
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}
