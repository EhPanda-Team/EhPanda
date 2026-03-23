//
//  DownloadsView.swift
//  EhPanda
//

import SwiftUI
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
        .sheet(item: $store.route.sending(\.setNavigation).quickSearch) { _ in
            QuickSearchView(
                store: store.scope(state: \.quickSearchState, action: \.quickSearch)
            ) { keyword in
                store.keyword = keyword
                store.send(.setNavigation(nil))
            }
            .accentColor(setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
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
        .sheet(item: $store.route.sending(\.setNavigation).filters) { _ in
            DownloadFiltersView(
                filter: $store.galleryFilter,
                resetAction: {
                    store.galleryFilter.reset()
                }
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
                    download.canPauseOrResume || download.isPendingQueue
                        ? L10n.Localizable.DownloadsView.Dialog.Message.deleteActiveDownload
                        : L10n.Localizable.DownloadsView.Dialog.Message.deleteDownloadedGallery
                )
            }
        }
        .background(navigationLink)
        .navigationTitle(L10n.Localizable.DownloadsView.Title.downloads)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(content: toolbar)
    }

    @ViewBuilder private var downloadsList: some View {
        switch store.loadingState {
        case .loading where store.downloads.isEmpty:
            LoadingView()

        case .failed(let error) where store.downloads.isEmpty:
            ErrorView(error: error, action: { store.send(.refreshDownloads) })

        default:
            List {
                ForEach(store.filteredDownloads) { download in
                    DownloadListRow(
                        download: download,
                        setting: setting,
                        tagTranslator: tagTranslator
                    ) {
                        store.send(.setNavigation(.detail(download.gid)))
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            store.send(.setNavigation(.inspector(download.gid)))
                        } label: {
                            Label(
                                L10n.Localizable.DownloadsView.Swipe.Button.pages,
                                systemImage: "list.bullet.rectangle.portrait"
                            )
                        }
                        .tint(setting.accentColor)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if download.canTriggerUpdate {
                            Button {
                                store.send(.updateDownload(download.gid))
                            } label: {
                                Label(
                                    L10n.Localizable.DownloadsView.Swipe.Button.update,
                                    systemImage: "arrow.triangle.2.circlepath"
                                )
                            }
                            .tint(.orange)
                        }

                        if download.canPauseOrResume || download.isPendingQueue {
                            Button {
                                store.send(.toggleDownloadPause(download.gid))
                            } label: {
                                Label(
                                    download.status == .paused
                                        ? L10n.Localizable.DownloadsView.Swipe.Button.resume
                                        : L10n.Localizable.DownloadsView.Swipe.Button.pause,
                                    systemImage: download.status == .paused
                                        ? "play.fill"
                                        : "pause.fill"
                                )
                            }
                            .tint(download.status == .paused ? .green : .indigo)
                        }

                        Button(role: .destructive) {
                            rowDialog = .delete(download)
                        } label: {
                            Label(L10n.Localizable.ConfirmationDialog.Button.delete, systemSymbol: .trash)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { store.send(.refreshDownloads) }
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
                    store.filter = .all
                    store.galleryFilter.reset()
                }
            }
        }
    }

    @ToolbarContentBuilder private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Menu {
                ForEach(DownloadListFilter.allCases) { filter in
                    Button {
                        store.filter = filter
                    } label: {
                        Text(filter.title)
                        if store.filter == filter {
                            Image(systemSymbol: .checkmark)
                        }
                    }
                }
            } label: {
                Image(systemSymbol: .line3HorizontalDecreaseCircle)
                    .symbolRenderingMode(.hierarchical)
            }

            ToolbarFeaturesMenu {
                FiltersButton {
                    store.send(.setNavigation(.filters()))
                }
                QuickSearchButton {
                    store.send(.setNavigation(.quickSearch()))
                }
                if store.filter != .all || store.keyword.notEmpty || store.galleryFilter.hasActiveValues {
                    Button {
                        store.filter = .all
                        store.keyword = ""
                        store.galleryFilter.reset()
                    } label: {
                        Label(
                            L10n.Localizable.DownloadsView.Button.clearFilters,
                            systemSymbol: .arrowCounterclockwise
                        )
                    }
                }
            }
        }
    }
}

private struct DownloadInspectorView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable private var store: StoreOf<DownloadInspectorReducer>
    private let setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<DownloadInspectorReducer>,
        setting: Setting,
        blurRadius: Double,
        tagTranslator: TagTranslator
    ) {
        self.store = store
        self.setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        Group {
            switch store.loadingState {
            case .loading where store.inspection == nil:
                LoadingView()

            case .failed(let error) where store.inspection == nil:
                ErrorView(error: error, action: { store.send(.loadInspection) })

            default:
                List {
                    if let inspection = store.inspection {
                        Section {
                            StaticGalleryDetailCell(
                                gallery: inspection.download.gallery,
                                resolvedCoverURL: inspection.coverURL,
                                setting: setting,
                                translateAction: {
                                    tagTranslator.lookup(
                                        word: $0,
                                        returnOriginal: !setting.translatesTags
                                    )
                                },
                                downloadBadge: inspection.download.badge
                            )
                            .listRowInsets(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
                            .listRowBackground(Color.clear)
                        }

                        if !inspection.failedPageIndices.isEmpty || inspection.download.canTriggerUpdate {
                            Section(L10n.Localizable.DownloadsView.Inspector.Section.actions) {
                                if !inspection.failedPageIndices.isEmpty {
                                    Button {
                                        store.send(.retryFailedPages)
                                    } label: {
                                        Label(
                                            L10n.Localizable.DownloadsView.Inspector.Button.retryFailedPages(
                                                inspection.failedPageIndices.count
                                            ),
                                            systemImage: "arrow.clockwise.circle"
                                        )
                                    }
                                }

                                if inspection.download.canTriggerUpdate {
                                    Button {
                                        store.send(.updateDownload)
                                    } label: {
                                        Label(
                                            L10n.Localizable.DownloadsView.Inspector.Button.updateDownload,
                                            systemImage: "arrow.triangle.2.circlepath"
                                        )
                                    }
                                }
                            }
                        }

                        Section(L10n.Localizable.DownloadsView.Inspector.Section.pages) {
                            ForEach(inspection.pages) { page in
                                DownloadInspectorPageRow(page: page) {
                                    store.send(.retryPage(page.index))
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .autoBlur(radius: blurRadius)
        .navigationTitle(L10n.Localizable.DownloadsView.Inspector.Title.downloadStatus)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            CustomToolbarItem(placement: .cancellationAction) {
                Button(L10n.Localizable.EhSettingView.ToolbarItem.Button.done) {
                    dismiss()
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

private struct DownloadListRow: View {
    let download: DownloadedGallery
    let setting: Setting
    let tagTranslator: TagTranslator
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            StaticGalleryDetailCell(
                gallery: download.gallery,
                resolvedCoverURL: download.coverURL,
                setting: setting,
                translateAction: {
                    tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
                },
                downloadBadge: download.badge
            )
            .allowsHitTesting(false)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: openAction)
    }
}

private struct DownloadInspectorPageRow: View {
    let page: DownloadPageInspection
    let retryAction: () -> Void

    private var symbolName: String {
        switch page.status {
        case .pending:
            return "clock"
        case .downloaded:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    private var tint: Color {
        switch page.status {
        case .pending:
            return .secondary
        case .downloaded:
            return .green
        case .failed:
            return .red
        }
    }

    private var subtitle: String {
        switch page.status {
        case .pending:
            return L10n.Localizable.DownloadsView.Inspector.Page.pending
        case .downloaded:
            return page.relativePath ?? L10n.Localizable.Struct.DownloadBadge.Text.downloaded
        case .failed:
            return page.failure?.message ?? L10n.Localizable.DownloadsView.Inspector.Page.tapToRetry
        }
    }

    var body: some View {
        Group {
            if page.status == .failed {
                Button(action: retryAction) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Localizable.DownloadsView.Inspector.Page.title(page.index))
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if page.status == .failed {
                Image(systemSymbol: .arrowClockwise)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
