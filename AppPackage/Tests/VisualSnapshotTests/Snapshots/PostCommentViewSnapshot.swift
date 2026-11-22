/// The snapshot states of `PostCommentView` (19-18).
enum PostCommentViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "comments-post-empty",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.comments(.postEmpty) },
                    interact: GalleryScenarios.holdStillOverKeyboard
                )
            ),
            SnapshotState(
                id: "comments-post-filled",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.comments(.postFilled) },
                    interact: GalleryScenarios.holdStillOverKeyboard
                )
            ),
            SnapshotState(
                id: "comments-posting-warning",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.comments(.postingWarning) },
                    interact: GalleryScenarios.holdStillOverKeyboard
                )
            )
        ]
    }
}
