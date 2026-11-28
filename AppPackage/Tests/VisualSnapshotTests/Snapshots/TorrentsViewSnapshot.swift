import CoreGraphics

/// The snapshot states of `TorrentsView` (19-18).
enum TorrentsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "detail-pages-torrents",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1728),
                        landscape: .init(xSmall: 431, large: 448, accessibility5: 937)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1131)
                    )
                ),
                factory: .init(
                    make: { try GalleryScenarios.torrents(empty: false) }, prepare: artwork,
                    interact: RevealStep.showLargeTitle()
                )
            ),
            SnapshotState(
                id: "detail-pages-torrents-empty",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 912),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 460)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.torrents(empty: true) }, prepare: artwork)
            )
        ]
    }
}
