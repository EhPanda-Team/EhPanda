import AppModels
import CoreGraphics

/// The snapshot states of `FavoritesView` (19-18).
enum FavoritesViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "favorites-list",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1184, large: 1190, accessibility5: 4506),
                        landscape: .init(xSmall: 1126, large: 1132, accessibility5: 2414)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 3808),
                        landscape: .init(xSmall: 1139, large: 1145, accessibility5: 2344)
                    )
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.favorites(.loaded(.row)) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "favorites-grid",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1237, large: 1257, accessibility5: 5447),
                        landscape: .init(xSmall: 799, large: 992, accessibility5: 8051)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1393, large: 1414, accessibility5: 6204),
                        landscape: .init(xSmall: 863, large: 909, accessibility5: 9035)
                    )
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.favorites(.loaded(.grid)) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "favorites-empty",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 942),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 559)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2344),
                        landscape: .init(xSmall: 863, large: 902, accessibility5: 2344)
                    )
                ),
                factory: ScenarioFactory(make: { LibraryScenarios.emptyFavorites() }).restingAtTop()
            ),
            SnapshotState(
                id: "favorites-signed-out",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 912),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 499)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2344),
                        landscape: .init(xSmall: 863, large: 902, accessibility5: 2344)
                    )
                ),
                factory: ScenarioFactory(
                    signedIn: false, make: { LibraryScenarios.favorites(.loaded(.row)) }
                ).restingAtTop()
            ),
            SnapshotState(
                id: "favorites-category-menu",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27, menus at the screen height: 「選單可以按你推薦處理」"
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.favorites(.loaded(.row)) }, prepare: artwork,
                    interact: LibraryScenarios.openCategoryMenu
                ).restingAtTop()
            )
        ]
    }
}
