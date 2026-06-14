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

    private static var invalidFolderNameError: AppError {
        .fileOperationFailed(
            L10n.Localizable.DownloadFileStorage.Error.invalidFolderName
        )
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var editingField: EditingField?
        var editingFolderName = ""
        var loadingState: LoadingState = .idle
        var folders = [String]()

        var normalizedEditingFolderName: String? {
            DownloadFileStorage.normalizedUserFolderName(editingFolderName)
        }

        var isEditingNameValid: Bool {
            guard let normalizedName = normalizedEditingFolderName else {
                return false
            }
            switch editingField {
            case .renameFolder(let oldName):
                return normalizedName == oldName || !folders.contains(normalizedName)
            case .newFolder, nil:
                return !folders.contains(normalizedName)
            }
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
                guard let name = state.normalizedEditingFolderName else {
                    state.loadingState = .failed(Self.invalidFolderNameError)
                    return .none
                }
                state.loadingState = .loading
                return .run { send in
                    try await downloadClient.createFolder(name)
                    await send(.createFolderDone(.success(())))
                } catch: { error, send in
                    await send(.createFolderDone(.failure(error as? AppError ?? .unknown)))
                }

            case .createFolderDone(.success):
                return .send(.fetchFolders)

            case .createFolderDone(.failure(let error)):
                state.loadingState = .failed(error)
                return .none

            case .renameFolder(let oldName):
                guard let newName = state.normalizedEditingFolderName else {
                    state.loadingState = .failed(Self.invalidFolderNameError)
                    return .none
                }
                state.loadingState = .loading
                return .run { send in
                    try await downloadClient.renameFolder(oldName, newName)
                    await send(.renameFolderDone(.success(())))
                } catch: { error, send in
                    await send(.renameFolderDone(.failure(error as? AppError ?? .unknown)))
                }

            case .renameFolderDone(.success):
                return .send(.fetchFolders)

            case .renameFolderDone(.failure(let error)):
                state.loadingState = .failed(error)
                return .none

            case .deleteFolder(let name):
                state.loadingState = .loading
                return .run { send in
                    try await downloadClient.deleteFolder(name)
                    await send(.deleteFolderDone(.success(())))
                } catch: { error, send in
                    await send(.deleteFolderDone(.failure(error as? AppError ?? .unknown)))
                }

            case .deleteFolderDone(.success):
                return .send(.fetchFolders)

            case .deleteFolderDone(.failure(let error)):
                state.loadingState = .failed(error)
                return .none

            case .teardown:
                return .cancel(id: CancelID.fetchFolders)

            case .fetchFolders:
                state.loadingState = .loading
                return .run { send in
                    await send(.fetchFoldersDone(try await downloadClient.fetchFolders()))
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
