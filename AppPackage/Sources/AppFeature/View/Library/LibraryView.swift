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
                        Button {
                            store.send(.select(.favorites(index)))
                        } label: {
                            Label(favoritesStore.user.getFavoriteCategory(index: index), systemSymbol: .heart)
                        }
                        .tag(LibraryGroup.favorites(index))
                    }
                } header: {
                    Text(.RLocalizable.favorites)
                }

                Section {
                    Button {
                        store.send(.select(.downloads(.all)))
                    } label: {
                        Label(.RLocalizable.downloads, systemSymbol: .arrowDownCircle)
                    }
                    .tag(LibraryGroup.downloads(.all))

                    ForEach(downloadsStore.folders, id: \.self) { folder in
                        Button {
                            store.send(.select(.downloads(.folder(folder))))
                        } label: {
                            Label(folder, systemSymbol: .folder)
                        }
                        .tag(LibraryGroup.downloads(.folder(folder)))
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
            .navigationTitle(.RLocalizable.library)
            .toolbarTitleDisplayMode(.inlineLarge)
            .scrollEdgeEffectStyle(.soft, for: .top)
        } detail: {
            detail
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
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
