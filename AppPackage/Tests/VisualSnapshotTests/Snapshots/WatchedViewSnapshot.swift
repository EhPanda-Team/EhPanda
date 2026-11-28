import AppModels
import CoreGraphics

/// The snapshot states of `WatchedView` (19-18).
enum WatchedViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "watched-list",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1188, large: 1188, accessibility5: 4445),
                        landscape: .init(xSmall: 1078, large: 1078, accessibility5: 1956)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2373),
                        landscape: .init(xSmall: 1143, large: 1143, accessibility5: 2125)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.watched(.loaded(.row)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "watched-grid",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1297, large: 1314, accessibility5: 5760),
                        landscape: .init(xSmall: 788, large: 978, accessibility5: 8291)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 8877),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 3593)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.watched(.loaded(.grid)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "watched-empty",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 912),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 594)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.watched(.failed(.notFound)) })
            ),
            SnapshotState(
                id: "watched-error",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 913),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 594)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
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
