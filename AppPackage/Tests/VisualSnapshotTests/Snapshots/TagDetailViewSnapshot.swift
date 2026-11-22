/// The snapshot states of `TagDetailView` (19-18).
enum TagDetailViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "detail-pages-tag-detail",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.tagDetail() }, prepare: GalleryScenarios.cacheTagArtwork)
            )
        ]
    }
}
