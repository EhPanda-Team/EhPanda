import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import ComposableArchitecture

struct DownloadsView: View {
    private enum RowDialog: Identifiable {
        case delete(DownloadedGallery)

        var id: String {
            switch self {
            case .delete(let download):
                return "delete-\(download.gid)"
            }
        }
    }

    @Bindable private var store: StoreOf<DownloadsReducer>
    @State private var rowDialog: RowDialog?
    @State private var moveDialogDownload: DownloadedGallery?
    @Binding private var setting: Setting
    private let user: User
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
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

    var body: some View {
        NavigationView {
            if DeviceUtil.isPad {
                contentView
                    .sheet(item: $store.route.sending(\.setNavigation).detail, id: \.self) { route in
                        NavigationView {
                            DetailView(
                                store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                                gid: route.wrappedValue,
                                user: user,
                                setting: $setting,
                                blurRadius: blurRadius,
                                tagTranslator: tagTranslator
                            )
                        }
                        .autoBlur(radius: blurRadius)
                        .environment(\.inSheet, true)
                        .navigationViewStyle(.stack)
                    }
            } else {
                contentView
            }
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
            prompt: L10n.Localizable.DownloadsView.Search.Prompt.downloads
        )
        .sheet(item: $store.route.sending(\.setNavigation).inspector, id: \.self) { _ in
            NavigationView {
                DownloadInspectorView(
                    store: store.scope(state: \.inspectorState, action: \.inspector),
                    setting: setting,
                    blurRadius: blurRadius,
                    tagTranslator: tagTranslator
                )
            }
            .autoBlur(radius: blurRadius)
            .navigationViewStyle(.stack)
        }
        .sheet(item: $store.route.sending(\.setNavigation).folderManager) { _ in
            FolderManagerView(
                store: store.scope(state: \.folderManagerState, action: \.folderManager)
            )
            .accentColor(setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
        .fullScreenCover(item: $store.route.sending(\.setNavigation).reading, id: \.self) { route in
            ReadingView(
                store: store.scope(state: \.readingState, action: \.reading),
                gid: route.wrappedValue,
                setting: $setting,
                blurRadius: blurRadius
            )
            .accentColor(setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert(
            L10n.Localizable.DownloadsView.Dialog.Title.deleteDownload,
            isPresented: Binding(
                get: { rowDialog != nil },
                set: { if !$0 { rowDialog = nil } }
            ),
            presenting: rowDialog
        ) { dialog in
            switch dialog {
            case .delete(let download):
                Button(L10n.Localizable.ConfirmationDialog.Button.delete, role: .destructive) {
                    store.send(.deleteDownload(download.gid))
                    rowDialog = nil
                }
                Button(L10n.Localizable.Common.Button.cancel, role: .cancel) {
                    rowDialog = nil
                }
            }
        } message: { dialog in
            switch dialog {
            case .delete(let download):
                Text(
                    download.canTogglePause
                        ? L10n.Localizable.DownloadsView.Dialog.Message.deleteActiveDownload
                        : L10n.Localizable.DownloadsView.Dialog.Message.deleteDownloadedGallery
                )
            }
        }
        .confirmationDialog(
            L10n.Localizable.DownloadsView.Menu.Button.moveToFolder,
            isPresented: Binding(
                get: { moveDialogDownload != nil },
                set: { if !$0 { moveDialogDownload = nil } }
            ),
            titleVisibility: .visible,
            presenting: moveDialogDownload
        ) { download in
            ForEach(moveDestinations(for: download), id: \.self) { folder in
                Button(folder) {
                    store.send(.moveDownload(download.gid, folder))
                    moveDialogDownload = nil
                }
            }
            Button(L10n.Localizable.Common.Button.cancel, role: .cancel) {
                moveDialogDownload = nil
            }
        }
        .background(navigationLink)
        .navigationTitle(L10n.Localizable.DownloadsView.Title.downloads)
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
                            store.send(.setNavigation(.inspector(download.gid)))
                        } label: {
                            Label(
                                L10n.Localizable.DownloadsView.Swipe.Button.pages,
                                systemSymbol: .listBulletRectanglePortrait
                            )
                        }
                        .tint(setting.accentColor)

                        if canMove(download) {
                            Button {
                                moveDialogDownload = download
                            } label: {
                                Label(
                                    L10n.Localizable.DownloadsView.Swipe.Button.move,
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
                                    L10n.Localizable.DownloadsView.Swipe.Button.update,
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
                                        ? L10n.Localizable.DownloadsView.Swipe.Button.resume
                                        : L10n.Localizable.DownloadsView.Swipe.Button.pause,
                                    systemSymbol: download.displayStatus == .inactive
                                        ? .playFill
                                        : .pauseFill
                                )
                            }
                            .tint(download.displayStatus == .inactive ? .green : .indigo)
                        }

                        Button(role: .destructive) {
                            rowDialog = .delete(download)
                        } label: {
                            Label(L10n.Localizable.ConfirmationDialog.Button.delete, systemSymbol: .trash)
                        }
                    }
                }
            }
            .refreshable { store.send(.refreshDownloads) }
        }
    }

    @ViewBuilder private func downloadContextMenu(_ download: DownloadedGallery) -> some View {
        Button {
            store.send(.setNavigation(.detail(download.gid)))
        } label: {
            Label(
                L10n.Localizable.DetailView.ContextMenu.Button.detail,
                systemSymbol: .infoCircle
            )
        }

        Button {
            store.send(.setNavigation(.inspector(download.gid)))
        } label: {
            Label(
                L10n.Localizable.DownloadsView.Swipe.Button.pages,
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
                    L10n.Localizable.DownloadsView.Menu.Button.moveToFolder,
                    systemSymbol: .folder
                )
            }
        }

        if download.canTriggerUpdate {
            Button {
                store.send(.updateDownload(download.gid))
            } label: {
                Label(
                    L10n.Localizable.DownloadsView.Swipe.Button.update,
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
                        ? L10n.Localizable.DownloadsView.Swipe.Button.resume
                        : L10n.Localizable.DownloadsView.Swipe.Button.pause,
                    systemSymbol: download.displayStatus == .inactive
                        ? .playFill
                        : .pauseFill
                )
            }
        }

        Button(role: .destructive) {
            rowDialog = .delete(download)
        } label: {
            Label(L10n.Localizable.ConfirmationDialog.Button.delete, systemSymbol: .trash)
        }
    }

    @ViewBuilder private var navigationLink: some View {
        if DeviceUtil.isPhone {
            NavigationLink(unwrapping: $store.route, case: \.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                    gid: route.wrappedValue,
                    user: user,
                    setting: $setting,
                    blurRadius: blurRadius,
                    tagTranslator: tagTranslator
                )
            }
        }
    }

    @ViewBuilder private var emptyStateView: some View {
        if store.downloads.isEmpty {
            AlertView(
                symbol: .squareAndArrowDown,
                message: L10n.Localizable.DownloadsView.EmptyState.downloads
            ) {
                EmptyView()
            }
        } else {
            AlertView(
                symbol: .line3HorizontalDecreaseCircle,
                message: L10n.Localizable.DownloadsView.EmptyState.noMatchingFilters
            ) {
                AlertViewButton(title: L10n.Localizable.DownloadsView.Button.clearFilters) {
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
                        store.send(.setNavigation(.folderManager()))
                    } label: {
                        Label(
                            L10n.Localizable.DownloadsView.Menu.Button.manageFolders,
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
