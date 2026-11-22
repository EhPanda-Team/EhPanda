import AppModels
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
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .row, inspecting: 0) }, prepare: artwork,
                    interact: LibraryScenarios.tapHeldRow
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-inspector-error",
                heights: .screen,
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
