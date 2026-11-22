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
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.folderManager(confirmingDelete: true) }, prepare: artwork
                )
            )
        ]
    }
}
