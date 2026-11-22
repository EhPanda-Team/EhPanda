import AppModels

/// The snapshot states of `WatchedView` (19-18).
enum WatchedViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "watched-list",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.watched(.loaded(.row)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "watched-grid",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.watched(.loaded(.grid)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "watched-empty",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.watched(.failed(.notFound)) })
            ),
            SnapshotState(
                id: "watched-error",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.watched(.failed(.networkingFailed)) })
            ),
            SnapshotState(
                id: "watched-signed-out",
                heights: .screen,
                factory: .init(signedIn: false, make: { BrowsingScenarios.watched(.loaded(.row)) }, prepare: artwork)
            )
        ]
    }
}
