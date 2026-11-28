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
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27, menus at the screen height: 「選單可以按你推薦處理」"
                ),
                factory: .init(
                    make: { try GalleryScenarios.comments(.list) }, interact: GalleryScenarios.openFirstRowMenu
                )
            ),
            SnapshotState(
                id: "comments-block-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
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
