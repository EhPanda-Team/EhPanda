import AppComponents
import AppModels
import ComposableArchitecture
import GalleryListComponents
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

/// A downloaded gallery rendered in either of the Library Downloads presentations.
///
/// The row and grid use the same action builders and status predicates. The child store remains
/// responsible for the per-gallery delete confirmation, so an observation tick can never retarget
/// a pending confirmation at a different gallery.
struct DownloadGalleryItem: View {
    enum Layout {
        case row
        case grid
    }

    @State private var gridCellWidth: CGFloat?

    @Bindable var store: StoreOf<DownloadsReducer>
    @Bindable var rowStore: StoreOf<DownloadRowFeature>
    let layout: Layout
    let rowFocus: AccessibilityFocusState<String?>.Binding
    let openInspectorAction: () -> Void

    private var download: DownloadedGallery { rowStore.download }

    var body: some View {
        switch layout {
        case .row:
            row
        case .grid:
            grid
        }
    }
}

private extension DownloadGalleryItem {
    var row: some View {
        DownloadListRow(
            download: download,
            rowFocus: rowFocus,
            readAction: { store.send(.openReading(download.gid)) }
        ) {
            store.send(.galleryTapped(download.gid))
        }
        .accessibilityIdentifier("download-gallery-\(download.gid)")
        .contextMenu {
            detailButton
            readButton
            managementMenu
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
            deleteButton(role: nil)
                .tint(.red)
        }
        // Swipe actions become native accessibility actions; Read is provided by the tap interaction.
        .confirmationDialog(
            $rowStore.scope(\.$confirmationDialog, action: \.confirmationDialog)
        )
    }

    var grid: some View {
        Button {
            store.send(.galleryTapped(download.gid))
        } label: {
            gridCell
                .onGeometryChange(for: CGFloat.self, of: \.size.width) {
                    gridCellWidth = $0
                }
        }
        .buttonStyle(.borderless)
        .modifier(GalleryReadInteraction(
            detailAction: { store.send(.galleryTapped(download.gid)) },
            readAction: { store.send(.openReading(download.gid)) }
        ))
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityFocused(rowFocus, equals: download.id)
        .accessibilityIdentifier("download-gallery-\(download.gid)")
        .contextMenu {
            managementMenu
        } preview: {
            gridCell
                .frame(width: gridCellWidth)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(.background, in: .rect(cornerRadius: 24))
        }
        .accessibilityActions {
            inspectButton
            if canMove { moveButton }
            if download.canTriggerUpdate { updateButton }
            if download.canTogglePause { pauseButton }
            deleteButton(role: .destructive)
        }
        .confirmationDialog(
            $rowStore.scope(\.$confirmationDialog, action: \.confirmationDialog)
        )
    }

    var gridCell: some View {
        GalleryThumbnailCell(
            gallery: download.gallery,
            coverSource: .static(download.coverURL),
            downloadBadge: download.badge,
            showsRating: false
        )
        .tint(.primary)
        .multilineTextAlignment(.leading)
    }

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
            Label(.RLocalizable.detail, systemSymbol: .infoCircle)
        }
    }

    var readButton: some View {
        Button {
            store.send(.openReading(download.gid))
        } label: {
            Label(.RLocalizable.read, systemSymbol: .bookFill)
        }
    }

    var inspectButton: some View {
        Button {
            openInspectorAction()
        } label: {
            Label(.inspectPages, systemSymbol: .listBulletRectanglePortrait)
        }
    }

    var moveButton: some View {
        Button {
            rowStore.send(.moveButtonTapped(destinations: moveDestinations))
        } label: {
            Label(.move, systemSymbol: .folder)
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
            Label(.moveToFolder, systemSymbol: .folder)
        }
    }

    var updateButton: some View {
        Button {
            store.send(.updateDownload(download.gid))
        } label: {
            Label(.RLocalizable.update, systemSymbol: .arrowTrianglehead2ClockwiseRotate90)
        }
    }

    var pauseButton: some View {
        Button {
            store.send(.toggleDownloadPause(download.gid))
        } label: {
            Label(
                download.displayStatus == .inactive ? .resume : .pause,
                systemSymbol: download.displayStatus == .inactive ? .playFill : .pauseFill
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

    @ViewBuilder
    var managementMenu: some View {
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
