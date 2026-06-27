import SwiftUI
import Resources
import SFSafeSymbols
import ComposableArchitecture
import SwiftUINavigationExt

struct FolderManagerView: View {
    @Bindable private var store: StoreOf<FolderManagerReducer>
    @FocusState private var focusedField: FolderManagerReducer.EditingField?
    @Environment(\.dismiss) private var dismiss

    init(store: StoreOf<FolderManagerReducer>) {
        self.store = store
    }

    var body: some View {
        NavigationView {
            ZStack {
                List {
                    if store.editingField == .newFolder {
                        newFolderRow
                            .padding(5)
                    }
                    ForEach(store.folders, id: \.self) { folder in
                        folderRow(folder)
                            .padding(5)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    store.send(.setNavigation(.deleteFolder(folder)))
                                } label: {
                                    Image(systemSymbol: .trash)
                                }
                                .tint(.red)
                                Button {
                                    store.send(.setEditingField(.renameFolder(folder)))
                                } label: {
                                    Image(systemSymbol: .squareAndPencil)
                                }
                            }
                            .confirmationDialog(
                                message: L10n.Localizable.FolderManagerView.Dialog.Message.deleteFolder,
                                unwrapping: $store.route,
                                case: \.deleteFolder,
                                matching: folder
                            ) { route in
                                Button(L10n.Localizable.ConfirmationDialog.Button.delete, role: .destructive) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        store.send(.deleteFolder(route))
                                    }
                                }
                            }
                    }
                }

                stateOverlay
            }
            .animation(.default, value: store.folders)
            .animation(.default, value: store.editingField)
            .synchronize($store.editingField, $focusedField)
            .onAppear {
                store.send(.fetchFolders)
            }
            .toolbar(content: toolbar)
            .navigationTitle(L10n.Localizable.FolderManagerView.Title.folders)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private var stateOverlay: some View {
        switch store.loadingState {
        case .loading where store.folders.isEmpty:
            LoadingView()

        case .failed(let error):
            ErrorView(error: error) {
                store.send(.fetchFolders)
            }

        case .idle, .loading:
            if store.folders.isEmpty && store.editingField != .newFolder {
                AlertView(
                    symbol: .folder,
                    message: L10n.Localizable.FolderManagerView.EmptyState.folders
                ) {
                    EmptyView()
                }
            }
        }
    }

    private var newFolderRow: some View {
        Label {
            editingTextField(.newFolder)
        } icon: {
            Image(systemSymbol: .folderBadgePlus)
        }
    }

    @ViewBuilder private func folderRow(_ folder: String) -> some View {
        if store.editingField == .renameFolder(folder) {
            Label {
                editingTextField(.renameFolder(folder))
            } icon: {
                Image(systemSymbol: .folder)
            }
        } else {
            Label(folder, systemSymbol: .folder)
        }
    }

    private func editingTextField(_ field: FolderManagerReducer.EditingField) -> some View {
        TextField(
            L10n.Localizable.FolderManagerView.Placeholder.folderName,
            text: $store.editingFolderName
        )
        .disableAutocorrection(true)
        .submitLabel(.done)
        .focused($focusedField, equals: field)
        .onSubmit {
            store.send(.submitEditingField)
        }
    }

    private func toolbar() -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close, action: dismiss.callAsFunction)
            }
            CustomToolbarItem {
                Button {
                    store.send(.setEditingField(.newFolder))
                } label: {
                    Image(systemSymbol: .plus)
                }
            }
        }
    }
}

struct FolderManagerView_Previews: PreviewProvider {
    static var previews: some View {
        FolderManagerView(
            store: .init(initialState: .init(), reducer: FolderManagerReducer.init)
        )
    }
}
