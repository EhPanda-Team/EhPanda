import AppModels

/// The snapshot states of `PopularView` (19-18).
enum PopularViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "popular-list",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.popular(.loaded(.row)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "popular-grid",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.popular(.loaded(.grid)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "popular-loading",
                heights: .screen,
                factory: .init(
                    make: { BrowsingScenarios.popular(.loading) }, still: BrowsingScenarios.freezeIndicators
                )
            ),
            SnapshotState(
                id: "popular-error",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.popular(.failed(.networkingFailed)) })
            )
        ]
    }
}
