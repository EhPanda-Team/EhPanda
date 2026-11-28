import AppModels

/// The snapshot states of `FavoritesView` (19-18).
enum FavoritesViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "favorites-list",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.favorites(.loaded(.row)) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "favorites-grid",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.favorites(.loaded(.grid)) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "favorites-empty",
                heights: .screen,
                factory: ScenarioFactory(make: { LibraryScenarios.emptyFavorites() }).restingAtTop()
            ),
            SnapshotState(
                id: "favorites-signed-out",
                heights: .screen,
                factory: ScenarioFactory(
                    signedIn: false, make: { LibraryScenarios.favorites(.loaded(.row)) }
                ).restingAtTop()
            ),
            SnapshotState(
                id: "favorites-category-menu",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27, menus at the screen height: 「選單可以按你推薦處理」"
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.favorites(.loaded(.row)) }, prepare: artwork,
                    interact: LibraryScenarios.openCategoryMenu
                ).restingAtTop()
            )
        ]
    }
}
