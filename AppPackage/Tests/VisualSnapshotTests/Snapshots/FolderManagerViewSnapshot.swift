import VisualSnapshotSupport

/// The snapshot states of `FolderManagerView` (19-18).
enum FolderManagerViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "detail-pages-folder-manager",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.folderManager(confirmingDelete: false) }, prepare: artwork
                )
            ),
            SnapshotState(
                id: "detail-pages-folder-delete-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { try GalleryScenarios.folderManager(confirmingDelete: true) }, prepare: artwork,
                    interact: RevealStep.reveal(.label(LibraryFixtures.downloadFolders.dropFirst().first ?? ""))
                )
            )
        ]
    }
}
