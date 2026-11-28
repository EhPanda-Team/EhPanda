import AppModels
import CoreGraphics

/// The snapshot states of `HomeView` (19-18).
enum HomeViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "home-populated",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1712, large: 1757, accessibility5: 4271),
                        landscape: .init(xSmall: 1656, large: 1725, accessibility5: 4352)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1809, large: 1858, accessibility5: 4605),
                        landscape: .init(xSmall: 1800, large: 1856, accessibility5: 4139)
                    )
                ),
                factory: .init(make: { TracerScenarios.home() }, prepare: TracerScenarios.cacheHomeArtwork)
            ),
            SnapshotState(
                id: "home-loading",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 943, accessibility5: 2590),
                        landscape: .init(xSmall: 856, large: 903, accessibility5: 2874)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2837),
                        landscape: .init(xSmall: 862, large: 896, accessibility5: 2371)
                    )
                ),
                factory: .init(
                    make: { BrowsingScenarios.home(loading: .loading) }, still: BrowsingScenarios.freezeIndicators
                )
            ),
            SnapshotState(
                id: "home-error",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 943, accessibility5: 2590),
                        landscape: .init(xSmall: 856, large: 903, accessibility5: 2874)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2837),
                        landscape: .init(xSmall: 862, large: 896, accessibility5: 2371)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.home(loading: .failed(.networkingFailed)) })
            )
        ]
    }
}
