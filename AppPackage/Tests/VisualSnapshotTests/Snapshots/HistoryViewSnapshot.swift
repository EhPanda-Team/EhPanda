import AppModels
import Foundation
import Resources

/// The snapshot states of `HistoryView` (19-18).
enum HistoryViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "history-list",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.history(.row) }, prepare: artwork)
            ),
            SnapshotState(
                id: "history-grid",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.history(.grid) }, prepare: artwork)
            ),
            SnapshotState(
                id: "history-empty",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.history(nil) })
            ),
            SnapshotState(
                id: "history-clear-confirmation",
                heights: .screen,
                factory: .init(
                    make: { BrowsingScenarios.history(.row) }, prepare: artwork,
                    interact: { window in
                        try await BrowsingScenarios.activate(String(localized: .RLocalizable.clear), in: window)
                        try await RevealStep.awaitDialogPlatter()(window)
                    }
                )
            )
        ]
    }
}
