//
//  FolderManagerView.swift
//  EhPanda
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct FolderManagerView: View {
    @Bindable private var store: StoreOf<FolderManagerReducer>
    @FocusState private var renamingFolderName: String?
    @Environment(\.dismiss) private var dismiss

    init(store: StoreOf<FolderManagerReducer>) {
        self.store = store
    }

    var body: some View {
        NavigationView {
            ZStack {
                List {
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
                                    store.editingFolderName = folder
                                    store.send(.setNavigation(.renameFolder(folder)))
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

                LoadingView().opacity(
                    store.loadingState == .loading && store.folders.isEmpty ? 1 : 0
                )
                AlertView(
                    symbol: .folder,
                    message: L10n.Localizable.FolderManagerView.EmptyState.folders
                ) {
                    EmptyView()
                }
                .opacity(
                    store.loadingState != .loading && store.folders.isEmpty ? 1 : 0
                )
            }
            .animation(.default, value: store.folders)
            .onChange(of: renamingFolderName) { oldValue, newValue in
                if newValue == nil, let oldValue, store.route == .renameFolder(oldValue) {
                    store.send(.setNavigation(nil))
                }
            }
            .onAppear {
                store.send(.fetchFolders)
            }
            .toolbar(content: toolbar)
            .background(navigationLinks)
            .navigationTitle(L10n.Localizable.FolderManagerView.Title.folders)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private func folderRow(_ folder: String) -> some View {
        if store.route == .renameFolder(folder) {
            Label {
                TextField(
                    L10n.Localizable.FolderManagerView.Placeholder.folderName,
                    text: $store.editingFolderName
                )
                .disableAutocorrection(true)
                .submitLabel(.done)
                .focused($renamingFolderName, equals: folder)
                .onAppear {
                    renamingFolderName = folder
                }
                .onSubmit {
                    if store.isEditingNameValid {
                        store.send(.renameFolder(folder))
                    }
                    store.send(.setNavigation(nil))
                }
            } icon: {
                Image(systemSymbol: .folder)
            }
        } else {
            Label(folder, systemSymbol: .folder)
        }
    }

    private func toolbar() -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close, action: dismiss.callAsFunction)
            }
            CustomToolbarItem {
                Button {
                    store.editingFolderName = ""
                    store.send(.setNavigation(.newFolder))
                } label: {
                    Image(systemSymbol: .plus)
                }
            }
        }
    }

    @ViewBuilder private var navigationLinks: some View {
        NavigationLink(unwrapping: $store.route, case: \.newFolder) { _ in
            EditFolderView(
                title: L10n.Localizable.FolderManagerView.Title.newFolder,
                folderName: $store.editingFolderName,
                isNameValid: store.isEditingNameValid,
                confirmAction: {
                    store.send(.createFolder)
                    store.send(.setNavigation(nil))
                }
            )
        }
    }
}

extension FolderManagerView {
    // MARK: EditFolderView
    struct EditFolderView: View {
        private let title: String
        @Binding private var folderName: String
        private let isNameValid: Bool
        private let confirmAction: () -> Void

        init(
            title: String,
            folderName: Binding<String>,
            isNameValid: Bool,
            confirmAction: @escaping () -> Void
        ) {
            self.title = title
            _folderName = folderName
            self.isNameValid = isNameValid
            self.confirmAction = confirmAction
        }

        var body: some View {
            Form {
                Section {
                    TextField(
                        L10n.Localizable.FolderManagerView.Placeholder.folderName,
                        text: $folderName
                    )
                    .disableAutocorrection(true)
                }
            }
            .toolbar(content: toolbar)
            .navigationTitle(title)
        }

        private func toolbar() -> some ToolbarContent {
            CustomToolbarItem {
                Button(role: .confirm, action: confirmAction)
                    .disabled(!isNameValid)
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
