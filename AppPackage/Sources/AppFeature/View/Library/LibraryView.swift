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
        NavigationSplitView {
            List(selection: $store.selection.sending(\.select)) {
                Section {
                    ForEach(-1..<10, id: \.self) { index in
                        NavigationLink(value: LibraryGroup.favorites(index)) {
                            Label(favoritesStore.user.getFavoriteCategory(index: index), systemSymbol: .heart)
                        }
                        .accessibilityIdentifier("library-favorites-\(index)")
                    }
                } header: {
                    Text(.RLocalizable.favorites)
                }

                Section {
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

                    Button {
                        store.send(.manageFolders)
                    } label: {
                        Label(.RLocalizable.manageFolders, systemSymbol: .folderBadgeGearshape)
                    }
                } header: {
                    Text(.RLocalizable.downloads)
                }
            }
            .accessibilityIdentifier("library-categories")
            .navigationTitle(.RLocalizable.library)
            .toolbarTitleDisplayMode(.inlineLarge)
            .scrollEdgeEffectStyle(.soft, for: .top)
        } detail: {
            detail
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
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
