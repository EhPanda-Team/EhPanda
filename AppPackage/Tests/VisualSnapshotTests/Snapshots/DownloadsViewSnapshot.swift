import AppModels
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
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .row) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-grid",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .grid) }, prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-empty",
                heights: .screen,
                factory: ScenarioFactory(make: { LibraryScenarios.downloads([], mode: .row) }).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-active-failed",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(LibraryFixtures.activeFailedDownloads, mode: .row) },
                    prepare: artwork
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-delete-confirmation",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .row, confirming: .delete) }, prepare: artwork,
                    interact: LibraryScenarios.tapHeldRow
                ).restingAtTop()
            ),
            SnapshotState(
                id: "downloads-move-confirmation",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { LibraryScenarios.downloads(completed, mode: .row, confirming: .move) }, prepare: artwork,
                    interact: LibraryScenarios.tapHeldRow
                ).restingAtTop()
            )
        ]
    }
}
