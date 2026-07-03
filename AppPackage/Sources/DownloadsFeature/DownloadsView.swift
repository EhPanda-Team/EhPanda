import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import ComposableArchitecture
import AppTools
import AppComponents
import ReadingFeature
import DetailFeature

public struct DownloadsView: View {
    @Bindable private var store: StoreOf<DownloadsReducer>
    @Binding private var setting: Setting
    private let user: User
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    public init(
        store: StoreOf<DownloadsReducer>,
        user: User,
        setting: Binding<Setting>,
        blurRadius: Double,
        tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    public var body: some View {
        GalleryNavigationContainer(
            store: store,
            state: \.path,
            action: \.path,
            user: user,
            setting: $setting,
            blurRadius: blurRadius,
            tagTranslator: tagTranslator
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
        .searchable(
            text: $store.keyword,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: L10n.Localizable.DownloadsView.searchDownloads
        )
        .sheet(
            item: $store.scope(state: \.destination?.inspector, action: \.destination.inspector)
        ) { store in
            NavigationStack {
                DownloadInspectorView(
                    store: store,
                    setting: setting,
                    blurRadius: blurRadius,
                    tagTranslator: tagTranslator
                )
            }
            .autoBlur(radius: blurRadius)
        }
        .sheet(
            item: $store.scope(state: \.destination?.folderManager, action: \.destination.folderManager)
        ) { store in
            FolderManagerView(store: store)
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
        }
        .fullScreenCover(
            item: $store.scope(state: \.destination?.reading, action: \.destination.reading)
        ) { store in
            ReadingView(
                store: store,
                gid: store.gallery.id,
                setting: $setting,
                blurRadius: blurRadius
            )
            .accentColor(setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
        .onAppear {
            store.send(.onAppear)
        }
        .appAlert($store.scope(state: \.alert, action: \.alert))
        .confirmationDialog(
            $store.scope(state: \.confirmationDialog, action: \.confirmationDialog)
        )
        .navigationTitle(L10n.Localizable.DownloadsView.downloads)
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
                        download: download,
                        setting: setting,
                        tagTranslator: tagTranslator
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
                                L10n.Localizable.DownloadsView.pages,
                                systemSymbol: .listBulletRectanglePortrait
                            )
                        }
                        .tint(setting.accentColor)

                        if canMove(download) {
                            Button {
                                store.send(.moveButtonTapped(download))
                            } label: {
                                Label(
                                    L10n.Localizable.DownloadsView.move,
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
                                    L10n.Localizable.DownloadsView.update,
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
                                        ? L10n.Localizable.DownloadsView.resume
                                        : L10n.Localizable.DownloadsView.pause,
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
                            Label(L10n.Localizable.ConfirmationDialog.delete, systemSymbol: .trash)
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
                L10n.Localizable.DetailView.detail,
                systemSymbol: .infoCircle
            )
        }

        Button {
            store.send(.inspectorButtonTapped(download.gid))
        } label: {
            Label(
                L10n.Localizable.DownloadsView.pages,
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
                    L10n.Localizable.DownloadsView.moveToFolder,
                    systemSymbol: .folder
                )
            }
        }

        if download.canTriggerUpdate {
            Button {
                store.send(.updateDownload(download.gid))
            } label: {
                Label(
                    L10n.Localizable.DownloadsView.update,
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
                        ? L10n.Localizable.DownloadsView.resume
                        : L10n.Localizable.DownloadsView.pause,
                    systemSymbol: download.displayStatus == .inactive
                        ? .playFill
                        : .pauseFill
                )
            }
        }

        Button(role: .destructive) {
            store.send(.deleteDownloadButtonTapped(download))
        } label: {
            Label(L10n.Localizable.ConfirmationDialog.delete, systemSymbol: .trash)
        }
    }

    @ViewBuilder private var emptyStateView: some View {
        if store.downloads.isEmpty {
            AlertView(
                symbol: .squareAndArrowDown,
                message: L10n.Localizable.DownloadsView.emptyDownloads
            ) {
                EmptyView()
            }
        } else {
            AlertView(
                symbol: .line3HorizontalDecreaseCircle,
                message: L10n.Localizable.DownloadsView.noMatchingFilters
            ) {
                AlertViewButton(title: L10n.Localizable.DownloadsView.clearFilters) {
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
                            L10n.Localizable.DownloadsView.manageFolders,
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
            store: .init(initialState: .init(), reducer: DownloadsReducer.init),
            user: .init(),
            setting: .constant(.init()),
            blurRadius: 0,
            tagTranslator: .init()
        )
    }
}
