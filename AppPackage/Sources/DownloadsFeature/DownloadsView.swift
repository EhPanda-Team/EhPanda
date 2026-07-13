import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import ComposableArchitecture
import AppTools
import AppComponents
import ReadingFeature
import DetailFeature
import SFSafeSymbolsExt

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
            contentView
        }
    }

    private var contentView: some View {
        let showsEmptyState = store.loadingState == .idle && store.filteredDownloads.isEmpty
        return ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            downloadsList
                .allowsHitTesting(!showsEmptyState)

            if showsEmptyState {
                VStack {
                    Spacer()
                    emptyStateView
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .searchable(text: $store.keyword, placement: .navigationBarDrawer, prompt: .searchDownloads)
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
                .accentColor(store.setting.accentColor)
                .privacyMask()
        }
        .fullScreenCover(
            item: $store.scope(\.$destination, action: \.destination).reading
        ) { store in
            ReadingView(
                store: store,
                gid: store.gallery.id,
                blurRadius: 0
            )
            .accentColor(store.setting.accentColor)
            .privacyMask()
        }
        .onAppear {
            store.send(.onAppear)
        }
        .appAlert($store.scope(\.$alert, action: \.alert))
        .confirmationDialog(
            $store.scope(\.$confirmationDialog, action: \.confirmationDialog)
        )
        .navigationTitle(.RLocalizable.downloads)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(content: toolbar)
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
                        .tint(store.setting.accentColor)

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
                            .tint(download.displayStatus == .inactive ? .green : .indigo)
                        }

                        Button(role: .destructive) {
                            store.send(.deleteDownloadButtonTapped(download))
                        } label: {
                            Label(.RLocalizable.delete, systemSymbol: .trash)
                        }
                    }
                }
            }
            .refreshable { store.send(.refreshDownloads) }
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
                        store.send(.moveDownload(download.gid, folder))
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
            AlertView(
                symbol: .squareAndArrowDown,
                message: .emptyDownloads
            ) {
                EmptyView()
            }
        } else {
            AlertView(
                symbol: .line3HorizontalDecreaseCircle,
                message: .noMatchingFilters
            ) {
                AlertViewButton(title: .clearFilters) {
                    store.keyword = ""
                    store.folderFilter = .all
                }
            }
        }
    }

    private func canMove(_ download: DownloadedGallery) -> Bool {
        download.displayStatus != .active && !moveDestinations(for: download).isEmpty
    }

    private func moveDestinations(for download: DownloadedGallery) -> [String] {
        store.folders.filter { $0 != download.folderName }
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
                Image(systemSymbol: .dialLow)
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

struct DownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadsView(
            store: .init(initialState: .init(), reducer: DownloadsReducer.init)
        )
    }
}
