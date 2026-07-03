import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import DownloadClient

@Reducer
public struct FolderManagerReducer: Sendable {
    public enum Dialog: Equatable, Sendable {
        case confirmDelete(String)
    }

    public enum EditingField: Equatable, Hashable {
        case newFolder
        case renameFolder(String)
    }

    private enum CancelID {
        case fetchFolders
    }

    private static var invalidFolderNameError: AppError {
        .fileOperationFailed(
            L10n.Localizable.DownloadStore.invalidFolderName
        )
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var editingField: EditingField?
        public var editingFolderName = ""
        public var loadingState: LoadingState = .idle
        public var folders = [String]()

        public init() {}

        var normalizedEditingFolderName: String? {
            DownloadStore.normalizedUserFolderName(editingFolderName)
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

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case confirmationDialog(PresentationAction<Dialog>)
        case deleteButtonTapped(String)
        case setEditingField(EditingField?)
        case submitEditingField

        case createFolder
        case createFolderDone(Result<Void, AppError>)
        case renameFolder(String)
        case renameFolderDone(Result<Void, AppError>)
        case deleteFolder(String)
        case deleteFolderDone(Result<Void, AppError>)

        case fetchFolders
        case fetchFoldersDone([String])
    }

    @Dependency(\.downloadClient) private var downloadClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .deleteButtonTapped(let folder):
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete(folder)) {
                        TextState(L10n.Localizable.ConfirmationDialog.delete)
                    }
                    ButtonState(role: .cancel) {
                        TextState(L10n.Localizable.Common.cancel)
                    }
                } message: {
                    TextState(String(localized: .deleteFolder))
                }
                return .none

            case .confirmationDialog(.presented(.confirmDelete(let folder))):
                return .send(.deleteFolder(folder))

            case .confirmationDialog:
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
                    await send(.createFolderDone(.failure(AppError(error))))
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
                    await send(.renameFolderDone(.failure(AppError(error))))
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
                    await send(.deleteFolderDone(.failure(AppError(error))))
                }

            case .deleteFolderDone(.success):
                return .send(.fetchFolders)

            case .deleteFolderDone(.failure(let error)):
                state.loadingState = .failed(error)
                return .none

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
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}
