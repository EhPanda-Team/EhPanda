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
    func testCreateFolderForwardsEditingNameAndRefetches() async {
        let createdName = UncheckedBox<String?>(nil)
        let store = makeStore(
            folders: { createdName.value.map { [$0] } ?? [] },
            createFolder: { name in
                createdName.value = name
                return .success(())
            }
        )
        store.exhaustivity = .off

        await store.send(.binding(.set(\.editingFolderName, "Favorites")))
        await store.send(.createFolder)
        await store.receive(\.createFolderDone)
        await store.receive(\.fetchFolders)
        await store.receive(\.fetchFoldersDone) {
            $0.folders = ["Favorites"]
        }

        #expect(createdName.value == "Favorites")
    }

    @MainActor
    @Test
    func testRenameFolderForwardsOriginalAndEditedNames() async {
        let renamedPair = UncheckedBox<(String, String)?>(nil)
        let store = makeStore(
            folders: { ["New Name"] },
            renameFolder: { oldName, newName in
                renamedPair.value = (oldName, newName)
                return .success(())
            }
        )
        store.exhaustivity = .off

        await store.send(.binding(.set(\.editingFolderName, "New Name")))
        await store.send(.renameFolder("Old Name"))
        await store.receive(\.renameFolderDone)
        await store.receive(\.fetchFoldersDone) {
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

        await store.send(.deleteFolder("Doomed"))
        await store.receive(\.deleteFolderDone)
        await store.receive(\.fetchFoldersDone) {
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
        await store.receive(\.createFolder)
        await store.receive(\.createFolderDone)
        await store.receive(\.fetchFoldersDone) {
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
        await store.receive(\.renameFolder)
        await store.receive(\.renameFolderDone)
        await store.receive(\.fetchFoldersDone) {
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
    func testEditingNameValidationRejectsBlankAndDuplicateNames() {
        var state = FolderManagerReducer.State()
        state.folders = ["Existing"]

        state.editingFolderName = "   "
        #expect(state.isEditingNameValid == false)

        state.editingFolderName = "Existing"
        #expect(state.isEditingNameValid == false)

        state.editingFolderName = "Fresh"
        #expect(state.isEditingNameValid)
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
        TestStore(initialState: FolderManagerReducer.State()) {
            FolderManagerReducer()
        } withDependencies: {
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
    }
}
