import AppModels

/// The snapshot states of `HomeView` (19-18).
enum HomeViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "home-populated",
                heights: .screen,
                factory: .init(make: { TracerScenarios.home() }, prepare: TracerScenarios.cacheHomeArtwork)
            ),
            SnapshotState(
                id: "home-loading",
                heights: .screen,
                factory: .init(
                    make: { BrowsingScenarios.home(loading: .loading) }, still: BrowsingScenarios.freezeIndicators
                )
            ),
            SnapshotState(
                id: "home-error",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.home(loading: .failed(.networkingFailed)) })
            )
        ]
    }
}
