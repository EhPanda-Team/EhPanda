import AppModels

/// The snapshot states of `SearchView` (19-18).
enum SearchViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "search-results-list",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.searchResults(.loaded(.row)) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "search-results-grid",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.searchResults(.loaded(.grid)) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "search-results-empty",
                heights: .screen,
                factory: ScenarioFactory(make: { LibraryScenarios.searchResults(.failed(.notFound)) }).restingAtTop()
            ),
            SnapshotState(
                id: "search-results-error",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.searchResults(.failed(.networkingFailed)) }
                ).restingAtTop()
            )
        ]
    }
}
