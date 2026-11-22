/// The snapshot states of `CommentsView` (19-18).
enum CommentsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "comments-list",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.comments(.list) })
            ),
            SnapshotState(
                id: "comments-menu",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.comments(.list) }, interact: GalleryScenarios.openFirstRowMenu
                )
            ),
            SnapshotState(
                id: "comments-block-confirmation",
                heights: .screen,
                factory: .init(
                    make: { try TracerScenarios.comments() }, interact: TracerScenarios.chooseBlock
                )
            ),
            SnapshotState(
                id: "comments-blocked-row-collapsed",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.comments(.blocked) })
            ),
            SnapshotState(
                id: "comments-blocked-row-shown",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.comments(.blockedShown) })
            )
        ]
    }
}
