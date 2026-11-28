import CoreGraphics

/// The snapshot states of `NewDawnView` (19-18).
enum NewDawnViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "detail-pages-new-dawn",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1201),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 786)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 966)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.newDawn() }, prepare: artwork)
            )
        ]
    }
}
