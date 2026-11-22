/// The snapshot states of `PreviewsView` (19-18).
enum PreviewsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "detail-pages-previews",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.previews(loaded: true) }, prepare: GalleryScenarios.cachePreviewArtwork
                )
            ),
            SnapshotState(
                id: "detail-pages-previews-loading",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.previews(loaded: false) }, prepare: artwork,
                    interact: GalleryScenarios.holdStill
                )
            )
        ]
    }
}
