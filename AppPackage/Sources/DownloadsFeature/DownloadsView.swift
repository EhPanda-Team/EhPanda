import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import DetailFeature
import ReadingFeature
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

public struct DownloadsView: View {
    @Bindable private var store: StoreOf<DownloadsReducer>

    public init(store: StoreOf<DownloadsReducer>) {
        self.store = store
    }

    public var body: some View {
        GalleryNavigationContainer(
            store: store,
            state: \.path,
            action: \.path
        ) {
            downloadsList
                .overlay {
                    emptyStateView
                        .padding(.horizontal, 24)
                        .animation(.default) {
                            $0.opacity(showsEmptyState ? 1 : 0)
                        }
                }
                .searchable(text: $store.keyword, placement: .navigationBarDrawer)
                .sheet(
                    item: $store.scope(\.$destination, action: \.destination).inspector
                ) { store in
                    NavigationStack {
                        DownloadInspectorView(store: store)
                    }
                    .privacyMask()
                }
                .sheet(
                    item: $store.scope(\.$destination, action: \.destination).folderManager
                ) { folderStore in
                    FolderManagerView(store: folderStore)
                        .privacyMask()
                }
                .fullScreenCover(
                    item: $store.scope(\.$destination, action: \.destination).reading
                ) { store in
                    ReadingView(store: store)
                    .privacyMask()
                }
                // The delete confirmation is per-row and lives on the row (see `DownloadRow`);
                // this one is the list-level move-to-folder dialog.
                .confirmationDialog(
                    $store.scope(\.$confirmationDialog, action: \.confirmationDialog)
                )
                .navigationTitle(.RLocalizable.downloads)
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar(content: toolbar)
        }
    }
}

// MARK: Subviews
private extension DownloadsView {
    @ViewBuilder private var downloadsList: some View {
        switch store.loadingState {
        case .loading where store.downloads.isEmpty:
            LoadingView()

        case .failed(let error) where store.downloads.isEmpty:
            ErrorView(error: error, action: { store.send(.fetchDownloads) })

        default:
            List {
                // Scoped per row so each one carries its own delete confirmation. The collection
                // is filtered rather than the state, because `.forEach` composes over the stored
                // rows: a row hidden by the keyword or folder filter still exists, it is simply
                // not rendered. Keyed on `state.id` because a `Store` is `Identifiable` by its own
                // object identity, which is not the row's gid.
                ForEach(visibleRows, id: \.state.id) { rowStore in
                    DownloadRow(store: store, rowStore: rowStore)
                }
            }
            .refreshable { store.send(.refreshDownloads) }
            // Scoped to row IDENTITY, never to the snapshot: `observeDownloads` re-emits the whole
            // list as pages land, so animating on `filteredDownloads` would animate every progress
            // tick. Keyed on the id list, only membership moves — a confirmed delete, a folder or
            // keyword filter change — so the deletion reads as the standard List collapse instead
            // of the snapshot snapping the row out with no transition at all.
            .animation(.default, value: store.filteredDownloads.map(\.id))
        }
    }

    private var showsEmptyState: Bool {
        store.loadingState == .idle && store.filteredDownloads.isEmpty
    }

    /// The row stores the current keyword and folder filter admit.
    private var visibleRows: [StoreOf<DownloadRowFeature>] {
        let visible = Set(store.filteredDownloads.map(\.id))
        return store.scope(\.rows, action: \.rows).filter({ visible.contains($0.state.id) })
    }

    @ViewBuilder private var emptyStateView: some View {
        if store.downloads.isEmpty {
            ContentUnavailableView {
                Label(.emptyDownloads, systemSymbol: .squareAndArrowDown)
            }
        } else {
            ContentUnavailableView {
                Label(.noMatchingFilters, systemSymbol: .line3HorizontalDecreaseCircle)
            } actions: {
                Button(.clearFilters) {
                    store.keyword = ""
                    store.folderFilter = .all
                }
                .buttonStyle(.glass(.regular.tint(.init(.systemGray5))))
                .padding()
            }
        }
    }

    @ToolbarContentBuilder private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Menu {
                Section {
                    Button {
                        store.send(.folderManagerButtonTapped)
                    } label: {
                        Label(
                            .RLocalizable.manageFolders,
                            systemSymbol: .folderBadgeGearshape
                        )
                    }
                }
                Section {
                    folderFilterButton(.all)
                    ForEach(store.folders, id: \.self) { folder in
                        folderFilterButton(.folder(folder))
                    }
                }
            } label: {
                Label(.RLocalizable.filters, systemSymbol: .dialLow)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private func folderFilterButton(_ filter: DownloadFolderFilter) -> some View {
        Button {
            store.folderFilter = filter
        } label: {
            Text(filter.title)
            if store.folderFilter == filter {
                Image(systemSymbol: .checkmark)
            }
        }
    }
}

// MARK: DownloadRow
/// One row of the list, bound to its own ``DownloadRowFeature`` store.
///
/// The row takes both stores on purpose. `rowStore` carries the delete confirmation and the intent
/// that presents it, because that is the only per-row presentation state on this screen. Inspect,
/// move, update, pause, open and the detail route are list-level actions with no per-row state
/// behind them, so they keep going to `store` instead of taking a delegate hop through the child
/// that would relocate them without simplifying anything.
///
/// The dialog is attached here, to the row, because that is where a per-row store exists. That is
/// in tension with the project's placement rule, which prefers the enclosing list container for a
/// per-row destructive action: a row that leaves the hierarchy while its dialog is up takes the
/// dialog with it. The tension is the price of per-row state, and it buys the popover anchoring to
/// the row the user actually swiped rather than to the list as a whole.
private struct DownloadRow: View {
    let store: StoreOf<DownloadsReducer>
    @Bindable var rowStore: StoreOf<DownloadRowFeature>

    private var download: DownloadedGallery { rowStore.download }

    var body: some View {
        DownloadListRow(
            download: download
        ) {
            store.send(.openReading(download.gid))
        }
        .contextMenu {
            downloadContextMenu()
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            inspectButton

            if canMove {
                moveButton
                    .tint(.teal)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if download.canTriggerUpdate {
                updateButton
                    .tint(.orange)
            }

            if download.canTogglePause {
                pauseButton
                    .tint(download.displayStatus == .inactive ? .accentColor : .indigo)
            }

            // Passed `nil` deliberately, and tinted instead — the one place the two surfaces
            // differ, which is why the role is a parameter rather than baked into the shared
            // button. `Button(role: .destructive)` inside `.swipeActions` makes SwiftUI play
            // an optimistic row-removal the instant the button is tapped — before, and
            // regardless of, any data mutation. This button mutates nothing: it only presents
            // a confirmation dialog. So the row vanished on tap, reappeared behind the dialog
            // (the next diff still contains it), and vanished a third time when the real
            // deletion arrived through the observe stream. The tint carries the red the role
            // was supplying, which is the only effect Apple documents for it here. The
            // dialog's Delete and the context-menu Delete KEEP their roles — neither surface
            // has the optimistic-removal behavior. Both sides are pinned by
            // `DownloadsSwipeActionSourceTests`.
            deleteButton(role: nil)
                .tint(.red)
        }
        .confirmationDialog(
            $rowStore.scope(\.$confirmationDialog, action: \.confirmationDialog)
        )
    }
}

// MARK: DownloadRow buttons
/// Each row action is defined once and used on both surfaces.
///
/// The swipe actions and the context menu offer the same operations, so writing them out twice
/// meant every change had to be made twice and any divergence between the two was invisible in
/// review. Styling stays at the call site instead of inside the button: `.tint` is meaningful on a
/// swipe action and not in a menu, and delete's role is a parameter because that difference is
/// deliberate rather than incidental — see the call site in the trailing swipe.
///
/// Move is the exception and stays two buttons. The swipe opens the list's folder dialog; the menu
/// inlines the destinations as a submenu. Those are different affordances, not one affordance
/// rendered twice, so folding them together would mean inventing a third behaviour.
private extension DownloadRow {
    var canMove: Bool {
        download.displayStatus != .active && !moveDestinations.isEmpty
    }

    var moveDestinations: [String] {
        store.folders.filter({ $0 != download.folderName })
    }

    var detailButton: some View {
        Button {
            store.send(.galleryTapped(download.gid))
        } label: {
            Label(
                .RLocalizable.detail,
                systemSymbol: .infoCircle
            )
        }
    }

    var inspectButton: some View {
        Button {
            store.send(.inspectorButtonTapped(download.gid))
        } label: {
            Label(
                .inspectPages,
                systemSymbol: .listBulletRectanglePortrait
            )
        }
    }

    var moveButton: some View {
        Button {
            store.send(.moveButtonTapped(download))
        } label: {
            Label(
                .move,
                systemSymbol: .folder
            )
        }
    }

    var moveMenu: some View {
        Menu {
            ForEach(moveDestinations, id: \.self) { folder in
                Button(folder) {
                    store.send(.moveDownload(gid: download.gid, folderName: folder))
                }
            }
        } label: {
            Label(
                .moveToFolder,
                systemSymbol: .folder
            )
        }
    }

    var updateButton: some View {
        Button {
            store.send(.updateDownload(download.gid))
        } label: {
            Label(
                .RLocalizable.update,
                systemSymbol: .arrowTrianglehead2ClockwiseRotate90
            )
        }
    }

    var pauseButton: some View {
        Button {
            store.send(.toggleDownloadPause(download.gid))
        } label: {
            Label(
                download.displayStatus == .inactive
                    ? .resume
                    : .pause,
                systemSymbol: download.displayStatus == .inactive
                    ? .playFill
                    : .pauseFill
            )
        }
    }

    func deleteButton(role: ButtonRole?) -> some View {
        Button(role: role) {
            rowStore.send(.deleteButtonTapped)
        } label: {
            Label(.RLocalizable.delete, systemSymbol: .trash)
        }
    }

    @ViewBuilder func downloadContextMenu() -> some View {
        detailButton
        inspectButton

        if canMove {
            moveMenu
        }

        if download.canTriggerUpdate {
            updateButton
        }

        if download.canTogglePause {
            pauseButton
        }

        deleteButton(role: .destructive)
    }
}

#Preview("Initial") {
    DownloadsView(
        store: .init(
            initialState: {
                func manifest(gid: String, title: String, rating: Float, pageCount: Int) -> DownloadManifest {
                    .init(
                        gid: gid, host: .ehentai, token: "", title: title, jpnTitle: nil,
                        category: .doujinshi, language: .english, remoteCoverURL: nil,
                        uploader: "Anonymous", tags: [], postedDate: .now, rating: rating,
                        pages: Dictionary(uniqueKeysWithValues: (1...pageCount).map { ($0, "") })
                    )
                }
                var state = DownloadsReducer.State()
                state.loadingState = .idle
                state.downloads = [
                    .init(
                        manifest: manifest(gid: "1", title: "Sample Download 1", rating: 4.5, pageCount: 24),
                        folderURL: .mock, folderName: "[1] Sample Download 1",
                        localCoverURL: nil, localPageURLs: [:], modificationDate: .now,
                        displayStatus: .completed
                    ),
                    .init(
                        manifest: manifest(gid: "2", title: "Sample Download 2", rating: 3.0, pageCount: 40),
                        folderURL: .mock, folderName: "[2] Sample Download 2",
                        localCoverURL: nil, localPageURLs: [:], modificationDate: .now,
                        displayStatus: .active
                    )
                ]
                return state
            }(),
            reducer: DownloadsReducer.init
        )
    )
}
