import AppModels
import ComposableArchitecture
import DownloadsFeature
import FavoritesFeature
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

struct LibraryView: View {
    @Bindable private var store: StoreOf<LibraryFeature>
    @Bindable private var favoritesStore: StoreOf<FavoritesReducer>
    @Bindable private var downloadsStore: StoreOf<DownloadsReducer>

    init(
        store: StoreOf<LibraryFeature>,
        favoritesStore: StoreOf<FavoritesReducer>,
        downloadsStore: StoreOf<DownloadsReducer>
    ) {
        self.store = store
        self.favoritesStore = favoritesStore
        self.downloadsStore = downloadsStore
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $store.selection.sending(\.select)) {
                Section(isExpanded: $store.isDownloadsExpanded) {
                    NavigationLink(value: LibraryGroup.downloads(.all)) {
                        Label(.RLocalizable.downloads, systemSymbol: .arrowDownCircle)
                    }
                    .accessibilityIdentifier("library-downloads-all")

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
            .toolbar(removing: .sidebarToggle)
            .navigationTitle(.RLocalizable.library)
            .toolbarTitleDisplayMode(.inlineLarge)
            .scrollEdgeEffectStyle(.soft, for: .top)
        } detail: {
            detail
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .ignoresSafeArea(.container, edges: .top)
    }

    @ViewBuilder private var detail: some View {
        switch store.selection {
        case .favorites:
            FavoritesView(store: favoritesStore)
        case .downloads:
            DownloadsView(store: downloadsStore)
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
