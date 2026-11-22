/// The snapshot states of `AgeWallView` (19-18).
enum AgeWallViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let reads = BrowsingScenarios.firstLaunchMinimumReads
        return [
            SnapshotState(
                id: "agewall-unticked",
                heights: .screen,
                factory: .init(signedIn: false, make: { BrowsingScenarios.ageWall(ticked: false) }, minimumReads: reads)
            ),
            SnapshotState(
                id: "agewall-ticked",
                heights: .screen,
                factory: .init(signedIn: false, make: { BrowsingScenarios.ageWall(ticked: true) }, minimumReads: reads)
            )
        ]
    }
}
