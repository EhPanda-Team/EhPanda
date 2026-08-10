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
                            $0.opacity(store.loadingState == .idle && store.filteredDownloads.isEmpty ? 1 : 0)
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
                .appAlert($store.scope(\.$alert, action: \.alert))
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
                ForEach(store.filteredDownloads) { download in
                    DownloadListRow(
                        download: download
                    ) {
                        store.send(.openReading(download.gid))
                    }
                    .contextMenu {
                        downloadContextMenu(download)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            store.send(.inspectorButtonTapped(download.gid))
                        } label: {
                            Label(
                                .inspectPages,
                                systemSymbol: .listBulletRectanglePortrait
                            )
                        }

                        if canMove(download) {
                            Button {
                                store.send(.moveButtonTapped(download))
                            } label: {
                                Label(
                                    .move,
                                    systemSymbol: .folder
                                )
                            }
                            .tint(.teal)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if download.canTriggerUpdate {
                            Button {
                                store.send(.updateDownload(download.gid))
                            } label: {
                                Label(
                                    .RLocalizable.update,
                                    systemSymbol: .arrowTrianglehead2ClockwiseRotate90
                                )
                            }
                            .tint(.orange)
                        }

                        if download.canTogglePause {
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
                            .tint(download.displayStatus == .inactive ? .accentColor : .indigo)
                        }

                        // Deliberately role-less, and tinted instead. `Button(role: .destructive)`
                        // inside `.swipeActions` makes SwiftUI play an optimistic row-removal the
                        // instant the button is tapped — before, and regardless of, any data
                        // mutation. This button mutates nothing: it only presents a confirmation
                        // alert. So the row vanished on tap, reappeared behind the alert (the next
                        // diff still contains it), and vanished a third time when the real deletion
                        // arrived through the observe stream. The tint carries the red the role was
                        // supplying, which is the only effect Apple documents for it here. The
                        // alert's Delete and the context-menu Delete below KEEP their roles —
                        // neither surface has the optimistic-removal behavior. Both sides are
                        // pinned by `DownloadsSwipeActionSourceTests`.
                        Button {
                            store.send(.deleteDownloadButtonTapped(download))
                        } label: {
                            Label(.RLocalizable.delete, systemSymbol: .trash)
                        }
                        .tint(.red)
                    }
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

    @ViewBuilder private func downloadContextMenu(_ download: DownloadedGallery) -> some View {
        Button {
            store.send(.galleryTapped(download.gid))
        } label: {
            Label(
                .RLocalizable.detail,
                systemSymbol: .infoCircle
            )
        }

        Button {
            store.send(.inspectorButtonTapped(download.gid))
        } label: {
            Label(
                .inspectPages,
                systemSymbol: .listBulletRectanglePortrait
            )
        }

        if canMove(download) {
            Menu {
                ForEach(moveDestinations(for: download), id: \.self) { folder in
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

        if download.canTriggerUpdate {
            Button {
                store.send(.updateDownload(download.gid))
            } label: {
                Label(
                    .RLocalizable.update,
                    systemSymbol: .arrowTrianglehead2ClockwiseRotate90
                )
            }
        }

        if download.canTogglePause {
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

        Button(role: .destructive) {
            store.send(.deleteDownloadButtonTapped(download))
        } label: {
            Label(.RLocalizable.delete, systemSymbol: .trash)
        }
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

    private func canMove(_ download: DownloadedGallery) -> Bool {
        download.displayStatus != .active && !moveDestinations(for: download).isEmpty
    }

    private func moveDestinations(for download: DownloadedGallery) -> [String] {
        store.folders.filter({ $0 != download.folderName })
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
