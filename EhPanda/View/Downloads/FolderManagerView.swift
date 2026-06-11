//
//  FolderManagerView.swift
//  EhPanda
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct FolderManagerView: View {
    @Bindable private var store: StoreOf<FolderManagerReducer>
    @FocusState private var focusedRoute: FolderManagerReducer.Route?
    @Environment(\.dismiss) private var dismiss

    init(store: StoreOf<FolderManagerReducer>) {
        self.store = store
    }

    var body: some View {
        NavigationView {
            ZStack {
                List {
                    if store.route == .newFolder {
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
                    store.loadingState != .loading && store.folders.isEmpty
                        && store.route != .newFolder ? 1 : 0
                )
            }
            .animation(.default, value: store.folders)
            .animation(.default, value: store.route)
            .onChange(of: focusedRoute) { oldValue, newValue in
                if newValue == nil, let oldValue, store.route == oldValue {
                    store.send(.setNavigation(nil))
                }
            }
            .onAppear {
                store.send(.fetchFolders)
            }
            .toolbar(content: toolbar)
            .navigationTitle(L10n.Localizable.FolderManagerView.Title.folders)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var newFolderRow: some View {
        Label {
            editingTextField(route: .newFolder, submitAction: .createFolder)
        } icon: {
            Image(systemSymbol: .folderBadgePlus)
        }
    }

    @ViewBuilder private func folderRow(_ folder: String) -> some View {
        if store.route == .renameFolder(folder) {
            Label {
                editingTextField(route: .renameFolder(folder), submitAction: .renameFolder(folder))
            } icon: {
                Image(systemSymbol: .folder)
            }
        } else {
            Label(folder, systemSymbol: .folder)
        }
    }

    private func editingTextField(
        route: FolderManagerReducer.Route, submitAction: FolderManagerReducer.Action
    ) -> some View {
        TextField(
            L10n.Localizable.FolderManagerView.Placeholder.folderName,
            text: $store.editingFolderName
        )
        .disableAutocorrection(true)
        .submitLabel(.done)
        .focused($focusedRoute, equals: route)
        .onAppear {
            focusedRoute = route
        }
        .onSubmit {
            if store.isEditingNameValid {
                store.send(submitAction)
            }
            store.send(.setNavigation(nil))
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
}

struct FolderManagerView_Previews: PreviewProvider {
    static var previews: some View {
        FolderManagerView(
            store: .init(initialState: .init(), reducer: FolderManagerReducer.init)
        )
    }
}
