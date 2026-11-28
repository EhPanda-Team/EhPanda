import AppModels
import CoreGraphics
import VisualSnapshotSupport

/// The snapshot states of `DownloadInspectorView` (19-18).
enum DownloadInspectorViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = LibraryScenarios.cacheDownloadArtwork
        let completed = LibraryFixtures.completedDownloads
        return [
            SnapshotState(
                id: "downloads-inspector",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 2339),
                        landscape: .init(xSmall: 763, large: 795, accessibility5: 1366)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1746),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1746)
                    )
                ),
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .row, inspecting: 0) }, prepare: artwork,
                    interact: LibraryScenarios.tapHeldRow
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-inspector-error",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 2279),
                        landscape: .init(xSmall: 763, large: 795, accessibility5: 1366)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1746),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1746)
                    )
                ),
                factory: ScenarioFactory(
                    make: {
                        LibraryScenarios.downloads(LibraryFixtures.activeFailedDownloads, mode: .row, inspecting: 1)
                    },
                    prepare: artwork, interact: LibraryScenarios.tapHeldRow
                ).restingAtTop()
            )
        ]
    }
}
