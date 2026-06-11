//
//  FolderManagerReducer.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct FolderManagerReducer {
    @CasePathable
    enum Route: Equatable {
        case deleteFolder(String)
    }

    enum EditingField: Equatable, Hashable {
        case newFolder
        case renameFolder(String)
    }

    private enum CancelID {
        case fetchFolders
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var editingField: EditingField?
        var editingFolderName = ""
        var loadingState: LoadingState = .idle
        var folders = [String]()

        var isEditingNameValid: Bool {
            let trimmedName = editingFolderName
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedName.isEmpty && !folders.contains(trimmedName)
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case setEditingField(EditingField?)
        case submitEditingField

        case createFolder
        case createFolderDone(Result<Void, AppError>)
        case renameFolder(String)
        case renameFolderDone(Result<Void, AppError>)
        case deleteFolder(String)
        case deleteFolderDone(Result<Void, AppError>)

        case teardown
        case fetchFolders
        case fetchFoldersDone([String])
    }

    @Dependency(\.downloadClient) private var downloadClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .setEditingField(let editingField):
                state.editingField = editingField
                switch editingField {
                case .renameFolder(let folderName):
                    state.editingFolderName = folderName
                case .newFolder, nil:
                    state.editingFolderName = ""
                }
                return .none

            case .submitEditingField:
                let editingField = state.editingField
                state.editingField = nil
                guard state.isEditingNameValid else { return .none }
                switch editingField {
                case .newFolder:
                    return .send(.createFolder)
                case .renameFolder(let oldName):
                    return .send(.renameFolder(oldName))
                case nil:
                    return .none
                }

            case .createFolder:
                return .run { [name = state.editingFolderName] send in
                    await send(.createFolderDone(await downloadClient.createFolder(name)))
                }

            case .createFolderDone:
                return .send(.fetchFolders)

            case .renameFolder(let oldName):
                return .run { [newName = state.editingFolderName] send in
                    await send(.renameFolderDone(await downloadClient.renameFolder(oldName, newName)))
                }

            case .renameFolderDone:
                return .send(.fetchFolders)

            case .deleteFolder(let name):
                return .run { send in
                    await send(.deleteFolderDone(await downloadClient.deleteFolder(name)))
                }

            case .deleteFolderDone:
                return .send(.fetchFolders)

            case .teardown:
                return .cancel(id: CancelID.fetchFolders)

            case .fetchFolders:
                state.loadingState = .loading
                return .run { send in
                    await send(.fetchFoldersDone(await downloadClient.fetchFolders()))
                }
                .cancellable(id: CancelID.fetchFolders, cancelInFlight: true)

            case .fetchFoldersDone(let folders):
                state.loadingState = .idle
                state.folders = folders
                return .none
            }
        }
    }
}
