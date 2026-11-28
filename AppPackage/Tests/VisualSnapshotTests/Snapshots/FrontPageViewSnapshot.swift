import AppModels

/// The snapshot states of `FrontPageView` (19-18).
enum FrontPageViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "front-page-list",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.frontPage(.loaded(.row)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "front-page-grid",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.frontPage(.loaded(.grid)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "front-page-loading",
                heights: .screen,
                factory: .init(
                    make: { BrowsingScenarios.frontPage(.loading) }, still: BrowsingScenarios.freezeIndicators
                )
            ),
            SnapshotState(
                id: "front-page-error",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.frontPage(.failed(.networkingFailed)) })
            ),
            SnapshotState(
                id: "front-page-empty",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.frontPage(.failed(.notFound)) })
            )
        ]
    }
}
