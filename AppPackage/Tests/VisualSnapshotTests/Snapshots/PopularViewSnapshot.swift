import AppModels
import CoreGraphics

/// The snapshot states of `PopularView` (19-18).
enum PopularViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "popular-list",
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
                factory: .init(make: { BrowsingScenarios.popular(.loaded(.row)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "popular-grid",
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
                factory: .init(make: { BrowsingScenarios.popular(.failed(.networkingFailed)) })
            )
        ]
    }
}
