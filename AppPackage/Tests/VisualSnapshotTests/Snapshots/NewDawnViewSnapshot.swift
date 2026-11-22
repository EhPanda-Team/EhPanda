/// The snapshot states of `NewDawnView` (19-18).
enum NewDawnViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "detail-pages-new-dawn",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.newDawn() }, prepare: artwork)
            )
        ]
    }
}
