import CoreGraphics

/// The snapshot states of `GallerySheetView` (19-18).
enum GallerySheetViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "gallery-detail-sheet",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 912),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 420)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1947),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1947)
                    )
                ),
                factory: .init(make: { try LibraryScenarios.gallerySheet() }, prepare: artwork)
            )
        ]
    }
}
