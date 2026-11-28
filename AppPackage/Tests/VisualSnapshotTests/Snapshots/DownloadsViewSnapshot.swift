import AppModels
import CoreGraphics
import VisualSnapshotSupport

/// The snapshot states of `DownloadsView` (19-18).
enum DownloadsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = LibraryScenarios.cacheDownloadArtwork
        let completed = LibraryFixtures.completedDownloads
        return [
            SnapshotState(
                id: "downloads-list",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1184, large: 1190, accessibility5: 4534),
                        landscape: .init(xSmall: 1126, large: 1132, accessibility5: 2442)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 3773),
                        landscape: .init(xSmall: 1139, large: 1145, accessibility5: 2577)
                    )
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .row) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-grid",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1256, large: 1276, accessibility5: 5477),
                        landscape: .init(xSmall: 811, large: 1005, accessibility5: 8081)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1412, large: 1432, accessibility5: 5874),
                        landscape: .init(xSmall: 962, large: 1007, accessibility5: 9065)
                    )
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .grid) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-empty",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1202),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 754)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2577),
                        landscape: .init(xSmall: 962, large: 1007, accessibility5: 2577)
                    )
                ),
                factory: ScenarioFactory(make: { LibraryScenarios.downloads([], mode: .row) }).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-active-failed",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1184, large: 1190, accessibility5: 4534),
                        landscape: .init(xSmall: 1126, large: 1132, accessibility5: 2442)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 3772),
                        landscape: .init(xSmall: 1139, large: 1145, accessibility5: 2577)
                    )
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(LibraryFixtures.activeFailedDownloads, mode: .row) },
                    prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-delete-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .row, confirming: .delete) }, prepare: artwork,
                    interact: LibraryScenarios.tapHeldRow
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-move-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .row, confirming: .move) }, prepare: artwork,
                    interact: LibraryScenarios.tapHeldRow
                ).restingAtTop()
            )
        ]
    }
}
