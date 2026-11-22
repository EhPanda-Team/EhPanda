import AppModels
import Foundation
import Resources

/// The snapshot states of `LibraryView` (19-18).
enum LibraryViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "shell-library-sidebar",
                heights: .screen,
                factory: .init(make: { BrowsingScenarios.library(selection: nil) })
            ),
            // Favorites under the menu hides its search field on scroll, so the list is brought to rest at its top
            // first, as the Favorites scenarios are: hosted early in a process it kept the field 2 points short
            // (run 42455556948, every text size but xSmall).
            SnapshotState(
                id: "shell-library-title-menu",
                heights: .screen,
                factory: ScenarioFactory(
                    make: { BrowsingScenarios.library(selection: .favorites(-1)) },
                    prepare: TracerScenarios.cacheHomeArtwork,
                    interact: { try await BrowsingScenarios.activate(String(localized: .RLocalizable.library), in: $0) }
                ).restingAtTop()
            )
        ]
    }
}
