import AnalyticsClient
import ComposableArchitecture
@testable import DetailFeature
import DownloadClient
import Foundation
import Testing

/// The Delete Folder confirmation belongs to one folder row (the owner's C7 item, 19-13). The reducer keeps one
/// dialog and the folder it was asked for, and exposes the dialog only for that folder, so each row can attach its own
/// `.confirmationDialog` and the iPad's popover points at the row.
///
/// `@MainActor` is on the cases that build a `TestStore`, whose `init` and `state` are main-actor-isolated.
struct FolderManagerDeleteConfirmationTests {
    @MainActor
    @Test
    func deleteButtonTappedExposesTheDialogForThatFolderOnly() async {
        let store = Self.makeStore()

        await store.send(.deleteButtonTapped("A"))

        #expect(store.state.pendingDeletion == "A")
        #expect(store.state[deleteConfirmationFor: "A"] != nil)
        #expect(store.state[deleteConfirmationFor: "A"] == store.state.confirmationDialog)
        #expect(store.state[deleteConfirmationFor: "B"] == nil)
    }

    @MainActor
    @Test
    func tappingDeleteOnAnotherFolderMovesTheDialogToIt() async {
        let store = Self.makeStore()

        await store.send(.deleteButtonTapped("A"))
        await store.send(.deleteButtonTapped("B"))

        #expect(store.state[deleteConfirmationFor: "A"] == nil)
        #expect(store.state[deleteConfirmationFor: "B"] != nil)
    }

    @MainActor
    @Test
    func confirmingDeletesTheTargetedFolderOnly() async {
        let deleted = LockIsolated<[String]>([])
        let store = Self.makeStore(deleteFolder: { name in deleted.withValue({ $0.append(name) }) })

        await store.send(.deleteButtonTapped("A"))
        await store.send(.confirmationDialog(.presented(.confirmDelete("A"))))
        await store.receive(\.deleteFolderDone)
        await store.skipReceivedActions(strict: false)

        #expect(deleted.value == ["A"])
        #expect(store.state.pendingDeletion == nil)
        #expect(store.state.confirmationDialog == nil)
        #expect(store.state[deleteConfirmationFor: "A"] == nil)
    }

    @MainActor
    @Test
    func dismissingClearsTheDialogAndTheTarget() async {
        let deleted = LockIsolated<[String]>([])
        let store = Self.makeStore(deleteFolder: { name in deleted.withValue({ $0.append(name) }) })

        await store.send(.deleteButtonTapped("A"))
        await store.send(.confirmationDialog(.dismiss))

        #expect(store.state.pendingDeletion == nil)
        #expect(store.state.confirmationDialog == nil)
        #expect(store.state[deleteConfirmationFor: "A"] == nil)
        #expect(deleted.value.isEmpty)
    }

    @MainActor
    private static func makeStore(
        deleteFolder: @escaping @Sendable (String) async throws -> Void = { _ in }
    ) -> TestStoreOf<FolderManagerReducer> {
        let store = TestStore(initialState: FolderManagerReducer.State(), reducer: FolderManagerReducer.init) {
            $0.analyticsClient = .noop
            $0.downloadClient = DownloadClient()
            $0.downloadClient.fetchFolders = { [] }
            $0.downloadClient.deleteFolder = deleteFolder
        }
        // The assertions read the state they are about; the store is not asked to account for every mutation.
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}
