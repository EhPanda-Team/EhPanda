/// The snapshot states of `GallerySheetView` (19-18).
enum GallerySheetViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "gallery-detail-sheet",
                heights: .screen,
                factory: .init(make: { try LibraryScenarios.gallerySheet() }, prepare: artwork)
            )
        ]
    }
}
