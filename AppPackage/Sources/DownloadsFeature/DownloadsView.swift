public import AppComponents
import AppModels
import AppTools
public import ComposableArchitecture
import DetailFeature
import GalleryListComponents
import ReadingFeature
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
public import SwiftUI
import SystemNotification

public struct DownloadsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focusedRowID: String?
    @State private var inspectorOriginID: String?
    @ScaledMetric(relativeTo: .callout) private var minCellWidth: CGFloat = 180
    @Bindable private var store: StoreOf<DownloadsReducer>

    private let showsFolderManagement: Bool
    private let libraryTitleMenu: LibraryTitleMenu?

    public init(
        store: StoreOf<DownloadsReducer>, showsFolderManagement: Bool = false,
        libraryTitleMenu: LibraryTitleMenu? = nil
    ) {
        self.store = store
        self.showsFolderManagement = showsFolderManagement
        self.libraryTitleMenu = libraryTitleMenu
    }

    public var body: some View {
        GalleryNavigationContainer(
            store: store,
            state: \.path,
            action: \.path
        ) {
            downloadsList
                .scrollEdgeEffectStyle(.soft, for: .top)
                .overlay {
                    emptyStateView
                        .padding(.horizontal, 24)
                        .animation(.default) {
                            $0.visible(showsEmptyState)
                        }
                }
                .searchable(text: $store.keyword, placement: .navigationBarDrawer)
                .sheet(
                    item: $store.scope(\.$destination, action: \.destination).inspector,
                    onDismiss: restoreInspectorFocus
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
                // Reports refused Pause/Resume and default-folder creation failures.
                .toast($store.scope(\.$toast, action: \.toast))
                .modifier(LibraryNavigationTitle(
                    title: String(localized: .RLocalizable.downloads), menu: libraryTitleMenu
                ))
                .toolbar(content: toolbar)
        }
    }
}

// MARK: Subviews
private extension DownloadsView {
    @ContentBuilder private var downloadsList: some View {
        switch store.loadingState {
        case .loading where store.downloads.isEmpty:
            LoadingView()

        default:
            downloadContent(for: store.setting.galleryListPresentation[.downloads])
            .accessibilityIdentifier("downloads-gallery-list")
            .refreshable { store.send(.refreshDownloads) }
            // Scoped to row IDENTITY, never to the snapshot: `observeDownloads` re-emits the whole
            // list as pages land, so animating on `filteredDownloads` would animate every progress
            // tick. Keyed on the id list, only membership moves — a confirmed delete, a folder or
            // keyword filter change — so the deletion reads as the standard List collapse instead
            // of the snapshot snapping the row out with no transition at all.
            // Under Reduce Motion the row snaps out instead of collapsing; delete flow and manifest unchanged.
            .animation(reduceMotion ? nil : .default, value: store.filteredDownloads.map(\.id))
            .onChange(of: store.filteredDownloads.map(\.id), initial: true) { previousIDs, ids in
                store.visibleGalleryID = GalleryScrollAnchor.retaining(
                    store.visibleGalleryID, previousIDs: previousIDs, currentIDs: ids
                )
            }
        }
    }

    @ContentBuilder
    private func downloadContent(for displayMode: GalleryListDisplayMode) -> some View {
        switch displayMode {
        case .row:
            DownloadRows(
                store: store,
                rows: visibleRows,
                rowFocus: $focusedRowID,
                scrollPositionID: $store.visibleGalleryID,
                openInspectorAction: openInspector
            )

        case .grid:
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: minCellWidth), spacing: 12, alignment: .top)],
                    spacing: 16
                ) {
                    ForEach(visibleRows, id: \.state.id) { rowStore in
                        DownloadGalleryItem(
                            store: store,
                            rowStore: rowStore,
                            layout: .grid,
                            rowFocus: $focusedRowID,
                            openInspectorAction: { openInspector(rowStore.state.id) }
                        )
                        .id(rowStore.state.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal)
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
            .scrollPosition(id: $store.visibleGalleryID, anchor: .top)
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

    private func openInspector(_ id: String) {
        inspectorOriginID = id
        store.send(.inspectorButtonTapped(id))
    }

    private func restoreInspectorFocus() {
        defer { inspectorOriginID = nil }
        guard let inspectorOriginID,
              visibleRows.contains(where: { $0.state.id == inspectorOriginID })
        else { return }
        focusedRowID = inspectorOriginID
    }

    @ContentBuilder private var emptyStateView: some View {
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

    @ContentBuilder private func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            GalleryLayoutPicker(scope: .downloads)
                .disabled(hasArmedConfirmation)
            Menu {
                Picker(selection: $store.folderFilter) {
                    Text(DownloadFolderFilter.all.title).tag(DownloadFolderFilter.all)
                    ForEach(store.folders, id: \.self) { folder in
                        Text(DownloadFolderFilter.folder(folder).title).tag(DownloadFolderFilter.folder(folder))
                    }
                } label: {
                    Text(.RLocalizable.filters)
                }
                .pickerStyle(.inline)
                if showsFolderManagement {
                    Divider()
                    Button {
                        store.send(.folderManagerButtonTapped)
                    } label: {
                        Label(.RLocalizable.manageFolders, systemSymbol: .folderBadgeGearshape)
                    }
                    if store.folders.isEmpty {
                        Button {
                            store.send(.createDefaultFolder)
                        } label: {
                            Label(.RLocalizable.createDefaultFolder, systemSymbol: .folderBadgePlus)
                        }
                        .disabled(store.isCreatingDefaultFolder)
                    }
                }
            } label: {
                Label(.RLocalizable.filters, systemSymbol: .dialLow)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private var hasArmedConfirmation: Bool {
        store.rows.contains(where: { $0.confirmationDialog != nil })
    }

}

/// Native List supplies swipe actions; its visible row IDs bridge scroll restoration to the grid.
private struct DownloadRows: View {
    let store: StoreOf<DownloadsReducer>
    let rows: [StoreOf<DownloadRowFeature>]
    let rowFocus: AccessibilityFocusState<String?>.Binding
    @Binding var scrollPositionID: String?
    let openInspectorAction: (String) -> Void
    @State private var visibleIDs = Set<String>()
    @State private var restorationID: String?

    init(
        store: StoreOf<DownloadsReducer>,
        rows: [StoreOf<DownloadRowFeature>],
        rowFocus: AccessibilityFocusState<String?>.Binding,
        scrollPositionID: Binding<String?>,
        openInspectorAction: @escaping (String) -> Void
    ) {
        self.store = store
        self.rows = rows
        self.rowFocus = rowFocus
        _scrollPositionID = scrollPositionID
        _restorationID = State(initialValue: scrollPositionID.wrappedValue)
        self.openInspectorAction = openInspectorAction
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(rows, id: \.state.id) { rowStore in
                    DownloadGalleryItem(
                        store: store,
                        rowStore: rowStore,
                        layout: .row,
                        rowFocus: rowFocus,
                        openInspectorAction: { openInspectorAction(rowStore.state.id) }
                    )
                    .id(rowStore.state.id)
                    .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                        if isVisible {
                            visibleIDs.insert(rowStore.state.id)
                        } else {
                            visibleIDs.remove(rowStore.state.id)
                        }
                        if restorationID == nil, !visibleIDs.isEmpty {
                            scrollPositionID = rows.first(where: { visibleIDs.contains($0.state.id) })?.state.id
                        }
                    }
                }
            }
            .onChange(of: rows.isEmpty, initial: true) { _, isEmpty in
                guard !isEmpty, let id = restorationID else { return }
                // Let the native list reveal the complete row inside its navigation insets.
                proxy.scrollTo(id)
                restorationID = nil
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
