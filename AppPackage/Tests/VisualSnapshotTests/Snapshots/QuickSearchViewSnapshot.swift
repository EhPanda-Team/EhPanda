import AppModels

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
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { LibraryScenarios.quickSearch(.deleteConfirmation) },
                    interact: RevealStep.reveal(.label((LibraryScenarios.savedSearches.first ?? .empty).name))
                )
            ),
            SnapshotState(
                id: "quick-search-word-editor",
                heights: .screen,
                factory: .init(
                    make: { LibraryScenarios.quickSearch(.wordEditor) }, still: LibraryScenarios.holdCaret
                )
            )
        ]
    }
}
