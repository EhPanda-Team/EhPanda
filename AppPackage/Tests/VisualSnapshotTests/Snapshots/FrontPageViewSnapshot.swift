import AppModels
import CoreGraphics

/// The snapshot states of `FrontPageView` (19-18).
enum FrontPageViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "front-page-list",
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
                factory: .init(make: { BrowsingScenarios.frontPage(.loaded(.row)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "front-page-grid",
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
                factory: .init(make: { BrowsingScenarios.frontPage(.failed(.networkingFailed)) })
            ),
            SnapshotState(
                id: "front-page-empty",
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
                factory: .init(make: { BrowsingScenarios.frontPage(.failed(.notFound)) })
            )
        ]
    }
}
