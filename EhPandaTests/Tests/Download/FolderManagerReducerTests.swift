//
//  FolderManagerReducerTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct FolderManagerReducerTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testFetchFoldersPopulatesState() async {
        let store = makeStore(folders: { ["Alpha", "Beta"] })

        await store.send(.fetchFolders) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchFoldersDone, ["Alpha", "Beta"]) {
            $0.loadingState = .idle
            $0.folders = ["Alpha", "Beta"]
        }
    }

    @MainActor
    @Test
    func testCreateFolderForwardsNormalizedEditingNameAndRefetches() async {
        let createdName = UncheckedBox<String?>(nil)
        let store = makeStore(
            folders: { createdName.value.map { [$0] } ?? [] },
            createFolder: { name in
                createdName.value = name
                return .success(())
            }
        )
        store.exhaustivity = .off

        await store.send(.binding(.set(\.editingFolderName, " Favorites/2026 ")))
        await store.send(.createFolder) {
            $0.loadingState = .loading
        }
        await store.receive(\.createFolderDone)
        await store.receive(\.fetchFolders)
        await store.receive(\.fetchFoldersDone) {
            $0.loadingState = .idle
            $0.folders = ["Favorites 2026"]
        }

        #expect(createdName.value == "Favorites 2026")
    }

    @MainActor
    @Test
    func testRenameFolderForwardsOriginalAndNormalizedEditedNames() async {
        let renamedPair = UncheckedBox<(String, String)?>(nil)
        let store = makeStore(
            folders: { ["New Name"] },
            renameFolder: { oldName, newName in
                renamedPair.value = (oldName, newName)
                return .success(())
            }
        )
        store.exhaustivity = .off

        await store.send(.binding(.set(\.editingFolderName, " New/Name ")))
        await store.send(.renameFolder("Old Name")) {
            $0.loadingState = .loading
        }
        await store.receive(\.renameFolderDone)
        await store.receive(\.fetchFolders)
        await store.receive(\.fetchFoldersDone) {
            $0.loadingState = .idle
            $0.folders = ["New Name"]
        }

        #expect(renamedPair.value?.0 == "Old Name")
        #expect(renamedPair.value?.1 == "New Name")
    }

    @MainActor
    @Test
    func testDeleteFolderForwardsNameAndRefetches() async {
        let deletedName = UncheckedBox<String?>(nil)
        let store = makeStore(
            folders: { deletedName.value == nil ? ["Doomed"] : [] },
            deleteFolder: { name in
                deletedName.value = name
                return .success(())
            }
        )
        store.exhaustivity = .off

        await store.send(.deleteFolder("Doomed")) {
            $0.loadingState = .loading
        }
        await store.receive(\.deleteFolderDone)
        await store.receive(\.fetchFolders)
        await store.receive(\.fetchFoldersDone) {
            $0.loadingState = .idle
            $0.folders = []
        }

        #expect(deletedName.value == "Doomed")
    }

    @MainActor
    @Test
    func testSetEditingFieldPrefillsAndClearsEditingName() async {
        let store = makeStore(folders: { [] })

        await store.send(.setEditingField(.renameFolder("Old Name"))) {
            $0.editingField = .renameFolder("Old Name")
            $0.editingFolderName = "Old Name"
        }
        await store.send(.setEditingField(.newFolder)) {
            $0.editingField = .newFolder
            $0.editingFolderName = ""
        }
        await store.send(.binding(.set(\.editingFolderName, "Drafted"))) {
            $0.editingFolderName = "Drafted"
        }
        await store.send(.setEditingField(nil)) {
            $0.editingField = nil
            $0.editingFolderName = ""
        }
    }

    @MainActor
    @Test
    func testSubmitEditingFieldCreatesFolderWhenNameIsValid() async {
        let createdName = UncheckedBox<String?>(nil)
        let store = makeStore(
            folders: { createdName.value.map { [$0] } ?? [] },
            createFolder: { name in
                createdName.value = name
                return .success(())
            }
        )
        store.exhaustivity = .off

        await store.send(.setEditingField(.newFolder)) {
            $0.editingField = .newFolder
        }
        await store.send(.binding(.set(\.editingFolderName, "Favorites")))
        await store.send(.submitEditingField) {
            $0.editingField = nil
        }
        await store.receive(\.createFolder) {
            $0.loadingState = .loading
        }
        await store.receive(\.createFolderDone)
        await store.receive(\.fetchFolders)
        await store.receive(\.fetchFoldersDone) {
            $0.loadingState = .idle
            $0.folders = ["Favorites"]
        }

        #expect(createdName.value == "Favorites")
    }

    @MainActor
    @Test
    func testSubmitEditingFieldRenamesFolderWithOriginalName() async {
        let renamedPair = UncheckedBox<(String, String)?>(nil)
        let store = makeStore(
            folders: { renamedPair.value == nil ? ["Old Name"] : ["New Name"] },
            renameFolder: { oldName, newName in
                renamedPair.value = (oldName, newName)
                return .success(())
            }
        )
        store.exhaustivity = .off

        await store.send(.setEditingField(.renameFolder("Old Name"))) {
            $0.editingField = .renameFolder("Old Name")
            $0.editingFolderName = "Old Name"
        }
        await store.send(.binding(.set(\.editingFolderName, "New Name")))
        await store.send(.submitEditingField) {
            $0.editingField = nil
        }
        await store.receive(\.renameFolder) {
            $0.loadingState = .loading
        }
        await store.receive(\.renameFolderDone)
        await store.receive(\.fetchFolders)
        await store.receive(\.fetchFoldersDone) {
            $0.loadingState = .idle
            $0.folders = ["New Name"]
        }

        #expect(renamedPair.value?.0 == "Old Name")
        #expect(renamedPair.value?.1 == "New Name")
    }

    @MainActor
    @Test
    func testSubmitEditingFieldWithInvalidNameOnlyDismissesField() async {
        let store = makeStore(folders: { [] })

        await store.send(.setEditingField(.newFolder)) {
            $0.editingField = .newFolder
        }
        await store.send(.submitEditingField) {
            $0.editingField = nil
        }
    }

    @MainActor
    @Test
    func testEditingNameValidationRejectsBlankAndNormalizedDuplicateNames() {
        var state = FolderManagerReducer.State()
        state.folders = ["Existing", "a b c"]

        state.editingFolderName = "   "
        #expect(state.isEditingNameValid == false)

        state.editingFolderName = "Existing"
        #expect(state.isEditingNameValid == false)

        state.editingFolderName = "a/b:c"
        #expect(state.isEditingNameValid == false)

        state.editingFolderName = "Fresh"
        #expect(state.isEditingNameValid)
    }

    @MainActor
    @Test
    func testRenameValidationAllowsNormalizedCurrentFolderName() {
        var state = FolderManagerReducer.State()
        state.editingField = .renameFolder("a b c")
        state.folders = ["a b c"]
        state.editingFolderName = "a/b:c"

        #expect(state.isEditingNameValid)
    }

    @MainActor
    @Test
    func testCreateFolderFailureSetsFailedStateWithoutRefetching() async {
        let fetchCount = UncheckedBox(0)
        let error = AppError.fileOperationFailed("disk full")
        let store = makeStore(
            folders: {
                fetchCount.value += 1
                return []
            },
            createFolder: { _ in .failure(error) }
        )

        await store.send(.binding(.set(\.editingFolderName, "Favorites"))) {
            $0.editingFolderName = "Favorites"
        }
        await store.send(.createFolder) {
            $0.loadingState = .loading
        }
        await store.receive(\.createFolderDone) {
            $0.loadingState = .failed(error)
        }
        #expect(fetchCount.value == 0)
    }

    @MainActor
    @Test
    func testRenameFolderFailureSetsFailedStateWithoutRefetching() async {
        let fetchCount = UncheckedBox(0)
        let error = AppError.fileOperationFailed("folder busy")
        let store = makeStore(
            folders: {
                fetchCount.value += 1
                return []
            },
            renameFolder: { _, _ in .failure(error) }
        )

        await store.send(.binding(.set(\.editingFolderName, "New Name"))) {
            $0.editingFolderName = "New Name"
        }
        await store.send(.renameFolder("Old Name")) {
            $0.loadingState = .loading
        }
        await store.receive(\.renameFolderDone) {
            $0.loadingState = .failed(error)
        }
        #expect(fetchCount.value == 0)
    }

    @MainActor
    @Test
    func testDeleteFolderFailureSetsFailedStateWithoutRefetching() async {
        let fetchCount = UncheckedBox(0)
        let error = AppError.fileOperationFailed("permission denied")
        let store = makeStore(
            folders: {
                fetchCount.value += 1
                return []
            },
            deleteFolder: { _ in .failure(error) }
        )

        await store.send(.deleteFolder("Doomed")) {
            $0.loadingState = .loading
        }
        await store.receive(\.deleteFolderDone) {
            $0.loadingState = .failed(error)
        }
        #expect(fetchCount.value == 0)
    }
}

// MARK: - Store Factory Helpers

private extension FolderManagerReducerTests {
    func makeStore(
        folders: @escaping @Sendable () -> [String],
        createFolder: @escaping @Sendable (String) async -> Result<Void, AppError>
        = { _ in .success(()) },
        renameFolder: @escaping @Sendable (String, String) async -> Result<Void, AppError>
        = { _, _ in .success(()) },
        deleteFolder: @escaping @Sendable (String) async -> Result<Void, AppError>
        = { _ in .success(()) }
    ) -> TestStoreOf<FolderManagerReducer> {
        TestStore(
            initialState: FolderManagerReducer.State(),
            reducer: FolderManagerReducer.init,
            withDependencies: {
                $0.downloadClient = .init(
                    observeDownloads: {
                        AsyncStream { continuation in continuation.finish() }
                    },
                    fetchDownloads: { [] },
                    fetchDownload: { _ in nil },
                    refreshDownloads: {},
                    resumeQueue: {},
                    badges: { _ in [:] },
                    enqueue: { _ in .success(()) },
                    togglePause: { _ in .success(()) },
                    retry: { _, _ in .success(()) },
                    delete: { _ in .success(()) },
                    loadManifest: { _ in .failure(.notFound) },
                    fetchFolders: { folders() },
                    createFolder: createFolder,
                    renameFolder: renameFolder,
                    deleteFolder: deleteFolder
                )
            }
        )
    }
}
