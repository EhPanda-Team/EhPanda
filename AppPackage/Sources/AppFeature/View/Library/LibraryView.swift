import AppComponents
import AppModels
import ComposableArchitecture
import DownloadsFeature
import FavoritesFeature
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

struct LibraryView: View {
    @Bindable var store: StoreOf<LibraryFeature>
    var favoritesStore: StoreOf<FavoritesReducer>
    var downloadsStore: StoreOf<DownloadsReducer>

    var body: some View {
        Group {
            if store.usesSidebar {
                LibrarySidebarView(
                    store: store, favoritesStore: favoritesStore, downloadsStore: downloadsStore
                )
            } else {
                LibraryDetailView(
                    selection: store.selection, favoritesStore: favoritesStore,
                    downloadsStore: downloadsStore, showsCategoryControls: true
                )
                .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 12) {
                    if showsSourcePicker {
                        LibrarySourcePicker(
                            store: store, favoritesIndex: favoritesStore.favoritesIndex,
                            downloadFilter: downloadsStore.folderFilter
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .onVisibleViewportChange { store.send(.viewportChanged($0)) }
        .background {
            WindowDeviceObservation { store.send(.deviceChanged($0)) }
        }
    }

    private var showsSourcePicker: Bool {
        switch store.selection {
        case .favorites: favoritesStore.path.isEmpty
        case .downloads: downloadsStore.path.isEmpty
        case .none: true
        }
    }
}

private struct LibrarySidebarView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    let store: StoreOf<LibraryFeature>
    let favoritesStore: StoreOf<FavoritesReducer>
    let downloadsStore: StoreOf<DownloadsReducer>

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            LibraryCategoriesList(
                store: store, favoritesStore: favoritesStore, downloadsStore: downloadsStore
            )
        } detail: {
            LibraryDetailView(
                selection: store.selection, favoritesStore: favoritesStore,
                downloadsStore: downloadsStore, showsCategoryControls: false
            )
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .ignoresSafeArea(.container, edges: .top)
    }
}

private struct LibrarySourcePicker: View {
    @Bindable var store: StoreOf<LibraryFeature>
    let favoritesIndex: Int
    let downloadFilter: DownloadFolderFilter

    var body: some View {
        Picker(.RLocalizable.library, selection: $store.selection.sending(\.select)) {
            Label(.RLocalizable.downloads, systemSymbol: .arrowDownCircle)
                .tag(Optional(LibraryGroup.downloads(downloadFilter)))
            Label(.RLocalizable.favorites, systemSymbol: .heart)
                .tag(Optional(LibraryGroup.favorites(favoritesIndex)))
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .fixedSize(horizontal: true, vertical: false)
        .glassEffect(.regular, in: .capsule)
        .accessibilityIdentifier("library-source-picker")
    }
}

private struct LibraryDetailView: View {
    let selection: LibraryGroup?
    let favoritesStore: StoreOf<FavoritesReducer>
    let downloadsStore: StoreOf<DownloadsReducer>
    let showsCategoryControls: Bool

    var body: some View {
        switch selection {
        case .favorites:
            FavoritesView(store: favoritesStore, showsCategoryControls: showsCategoryControls)
        case .downloads:
            DownloadsView(store: downloadsStore, showsFolderManagement: showsCategoryControls)
        case .none:
            ContentUnavailableView {
                Label(.RLocalizable.library, systemSymbol: .booksVertical)
            } description: {
                Text(.RLocalizable.librarySelectionPrompt)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }
}

private struct LibraryCategoriesList: View {
    @Bindable var store: StoreOf<LibraryFeature>
    let favoritesStore: StoreOf<FavoritesReducer>
    let downloadsStore: StoreOf<DownloadsReducer>

    var body: some View {
        List(selection: $store.selection.sending(\.select)) {
            Section(isExpanded: $store.isDownloadsExpanded) {
                ForEach(downloadsStore.folders, id: \.self) { folder in
                    NavigationLink(value: LibraryGroup.downloads(.folder(folder))) {
                        Label(folder, systemSymbol: .folder)
                    }
                    .accessibilityIdentifier("library-downloads-\(folder)")
                }
            } header: {
                Text(.RLocalizable.downloads)
            }
            .sectionActions {
                Button {
                    store.send(.manageFolders)
                } label: {
                    Label(.RLocalizable.manageFolders, systemSymbol: .folderBadgeGearshape)
                }
                .accessibilityIdentifier("library-manage-folders")

                if downloadsStore.folders.isEmpty {
                    Button {
                        store.send(.createDefaultFolder)
                    } label: {
                        Label(.RLocalizable.createDefaultFolder, systemSymbol: .folderBadgePlus)
                    }
                    .disabled(downloadsStore.isCreatingDefaultFolder)
                    .accessibilityIdentifier("library-create-default-folder")
                }
            }

            Section(isExpanded: $store.isFavoritesExpanded) {
                ForEach(-1..<10, id: \.self) { index in
                    NavigationLink(value: LibraryGroup.favorites(index)) {
                        Label(favoritesStore.user.getFavoriteCategory(index: index), systemSymbol: .heart)
                    }
                    .accessibilityIdentifier("library-favorites-\(index)")
                }
            } header: {
                Text(.RLocalizable.favorites)
            }
        }
        .accessibilityIdentifier("library-categories")
        .listStyle(.sidebar)
        .navigationTitle(.RLocalizable.library)
        .toolbarTitleDisplayMode(.inlineLarge)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
