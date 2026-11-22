/// The snapshot states of `QuickSearchView` (19-18).
enum QuickSearchViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "quick-search-list",
                heights: .screen,
                factory: .init(make: { LibraryScenarios.quickSearch(.list) })
            ),
            SnapshotState(
                id: "quick-search-empty",
                heights: .screen,
                factory: .init(make: { LibraryScenarios.quickSearch(.empty) })
            ),
            SnapshotState(
                id: "quick-search-delete-confirmation",
                heights: .screen,
                factory: .init(make: { LibraryScenarios.quickSearch(.deleteConfirmation) })
            ),
            SnapshotState(
                id: "quick-search-word-editor",
                heights: .screen,
                factory: .init(
                    make: { LibraryScenarios.quickSearch(.wordEditor) }, interact: LibraryScenarios.holdCaret
                )
            )
        ]
    }
}
