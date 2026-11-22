/// The snapshot states of `TorrentsView` (19-18).
enum TorrentsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "detail-pages-torrents",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.torrents(empty: false) }, prepare: artwork,
                    interact: RevealStep.showLargeTitle()
                )
            ),
            SnapshotState(
                id: "detail-pages-torrents-empty",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.torrents(empty: true) }, prepare: artwork)
            )
        ]
    }
}
