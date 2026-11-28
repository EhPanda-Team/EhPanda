import CoreGraphics

/// The snapshot states of `GalleryInfoView` (19-18).
enum GalleryInfoViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "detail-pages-gallery-info",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1365, large: 1457, accessibility5: 4581),
                        landscape: .init(xSmall: 1239, large: 1305, accessibility5: 2656)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1272, large: 1338, accessibility5: 2652),
                        landscape: .init(xSmall: 1272, large: 1338, accessibility5: 2431)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.galleryInfo() })
            )
        ]
    }
}
