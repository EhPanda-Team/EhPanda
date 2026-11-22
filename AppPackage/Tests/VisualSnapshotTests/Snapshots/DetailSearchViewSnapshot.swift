import AppModels

/// The snapshot states of `DetailSearchView` (19-18).
enum DetailSearchViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "detail-pages-detail-search-list",
                heights: .screen,
                factory: .init(
                    make: { GalleryScenarios.detailSearch(.loaded(.row)) }, prepare: artwork
                )
            ),
            SnapshotState(
                id: "detail-pages-detail-search-grid",
                heights: .screen,
                factory: .init(
                    make: { GalleryScenarios.detailSearch(.loaded(.grid)) }, prepare: artwork
                )
            )
        ]
    }
}
