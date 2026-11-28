import CoreGraphics

/// The snapshot states of `TagDetailView` (19-18).
enum TagDetailViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "detail-pages-tag-detail",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1476),
                        landscape: .init(xSmall: 600, large: 623, accessibility5: 1140)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1183)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.tagDetail() }, prepare: GalleryScenarios.cacheTagArtwork)
            )
        ]
    }
}
