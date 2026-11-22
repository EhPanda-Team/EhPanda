/// The snapshot states of `GalleryInfoView` (19-18).
enum GalleryInfoViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "detail-pages-gallery-info",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.galleryInfo() })
            )
        ]
    }
}
