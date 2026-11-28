import AppModels
import CoreGraphics

/// The snapshot states of `SearchView` (19-18).
enum SearchViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "search-results-list",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1236, large: 1242, accessibility5: 4579),
                        landscape: .init(xSmall: 1126, large: 1132, accessibility5: 2090)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2183),
                        landscape: .init(xSmall: 1191, large: 1197, accessibility5: 2183)
                    )
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.searchResults(.loaded(.row)) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "search-results-grid",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1345, large: 1368, accessibility5: 5894),
                        landscape: .init(xSmall: 836, large: 1032, accessibility5: 8425)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 9011),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 3727)
                    )
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.searchResults(.loaded(.grid)) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "search-results-empty",
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
                factory: ScenarioFactory(make: { LibraryScenarios.searchResults(.failed(.notFound)) }).restingAtTop()
            ),
            SnapshotState(
                id: "search-results-error",
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
                factory: ScenarioFactory(
                    make: { LibraryScenarios.searchResults(.failed(.networkingFailed)) }
                ).restingAtTop()
            )
        ]
    }
}
