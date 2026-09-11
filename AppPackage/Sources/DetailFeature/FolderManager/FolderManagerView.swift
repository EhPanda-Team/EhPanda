import AppComponents
import ComposableArchitecture
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

public struct FolderManagerView: View {
    @Bindable private var store: StoreOf<FolderManagerReducer>
    @FocusState private var focusedField: FolderManagerReducer.EditingField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<FolderManagerReducer>) {
        self.store = store
    }

    /// Folders come and go as whole rows, and `editingField == .newFolder` inserts the new-folder
    /// row at the top, pushing every folder row down — position motion, instant under Reduce Motion
    /// (D-29). The rename swap is in place, but it rides the same keyed animation, so it goes with it.
    private var listAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    public var body: some View {
        NavigationStack {
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
                                store.send(.deleteButtonTapped(folder))
                            } label: {
                                Label(.RLocalizable.delete, systemSymbol: .trash)
                                    .labelStyle(.iconOnly)
                            }
                            .tint(.red)

                            Button {
                                store.send(.setEditingField(.renameFolder(folder)))
                            } label: {
                                Label(.renameFolder, systemSymbol: .squareAndPencil)
                                    .labelStyle(.iconOnly)
                            }
                        }
                }
            }
            .overlay(content: { stateOverlay })
            .confirmationDialog(
                $store.scope(\.$confirmationDialog, action: \.confirmationDialog)
            )
            .animation(listAnimation, value: store.folders)
            .animation(listAnimation, value: store.editingField)
            .synchronize($store.editingField, $focusedField)
            .toolbar(content: toolbar)
            .navigationTitle(.folders)
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
                ContentUnavailableView {
                    Label(.emptyFolders, systemSymbol: .folder)
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
        .labelStyle(FolderRowLabelStyle())
    }

    @ViewBuilder private func folderRow(_ folder: String) -> some View {
        if store.editingField == .renameFolder(folder) {
            Label {
                editingTextField(.renameFolder(folder))
            } icon: {
                Image(systemSymbol: .folder)
            }
            .labelStyle(FolderRowLabelStyle())
        } else {
            Label(folder, systemSymbol: .folder)
                .labelStyle(FolderRowLabelStyle())
        }
    }

    private func editingTextField(_ field: FolderManagerReducer.EditingField) -> some View {
        TextField(
            .folderName,
            text: $store.editingFolderName
        )
        .autocorrectionDisabled(true)
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    store.send(.setEditingField(.newFolder))
                } label: {
                    Label(.newFolder, systemSymbol: .plus)
                }
            }
        }
    }
}

private struct FolderRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            configuration.title
        }
    }
}

#Preview("Initial") {
    FolderManagerView(
        store: .init(
            initialState: {
                var state = FolderManagerReducer.State()
                state.folders = ["Favorites", "To Read", "Archive"]
                return state
            }(),
            reducer: FolderManagerReducer.init
        )
    )
}
