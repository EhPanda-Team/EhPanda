import CoreGraphics

/// The snapshot states of `AgeWallView` (19-18).
enum AgeWallViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let reads = BrowsingScenarios.firstLaunchMinimumReads
        return [
            SnapshotState(
                id: "agewall-unticked",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1729),
                        landscape: .init(xSmall: 497, large: 515, accessibility5: 1509)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1547),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1547)
                    )
                ),
                factory: .init(signedIn: false, make: { BrowsingScenarios.ageWall(ticked: false) }, minimumReads: reads)
            ),
            SnapshotState(
                id: "agewall-ticked",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1729),
                        landscape: .init(xSmall: 497, large: 515, accessibility5: 1509)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1547),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1547)
                    )
                ),
                factory: .init(signedIn: false, make: { BrowsingScenarios.ageWall(ticked: true) }, minimumReads: reads)
            )
        ]
    }
}
