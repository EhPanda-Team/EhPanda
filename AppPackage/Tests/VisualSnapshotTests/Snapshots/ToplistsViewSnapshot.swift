import AppModels
import Foundation
@testable import HomeFeature
import Resources

/// The snapshot states of `ToplistsView` (19-18).
enum ToplistsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "toplists-list",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.toplists(.loaded(.row)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "toplists-grid",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.toplists(.loaded(.grid)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "toplists-error",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.toplists(.failed(.networkingFailed)) })
            ),
            SnapshotState(
                id: "toplists-period-menu",
                heights: .screen,
                factory: .init(
                    make: { BrowsingScenarios.toplists(.loaded(.row)) }, prepare: artwork,
                    interact: { try await BrowsingScenarios.activate(String(localized: .timeRange), in: $0) }
                )
            ),
            SnapshotState(
                id: "app-wide-app-alert",
                heights: .screen,
                factory: .init(
                    make: { SettingsScenarios.jumpPageAlert() }, prepare: TracerScenarios.cacheHomeArtwork,
                    interact: { window in
                        try await RevealStep.reveal(.label(String(localized: .RLocalizable.jumpPage)))(window)
                        try await SettingsScenarios.holdAlertCaret(window)
                    }
                )
            )
        ]
    }
}
