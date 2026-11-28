import CoreGraphics

/// The snapshot states of `PreviewsView` (19-18).
enum PreviewsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "detail-pages-previews",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1730, large: 1748, accessibility5: 2286),
                        landscape: .init(xSmall: 2754, large: 2805, accessibility5: 3390)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1940, large: 1973, accessibility5: 2429),
                        landscape: .init(xSmall: 1323, large: 1344, accessibility5: 1648)
                    )
                ),
                factory: .init(
                    make: { try GalleryScenarios.previews(loaded: true) }, prepare: GalleryScenarios.cachePreviewArtwork
                )
            ),
            SnapshotState(
                id: "detail-pages-previews-loading",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1730, large: 1748, accessibility5: 2286),
                        landscape: .init(xSmall: 2754, large: 2805, accessibility5: 3390)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1940, large: 1973, accessibility5: 2429),
                        landscape: .init(xSmall: 1323, large: 1344, accessibility5: 1648)
                    )
                ),
                factory: .init(
                    make: { try GalleryScenarios.previews(loaded: false) }, prepare: artwork,
                    still: GalleryScenarios.holdStill
                )
            )
        ]
    }
}
